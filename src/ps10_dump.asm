; PS10 MCU dump firmware for the FMD FT61E0A5 (PIC16F1-compatible core).
;
; Runs as an application behind the stock Tuya bootloader (0x000-0x5FF is never
; touched; this image is linked at 0x600 like the stock firmware) and speaks
; just enough of the Tuya MCU serial protocol for ESPHome's `tuya:` and for
; `tuya_mcu_dfu`:
;
;   0x00 heartbeat       -> [00] once after reset, then [01]
;   0x01 product query   -> {"p":"ps10dump","v":"<VERSION>","m":0}
;   0x02 working mode    -> empty (MCU handles its own network LED)
;   0x03 Wi-Fi state     -> empty ack
;   0x08 status query    -> DP 200 raw [00 00 00 00]
;   0x06 DP 200 raw      -> dump request, reply 0x07 DP 201 raw (below)
;   0x06 any other DP    -> echoed back as 0x07 (keeps tuya: in step)
;   0x0A upgrade start   -> stock contract: data EEPROM 0x00 and 0x01 = 0xFF,
;                           then RESET into the bootloader, which answers the
;                           retried 0x0A. This is how both DFU and rollback to
;                           the stock image work.
;
; Dump request, DP 200 (raw, 4 bytes): [dspace, addr_hi, addr_lo, count]
;   'F' 0x46  program flash, word address, count 1..32 words (2 bytes each, LE)
;   'C' 0x43  configuration dspace (EECON1.CFGS=1), word address, 1..32 words
;   'E' 0x45  data EEPROM, byte address, count 1..64 bytes
; Reply DP 201 (raw): [dspace, addr_hi, addr_lo, count, data...]; count 0 means
; the request was rejected.
;
; Side effects: none besides the UART. Memory is only ever read (EECON1.WREN
; is never set, except by the 0x0A handler). No pin other than the Wi-Fi UART
; (USART1: TX PA6, RX PA7) is configured or driven; the UART is set up exactly
; as the stock 1.0.5 firmware does it. Interrupts stay disabled.
; Register names and values: FT61E0Ax datasheet V1.02 (docs/datasheets/), and
; docs/ft61e0a5.md.

        processor 16f1829
        radix   dec
        errorlevel -302, -306

#ifndef VERSION_STR
#define VERSION_STR "0.1.0-dump"
#endif

; ---- core registers (any bank) ---------------------------------------------
INDF0   equ 0x00
INDF1   equ 0x01
STATUS  equ 0x03
FSR0L   equ 0x04
FSR0H   equ 0x05
FSR0    equ 0
WREG    equ 0x09
INTCON  equ 0x0B
C       equ 0
Z       equ 2

; ---- FT61E0A5 registers (datasheet names) ----------------------------------
; bank 1
OSCCON  equ 0x19        ; 0x099: 0x71 = SysClk HIRC 16 MHz, divider 1 (as stock)
PCKEN   equ 0x1A        ; 0x09A: peripheral clock enables, bit5 UART1EN
WDTCON  equ 0x17        ; 0x097: 0x55 = WDTPRE /4, WDTPS 32768, SWDTEN: ~4 s on LIRC (as stock)
TRISA   equ 0x0C        ; 0x08C
; bank 3: data EEPROM / PROM controller
EEADRL  equ 0x11
EEADRH  equ 0x12
EEDATL  equ 0x13
EEDATH  equ 0x14
EECON1  equ 0x15
EECON2  equ 0x16
RD      equ 0
WR      equ 1
WREN    equ 2
CFGS    equ 6
EEPGD   equ 7
MISC0   equ 0x1D        ; 0x19D: WCKSEL = 00, WDT clock LIRC (stock clears it)
; bank 4
ODCON0  equ 0x1F        ; 0x21F: bit0 UR1OD, USART1 TX open drain (as stock)
; bank 9: USART1, the Tuya link (TX PA6, RX PA7: AFP0/AFP1 left at reset)
UDAT    equ 0x0C        ; 0x48C UR1DATAL
UCTL0   equ 0x0E        ; 0x48E UR1IER = 0x23 (TCEN, TE, RXNE; unused, GIE stays 0)
UCTL1   equ 0x0F        ; 0x48F UR1LCR = 0x01: 8 bits, no parity, 1 stop
UCTL3   equ 0x11        ; 0x491 UR1MCR = 0x18: TXEN, RXEN
USTAT   equ 0x12        ; 0x492 UR1LSR: bit0 RXNEF, bit5 TXEF
UBRGL   equ 0x14        ; 0x494 UR1DLL = 104: 16 MHz / (16 * 104) = 9615 baud
UBRGH   equ 0x15        ; 0x495 UR1DLH = 0
UCTL2   equ 0x1C        ; 0x49C UR1TC: bit0 TCF, write 1 to clear (as stock)
RXRDY   equ 0
TXIDLE  equ 5

; ---- variables (common RAM, visible from every bank) -------------------------
state   equ 0x70        ; parser state
cmd     equ 0x71
lenhi   equ 0x72
lenlo   equ 0x73
cnt     equ 0x74        ; payload bytes stored
rsum    equ 0x75        ; checksum of the frame being received
tsum    equ 0x76        ; checksum of the frame being sent
tmp     equ 0x77
flags   equ 0x78        ; bit0: first heartbeat answered, bit1: frame overflow
idle_l  equ 0x79
idle_h  equ 0x7A
dspace   equ 0x7B
ahi     equ 0x7C
alo     equ 0x7D
n       equ 0x7E
tmp2    equ 0x7F
F_HB    equ 0
F_OVF   equ 1

RXBUF   equ 0x2000      ; linear address of bank 0 GPR 0x20
RXMAX   equ 64

; ---- vectors ----------------------------------------------------------------
        org     0x600
        movlp   0x00
        goto    main
        nop
        nop
        org     0x604           ; interrupt vector of the application
        retfie                  ; never enabled

; ---- init -------------------------------------------------------------------
main:
        clrf    INTCON          ; no interrupts
        clrwdt
        movlb   1
        movlw   0x71            ; system clock, as stock
        movwf   OSCCON
        movlb   3
        clrf    MISC0           ; watchdog, as stock
        movlw   0x55
        movlb   1
        movwf   WDTCON
        clrwdt
        bsf     PCKEN, 5        ; UART clock
        bsf     TRISA, 7        ; PA7 = USART1 RX in, PA6 = USART1 TX out: what
        bcf     TRISA, 6        ; stock does (the bootloader drives them too)
        movlb   9
        movlw   0x23
        movwf   UCTL0
        movlw   0x01
        movwf   UCTL1
        movlw   0x18
        movwf   UCTL3
        movlw   0x68
        movwf   UBRGL
        clrf    UBRGH
        bsf     UCTL2, 0
        movlb   4
        bsf     ODCON0, 0
        clrf    flags
        clrf    state

; ---- main loop: poll the UART, parse Tuya frames -----------------------------
loop:
        clrwdt
        movlb   9
        btfsc   USTAT, RXRDY
        goto    got_byte
        movf    state, f        ; idle timeout while inside a frame
        btfsc   STATUS, Z
        goto    loop
        incfsz  idle_l, f
        goto    loop
        incf    idle_h, f
        movlw   8
        subwf   idle_h, w
        btfsc   STATUS, C
        clrf    state           ; ~0.5 M polls without a byte: resync
        goto    loop

got_byte:
        movf    UDAT, w
        movwf   tmp
        clrf    idle_l
        clrf    idle_h
        movf    state, w
        brw
        goto    st_h1
        goto    st_h2
        goto    st_ver
        goto    st_cmd
        goto    st_lenh
        goto    st_lenl
        goto    st_data
        goto    st_sum

st_h1:  movlw   0x55
        xorwf   tmp, w
        btfss   STATUS, Z
        goto    loop
        movlw   0x55
        movwf   rsum
        movlw   1
        movwf   state
        goto    loop

st_h2:  movlw   0xAA
        xorwf   tmp, w
        btfsc   STATUS, Z
        goto    st_h2ok
        movlw   0x55            ; 55 55 AA: stay in sync
        xorwf   tmp, w
        btfss   STATUS, Z
        clrf    state
        goto    loop
st_h2ok:
        movlw   0xAA
        addwf   rsum, f
        movlw   2
        movwf   state
        goto    loop

st_ver: call    sum_next
        goto    loop

st_cmd: movf    tmp, w
        movwf   cmd
        call    sum_next
        goto    loop

st_lenh:
        movf    tmp, w
        movwf   lenhi
        call    sum_next
        goto    loop

st_lenl:
        movf    tmp, w
        movwf   lenlo
        addwf   rsum, f
        clrf    cnt
        bcf     flags, F_OVF
        movlw   RXMAX + 1       ; more than RXMAX bytes: receive, don't keep
        subwf   lenlo, w
        btfsc   STATUS, C
        bsf     flags, F_OVF
        movf    lenhi, f
        btfss   STATUS, Z
        bsf     flags, F_OVF
        movlw   6
        movwf   state
        movf    lenhi, w
        iorwf   lenlo, w
        btfsc   STATUS, Z
        incf    state, f        ; no payload: checksum next
        goto    loop

st_data:
        movf    tmp, w
        addwf   rsum, f
        btfsc   flags, F_OVF
        goto    st_skip
        movlw   low RXBUF       ; store at RXBUF + cnt
        addwf   cnt, w
        movwf   FSR0L
        movlw   high RXBUF
        movwf   FSR0H
        movf    tmp, w
        movwf   INDF0
        incf    cnt, f
st_skip:
        movf    lenlo, w        ; 16-bit remaining count
        btfsc   STATUS, Z
        decf    lenhi, f
        decf    lenlo, f
        movf    lenhi, w
        iorwf   lenlo, w
        btfsc   STATUS, Z
        incf    state, f
        goto    loop

st_sum: clrf    state
        movf    tmp, w
        xorwf   rsum, w
        btfss   STATUS, Z
        goto    loop            ; bad checksum: drop
        btfsc   flags, F_OVF
        goto    loop            ; too long for us: drop
        call    dispatch
        goto    loop

sum_next:
        movf    tmp, w
        addwf   rsum, f
        incf    state, f
        return

; ---- command dispatch --------------------------------------------------------
dispatch:
        movf    cmd, w
        btfsc   STATUS, Z
        goto    c_heartbeat
        xorlw   0x01
        btfsc   STATUS, Z
        goto    c_product
        xorlw   0x01 ^ 0x02
        btfsc   STATUS, Z
        goto    c_empty
        xorlw   0x02 ^ 0x03
        btfsc   STATUS, Z
        goto    c_empty
        xorlw   0x03 ^ 0x06
        btfsc   STATUS, Z
        goto    c_dp
        xorlw   0x06 ^ 0x08
        btfsc   STATUS, Z
        goto    c_query
        xorlw   0x08 ^ 0x0A
        btfsc   STATUS, Z
        goto    c_upgrade
        return

c_heartbeat:
        clrf    lenhi
        movlw   1
        call    tx_header       ; cmd 0x00, length 1
        movlw   0x00
        btfsc   flags, F_HB
        movlw   0x01
        call    tx_byte
        bsf     flags, F_HB
        goto    tx_sum

c_empty:                        ; reply with the same command, no data
        clrf    lenhi
        movlw   0
        call    tx_header
        goto    tx_sum

c_product:
        clrf    lenhi
        movlw   PRODUCT_LEN
        call    tx_header
        clrf    n
c_prod_l:
        movf    n, w
        call    product_str
        call    tx_byte
        incf    n, f
        movlw   PRODUCT_LEN
        xorwf   n, w
        btfss   STATUS, Z
        goto    c_prod_l
        goto    tx_sum

c_query:                        ; report DP 200 so tuya: finishes its init
        movlw   0x07
        movwf   cmd
        clrf    lenhi
        movlw   8
        call    tx_header
        movlw   200
        call    tx_byte
        movlw   0x00            ; raw
        call    tx_byte
        movlw   0
        call    tx_byte
        movlw   4
        call    tx_byte
        movlw   0
        call    tx_byte
        movlw   0
        call    tx_byte
        movlw   0
        call    tx_byte
        movlw   0
        call    tx_byte
        goto    tx_sum

; 0x06: DP 200 raw len 4 is a dump request; anything else is echoed as 0x07
c_dp:
        movlw   0x07
        movwf   cmd
        movlw   8
        xorwf   cnt, w
        btfss   STATUS, Z
        goto    c_echo
        movlw   low RXBUF
        movwf   FSR0L
        movlw   high RXBUF
        movwf   FSR0H
        moviw   0[FSR0]
        xorlw   200
        btfss   STATUS, Z
        goto    c_echo
        moviw   1[FSR0]         ; type raw
        btfss   STATUS, Z
        goto    c_echo
        moviw   2[FSR0]
        btfss   STATUS, Z
        goto    c_echo
        moviw   3[FSR0]
        xorlw   4
        btfss   STATUS, Z
        goto    c_echo
        moviw   4[FSR0]
        movwf   dspace
        moviw   5[FSR0]
        movwf   ahi
        moviw   6[FSR0]
        movwf   alo
        moviw   7[FSR0]
        movwf   n
        goto    dump

c_echo:
        clrf    lenhi
        movf    cnt, w
        call    tx_header
        movlw   low RXBUF
        movwf   FSR0L
        movlw   high RXBUF
        movwf   FSR0H
        movf    cnt, f
        btfsc   STATUS, Z
        goto    tx_sum
c_echo_l:
        moviw   FSR0++
        call    tx_byte
        decfsz  cnt, f
        goto    c_echo_l
        goto    tx_sum

; ---- dump --------------------------------------------------------------------
; dspace/ahi/alo/n set. tmp2 = bytes per item (2 = word, 1 = byte)
dump:
        movlw   2
        movwf   tmp2
        movlw   'F'
        xorwf   dspace, w
        btfsc   STATUS, Z
        goto    dump_w
        movlw   'C'
        xorwf   dspace, w
        btfsc   STATUS, Z
        goto    dump_w
        movlw   'E'
        xorwf   dspace, w
        btfss   STATUS, Z
        goto    dump_bad
        movlw   1
        movwf   tmp2
        movf    n, w            ; 1..64 bytes
        btfsc   STATUS, Z
        goto    dump_bad
        sublw   64
        btfss   STATUS, C
        goto    dump_bad
        movf    n, w
        movwf   tmp             ; data length
        goto    dump_go
dump_w:
        movf    n, w            ; 1..32 words
        btfsc   STATUS, Z
        goto    dump_bad
        sublw   32
        btfss   STATUS, C
        goto    dump_bad
        lslf    n, w
        movwf   tmp
        goto    dump_go
dump_bad:
        clrf    n
        clrf    tmp
dump_go:
        ; 0x07 [201][00][00][4+len][dspace][ahi][alo][n][data]
        clrf    lenhi
        movlw   8
        addwf   tmp, w
        call    tx_header
        movlw   201
        call    tx_byte
        movlw   0
        call    tx_byte
        movlw   0
        call    tx_byte
        movlw   4
        addwf   tmp, w
        call    tx_byte
        movf    dspace, w
        call    tx_byte
        movf    ahi, w
        call    tx_byte
        movf    alo, w
        call    tx_byte
        movf    n, w
        call    tx_byte
        movf    n, f
        btfsc   STATUS, Z
        goto    tx_sum
        movlb   3
        movf    ahi, w
        movwf   EEADRH
        movf    alo, w
        movwf   EEADRL
dump_l:
        movlb   3
        movlw   0x80            ; EEPGD: program flash
        movwf   EECON1
        movlw   'C'
        xorwf   dspace, w
        btfsc   STATUS, Z
        bsf     EECON1, CFGS    ; configuration dspace
        movlw   'E'
        xorwf   dspace, w
        btfsc   STATUS, Z
        clrf    EECON1          ; data EEPROM
        bsf     EECON1, RD
        nop                     ; PROM/UCFG data after 2 cycles,
        nop
        nop                     ; DATA EEPROM after 4 (datasheet 10.3.4)
        nop
        movf    EEDATL, w
        call    tx_byte
        movlw   2
        xorwf   tmp2, w
        btfss   STATUS, Z
        goto    dump_next
        movlb   3
        movf    EEDATH, w
        call    tx_byte
dump_next:
        movlb   3
        clrf    EECON1
        incf    EEADRL, f
        btfsc   STATUS, Z
        incf    EEADRH, f
        decfsz  n, f
        goto    dump_l
        goto    tx_sum

; ---- 0x0A: hand over to the bootloader -----------------------------------------
c_upgrade:
        movlw   0x00
        call    ee_ff
        movlw   0x01
        call    ee_ff
        reset

ee_ff:                          ; data EEPROM[W] = 0xFF (sequence as stock)
        movlb   3
        movwf   EEADRL
        clrf    EEADRH
        movlw   0xFF
        movwf   EEDATL
        bcf     EECON1, CFGS
        bcf     EECON1, EEPGD
        bsf     EECON1, WREN
        movlw   0x55
        movwf   EECON2
        movlw   0xAA
        movwf   EECON2
        bsf     EECON1, WR
        nop
        nop
        nop
        nop
ee_wait:
        clrwdt
        movlb   3
        btfsc   EECON1, WR
        goto    ee_wait
        bcf     EECON1, WREN
        return

; ---- UART tx ---------------------------------------------------------------------
; tx_header: W = length low (lenhi = length high), cmd = command
tx_header:
        movwf   lenlo
        clrf    tsum
        movlw   0x55
        call    tx_byte
        movlw   0xAA
        call    tx_byte
        movlw   0x03            ; protocol version, as the stock MCU
        call    tx_byte
        movf    cmd, w
        call    tx_byte
        movf    lenhi, w
        call    tx_byte
        movf    lenlo, w
        goto    tx_byte

tx_sum:
        movf    tsum, w
        ; fall through
tx_byte:
        movlb   9
        clrwdt
        btfss   USTAT, TXIDLE
        goto    tx_byte
        movwf   UDAT
        addwf   tsum, f
tx_wait:
        clrwdt
        btfss   USTAT, TXIDLE
        goto    tx_wait
        return

; ---- product information -----------------------------------------------------------
product_str:
        brw
PRODUCT_START:
        dt      "{\"p\":\"ps10dump\",\"v\":\"", VERSION_STR, "\",\"m\":0}"
PRODUCT_END:
PRODUCT_LEN equ PRODUCT_END - PRODUCT_START

        end
