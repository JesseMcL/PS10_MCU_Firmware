; Tuya PS10 MCU firmware 1.0.5 (product o9a6at9cyfchb47y), FMD FT61E0A5.
;
; Disassembled from the official update image (reference/ps10-mcu-1.0.5.bin,
; md5 9bd5f57fc1efad47a285cd7e0d951c7b) with tools/disasm.py. tools/build.py
; reassembles it and checks the result is identical, word for word. Keep it
; that way: this branch is the factory firmware, for reference and rollback.
;
; Opcodes are PIC16F1 (gpasm); the build converts them to the FMD encoding.
; Register comments use the datasheet's names (docs/ft61e0a5.md).
;
; Landmarks (see docs/pinout.md and docs/bootloader.md):
;   0x0000-0x0018  interrupt stub + nops: never programmed (the bootloader
;                  discards image bytes below 0x600)
;   0x0600         reset vector -> 0x06E2 C startup -> main (init calls from 0x1E88)
;   0x0604         interrupt: radar soft UART TX (TIM1, PB3) and RX
;                  (TIM2 + EINT4, PB4), USART1 RX (Tuya), TIM4 0.2 ms tick
;                  (button PA3, switch PC0, radar OUT PB7 timing)
;   0x0810         LD2410C 0x00A9 Bluetooth password "123465"
;   0x08ED/0x0978  LD2410C 0x0064 sensitivity / 0x0060 max gates
;   0x0D0B         end of a radar config pass: password if armed, else end-config
;   0x0E6B         data EEPROM write
;   0x14D0         LD2410C frame parser (F4F3F2F1 / FDFCFBFA)
;   0x16E0         Tuya command dispatch (0x03 arms the password on status 0/1,
;                  0x0A clears EEPROM 0/1 and resets into the bootloader)
;   0x1AF0-0x1BC5  hardware init (clock, ports, UART, timers, ADC)
;   0x1F0E/0x1F2B  output (PA2, triac) on/off
;   0x1FF5         USART1 transmit byte
;
        processor 16f1789   ; any PIC16F1 with >= 10K words; only the core matters
        radix   dec
        errorlevel -302, -306, -202
FSR0    equ 0           ; moviw/movwi operand
FSR1    equ 1
FSR0L   equ 4           ; addfsr operand
FSR1L   equ 6


        org 0x0000
        nop
        nop
        nop
        nop
        movwf 0x70                  ; common 0x70
        swapf 0x08, 0               ; BSR
        movwf 0x71                  ; common 0x71
        movlb 0x1F
        swapf 0x71, 0               ; common 0x71
        movwf 0x66
        swapf 0x03, 0               ; STATUS
        swapf 0x09, 0               ; WREG
        movwf 0x64
        movf 0x0A, 0                ; PCLATH
        movwf 0x67
        movf 0x04, 0                ; FSR0L
        movwf 0x68
        movf 0x05, 0                ; FSR0H
        movwf 0x69
        movf 0x06, 0                ; FSR1L
        movwf 0x6A
        movf 0x07, 0                ; FSR1H
        movwf 0x6B
        movf 0x70, 0                ; common 0x70
        movwf 0x65
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        movlp 0x06
        goto L_06E2
        nop
        movlw 0x01
        bsf 0x7E, 0                 ; common 0x7E
        movlp 0x06
        movlb 0x04
        btfss 0x15, 0               ; TIM1IER
        andlw 0x00
        btfss 0x16, 0               ; TIM1SR1
        andlw 0x00
        btfss 0x09, 0               ; WREG
        goto L_063F
        bsf 0x16, 0                 ; TIM1SR1
        movlb 0x02
        movf 0x20, 0
        btfsc 0x03, 2               ; STATUS
        goto L_0618
        movlb 0x00
        bcf 0x0D, 3                 ; PORTB
        movlb 0x02
        clrf 0x20
        goto L_0639
L_0618:
        movlw 0x08
        subwf 0x21, 0
        btfsc 0x03, 0               ; STATUS
        goto L_0632
        movf 0x22, 0
        addlw 0x24
        movwf 0x06                  ; FSR1L
        movlw 0x01
        movwf 0x07                  ; FSR1H
        movf 0x01, 0                ; INDF1
        movwf 0x77                  ; common 0x77
        incf 0x21, 0
        goto L_0626
L_0625:
        lsrf 0x77, 1                ; common 0x77
L_0626:
        decfsz 0x09, 1              ; WREG
        goto L_0625
        btfss 0x77, 0               ; common 0x77
        goto L_062D
        movlb 0x00
        bsf 0x0D, 3                 ; PORTB
        goto L_062F
L_062D:
        movlb 0x00
        bcf 0x0D, 3                 ; PORTB
L_062F:
        movlb 0x02
        incf 0x21, 1
        goto L_0639
L_0632:
        movlb 0x00
        bsf 0x0D, 3                 ; PORTB
        movlb 0x02
        clrf 0x20
        incf 0x20, 1
        clrf 0x21
        incf 0x22, 1
L_0639:
        movf 0x23, 0
        subwf 0x22, 0
        btfss 0x03, 0               ; STATUS
        goto L_063F
        movlb 0x04
        bcf 0x11, 0                 ; TIM1CR1
L_063F:
        movlw 0x01
        movlb 0x06
        btfss 0x0D, 0               ; TIM2IER
        andlw 0x00
        btfss 0x0E, 0               ; TIM2SR1
        andlw 0x00
        btfss 0x09, 0               ; WREG
        goto L_0665
        bsf 0x0E, 0                 ; TIM2SR1
        movlb 0x01
        movlw 0x09
        incf 0x5C, 1
        xorwf 0x5C, 0
        btfss 0x03, 2               ; STATUS
        goto L_0656
        movlb 0x06
        bcf 0x0C, 0                 ; TIM2CR1
        movlb 0x01
        movf 0x49, 0
        movlp 0x1B
        call L_1B5C
        movlp 0x06
        goto L_0665
L_0656:
        movlb 0x00
        btfss 0x0D, 4               ; PORTB
        goto L_0665
        movlw 0x01
        movwf 0x77                  ; common 0x77
        movlb 0x01
        movf 0x5C, 0
        addlw 0xFF
        incf 0x09, 1                ; WREG
        goto L_0661
L_0660:
        lslf 0x77, 1                ; common 0x77
L_0661:
        decfsz 0x09, 1              ; WREG
        goto L_0660
        movf 0x77, 0                ; common 0x77
        iorwf 0x49, 1
L_0665:
        movlw 0x01
        movlb 0x02
        btfss 0x12, 0               ; TIM4IER
        andlw 0x00
        btfss 0x13, 0               ; TIM4SR
        andlw 0x00
        btfss 0x09, 0               ; WREG
        goto L_06C2
        bsf 0x13, 0                 ; TIM4SR
        movlb 0x01
        incf 0x3D, 1
        btfsc 0x03, 2               ; STATUS
        incf 0x3E, 1
        movlw 0x05
        incf 0x4C, 1
        subwf 0x4C, 0
        btfss 0x03, 0               ; STATUS
        goto L_0684
        clrf 0x4C
        movlb 0x00
        btfsc 0x0C, 3               ; PORTA
        goto L_067F
        movlb 0x01
        incf 0x22, 1
        btfsc 0x03, 2               ; STATUS
        incf 0x23, 1
L_067F:
        movlb 0x00
        btfsc 0x0E, 0               ; PORTC
        goto L_0684
        movlb 0x01
        incf 0x25, 1
L_0684:
        movlb 0x01
        movf 0x40, 0
        movwf 0x78                  ; common 0x78
        movf 0x3F, 0
        movwf 0x77                  ; common 0x77
        incf 0x3F, 1
        btfsc 0x03, 2               ; STATUS
        incf 0x40, 1
        movlw 0x01
        subwf 0x78, 0               ; common 0x78
        movlw 0xF4
        btfsc 0x03, 2               ; STATUS
        subwf 0x77, 0               ; common 0x77
        btfss 0x03, 0               ; STATUS
        goto L_06C2
        clrf 0x3F
        clrf 0x40
        incf 0x4B, 1
        incf 0x4F, 1
        incf 0x41, 1
        btfsc 0x03, 2               ; STATUS
        incf 0x42, 1
        incf 0x4A, 1
        movf 0x2E, 0
        btfsc 0x03, 2               ; STATUS
        goto L_06A1
        incf 0x32, 1
        btfsc 0x03, 2               ; STATUS
        incf 0x33, 1
L_06A1:
        movf 0x31, 0
        btfsc 0x03, 2               ; STATUS
        goto L_06B4
        movlb 0x00
        btfss 0x0D, 7               ; PORTB
        goto L_06AD
        movlb 0x01
        clrf 0x34
        clrf 0x35
        clrf 0x36
        clrf 0x37
        goto L_06B4
L_06AD:
        movlw 0x01
        movlb 0x01
        addwf 0x34, 1
        movlw 0x00
        addwfc 0x35, 1
        addwfc 0x36, 1
        addwfc 0x37, 1
L_06B4:
        movf 0x38, 0
        btfsc 0x03, 2               ; STATUS
        goto L_06C2
        movlb 0x00
        btfss 0x0D, 7               ; PORTB
        goto L_06BE
        movlb 0x01
        clrf 0x39
        clrf 0x3A
        goto L_06C2
L_06BE:
        movlb 0x01
        incf 0x39, 1
        btfsc 0x03, 2               ; STATUS
        incf 0x3A, 1
L_06C2:
        movlb 0x09
        btfsc 0x0E, 0               ; UR1IER
        btfss 0x12, 0               ; UR1LSR
        goto L_06CA
        movf 0x0C, 0                ; UR1DATAL
        movlp 0x1B
        call L_1B7D
        movlp 0x06
L_06CA:
        movlb 0x00
        movf 0x14, 0                ; EPIF0
        movlb 0x01
        andwf 0x14, 0               ; EPIE0
        btfsc 0x03, 2               ; STATUS
        goto L_06E0
        movlb 0x00
        btfsc 0x14, 4               ; EPIF0
        btfsc 0x0D, 4               ; PORTB
        goto L_06DD
        movlw 0x09
        movlb 0x01
        subwf 0x5C, 0
        btfss 0x03, 0               ; STATUS
        goto L_06DD
        clrf 0x49
        clrf 0x5C
        movlb 0x06
        bsf 0x0C, 0                 ; TIM2CR1
L_06DD:
        movlw 0xFF
        movlb 0x00
        movwf 0x14                  ; EPIF0
L_06E0:
        bcf 0x7E, 0                 ; common 0x7E
        retfie
L_06E2:
        movlp 0x06
        goto L_06E4
L_06E4:
        movlw 0xA0
        movwf 0x79                  ; common 0x79
        movwf 0x6F
        movlb 0x01
        movlw 0x57
        movwf 0x59
        movwf 0x5A
        movlw 0xFF
        movwf 0x5B
        movlw 0x09
        movwf 0x5C
        movlw 0xFF
        movwf 0x5D
        movlw 0xB4
        movwf 0x04                  ; FSR0L
        movlw 0x9C
        movwf 0x05                  ; FSR0H
        movlw 0x20
        movwf 0x06                  ; FSR1L
        movlw 0x03
        movwf 0x07                  ; FSR1H
        movlw 0x48
        clrf 0x7F                   ; common 0x7F
        movlp 0x1B
        call L_1B10
        movlp 0x06
        movlw 0x6C
        movwf 0x04                  ; FSR0L
        movlw 0x9C
        movwf 0x05                  ; FSR0H
        movlw 0xA0
        movwf 0x06                  ; FSR1L
        movlw 0x03
        movwf 0x07                  ; FSR1H
        movlw 0x48
        clrf 0x7F                   ; common 0x7F
        movlp 0x1B
        call L_1B10
        movlp 0x06
        movlw 0x90
        movwf 0x04                  ; FSR0L
        movlw 0x23
        movwf 0x05                  ; FSR0H
        movlw 0x60
        movwf 0x7E                  ; common 0x7E
        clrf 0x7F                   ; common 0x7F
        movlp 0x1B
        call L_1B04
        movlp 0x06
        clrf 0x70                   ; common 0x70
        clrf 0x71                   ; common 0x71
        clrf 0x72                   ; common 0x72
        clrf 0x73                   ; common 0x73
        clrf 0x74                   ; common 0x74
        movlb 0x00
        movlw 0xA0
        clrf 0x6D
        clrf 0x6E
        movwf 0x04                  ; FSR0L
        movlw 0x00
        movwf 0x05                  ; FSR0H
        movlw 0x31
        movwf 0x7E                  ; common 0x7E
        clrf 0x7F                   ; common 0x7F
        movlp 0x1B
        call L_1B04
        movlp 0x06
        movlw 0x20
        movwf 0x04                  ; FSR0L
        movlw 0x01
        movwf 0x05                  ; FSR0H
        movlw 0x49
        movwf 0x7E                  ; common 0x7E
        clrf 0x7F                   ; common 0x7F
        movlp 0x1B
        call L_1B04
        movlp 0x06
        movlw 0xA0
        movwf 0x04                  ; FSR0L
        movlw 0x01
        movwf 0x05                  ; FSR0H
        movlw 0x4A
        movwf 0x7E                  ; common 0x7E
        clrf 0x7F                   ; common 0x7F
        movlp 0x1B
        call L_1B04
        movlp 0x06
        movlw 0x20
        movwf 0x04                  ; FSR0L
        movlw 0x02
        movwf 0x05                  ; FSR0H
        movlw 0x4E
        movwf 0x7E                  ; common 0x7E
        clrf 0x7F                   ; common 0x7F
        movlp 0x1B
        call L_1B04
        movlp 0x06
        movlw 0xA0
        movwf 0x04                  ; FSR0L
        movlw 0x02
        movwf 0x05                  ; FSR0H
        movlw 0x2A
        movwf 0x7E                  ; common 0x7E
        movlw 0x00
        clrf 0x7F                   ; common 0x7F
        movlp 0x1B
        call L_1B04
        bcf 0x7E, 0                 ; common 0x7E
        movlb 0x00
        movlp 0x1E
        goto L_1E89
L_0753:
        movwf 0x4E
        xorlw 0x65
        btfsc 0x03, 2               ; STATUS
        goto L_0790
        xorlw 0x02
        btfsc 0x03, 2               ; STATUS
        goto L_0770
        xorlw 0x0F
        btfsc 0x03, 2               ; STATUS
        goto L_0770
        xorlw 0x01
        btfsc 0x03, 2               ; STATUS
        goto L_0770
        xorlw 0x03
        btfsc 0x03, 2               ; STATUS
        goto L_0770
        xorlw 0x06
        btfsc 0x03, 2               ; STATUS
        goto L_078D
        xorlw 0x01
        btfsc 0x03, 2               ; STATUS
        goto L_0770
        xorlw 0x03
        btfsc 0x03, 2               ; STATUS
        goto L_0788
        xorlw 0x01
        btfsc 0x03, 2               ; STATUS
        goto L_0788
        goto L_0793
L_0770:
        movf 0x49, 0
        movwf 0x3E
        clrf 0x3F
        movf 0x48, 0
        call L_07AE
        movf 0x41, 0
        movwf 0x4D
        movf 0x40, 0
        movwf 0x4C
        movf 0x3F, 0
        movwf 0x4B
        movf 0x3E, 0
        movwf 0x4A
        movf 0x4D, 0
        movwf 0x46
        movf 0x4C, 0
        movwf 0x45
        movf 0x4B, 0
        movwf 0x44
        movf 0x4A, 0
        movwf 0x43
        movf 0x4E, 0
        movlp 0x08
        goto L_085E
L_0788:
        call L_07E7
        movwf 0x40
        movf 0x4E, 0
        movlp 0x0E
        goto L_0E07
L_078D:
        call L_07E7
        movlp 0x07
        goto L_0794
L_0790:
        call L_07E7
        movlp 0x1F
        goto L_1F49
L_0793:
        return
L_0794:
        movwf 0x44
        movwf 0x40
        movlw 0xD4
        clrf 0x41
        clrf 0x42
        clrf 0x43
        movwf 0x06                  ; FSR1L
        movlw 0x23
        movwf 0x07                  ; FSR1H
        movf 0x40, 0
        movwi 0[FSR1]
        movf 0x41, 0
        movwi 1[FSR1]
        movf 0x42, 0
        movwi 2[FSR1]
        movf 0x43, 0
        movwi 3[FSR1]
        movlp 0x0E
        call L_0E62
        movlp 0x07
        movlb 0x00
        movf 0x44, 0
        movwf 0x3D
        movlw 0x6C
        movlp 0x1F
        goto L_1F7B
L_07AE:
        movwf 0x43
        call L_07B9
        movf 0x37, 0
        movwf 0x41
        movf 0x36, 0
        movwf 0x40
        movf 0x35, 0
        movwf 0x3F
        movf 0x34, 0
        movwf 0x3E
        return
L_07B9:
        movwf 0x3D
        movwf 0x06                  ; FSR1L
        movlw 0x01
        movwf 0x07                  ; FSR1H
        movf 0x01, 0                ; INDF1
        movwf 0x39
        clrf 0x3A
        clrf 0x3B
        clrf 0x3C
        movf 0x3B, 0
        movwf 0x3C
        movf 0x3A, 0
        movwf 0x3B
        movf 0x39, 0
        movwf 0x3A
        clrf 0x39
        incf 0x3D, 0
        call L_07DB
        movlp 0x07
        addlw 0x02
        call L_07DB
        addlw 0x03
        movwf 0x06                  ; FSR1L
        movf 0x01, 0                ; INDF1
        iorwf 0x39, 1
        movf 0x3C, 0
        movwf 0x37
        movf 0x3B, 0
        movwf 0x36
        movf 0x3A, 0
        movwf 0x35
        movf 0x39, 0
        movwf 0x34
        return
L_07DB:
        movwf 0x06                  ; FSR1L
        movf 0x01, 0                ; INDF1
        iorwf 0x39, 1
        movf 0x3B, 0
        movwf 0x3C
        movf 0x3A, 0
        movwf 0x3B
        movf 0x39, 0
        movwf 0x3A
        clrf 0x39
        movf 0x3D, 0
        return
L_07E7:
        movf 0x48, 0
        movwf 0x06                  ; FSR1L
        movlw 0x01
        movwf 0x07                  ; FSR1H
        movf 0x01, 0                ; INDF1
        return
L_07ED:
        movlb 0x01
        bsf 0x1A, 1                 ; SFR 0x09A
        movlw 0x20
        movwf 0x15                  ; CKOCON
        movlw 0x03
        movlb 0x06
        movwf 0x1F                  ; TCKSRC
        movlw 0x84
        movlb 0x04
        movwf 0x11                  ; TIM1CR1
        movlw 0x01
        movwf 0x15                  ; TIM1IER
        movlw 0x0D
        movlb 0x05
        movwf 0x10                  ; TIM1ARRH
        movlw 0x10
        movwf 0x11                  ; TIM1ARRL
        return
        nop
        nop
L_0801:
        movlb 0x01
        bsf 0x1A, 3                 ; SFR 0x09A
        movlw 0x05
        movlb 0x02
        movwf 0x11                  ; TIM4CR1
        movlw 0x01
        movwf 0x12                  ; TIM4IER
        clrf 0x13                   ; TIM4SR
        clrf 0x14                   ; TIM4EGR
        clrf 0x15                   ; TIM4CNTR
        movlw 0x04
        movwf 0x16                  ; TIM4PSCR
        movlw 0xC8
        movwf 0x17                  ; TIM4ARR
        return
L_0810:
        movlb 0x00
        movlw 0xFD
        clrf 0x34
        movlb 0x02
        movwf 0x24
        movlb 0x00
        incf 0x34, 1
        movf 0x34, 0
        movlp 0x0A
        call L_0A0F
        movlp 0x08
        call L_0858
        movlp 0x08
        movlw 0xFB
        call L_0858
        movlp 0x08
        movlw 0xFA
        call L_0858
        movlp 0x08
        movlw 0x08
        call L_0858
        movlp 0x08
        clrf 0x01                   ; INDF1
        incf 0x34, 1
        movf 0x34, 0
        addlw 0x24
        movwf 0x06                  ; FSR1L
        movlw 0xA9
        call L_0858
        movlp 0x08
        clrf 0x01                   ; INDF1
        incf 0x34, 1
        movf 0x34, 0
        addlw 0x24
        movwf 0x06                  ; FSR1L
        movlw 0x31
        call L_0858
        movlp 0x08
        movlw 0x32
        call L_0858
        movlp 0x08
        movlw 0x33
        call L_0858
        movlp 0x08
        movlw 0x34
        call L_0858
        movlp 0x08
        movlw 0x36
        call L_0858
        movlp 0x08
        movlw 0x35
        call L_0858
        movlp 0x08
        movlw 0x04
        call L_0858
        movlp 0x08
        movlw 0x03
        call L_0858
        movlp 0x08
        movlw 0x02
        call L_0858
        clrf 0x01                   ; INDF1
        incf 0x01, 1                ; INDF1
        incf 0x34, 1
        movlp 0x0A
        call L_0A08
        movlp 0x08
        movf 0x34, 0
        movlp 0x0A
        call L_0A23
        movlp 0x09
        goto L_09CF
L_0858:
        movwf 0x01                  ; INDF1
        incf 0x34, 1
        movf 0x34, 0
        addlw 0x24
        movwf 0x06                  ; FSR1L
        return
L_085E:
        movwf 0x47
        xorlw 0x67
        btfsc 0x03, 2               ; STATUS
        goto L_086F
        xorlw 0x0F
        btfsc 0x03, 2               ; STATUS
        goto L_0875
        xorlw 0x01
        btfsc 0x03, 2               ; STATUS
        goto L_087B
        xorlw 0x03
        btfsc 0x03, 2               ; STATUS
        goto L_0880
        xorlw 0x07
        btfsc 0x03, 2               ; STATUS
        goto L_0885
        goto L_089D
L_086F:
        call L_08D7
        movlp 0x08
        movlw 0x02
L_0872:
        movlb 0x01
        movwf 0x47
L_0874:
        goto L_089E
L_0875:
        call L_08D7
        movlp 0x08
        movlb 0x01
        clrf 0x47
        incf 0x47, 1
        goto L_0874
L_087B:
        clrf 0x6E
        call L_08D7
        movlp 0x08
        movlw 0x03
        goto L_0872
L_0880:
        clrf 0x6E
        call L_08D7
        movlp 0x08
        movlw 0x04
        goto L_0872
L_0885:
        movlw 0xDC
        movwf 0x06                  ; FSR1L
        movlw 0x23
        movwf 0x07                  ; FSR1H
        movf 0x43, 0
        movwi 0[FSR1]
        movf 0x44, 0
        movwi 1[FSR1]
        movf 0x45, 0
        movwi 2[FSR1]
        movf 0x46, 0
        movwi 3[FSR1]
        movwf 0x40
        movf 0x45, 0
        movwf 0x3F
        movf 0x44, 0
        movwf 0x3E
        movf 0x43, 0
        movwf 0x3D
        movf 0x47, 0
        movlp 0x14
        call L_140F
        movlp 0x0E
        goto L_0E85
L_089D:
        return
L_089E:
        movlb 0x00
        movlw 0xFD
        clrf 0x34
        movlb 0x02
        movwf 0x24
        movlb 0x00
        incf 0x34, 1
        movf 0x34, 0
        call L_0A0F
        movlp 0x08
        call L_08E0
        movlp 0x08
        movlw 0xFB
        call L_08E0
        movlp 0x08
        movlw 0xFA
        call L_08E0
        movlp 0x08
        movlw 0x04
        call L_08E0
        movlp 0x08
        clrf 0x01                   ; INDF1
        incf 0x34, 1
        movf 0x34, 0
        addlw 0x24
        movwf 0x06                  ; FSR1L
        movlw 0xFF
        call L_08E0
        movlp 0x08
        clrf 0x01                   ; INDF1
        call L_08E6
        movlp 0x08
        incf 0x01, 1                ; INDF1
        call L_08E6
        movlp 0x08
        incf 0x34, 1
        movf 0x34, 0
        addlw 0x24
        movwf 0x06                  ; FSR1L
        movlw 0x04
        call L_08E0
        movlp 0x08
        movlw 0x03
        call L_08E0
        movlp 0x08
        movlw 0x02
        call L_08E0
        movlp 0x08
        clrf 0x01                   ; INDF1
        incf 0x01, 1                ; INDF1
        incf 0x34, 1
        call L_0A08
        movlp 0x08
        movf 0x34, 0
        call L_0A23
        movlp 0x08
        goto L_09CF
L_08D7:
        movf 0x46, 0
        movwf 0x73                  ; common 0x73
        movf 0x45, 0
        movwf 0x72                  ; common 0x72
        movf 0x44, 0
        movwf 0x71                  ; common 0x71
        movf 0x43, 0
        movwf 0x70                  ; common 0x70
        return
L_08E0:
        movwf 0x01                  ; INDF1
        incf 0x34, 1
        movf 0x34, 0
        addlw 0x24
        movwf 0x06                  ; FSR1L
        return
L_08E6:
        incf 0x34, 1
        movf 0x34, 0
        addlw 0x24
        movwf 0x06                  ; FSR1L
        clrf 0x01                   ; INDF1
        return
L_08EC:
        movwf 0x40
        movlw 0xFD
        clrf 0x41
        movlb 0x02
        movwf 0x24
        movlb 0x00
        incf 0x41, 1
        movf 0x41, 0
        call L_0A0F
        movlp 0x08
        call L_0A02
        movlp 0x08
        movlw 0xFB
        call L_0A02
        movlp 0x08
        movlw 0xFA
        call L_0A02
        movlp 0x08
        movlw 0x14
        call L_0A02
        movlp 0x08
        clrf 0x01                   ; INDF1
        incf 0x41, 1
        movf 0x41, 0
        addlw 0x24
        movwf 0x06                  ; FSR1L
        movlw 0x64
        call L_0A02
        movlp 0x08
        clrf 0x01                   ; INDF1
        incf 0x41, 1
        movf 0x41, 0
        addlw 0x24
        movwf 0x06                  ; FSR1L
        clrf 0x01                   ; INDF1
        incf 0x41, 1
        movf 0x41, 0
        addlw 0x24
        movwf 0x06                  ; FSR1L
        clrf 0x01                   ; INDF1
        incf 0x41, 1
        movf 0x41, 0
        addlw 0x24
        movwf 0x06                  ; FSR1L
        movf 0x40, 0
        call L_0A02
        movlp 0x08
        clrf 0x01                   ; INDF1
        incf 0x41, 1
        movf 0x41, 0
        addlw 0x24
        movwf 0x06                  ; FSR1L
        clrf 0x01                   ; INDF1
        incf 0x41, 1
        movf 0x41, 0
        addlw 0x24
        movwf 0x06                  ; FSR1L
        clrf 0x01                   ; INDF1
        call L_0A28
        movlp 0x08
        incf 0x01, 1                ; INDF1
        call L_0A28
        movlp 0x08
        call L_0A1C
        movlp 0x08
        movf 0x37, 0
        call L_0959
        movlp 0x08
        addlw 0x20
        addwf 0x40, 0
        movwf 0x3F
        movwf 0x04                  ; FSR0L
        movlw 0x03
        call L_09E9
        movlp 0x08
        movlw 0x02
        call L_0A02
        movlp 0x08
        clrf 0x01                   ; INDF1
        call L_0A1C
        movlp 0x08
        movf 0x3B, 0
        call L_0959
        movlp 0x08
        addlw 0xA0
        addwf 0x40, 0
        movwf 0x3F
        movwf 0x04                  ; FSR0L
        movlw 0x03
        call L_09E9
        movlp 0x08
        movlw 0x04
        call L_0A02
        movlp 0x08
        movlw 0x03
        call L_0A02
        movlp 0x08
        movlw 0x02
        call L_0A02
        movlp 0x08
        clrf 0x01                   ; INDF1
        incf 0x01, 1                ; INDF1
        incf 0x41, 1
        call L_0A08
        movlp 0x08
        movf 0x41, 0
        call L_0A23
        movlp 0x08
        goto L_09CF
L_0959:
        movwf 0x36
        clrf 0x35
L_095B:
        movf 0x34, 0
        btfsc 0x36, 0
        addwf 0x35, 1
        lslf 0x34, 1
        lsrf 0x36, 1
        movf 0x36, 0
        btfss 0x03, 2               ; STATUS
        goto L_095B
        movf 0x35, 0
        return
L_0965:
        movlw 0x4B
        clrf 0x4B
        movwf 0x34
        clrf 0x35
        clrf 0x36
        clrf 0x37
        movf 0x45, 0
        movwf 0x3B
        movf 0x44, 0
        movwf 0x3A
        movf 0x43, 0
        movwf 0x39
        movf 0x42, 0
        movwf 0x38
        movlp 0x1D
        call L_1D68
        movlp 0x08
        movf 0x34, 0
        movwf 0x4A
        movlw 0xFD
        movlb 0x02
        movwf 0x24
        movlb 0x00
        incf 0x4B, 1
        movf 0x4B, 0
        call L_0A0F
        movlp 0x08
        movwf 0x01                  ; INDF1
        incf 0x4B, 1
        movf 0x4B, 0
        addlw 0x24
        movwf 0x06                  ; FSR1L
        movlw 0xFB
        movwf 0x01                  ; INDF1
        incf 0x4B, 1
        movf 0x4B, 0
        addlw 0x24
        movwf 0x06                  ; FSR1L
        movlw 0xFA
        movwf 0x01                  ; INDF1
        incf 0x4B, 1
        movf 0x4B, 0
        addlw 0x24
        movwf 0x06                  ; FSR1L
        movlw 0x14
        movwf 0x01                  ; INDF1
        incf 0x4B, 1
        movf 0x4B, 0
        addlw 0x24
        movwf 0x06                  ; FSR1L
        clrf 0x01                   ; INDF1
        incf 0x4B, 1
        movf 0x4B, 0
        addlw 0x24
        movwf 0x06                  ; FSR1L
        movlw 0x60
        call L_09D4
        movlp 0x08
        movf 0x4A, 0
        call L_09D4
        movlp 0x08
        clrf 0x01                   ; INDF1
        incf 0x01, 1                ; INDF1
        incf 0x4B, 1
        movf 0x4B, 0
        addlw 0x24
        movwf 0x06                  ; FSR1L
        clrf 0x01                   ; INDF1
        incf 0x4B, 1
        movf 0x4B, 0
        addlw 0x24
        movwf 0x06                  ; FSR1L
        movf 0x4A, 0
        call L_09D4
        movlp 0x08
        call L_0A14
        movlp 0x08
        incf 0x4B, 1
        movf 0x4B, 0
        addlw 0x24
        movwf 0x06                  ; FSR1L
        movf 0x46, 0
        call L_09D4
        movlp 0x08
        movlw 0x04
        movwf 0x01                  ; INDF1
        incf 0x4B, 1
        movf 0x4B, 0
        addlw 0x24
        movwf 0x06                  ; FSR1L
        movlw 0x03
        movwf 0x01                  ; INDF1
        incf 0x4B, 1
        movf 0x4B, 0
        addlw 0x24
        movwf 0x06                  ; FSR1L
        call L_0A14
        movlp 0x08
        incf 0x01, 1                ; INDF1
        incf 0x4B, 1
        call L_0A08
        movlp 0x08
        movf 0x4B, 0
        call L_0A23
        movlp 0x08
        goto L_09CF
L_09CF:
        movlb 0x01
        clrf 0x46
        clrf 0x45
        incf 0x45, 1
        return
L_09D4:
        movwf 0x01                  ; INDF1
        incf 0x4B, 1
        movf 0x4B, 0
        addlw 0x24
        movwf 0x06                  ; FSR1L
        clrf 0x01                   ; INDF1
        incf 0x4B, 1
        movf 0x4B, 0
        addlw 0x24
        movwf 0x06                  ; FSR1L
        clrf 0x01                   ; INDF1
        incf 0x4B, 1
        movf 0x4B, 0
        addlw 0x24
        movwf 0x06                  ; FSR1L
        clrf 0x01                   ; INDF1
        incf 0x4B, 1
        movf 0x4B, 0
        addlw 0x24
        movwf 0x06                  ; FSR1L
        return
L_09E9:
        movwf 0x05                  ; FSR0H
        movf 0x00, 0                ; INDF0
        movwf 0x01                  ; INDF1
        incf 0x41, 1
        movf 0x41, 0
        addlw 0x24
        movwf 0x06                  ; FSR1L
        movlw 0x01
        movwf 0x07                  ; FSR1H
        clrf 0x01                   ; INDF1
        incf 0x41, 1
        movf 0x41, 0
        addlw 0x24
        movwf 0x06                  ; FSR1L
        clrf 0x01                   ; INDF1
        incf 0x41, 1
        movf 0x41, 0
        addlw 0x24
        movwf 0x06                  ; FSR1L
        clrf 0x01                   ; INDF1
        incf 0x41, 1
        movf 0x41, 0
        addlw 0x24
        movwf 0x06                  ; FSR1L
        return
L_0A02:
        movwf 0x01                  ; INDF1
        incf 0x41, 1
        movf 0x41, 0
        addlw 0x24
        movwf 0x06                  ; FSR1L
        return
L_0A08:
        movlb 0x02
        clrf 0x21
        clrf 0x20
        incf 0x20, 1
        clrf 0x22
        movlb 0x00
        return
L_0A0F:
        addlw 0x24
        movwf 0x06                  ; FSR1L
        movlw 0x01
        movwf 0x07                  ; FSR1H
        retlw 0xFC
L_0A14:
        movlw 0x02
        movwf 0x01                  ; INDF1
        incf 0x4B, 1
        movf 0x4B, 0
        addlw 0x24
        movwf 0x06                  ; FSR1L
        clrf 0x01                   ; INDF1
        return
L_0A1C:
        incf 0x41, 1
        movf 0x41, 0
        addlw 0x24
        movwf 0x06                  ; FSR1L
        movlw 0x09
        movwf 0x34
        return
L_0A23:
        movlb 0x02
        movwf 0x23
        movlb 0x04
        bsf 0x11, 0                 ; TIM1CR1
        return
L_0A28:
        incf 0x41, 1
        movf 0x41, 0
        addlw 0x24
        movwf 0x06                  ; FSR1L
        clrf 0x01                   ; INDF1
        return
L_0A2E:
        movlw 0xD4
        clrf 0x54
        incf 0x54, 1
        movwf 0x06                  ; FSR1L
        movlw 0x23
        movwf 0x07                  ; FSR1H
        moviw FSR1++
        xorlw 0x03
        movwf 0x4C
        moviw FSR1++
        iorwf 0x4C, 1
        moviw FSR1++
        iorwf 0x4C, 1
        moviw FSR1++
        iorwf 0x4C, 1
        btfsc 0x03, 2               ; STATUS
        goto L_0A55
        call L_0B17
        movlp 0x0A
        movf 0x42, 0
        movwf 0x53
        movf 0x41, 0
        movwf 0x52
        call L_0C0D
        movlp 0x0A
        call L_0AF6
        movlp 0x0A
        movf 0x35, 0
        movwf 0x51
        movf 0x34, 0
        movwf 0x50
        movf 0x53, 0
        subwf 0x51, 0
        btfss 0x03, 2               ; STATUS
        goto L_0A53
        movf 0x52, 0
        subwf 0x50, 0
L_0A53:
        btfss 0x03, 0               ; STATUS
        clrf 0x54
L_0A55:
        movf 0x54, 0
        btfsc 0x03, 2               ; STATUS
        return
        movlb 0x01
        movlp 0x1F
        call L_1FFA
        incf 0x31, 1
        clrf 0x30
        incf 0x30, 1
        return
L_0A5F:
        incf 0x3B, 1
        btfsc 0x03, 2               ; STATUS
        incf 0x3C, 1
        goto L_0AE7
L_0A63:
        movlw 0x02
        subwf 0x5D, 0
        btfss 0x03, 0               ; STATUS
        goto L_0A6B
        movlw 0x05
        xorwf 0x5D, 0
        btfss 0x03, 2               ; STATUS
        return
L_0A6B:
        clrf 0x3B
        clrf 0x3C
        clrf 0x44
        incf 0x44, 1
L_0A6F:
        goto L_0B10
L_0A70:
        decfsz 0x5B, 0
        goto L_0A86
        movlb 0x00
        bsf 0x0D, 6                 ; PORTB
        bsf 0x0C, 2                 ; PORTA
        movlw 0x0B
        movlb 0x01
        subwf 0x3C, 0
        movlw 0xB9
        btfsc 0x03, 2               ; STATUS
        subwf 0x3B, 0
        btfss 0x03, 0               ; STATUS
        return
        movlw 0x02
        clrf 0x3B
        clrf 0x3C
        movwf 0x44
        clrf 0x48
        movlb 0x00
        bcf 0x0D, 6                 ; PORTB
L_0A84:
        bcf 0x0C, 2
        return
L_0A86:
        movlw 0x00
        subwf 0x3C, 0
        movlw 0x65
        btfsc 0x03, 2               ; STATUS
        subwf 0x3B, 0
        btfss 0x03, 0               ; STATUS
        return
        movlw 0x40
        clrf 0x3B
        clrf 0x3C
        movlb 0x00
        xorwf 0x0D, 1               ; PORTB
        movlw 0x04
        xorwf 0x0C, 1               ; PORTA
        movlb 0x01
        incfsz 0x5B, 0
        return
        goto L_0A6F
L_0A98:
        movlw 0x01
        subwf 0x3C, 0
        movlw 0xF5
        btfsc 0x03, 2               ; STATUS
        subwf 0x3B, 0
        btfss 0x03, 0               ; STATUS
        goto L_0ABA
        call L_0B17
        movlp 0x0A
        movf 0x42, 0
        movwf 0x51
        movf 0x41, 0
        movwf 0x50
        movlw 0x02
        call L_0AF6
        movlp 0x0A
        movf 0x35, 0
        movwf 0x53
        movf 0x34, 0
        movwf 0x52
        movf 0x53, 0
        subwf 0x51, 0
        btfss 0x03, 2               ; STATUS
        goto L_0AB2
        movf 0x52, 0
        subwf 0x50, 0
L_0AB2:
        btfsc 0x03, 0               ; STATUS
        goto L_0AB6
        bsf 0x0C, 2
        goto L_0AB7
L_0AB6:
        bcf 0x0C, 2
L_0AB7:
        movlb 0x01
        clrf 0x3B
        clrf 0x3C
L_0ABA:
        movf 0x48, 0
        btfsc 0x03, 2               ; STATUS
        return
        movlw 0x03
        clrf 0x48
        movwf 0x44
        movlw 0x90
        call L_0C09
        movlp 0x10
        call L_10E8
        return
L_0AC5:
        movlw 0x01
        subwf 0x3C, 0
        movlw 0xF5
        btfsc 0x03, 2               ; STATUS
        subwf 0x3B, 0
        btfss 0x03, 0               ; STATUS
        return
        movlw 0xCC
        clrf 0x3B
        clrf 0x3C
        movwf 0x06                  ; FSR1L
        movlw 0x23
        movwf 0x07                  ; FSR1H
        moviw 3[FSR1]
        btfsc 0x09, 7               ; WREG
        goto L_0AE5
        moviw 3[FSR1]
        btfss 0x03, 2               ; STATUS
        goto L_0A84
        moviw 2[FSR1]
        btfss 0x03, 2               ; STATUS
        goto L_0A84
        moviw 1[FSR1]
        btfss 0x03, 2               ; STATUS
        goto L_0A84
        moviw 0[FSR1]
        movlb 0x00
        movwf 0x4C
        movlw 0x64
        subwf 0x4C, 0
        btfsc 0x03, 0               ; STATUS
        goto L_0A84
L_0AE5:
        bsf 0x0C, 2
        return
L_0AE7:
        movf 0x44, 0
        xorlw 0x00
        btfsc 0x03, 2               ; STATUS
        goto L_0A63
        xorlw 0x01
        btfsc 0x03, 2               ; STATUS
        goto L_0A70
        xorlw 0x03
        btfsc 0x03, 2               ; STATUS
        goto L_0A98
        xorlw 0x01
        btfsc 0x03, 2               ; STATUS
        goto L_0AC5
        goto L_0AF5
L_0AF5:
        return
L_0AF6:
        movwf 0x37
        goto L_0B00
L_0AF8:
        movlw 0x0A
        goto L_0AFD
L_0AFA:
        movlw 0x18
        goto L_0AFD
L_0AFC:
        movlw 0x2C
L_0AFD:
        movwf 0x38
        clrf 0x39
        goto L_0B0B
L_0B00:
        movf 0x37, 0
        xorlw 0x00
        btfsc 0x03, 2               ; STATUS
        goto L_0AF8
        xorlw 0x01
        btfsc 0x03, 2               ; STATUS
        goto L_0AFA
        xorlw 0x03
        btfsc 0x03, 2               ; STATUS
        goto L_0AFC
        goto L_0AFC
L_0B0B:
        movf 0x39, 0
        movwf 0x35
        movf 0x38, 0
        movwf 0x34
        return
L_0B10:
        movlw 0x03
        movlb 0x00
        movwf 0x39
        movlw 0x0E
        clrf 0x3A
        movlp 0x1F
        goto L_1FA2
L_0B17:
        movlw 0x05
        movlb 0x00
        movwf 0x47
        clrf 0x48
        clrf 0x49
        clrf 0x4A
        clrf 0x4B
        movlb 0x01
        bsf 0x1D, 0                 ; ADCON0
L_0B20:
        movlb 0x00
        movf 0x47, 0
        btfsc 0x03, 2               ; STATUS
        goto L_0B30
        movlw 0x02
        decf 0x47, 1
        call L_0BD2
        movlp 0x0A
        movf 0x39, 0
        addwf 0x48, 1
        movf 0x3A, 0
        addwfc 0x49, 1
        movlw 0x00
        addwfc 0x4A, 1
        addwfc 0x4B, 1
        goto L_0B20
L_0B30:
        movlb 0x01
        bcf 0x1D, 0                 ; ADCON0
        movlw 0x05
        movlb 0x00
        movwf 0x34
        clrf 0x35
        clrf 0x36
        clrf 0x37
        movf 0x4B, 0
        movwf 0x3B
        movf 0x4A, 0
        movwf 0x3A
        movf 0x49, 0
        movwf 0x39
        movf 0x48, 0
        movwf 0x38
        call L_0B6E
        movlp 0x0A
        movf 0x37, 0
        movwf 0x4B
        movf 0x36, 0
        movwf 0x4A
        movf 0x35, 0
        movwf 0x49
        movf 0x34, 0
        movwf 0x48
        movf 0x4B, 0
        movwf 0x37
        movf 0x4A, 0
        movwf 0x36
        movf 0x49, 0
        movwf 0x35
        movf 0x48, 0
        movwf 0x34
        movlw 0x0B
        clrf 0x3B
        clrf 0x3A
        movwf 0x39
        movlw 0xB8
        movwf 0x38
        call L_0BAD
        movlp 0x0A
        movf 0x37, 0
        movwf 0x46
        movf 0x36, 0
        movwf 0x45
        movf 0x35, 0
        movwf 0x44
        movf 0x34, 0
        movwf 0x43
        movlw 0x0C
L_0B63:
        lsrf 0x46, 1
        rrf 0x45, 1
        rrf 0x44, 1
        rrf 0x43, 1
        decfsz 0x09, 1              ; WREG
        goto L_0B63
        movf 0x44, 0
        movwf 0x42
        movf 0x43, 0
        movwf 0x41
        return
L_0B6E:
        clrf 0x3C
        clrf 0x3D
        clrf 0x3E
        clrf 0x3F
        movf 0x37, 0
        iorwf 0x36, 0
        iorwf 0x35, 0
        iorwf 0x34, 0
        btfsc 0x03, 2               ; STATUS
        goto L_0BA4
        clrf 0x40
L_0B79:
        incf 0x40, 1
        btfsc 0x37, 7
        goto L_0B81
        lslf 0x34, 1
        rlf 0x35, 1
        rlf 0x36, 1
        rlf 0x37, 1
        goto L_0B79
L_0B81:
        lslf 0x3C, 1
        rlf 0x3D, 1
        rlf 0x3E, 1
        rlf 0x3F, 1
        movf 0x37, 0
        subwf 0x3B, 0
        btfss 0x03, 2               ; STATUS
        goto L_0B93
        movf 0x36, 0
        subwf 0x3A, 0
        btfss 0x03, 2               ; STATUS
        goto L_0B93
        movf 0x35, 0
        subwf 0x39, 0
        btfss 0x03, 2               ; STATUS
        goto L_0B93
        movf 0x34, 0
        subwf 0x38, 0
L_0B93:
        btfss 0x03, 0               ; STATUS
        goto L_0B9E
        movf 0x34, 0
        subwf 0x38, 1
        movf 0x35, 0
        subwfb 0x39, 1
        movf 0x36, 0
        subwfb 0x3A, 1
        movf 0x37, 0
        subwfb 0x3B, 1
        bsf 0x3C, 0
L_0B9E:
        lsrf 0x37, 1
        rrf 0x36, 1
        rrf 0x35, 1
        rrf 0x34, 1
        decfsz 0x40, 1
        goto L_0B81
L_0BA4:
        movf 0x3F, 0
        movwf 0x37
        movf 0x3E, 0
        movwf 0x36
        movf 0x3D, 0
        movwf 0x35
        movf 0x3C, 0
        movwf 0x34
        return
L_0BAD:
        clrf 0x3C
        clrf 0x3D
        clrf 0x3E
        clrf 0x3F
L_0BB1:
        btfss 0x34, 0
        goto L_0BBB
        movf 0x38, 0
        addwf 0x3C, 1
        movf 0x39, 0
        addwfc 0x3D, 1
        movf 0x3A, 0
        addwfc 0x3E, 1
        movf 0x3B, 0
        addwfc 0x3F, 1
L_0BBB:
        lslf 0x38, 1
        rlf 0x39, 1
        rlf 0x3A, 1
        rlf 0x3B, 1
        lsrf 0x37, 1
        rrf 0x36, 1
        rrf 0x35, 1
        rrf 0x34, 1
        movf 0x37, 0
        iorwf 0x36, 0
        iorwf 0x35, 0
        iorwf 0x34, 0
        btfss 0x03, 2               ; STATUS
        goto L_0BB1
        movf 0x3F, 0
        movwf 0x37
        movf 0x3E, 0
        movwf 0x36
        movf 0x3D, 0
        movwf 0x35
        movf 0x3C, 0
        movwf 0x34
        return
L_0BD2:
        movwf 0x3C
        nop
        nop
        nop
        nop
        movlw 0x0F
        movlb 0x01
        andwf 0x1D, 1               ; ADCON0
        movlb 0x00
        swapf 0x3C, 0
        andlw 0xF0
        movlb 0x01
        iorwf 0x1D, 1               ; ADCON0
        movlw 0x28
        movlb 0x00
        movwf 0x34
        clrf 0x35
        call L_0BF9
        movlp 0x0A
        movlb 0x01
        bsf 0x1D, 1                 ; ADCON0
        nop
        nop
L_0BE9:
        movlb 0x01
        btfsc 0x1D, 1               ; ADCON0
        goto L_0BE9
        movf 0x1C, 0                ; ADRESH
        movlb 0x00
        movwf 0x3E
        clrf 0x3D
        movlb 0x01
        movf 0x1B, 0                ; ADRESL
        movlb 0x00
        iorwf 0x3D, 1
        movf 0x3E, 0
        movwf 0x3A
        movf 0x3D, 0
        movwf 0x39
        return
L_0BF9:
        clrf 0x38
L_0BFA:
        movf 0x38, 0
        movwf 0x36
        clrf 0x37
        movf 0x35, 0
        subwf 0x37, 0
        btfss 0x03, 2               ; STATUS
        goto L_0C03
        movf 0x34, 0
        subwf 0x36, 0
L_0C03:
        btfsc 0x03, 0               ; STATUS
        return
        nop
        movlb 0x00
        incf 0x38, 1
        goto L_0BFA
L_0C09:
        movwf 0x06                  ; FSR1L
        movlw 0x23
        movwf 0x07                  ; FSR1H
        retlw 0x01
L_0C0D:
        movlw 0xD4
        movwf 0x06                  ; FSR1L
        movlw 0x23
        movwf 0x07                  ; FSR1H
        movf 0x01, 0                ; INDF1
        return
L_0C13:
        movf 0x4C, 0
        addlw 0xA7
        movwf 0x06                  ; FSR1L
        movlw 0x01
        movwf 0x07                  ; FSR1H
        movf 0x01, 0                ; INDF1
        movwf 0x5E
        clrf 0x5D
        movf 0x4C, 0
        addlw 0xA6
        movwf 0x06                  ; FSR1L
        movf 0x01, 0                ; INDF1
        addwf 0x5D, 1
        btfsc 0x03, 0               ; STATUS
        incf 0x5E, 1
        movf 0x4C, 0
        addlw 0xA8
        movwf 0x06                  ; FSR1L
        movf 0x01, 0                ; INDF1
        movwf 0x5F
        goto L_0D99
L_0C28:
        movlp 0x1D
        call L_1D19
        movlp 0x0C
        movlb 0x00
        decfsz 0x5F, 0
        goto L_0C31
        movlw 0x02
        movlp 0x1D
        goto L_1D1C
L_0C31:
        movlb 0x01
        decfsz 0x4E, 0
        goto L_0C87
        movlw 0xB4
        call L_0DDA
        movlp 0x0C
        call L_0DFF
        movlp 0x0C
        movlw 0x90
        movwf 0x06                  ; FSR1L
        addfsr FSR1L, 28
        call L_0DF6
        movlp 0x09
        goto L_0965
L_0C3F:
        movf 0x73, 0                ; common 0x73
        movlb 0x00
        movwf 0x3A
        movf 0x72, 0                ; common 0x72
        movwf 0x39
        movf 0x71, 0                ; common 0x71
        movwf 0x38
        movf 0x70, 0                ; common 0x70
        movwf 0x37
        movlw 0xC4
        movwf 0x06                  ; FSR1L
        movlw 0x23
        movwf 0x07                  ; FSR1H
        moviw 0[FSR1]
        movwf 0x3B
        moviw 1[FSR1]
        movwf 0x3C
        moviw 2[FSR1]
        movwf 0x3D
        moviw 3[FSR1]
        movwf 0x3E
        movf 0x6E, 0
        movlp 0x08
        goto L_08EC
L_0C57:
        movlw 0xBC
        call L_0DDA
        movwf 0x37
        moviw 1[FSR1]
        movwf 0x38
        moviw 2[FSR1]
        movwf 0x39
        moviw 3[FSR1]
        movwf 0x3A
        movf 0x73, 0                ; common 0x73
        movwf 0x3E
        movf 0x72, 0                ; common 0x72
        movwf 0x3D
        movf 0x71, 0                ; common 0x71
        movwf 0x3C
        movf 0x70, 0                ; common 0x70
        movwf 0x3B
        movf 0x6E, 0
        movlp 0x08
        goto L_08EC
L_0C6B:
        movf 0x73, 0                ; common 0x73
        movlb 0x00
        movwf 0x45
        movf 0x72, 0                ; common 0x72
        movwf 0x44
        movf 0x71, 0                ; common 0x71
        movwf 0x43
        movf 0x70, 0                ; common 0x70
        movwf 0x42
        call L_0DF0
        movlp 0x0C
        call L_0DF6
        movlp 0x09
        goto L_0965
L_0C79:
        movlw 0xB4
        call L_0DDA
        movlp 0x0C
        call L_0DFF
        movf 0x73, 0                ; common 0x73
        movwf 0x49
        movf 0x72, 0                ; common 0x72
        movwf 0x48
        movf 0x71, 0                ; common 0x71
        movwf 0x47
        movf 0x70, 0                ; common 0x70
        movwf 0x46
        movlp 0x09
        goto L_0965
L_0C87:
        movf 0x47, 0
        xorlw 0x01
        btfsc 0x03, 2               ; STATUS
        goto L_0C6B
        xorlw 0x03
        btfsc 0x03, 2               ; STATUS
        goto L_0C79
        xorlw 0x01
        btfsc 0x03, 2               ; STATUS
        goto L_0C3F
        xorlw 0x07
        btfsc 0x03, 2               ; STATUS
        goto L_0C57
        goto L_0C95
L_0C95:
        return
L_0C96:
        movlp 0x1D
        call L_1D19
        clrf 0x47
        clrf 0x4E
        return
L_0C9B:
        movlp 0x1D
        call L_1D19
        movlp 0x0C
        movlb 0x00
        decfsz 0x5F, 0
        goto L_0CA4
        movlw 0x02
        movlp 0x1D
        goto L_1D1C
L_0CA4:
        movlb 0x01
        decfsz 0x4E, 0
        goto L_0CB5
        movlb 0x00
        movlw 0x03
        clrf 0x6E
        movlb 0x01
        movwf 0x4E
        movlw 0xBC
        call L_0DDA
        movlp 0x0C
        movwf 0x37
        moviw 1[FSR1]
        movwf 0x38
        call L_0DE0
        movlp 0x08
        goto L_08EC
L_0CB5:
        movlw 0x02
        movlp 0x1D
        call L_1D1C
        movlp 0x0C
        movlb 0x01
        decfsz 0x47, 0
        goto L_0CC5
        call L_0DC4
        movlw 0x68
        movlp 0x14
        call L_140F
        movlp 0x0C
        movlw 0xB4
        call L_0DCE
        movlp 0x0E
        goto L_0EA5
L_0CC5:
        movlw 0x02
        xorwf 0x47, 0
        btfss 0x03, 2               ; STATUS
        return
        call L_0DC4
        movlw 0x67
        movlp 0x14
        call L_140F
        movlp 0x0C
        call L_0DF0
        movlp 0x0C
        movf 0x70, 0                ; common 0x70
        movwi 0[FSR1]
        movf 0x71, 0                ; common 0x71
        movwi 1[FSR1]
        movf 0x72, 0                ; common 0x72
        movwi 2[FSR1]
        movf 0x73, 0                ; common 0x73
        movwi 3[FSR1]
        call L_0DF0
        movf 0x01, 0                ; INDF1
        movwf 0x36
        movlw 0x0A
        movlp 0x0E
        goto L_0E58
L_0CDE:
        movlp 0x1D
        call L_1D19
        movlp 0x0C
        movlb 0x00
        movf 0x6E, 0
        btfss 0x03, 2               ; STATUS
        goto L_0D0B
        movlw 0x03
        movlb 0x01
        xorwf 0x4E, 0
        btfsc 0x03, 2               ; STATUS
        goto L_0D0B
        movlw 0x03
        xorwf 0x47, 0
        btfss 0x03, 2               ; STATUS
        goto L_0CFA
        call L_0DC4
        movlw 0x69
        movlp 0x14
        call L_140F
        movlp 0x0C
        movlw 0xBC
        call L_0DCE
        movlp 0x0C
        movf 0x01, 0                ; INDF1
        movwf 0x36
        movlw 0x0C
        goto L_0D08
L_0CFA:
        movlw 0x04
        xorwf 0x47, 0
        btfss 0x03, 2               ; STATUS
        goto L_0D0B
        call L_0DC4
        movlw 0x6A
        movlp 0x14
        call L_140F
        movlp 0x0C
        movlw 0xC4
        call L_0DCE
        movf 0x01, 0                ; INDF1
        movwf 0x36
        movlw 0x0D
L_0D08:
        movlp 0x0E
        call L_0E58
        movlp 0x0C
L_0D0B:
        movlb 0x00
        movlw 0x09
        incf 0x6E, 1
        subwf 0x6E, 0
        btfss 0x03, 0               ; STATUS
        goto L_0D1A
        movlb 0x01
        movf 0x26, 0
        btfsc 0x03, 2               ; STATUS
        goto L_0D17
        movlp 0x08
        goto L_0810
L_0D17:
        movlw 0x02
        movlp 0x1D
        goto L_1D1C
L_0D1A:
        movlw 0xBC
        movwf 0x06                  ; FSR1L
        movlw 0x23
        movwf 0x07                  ; FSR1H
        moviw 0[FSR1]
        movwf 0x37
        moviw 1[FSR1]
        movwf 0x38
        call L_0DE0
        movlp 0x08
        goto L_08EC
L_0D25:
        movlp 0x16
        goto L_16FE
L_0D27:
        movlw 0x02
        movlp 0x1D
        goto L_1D1C
L_0D2A:
        movlb 0x01
        movlw 0x02
        clrf 0x26
        movlp 0x1D
        goto L_1D1C
L_0D2F:
        movlp 0x1B
        call L_1BFC
        movlp 0x0C
        moviw FSR1++
        xorlw 0x01
        movwf 0x4F
        moviw FSR1++
        iorwf 0x4F, 1
        moviw FSR1++
        iorwf 0x4F, 1
        moviw FSR1++
        iorwf 0x4F, 1
        btfss 0x03, 2               ; STATUS
        return
        movf 0x4C, 0
        addlw 0xA8
        movwf 0x06                  ; FSR1L
        movlw 0x01
        movwf 0x07                  ; FSR1H
        movf 0x01, 0                ; INDF1
        movwf 0x5C
        movlb 0x01
        movwf 0x20
        movlb 0x00
        movf 0x4C, 0
        addlw 0xB0
        movwf 0x06                  ; FSR1L
        movf 0x01, 0                ; INDF1
        movwf 0x61
        clrf 0x60
        movf 0x4C, 0
        addlw 0xAF
        movwf 0x06                  ; FSR1L
        movf 0x01, 0                ; INDF1
        addwf 0x60, 1
        btfsc 0x03, 0               ; STATUS
        incf 0x61, 1
        movf 0x60, 0
        movwf 0x4F
        movf 0x61, 0
        movwf 0x50
        movlw 0xB4
        clrf 0x51
        clrf 0x52
        movwf 0x06                  ; FSR1L
        movlw 0x23
        movwf 0x07                  ; FSR1H
        moviw 0[FSR1]
        movwf 0x53
        moviw 1[FSR1]
        movwf 0x54
        moviw 2[FSR1]
        movwf 0x55
        moviw 3[FSR1]
        movwf 0x56
        xorlw 0x80
        movwf 0x57
        movf 0x52, 0
        xorlw 0x80
        subwf 0x57, 0
        btfss 0x03, 2               ; STATUS
        goto L_0D77
        movf 0x51, 0
        subwf 0x55, 0
        btfss 0x03, 2               ; STATUS
        goto L_0D77
        movf 0x50, 0
        subwf 0x54, 0
        btfss 0x03, 2               ; STATUS
        goto L_0D77
        movf 0x4F, 0
        subwf 0x53, 0
L_0D77:
        btfss 0x03, 0               ; STATUS
        goto L_0D80
        movf 0x60, 0
        movwf 0x58
        movf 0x61, 0
        movwf 0x59
        clrf 0x5A
        clrf 0x5B
        goto L_0D8C
L_0D80:
        movlw 0xB4
        movwf 0x06                  ; FSR1L
        movlw 0x23
        movwf 0x07                  ; FSR1H
        moviw 0[FSR1]
        movwf 0x58
        moviw 1[FSR1]
        movwf 0x59
        moviw 2[FSR1]
        movwf 0x5A
        moviw 3[FSR1]
        movwf 0x5B
L_0D8C:
        movlw 0xCC
        movwf 0x06                  ; FSR1L
        movlw 0x23
        movwf 0x07                  ; FSR1H
        movf 0x58, 0
        movwi 0[FSR1]
        movf 0x59, 0
        movwi 1[FSR1]
        movf 0x5A, 0
        movwi 2[FSR1]
        movf 0x5B, 0
        movwi 3[FSR1]
        return
L_0D99:
        movf 0x5E, 0
        xorlw 0x01
        btfsc 0x03, 2               ; STATUS
        goto L_0DA1
        xorlw 0xAB
        btfsc 0x03, 2               ; STATUS
        goto L_0DBE
        goto L_0DC3
L_0DA1:
        movf 0x5D, 0
        xorlw 0x60
        btfsc 0x03, 2               ; STATUS
        goto L_0C9B
        xorlw 0x01
        btfsc 0x03, 2               ; STATUS
        goto L_0DC3
        xorlw 0x05
        btfsc 0x03, 2               ; STATUS
        goto L_0CDE
        xorlw 0xC6
        btfsc 0x03, 2               ; STATUS
        goto L_0D25
        xorlw 0x01
        btfsc 0x03, 2               ; STATUS
        goto L_0D27
        xorlw 0x07
        btfsc 0x03, 2               ; STATUS
        goto L_0DC3
        xorlw 0x0D
        btfsc 0x03, 2               ; STATUS
        goto L_0D2A
        xorlw 0x57
        btfsc 0x03, 2               ; STATUS
        goto L_0C96
        xorlw 0x01
        btfsc 0x03, 2               ; STATUS
        goto L_0C28
        goto L_0DC3
L_0DBE:
        movf 0x5D, 0
        xorlw 0x02
        btfsc 0x03, 2               ; STATUS
        goto L_0D2F
        goto L_0DC3
L_0DC3:
        return
L_0DC4:
        movf 0x73, 0                ; common 0x73
        movlb 0x00
        movwf 0x40
        movf 0x72, 0                ; common 0x72
        movwf 0x3F
        movf 0x71, 0                ; common 0x71
        movwf 0x3E
        movf 0x70, 0                ; common 0x70
        movwf 0x3D
        return
L_0DCE:
        movwf 0x06                  ; FSR1L
        movlw 0x23
        movwf 0x07                  ; FSR1H
        movf 0x70, 0                ; common 0x70
        movwi 0[FSR1]
        movf 0x71, 0                ; common 0x71
        movwi 1[FSR1]
        movf 0x72, 0                ; common 0x72
        movwi 2[FSR1]
        movf 0x73, 0                ; common 0x73
        movwi 3[FSR1]
        return
L_0DDA:
        movwf 0x06                  ; FSR1L
        movlw 0x23
        movwf 0x07                  ; FSR1H
        moviw 0[FSR1]
        movlb 0x00
        return
L_0DE0:
        moviw 2[FSR1]
        movwf 0x39
        moviw 3[FSR1]
        movwf 0x3A
        movlw 0xC4
        movwf 0x06                  ; FSR1L
        moviw 0[FSR1]
        movwf 0x3B
        moviw 1[FSR1]
        movwf 0x3C
        moviw 2[FSR1]
        movwf 0x3D
        moviw 3[FSR1]
        movwf 0x3E
        movf 0x6E, 0
        return
L_0DF0:
        movlw 0x90
        movwf 0x06                  ; FSR1L
        movlw 0x23
        movwf 0x07                  ; FSR1H
        addfsr FSR1L, 28
        return
L_0DF6:
        moviw 0[FSR1]
        movwf 0x46
        moviw 1[FSR1]
        movwf 0x47
        moviw 2[FSR1]
        movwf 0x48
        moviw 3[FSR1]
        movwf 0x49
        return
L_0DFF:
        movwf 0x42
        moviw 1[FSR1]
        movwf 0x43
        moviw 2[FSR1]
        movwf 0x44
        moviw 3[FSR1]
        movwf 0x45
        return
L_0E07:
        movwf 0x45
        movf 0x40, 0
        movwf 0x3D
        movf 0x45, 0
        movlp 0x14
        call L_1452
        movlp 0x0E
        movf 0x45, 0
        xorlw 0x6E
        btfsc 0x03, 2               ; STATUS
        goto L_0E16
        xorlw 0x01
        btfsc 0x03, 2               ; STATUS
        goto L_0E2A
        goto L_0E57
L_0E16:
        movf 0x40, 0
        btfsc 0x03, 2               ; STATUS
        goto L_0E1E
        movlb 0x01
        decf 0x2F, 0
        btfsc 0x03, 2               ; STATUS
        return
        goto L_0FF8
L_0E1E:
        movlw 0x02
        movlb 0x01
        xorwf 0x2F, 0
        btfsc 0x03, 2               ; STATUS
        return
        movlw 0x02
        clrf 0x2E
        incf 0x2E, 1
        clrf 0x32
        clrf 0x33
        movwf 0x30
        return
L_0E2A:
        movf 0x40, 0
        btfsc 0x03, 2               ; STATUS
        goto L_0E3F
        call L_0F99
        movlp 0x0E
        movwf 0x41
        moviw 1[FSR1]
        movwf 0x42
        moviw 2[FSR1]
        movwf 0x43
        moviw 3[FSR1]
        movwf 0x44
        iorwf 0x43, 0
        iorwf 0x42, 0
        iorwf 0x41, 0
        btfsc 0x03, 2               ; STATUS
        goto L_0E41
        movlb 0x01
        clrf 0x2D
        incf 0x2D, 1
        goto L_0E41
L_0E3F:
        movlb 0x01
        clrf 0x2D
L_0E41:
        movlb 0x00
        movf 0x40, 0
        movwf 0x41
        movlw 0xEC
        clrf 0x42
        clrf 0x43
        clrf 0x44
        movwf 0x06                  ; FSR1L
        movlw 0x23
        movwf 0x07                  ; FSR1H
        movf 0x41, 0
        movwi 0[FSR1]
        movf 0x42, 0
        movwi 1[FSR1]
        movf 0x43, 0
        movwi 2[FSR1]
        movf 0x44, 0
        movwi 3[FSR1]
        movf 0x01, 0                ; INDF1
        movwf 0x36
        movlw 0x09
        goto L_0E58
L_0E57:
        return
L_0E58:
        movwf 0x37
        call L_0EC5
        movlp 0x0E
        movlb 0x00
        movf 0x36, 0
        movwf 0x34
        movf 0x37, 0
        call L_0F51
        movlp 0x0E
        goto L_0ECC
L_0E62:
        call L_0EC5
        movlp 0x0E
        movlw 0xD4
        call L_0F8D
        movlp 0x0E
        movlw 0x04
        call L_0F51
        movlp 0x0E
        goto L_0ECC
L_0E6B:
        call L_0EC5
        movlp 0x0E
        movlw 0xFF
        movlb 0x00
        movwf 0x34
        movlw 0x00
        call L_0F51
        movlp 0x0E
        movlw 0xFF
        movlb 0x00
        movwf 0x34
        movlw 0x01
        call L_0F51
        movlp 0x0E
        goto L_0ECC
L_0E7A:
        call L_0EC5
        movlp 0x0E
        call L_0F9F
        movlp 0x0E
        call L_0F51
        movlp 0x0E
        call L_0F9F
        movlp 0x0E
        call L_0F51
        movlp 0x0E
        goto L_0ECC
L_0E85:
        call L_0EC5
        movlp 0x0E
        movlw 0xDC
        call L_0F8D
        movlp 0x0E
        movlw 0x05
        call L_0F51
        movlw 0xDC
        movlp 0x0D
        call L_0DDA
        movlp 0x0E
        movwf 0x36
        moviw 1[FSR1]
        movwf 0x37
        moviw 2[FSR1]
        movwf 0x38
        moviw 3[FSR1]
        movwf 0x39
        movlw 0x08
        movwf 0x3A
L_0E99:
        asrf 0x39, 1
        rrf 0x38, 1
        rrf 0x37, 1
        rrf 0x36, 1
        decfsz 0x3A, 1
        goto L_0E99
        movf 0x36, 0
        movwf 0x34
        movlw 0x06
        call L_0F51
        movlp 0x0E
        goto L_0ECC
L_0EA5:
        call L_0EC5
        movlp 0x0E
        movlw 0xB4
        call L_0F8D
        movlp 0x0E
        movlw 0x07
        call L_0F51
        movlw 0xB4
        movlp 0x0D
        call L_0DDA
        movlp 0x0E
        movwf 0x36
        moviw 1[FSR1]
        movwf 0x37
        moviw 2[FSR1]
        movwf 0x38
        moviw 3[FSR1]
        movwf 0x39
        movlw 0x08
        movwf 0x3A
L_0EB9:
        asrf 0x39, 1
        rrf 0x38, 1
        rrf 0x37, 1
        rrf 0x36, 1
        decfsz 0x3A, 1
        goto L_0EB9
        movf 0x36, 0
        movwf 0x34
        movlw 0x08
        call L_0F51
        movlp 0x0E
        goto L_0ECC
L_0EC5:
        bcf 0x0B, 6                 ; INTCON
L_0EC6:
        btfss 0x0B, 7               ; INTCON
        return
        bcf 0x0B, 7                 ; INTCON
        nop
        nop
        goto L_0EC6
L_0ECC:
        bsf 0x0B, 7                 ; INTCON
        bsf 0x0B, 6                 ; INTCON
        return
L_0ECF:
        call L_0EC5
        movlp 0x0E
        movlw 0xEC
        movwf 0x06                  ; FSR1L
        movlw 0x23
        movwf 0x07                  ; FSR1H
        moviw FSR1++
        xorlw 0x01
        call L_0F6A
        movlp 0x0E
        btfsc 0x03, 2               ; STATUS
        goto L_0EE4
        movlw 0xEC
        call L_0F79
        movlp 0x0E
        call L_0F73
        movlp 0x0E
        movlw 0x09
        clrf 0x34
        incf 0x34, 1
        call L_0F51
L_0EE4:
        movlp 0x0D
        call L_0DF0
        movlp 0x0E
        moviw FSR1++
        xorlw 0x05
        call L_0F6A
        movlp 0x0E
        btfsc 0x03, 2               ; STATUS
        goto L_0EFF
        movlw 0x90
        movwf 0x06                  ; FSR1L
        movlw 0x23
        movwf 0x07                  ; FSR1H
        movlw 0x05
        addfsr FSR1L, 28
        call L_0F73
        movlp 0x0E
        movlw 0x05
        movwf 0x34
        movlw 0x0A
        call L_0F51
        movlp 0x0E
        movlb 0x00
        movlw 0x0B
        clrf 0x34
        call L_0F51
        movlp 0x0E
L_0EFF:
        movlw 0xBC
        movwf 0x06                  ; FSR1L
        call L_0F84
        movlp 0x0E
        call L_0F6A
        movlp 0x0E
        btfsc 0x03, 2               ; STATUS
        goto L_0F11
        movlw 0xBC
        call L_0F89
        movlp 0x0E
        call L_0F73
        movlp 0x0E
        movlw 0x03
        movwf 0x34
        movlw 0x0C
        call L_0F51
        movlp 0x0E
L_0F11:
        movlw 0xC4
        movwf 0x06                  ; FSR1L
        call L_0F84
        movlp 0x0E
        call L_0F6A
        movlp 0x0E
        btfsc 0x03, 2               ; STATUS
        goto L_0F23
        movlw 0xC4
        call L_0F89
        movlp 0x0E
        call L_0F73
        movlp 0x0E
        movlw 0x03
        movwf 0x34
        movlw 0x0D
        call L_0F51
        movlp 0x0E
L_0F23:
        movlw 0x90
        call L_0F7D
        movlp 0x0E
        call L_0F6A
        movlp 0x0E
        btfsc 0x03, 2               ; STATUS
        goto L_0F34
        call L_0F94
        movlp 0x0E
        addfsr FSR1L, 12
        call L_0F73
        movlp 0x0E
        movlw 0x0E
        clrf 0x34
        incf 0x34, 1
        call L_0F51
        movlp 0x0E
L_0F34:
        call L_0ECC
        movlp 0x0E
        movlw 0x90
        call L_0F7D
        movlp 0x0E
        call L_0F6A
        movlp 0x0E
        btfss 0x03, 2               ; STATUS
        goto L_0F3F
        movlp 0x11
        goto L_11FF
L_0F3F:
        call L_0F99
        movlp 0x0E
        movwf 0x36
        moviw 1[FSR1]
        movwf 0x37
        moviw 2[FSR1]
        movwf 0x38
        moviw 3[FSR1]
        movwf 0x39
        iorwf 0x38, 0
        iorwf 0x37, 0
        iorwf 0x36, 0
        btfsc 0x03, 2               ; STATUS
        goto L_0F4F
        movlp 0x12
        goto L_1207
L_0F4F:
        movlp 0x12
        goto L_1203
L_0F51:
        movwf 0x35
        movlb 0x03
        movwf 0x11                  ; EEADRL
        movlb 0x00
        movf 0x34, 0
        movlb 0x03
        movwf 0x13                  ; EEDATL
        bcf 0x15, 6                 ; EECON1
        bcf 0x15, 7                 ; EECON1
        bsf 0x15, 2                 ; EECON1
        bcf 0x0B, 2                 ; INTCON
        movlw 0x55
        movwf 0x16                  ; EECON2
        movlw 0xAA
        movwf 0x16                  ; EECON2
        bsf 0x15, 1                 ; EECON1
        nop
        nop
        nop
        nop
L_0F65:
        movlb 0x03
        btfsc 0x15, 1               ; EECON1
        goto L_0F65
        bcf 0x15, 2                 ; EECON1
        return
L_0F6A:
        movlb 0x00
        movwf 0x36
        moviw FSR1++
        iorwf 0x36, 1
        moviw FSR1++
        iorwf 0x36, 1
        moviw FSR1++
        iorwf 0x36, 1
        return
L_0F73:
        movwi 0[FSR1]
        movlw 0x00
        movwi 1[FSR1]
        movwi 2[FSR1]
        movwi 3[FSR1]
        return
L_0F79:
        movwf 0x06                  ; FSR1L
        movlw 0x23
        movwf 0x07                  ; FSR1H
        retlw 0x01
L_0F7D:
        movwf 0x06                  ; FSR1L
        movlw 0x23
        movwf 0x07                  ; FSR1H
        addfsr FSR1L, 12
        moviw FSR1++
        xorlw 0x01
        return
L_0F84:
        movlw 0x23
        movwf 0x07                  ; FSR1H
        moviw FSR1++
        xorlw 0x03
        return
L_0F89:
        movwf 0x06                  ; FSR1L
        movlw 0x23
        movwf 0x07                  ; FSR1H
        retlw 0x03
L_0F8D:
        movwf 0x06                  ; FSR1L
        movlw 0x23
        movwf 0x07                  ; FSR1H
        movf 0x01, 0                ; INDF1
        movlb 0x00
        movwf 0x34
        return
L_0F94:
        movlw 0x90
        movwf 0x06                  ; FSR1L
        movlw 0x23
        movwf 0x07                  ; FSR1H
        retlw 0x01
L_0F99:
        movlw 0xE4
        movwf 0x06                  ; FSR1L
        movlw 0x23
        movwf 0x07                  ; FSR1H
        moviw 0[FSR1]
        return
L_0F9F:
        movlw 0xAA
        movlb 0x00
        movwf 0x34
        retlw 0x7F
L_0FA3:
        movlb 0x00
        btfss 0x0C, 3               ; PORTA
        goto L_0FCE
        call L_0FFC
        movlp 0x0E
        btfsc 0x03, 2               ; STATUS
        subwf 0x22, 0
        btfss 0x03, 0               ; STATUS
        goto L_0FB8
        clrf 0x22
        clrf 0x23
        movf 0x4D, 0
        btfss 0x03, 2               ; STATUS
        goto L_0FB3
        movlw 0x01
        goto L_0FB4
L_0FB3:
        movlw 0x00
L_0FB4:
        movwf 0x4D
        call L_0FEB
        movlp 0x0E
        goto L_0FDD
L_0FB8:
        movf 0x22, 0
        iorwf 0x23, 0
        btfsc 0x03, 2               ; STATUS
        goto L_0FDD
        clrf 0x22
        clrf 0x23
        movf 0x50, 0
        btfsc 0x03, 2               ; STATUS
        goto L_0FC4
        clrf 0x48
        incf 0x48, 1
        goto L_0FDD
L_0FC4:
        decf 0x2F, 0
        btfsc 0x03, 2               ; STATUS
        goto L_0FCB
        clrf 0x31
        clrf 0x30
        incf 0x30, 1
        goto L_0FDD
L_0FCB:
        call L_0FF2
        movlp 0x0E
        goto L_0FDD
L_0FCE:
        call L_0FFC
        movlp 0x0E
        btfsc 0x03, 2               ; STATUS
        subwf 0x22, 0
        btfss 0x03, 0               ; STATUS
        goto L_0FD6
        clrf 0x2D
        goto L_0FDD
L_0FD6:
        movf 0x50, 0
        btfss 0x03, 2               ; STATUS
        goto L_0FDD
        decfsz 0x24, 0
        goto L_0FDD
        clrf 0x2D
        incf 0x2D, 1
L_0FDD:
        movlb 0x00
        btfss 0x0E, 0               ; PORTC
        return
        movlb 0x01
        movf 0x25, 0
        btfsc 0x03, 2               ; STATUS
        return
        clrf 0x25
        decf 0x2F, 0
        btfsc 0x03, 2               ; STATUS
        goto L_0FE9
        goto L_0FF8
L_0FE9:
        call L_0FF2
        return
L_0FEB:
        movlw 0x03
        movlb 0x00
        movwf 0x39
        movlw 0x04
        clrf 0x3A
        movlp 0x1F
        goto L_1FA2
L_0FF2:
        movlw 0x02
        movwf 0x2E
        clrf 0x32
        clrf 0x33
        movwf 0x30
        return
L_0FF8:
        clrf 0x31
        clrf 0x30
        incf 0x30, 1
        return
L_0FFC:
        movlw 0x13
        movlb 0x01
        subwf 0x23, 0
        retlw 0x89
        nop
L_1001:
        movlb 0x00
        btfsc 0x0C, 3               ; PORTA
        return
        movlb 0x01
        movf 0x50, 0
        btfss 0x03, 2               ; STATUS
        goto L_1001
        movlb 0x00
        bsf 0x0D, 6                 ; PORTB
        bsf 0x0C, 2                 ; PORTA
        movlw 0x05
        movlb 0x01
        subwf 0x4F, 0
        btfss 0x03, 0               ; STATUS
        goto L_1001
        clrf 0x50
        incf 0x50, 1
        movlb 0x00
        bcf 0x0D, 6                 ; PORTB
        bcf 0x0C, 2                 ; PORTA
        movlb 0x02
        goto L_1001
L_1017:
        movlw 0x90
        movlb 0x00
        call L_10E0
        movlp 0x10
        movlw 0x01
        call L_10B1
        movlp 0x10
        movlw 0x04
        movwf 0x01                  ; INDF1
        movf 0x36, 0
        movwf 0x06                  ; FSR1L
        movf 0x37, 0
        movwf 0x07                  ; FSR1H
        movlw 0x98
        addfsr FSR1L, 2
        clrf 0x01                   ; INDF1
        call L_10E0
        movlp 0x10
        movlw 0x65
        call L_10B1
        movlp 0x10
        movlw 0x04
        call L_10CB
        movlp 0x10
        movlw 0x01
        call L_10E8
        movlp 0x10
        movlw 0xA0
        call L_10E0
        movlp 0x10
        movlw 0x66
        call L_10B1
        movlp 0x10
        movlw 0x04
        movwf 0x01                  ; INDF1
        call L_10D7
        movlp 0x10
        call L_10BD
        movlp 0x10
        movlw 0xA8
        call L_10E0
        movlp 0x10
        movlw 0x67
        call L_10B1
        movlp 0x10
        movlw 0x02
        call L_10CB
        movlp 0x10
        movlw 0x05
        call L_10E8
        movlp 0x10
        movlw 0xB0
        call L_10E0
        movlp 0x10
        movlw 0x68
        call L_10B1
        movlp 0x10
        movlw 0x02
        call L_10CB
        movlp 0x10
        movlw 0x58
        addfsr FSR1L, 4
        movwi 0[FSR1]
        movlw 0x02
        movwi 1[FSR1]
        movlw 0x00
        movwi 2[FSR1]
        movwi 3[FSR1]
        movlw 0xB8
        call L_10E0
        movlp 0x10
        movlw 0x69
        call L_10B1
        movlp 0x10
        movlw 0x02
        call L_10CB
        movlp 0x10
        movlw 0x03
        call L_10E8
        movlp 0x10
        movlw 0xC0
        call L_10E0
        movlp 0x10
        movlw 0x6A
        call L_10B1
        movlp 0x10
        movlw 0x02
        call L_10CB
        movlp 0x10
        movlw 0x03
        call L_10E8
        movlp 0x10
        movlw 0xC8
        call L_10E0
        movlp 0x10
        movlw 0x6B
        call L_10B1
        movlp 0x10
        movlw 0x02
        movwf 0x01                  ; INDF1
        call L_10D7
        movlp 0x10
        call L_10BD
        movlp 0x10
        movlw 0xD0
        call L_10E0
        movlp 0x10
        movlw 0x6C
        call L_10B1
        movlp 0x10
        movlw 0x04
        call L_10CB
        movlp 0x10
        movlw 0x03
        call L_10E8
        movlp 0x10
        movlw 0xD8
        call L_10E0
        movlp 0x10
        movlw 0x6D
        call L_10B1
        movlp 0x10
        movlw 0x02
        call L_10CB
        movlp 0x10
        movlw 0x0A
        call L_10E8
        movlp 0x10
        movlw 0xE0
        call L_10E0
        movlp 0x10
        movlw 0x6E
        call L_10B1
        movlp 0x10
        movlw 0x01
        movwf 0x01                  ; INDF1
        movf 0x36, 0
        movwf 0x06                  ; FSR1L
        movf 0x37, 0
        movwf 0x07                  ; FSR1H
        movlw 0xE8
        addfsr FSR1L, 2
        clrf 0x01                   ; INDF1
        call L_10E0
        movlp 0x10
        movlw 0x6F
        call L_10B1
        movlp 0x10
        movlw 0x01
        call L_10CB
        movlp 0x10
        movlw 0x01
        call L_10E8
        return
L_10B1:
        movwf 0x01                  ; INDF1
        movf 0x36, 0
        addlw 0x01
        movwf 0x34
        movlw 0x00
        addwfc 0x37, 0
        movwf 0x35
        movf 0x34, 0
        movwf 0x06                  ; FSR1L
        movf 0x35, 0
        movwf 0x07                  ; FSR1H
        return
L_10BD:
        movwf 0x34
        movlw 0x00
        addwfc 0x37, 0
        movwf 0x35
        movf 0x34, 0
        movwf 0x06                  ; FSR1L
        movf 0x35, 0
        movwf 0x07                  ; FSR1H
        movlw 0x00
        movwi 0[FSR1]
        movwi 1[FSR1]
        movwi 2[FSR1]
        movwi 3[FSR1]
        return
L_10CB:
        movwf 0x01                  ; INDF1
        movf 0x36, 0
        movwf 0x06                  ; FSR1L
        movf 0x37, 0
        movwf 0x07                  ; FSR1H
        addfsr FSR1L, 2
        clrf 0x01                   ; INDF1
        movf 0x36, 0
        movwf 0x06                  ; FSR1L
        movf 0x37, 0
        movwf 0x07                  ; FSR1H
        return
L_10D7:
        movf 0x36, 0
        movwf 0x06                  ; FSR1L
        movf 0x37, 0
        movwf 0x07                  ; FSR1H
        addfsr FSR1L, 2
        clrf 0x01                   ; INDF1
        movf 0x36, 0
        addlw 0x04
        return
L_10E0:
        movwf 0x36
        movlw 0x23
        movwf 0x37
        movf 0x36, 0
        movwf 0x06                  ; FSR1L
        movf 0x37, 0
        movwf 0x07                  ; FSR1H
        return
L_10E8:
        addfsr FSR1L, 4
        movwi 0[FSR1]
        movlw 0x00
        movwi 1[FSR1]
        movwi 2[FSR1]
        movwi 3[FSR1]
        return
L_10EF:
        movlp 0x0E
        call L_0E7A
        movlp 0x10
        movlw 0x04
        call L_11B1
        movlp 0x10
        movwf 0x3D
        incf 0x3D, 0
        btfsc 0x03, 2               ; STATUS
        goto L_10FE
        movf 0x3D, 0
        movwf 0x36
        movlw 0xD4
        call L_11C1
        movlp 0x10
L_10FE:
        movlw 0x05
        call L_11B1
        movlp 0x10
        movwf 0x3D
        incf 0x3D, 0
        btfsc 0x03, 2               ; STATUS
        goto L_1115
        movf 0x3D, 0
        movwf 0x36
        movlw 0xDC
        call L_11C1
        movlp 0x10
        movlw 0x06
        call L_11B1
        movlp 0x10
        call L_11DF
        movlp 0x10
        movlw 0xDC
        movwf 0x06                  ; FSR1L
        movlw 0x23
        movwf 0x07                  ; FSR1H
        call L_11EE
        movlp 0x10
L_1115:
        movlw 0x07
        call L_11B1
        movlp 0x10
        movwf 0x3D
        incf 0x3D, 0
        btfsc 0x03, 2               ; STATUS
        goto L_112C
        movf 0x3D, 0
        movwf 0x36
        movlw 0xB4
        call L_11C1
        movlp 0x10
        movlw 0x08
        call L_11B1
        movlp 0x10
        call L_11DF
        movlp 0x10
        movlw 0xB4
        movwf 0x06                  ; FSR1L
        movlw 0x23
        movwf 0x07                  ; FSR1H
        call L_11EE
        movlp 0x10
L_112C:
        movlw 0x09
        call L_11B1
        movlp 0x10
        movwf 0x3D
        incfsz 0x3D, 0
        goto L_113A
        movlw 0xEC
        movlp 0x0F
        call L_0F79
        movlp 0x10
        movlp 0x0F
        call L_0F73
        movlp 0x10
        goto L_113F
L_113A:
        movf 0x3D, 0
        movwf 0x36
        movlw 0xEC
        call L_11C1
        movlp 0x10
L_113F:
        movlw 0x0A
        call L_11B1
        movlp 0x10
        movwf 0x3D
        incf 0x3D, 0
        btfsc 0x03, 2               ; STATUS
        goto L_1156
        call L_11FA
        movlp 0x10
        call L_11D0
        movlp 0x10
        addfsr FSR1L, 28
        call L_11D6
        movlp 0x10
        movlw 0x0B
        call L_11B1
        movlp 0x10
        call L_11DF
        movlp 0x0D
        call L_0DF0
        movlp 0x10
        call L_11EE
        movlp 0x10
L_1156:
        movlw 0x0C
        call L_11B1
        movlp 0x10
        movwf 0x3D
        incf 0x3D, 0
        btfsc 0x03, 2               ; STATUS
        goto L_1162
        movf 0x3D, 0
        movwf 0x36
        movlw 0xBC
        call L_11C1
        movlp 0x10
L_1162:
        movlw 0x0D
        call L_11B1
        movlp 0x10
        movwf 0x3D
        incf 0x3D, 0
        btfsc 0x03, 2               ; STATUS
        goto L_116E
        movf 0x3D, 0
        movwf 0x36
        movlw 0xC4
        call L_11C1
        movlp 0x10
L_116E:
        movlw 0x0E
        call L_11B1
        movlp 0x10
        movwf 0x3D
        incf 0x3D, 0
        btfsc 0x03, 2               ; STATUS
        goto L_117C
        call L_11FA
        movlp 0x10
        call L_11D0
        movlp 0x10
        addfsr FSR1L, 12
        call L_11D6
        movlp 0x10
L_117C:
        movlw 0x0F
        call L_11B1
        movlp 0x10
        movwf 0x3D
        incf 0x3D, 0
        btfsc 0x03, 2               ; STATUS
        goto L_1187
        movf 0x3D, 0
        movwf 0x36
        movlw 0xE4
        call L_11C1
L_1187:
        movlb 0x01
        movlw 0x90
        clrf 0x20
        clrf 0x34
        clrf 0x35
        clrf 0x36
        clrf 0x37
        clrf 0x26
        clrf 0x21
        clrf 0x24
        incf 0x24, 1
        movlp 0x0F
        call L_0F7D
        movlp 0x10
        movlb 0x00
        movwf 0x36
        moviw FSR1++
        iorwf 0x36, 1
        moviw FSR1++
        iorwf 0x36, 1
        moviw FSR1++
        iorwf 0x36, 1
        btfss 0x03, 2               ; STATUS
        goto L_11A0
        goto L_11FF
L_11A0:
        movlp 0x0F
        call L_0F99
        movlp 0x10
        movwf 0x36
        moviw 1[FSR1]
        movwf 0x37
        moviw 2[FSR1]
        movwf 0x38
        moviw 3[FSR1]
        movwf 0x39
        iorwf 0x38, 0
        iorwf 0x37, 0
        iorwf 0x36, 0
        btfsc 0x03, 2               ; STATUS
        goto L_11B0
        goto L_1207
L_11B0:
        goto L_1203
L_11B1:
        movlb 0x00
        movwf 0x34
        movlb 0x03
        movwf 0x11                  ; EEADRL
        bcf 0x15, 6                 ; EECON1
        bcf 0x15, 7                 ; EECON1
        bsf 0x15, 0                 ; EECON1
        nop
        nop
        nop
        nop
        movlb 0x03
        movf 0x13, 0                ; EEDATL
        movlb 0x00
        movwf 0x35
        return
L_11C1:
        clrf 0x37
        clrf 0x38
        clrf 0x39
        movwf 0x06                  ; FSR1L
        movlw 0x23
        movwf 0x07                  ; FSR1H
        movf 0x36, 0
        movwi 0[FSR1]
        movf 0x37, 0
        movwi 1[FSR1]
        movf 0x38, 0
        movwi 2[FSR1]
        movf 0x39, 0
        movwi 3[FSR1]
        return
L_11D0:
        clrf 0x38
        clrf 0x39
        movwf 0x06                  ; FSR1L
        movlw 0x23
        movwf 0x07                  ; FSR1H
        return
L_11D6:
        movf 0x36, 0
        movwi 0[FSR1]
        movf 0x37, 0
        movwi 1[FSR1]
        movf 0x38, 0
        movwi 2[FSR1]
        movf 0x39, 0
        movwi 3[FSR1]
        return
L_11DF:
        movwf 0x3D
        movwf 0x36
        clrf 0x37
        movwf 0x37
        clrf 0x36
        movf 0x36, 0
        movwf 0x39
        movf 0x37, 0
        movwf 0x3A
        movlw 0x00
        btfsc 0x3A, 7
        movlw 0xFF
        movwf 0x3B
        movwf 0x3C
        return
L_11EE:
        movf 0x39, 0
        addwf 0x01, 1               ; INDF1
        addfsr FSR1L, 1
        movf 0x3A, 0
        addwfc 0x01, 1              ; INDF1
        addfsr FSR1L, 1
        movf 0x3B, 0
        addwfc 0x01, 1              ; INDF1
        addfsr FSR1L, 1
        movf 0x3C, 0
        addwfc 0x01, 1              ; INDF1
        return
L_11FA:
        movf 0x3D, 0
        movwf 0x36
        movlw 0x90
        clrf 0x37
        return
L_11FF:
        movlw 0x03
        movlb 0x01
        movwf 0x30
        return
L_1203:
        movlb 0x01
        clrf 0x2F
        clrf 0x30
        return
L_1207:
        movlb 0x01
        clrf 0x30
        incf 0x30, 1
        return
L_120B:
        movf 0x31, 0
        btfsc 0x03, 2               ; STATUS
        goto L_1272
        movlp 0x1B
        call L_1BC4
        movlp 0x12
        movf 0x43, 0
        movlb 0x01
        subwf 0x37, 0
        btfss 0x03, 2               ; STATUS
        goto L_1226
        movlb 0x00
        movf 0x42, 0
        movlb 0x01
        subwf 0x36, 0
        btfss 0x03, 2               ; STATUS
        goto L_1226
        movlb 0x00
        movf 0x41, 0
        movlb 0x01
        subwf 0x35, 0
        btfss 0x03, 2               ; STATUS
        goto L_1226
        movlb 0x00
        movf 0x40, 0
        movlb 0x01
        subwf 0x34, 0
L_1226:
        btfss 0x03, 0               ; STATUS
        goto L_1272
        movlw 0x03
        movwf 0x2E
        movlw 0x02
        clrf 0x32
        clrf 0x33
        movlp 0x1F
        call L_1FFA
        movlp 0x12
        goto L_1253
L_1231:
        movlw 0x02
        xorwf 0x2E, 0
        btfss 0x03, 2               ; STATUS
        goto L_1239
        movlw 0x46
        subwf 0x33, 0
        movlw 0x50
        goto L_1243
L_1239:
        decfsz 0x2E, 0
        goto L_123C
        goto L_1240
L_123C:
        movlw 0x03
        xorwf 0x2E, 0
        btfss 0x03, 2               ; STATUS
        goto L_1247
L_1240:
        movlw 0x00
        subwf 0x33, 0
        movlw 0x32
L_1243:
        btfsc 0x03, 2               ; STATUS
        subwf 0x32, 0
        btfsc 0x03, 0               ; STATUS
        clrf 0x2E
L_1247:
        movf 0x2E, 0
        btfss 0x03, 2               ; STATUS
        goto L_1272
        movlp 0x14
        call L_14AD
        movlp 0x12
        call L_1352
        movlp 0x12
        btfss 0x03, 2               ; STATUS
        goto L_1255
        movlw 0x03
        movlb 0x01
L_1253:
        movwf 0x30
        goto L_1272
L_1255:
        movlb 0x01
        clrf 0x30
        goto L_1272
L_1258:
        movlp 0x1B
        call L_1BFC
        movlp 0x12
        call L_1352
        movlp 0x12
        btfss 0x03, 2               ; STATUS
        goto L_1272
        movlp 0x0A
        call L_0A2E
        movlp 0x12
        goto L_1272
L_1263:
        movlb 0x01
        movf 0x2F, 0
        xorlw 0x00
        btfsc 0x03, 2               ; STATUS
        goto L_1272
        xorlw 0x01
        btfsc 0x03, 2               ; STATUS
        goto L_120B
        xorlw 0x03
        btfsc 0x03, 2               ; STATUS
        goto L_1231
        xorlw 0x01
        btfsc 0x03, 2               ; STATUS
        goto L_1258
        goto L_1258
L_1272:
        movlp 0x1C
        call L_1C1E
        movlp 0x12
        xorwf 0x58, 0
        btfsc 0x03, 2               ; STATUS
        goto L_1292
        movlp 0x1C
        call L_1C1E
        movlp 0x12
        movwf 0x58
        movf 0x58, 0
        btfsc 0x03, 2               ; STATUS
        goto L_1292
        movlw 0x90
        movlp 0x0C
        call L_0C09
        movlp 0x12
        movlp 0x10
        call L_10E8
        movlp 0x12
        movlw 0x92
        movlp 0x1C
        call L_1C24
        movlp 0x12
        movlw 0xCA
        movwf 0x06                  ; FSR1L
        movlw 0x01
        movwf 0x01                  ; INDF1
        clrf 0x39
        clrf 0x3A
        clrf 0x38
        incf 0x38, 1
L_1292:
        movlw 0x04
        xorwf 0x5D, 0
        btfss 0x03, 2               ; STATUS
        goto L_1340
        movlp 0x1B
        call L_1BFC
        movlp 0x12
        call L_1352
        movlp 0x12
        btfss 0x03, 2               ; STATUS
        goto L_133C
        movlp 0x1B
        call L_1BC4
        movlp 0x12
        movf 0x43, 0
        movlb 0x01
        movwf 0x57
        movlb 0x00
        movf 0x42, 0
        movlb 0x01
        movwf 0x56
        movlb 0x00
        movf 0x41, 0
        movlb 0x01
        movwf 0x55
        movlb 0x00
        movf 0x40, 0
        movlb 0x01
        movwf 0x54
        movf 0x57, 0
        btfss 0x03, 2               ; STATUS
        goto L_12BB
        movf 0x56, 0
        btfss 0x03, 2               ; STATUS
        goto L_12BB
        movlw 0x2D
        subwf 0x54, 0
        movlw 0x01
        subwfb 0x55, 0
        btfss 0x03, 0               ; STATUS
        goto L_12C1
L_12BB:
        movlw 0x01
        clrf 0x57
        clrf 0x56
        movwf 0x55
        movlw 0x2C
        movwf 0x54
L_12C1:
        movf 0x39, 0
        movlb 0x00
        movwf 0x2A
        movlb 0x01
        movf 0x3A, 0
        movlb 0x00
        movwf 0x2B
        clrf 0x2C
        clrf 0x2D
        movlb 0x01
        movf 0x57, 0
        movlb 0x00
        subwf 0x2D, 0
        btfss 0x03, 2               ; STATUS
        goto L_12E0
        movlb 0x01
        movf 0x56, 0
        movlb 0x00
        subwf 0x2C, 0
        btfss 0x03, 2               ; STATUS
        goto L_12E0
        movlb 0x01
        movf 0x55, 0
        movlb 0x00
        subwf 0x2B, 0
        btfss 0x03, 2               ; STATUS
        goto L_12E0
        movlb 0x01
        movf 0x54, 0
        movlb 0x00
        subwf 0x2A, 0
L_12E0:
        btfss 0x03, 0               ; STATUS
        goto L_130C
        movlw 0x94
        movwf 0x06                  ; FSR1L
        movlw 0x23
        movlp 0x1B
        call L_1BF5
        movlp 0x12
        movlw 0x92
        movwf 0x06                  ; FSR1L
        movlw 0x01
        movwf 0x01                  ; INDF1
        movlw 0xA4
        movlp 0x1C
        call L_1C10
        movlp 0x12
        movlw 0xA2
        movwf 0x06                  ; FSR1L
        movlw 0x01
        movwf 0x01                  ; INDF1
        movlw 0xB4
        movwf 0x06                  ; FSR1L
        moviw 0[FSR1]
        movwf 0x2A
        moviw 1[FSR1]
        movwf 0x2B
        moviw 2[FSR1]
        movwf 0x2C
        moviw 3[FSR1]
        movwf 0x2D
        movlw 0xCC
        movwf 0x06                  ; FSR1L
        movf 0x2A, 0
        movwi 0[FSR1]
        movf 0x2B, 0
        movwi 1[FSR1]
        movf 0x2C, 0
        movwi 2[FSR1]
        movf 0x2D, 0
        movwi 3[FSR1]
        movlw 0xCA
        movwf 0x06                  ; FSR1L
        movlw 0x01
        movwf 0x01                  ; INDF1
L_130C:
        movlw 0x0A
        movlb 0x01
        subwf 0x51, 0
        btfss 0x03, 0               ; STATUS
        goto L_133C
        clrf 0x51
        btfss 0x20, 0
        goto L_1329
        movlp 0x1C
        call L_1C0A
        movlp 0x12
        moviw FSR1++
        xorlw 0x02
        movlb 0x00
        movwf 0x2A
        moviw FSR1++
        iorwf 0x2A, 1
        moviw FSR1++
        iorwf 0x2A, 1
        moviw FSR1++
        iorwf 0x2A, 1
        btfsc 0x03, 2               ; STATUS
        goto L_133C
        movlw 0x90
        movwf 0x06                  ; FSR1L
        movlw 0x23
        movwf 0x07                  ; FSR1H
        movlw 0x02
        goto L_1335
L_1329:
        btfss 0x20, 1
        goto L_133C
        movlp 0x1C
        call L_1C0A
        movlp 0x12
        call L_1352
        movlp 0x12
        btfsc 0x03, 2               ; STATUS
        goto L_133C
        movlp 0x0F
        call L_0F94
        movlp 0x12
L_1335:
        movlp 0x1C
        call L_1C17
        movlp 0x12
        movlw 0xA2
        movlp 0x1C
        call L_1C24
        movlp 0x12
L_133C:
        movlp 0x13
        call L_137A
L_133E:
        movlp 0x1E
        goto L_1EBB
L_1340:
        movlw 0xAA
        xorwf 0x24, 0
        btfss 0x03, 2               ; STATUS
        goto L_133E
        movlw 0x04
        subwf 0x42, 0
        movlw 0xB1
        btfsc 0x03, 2               ; STATUS
        subwf 0x41, 0
        btfss 0x03, 0               ; STATUS
        goto L_133E
        clrf 0x41
        clrf 0x42
        clrf 0x4D
        clrf 0x24
        incf 0x24, 1
        clrf 0x2D
        goto L_133E
L_1352:
        moviw FSR1++
        xorlw 0x01
        movlb 0x00
        movwf 0x2A
        moviw FSR1++
        iorwf 0x2A, 1
        moviw FSR1++
        iorwf 0x2A, 1
        moviw FSR1++
        iorwf 0x2A, 1
        return
L_135D:
        clrf 0x3D
        movlb 0x01
        movf 0x43, 0
        btfss 0x03, 2               ; STATUS
        goto L_136C
        movlb 0x00
        clrf 0x34
        movf 0x3D, 0
        call L_1444
        movlp 0x13
        movwf 0x3D
        movlb 0x01
        clrf 0x43
        incf 0x43, 1
        goto L_1372
L_136C:
        movlb 0x00
        clrf 0x34
        incf 0x34, 1
        movf 0x3D, 0
        call L_1444
        movwf 0x3D
L_1372:
        movlw 0x03
        movlb 0x00
        movwf 0x39
        movf 0x3D, 0
        movwf 0x3A
        movlw 0x00
        movlp 0x1F
        goto L_1FA2
L_137A:
        movlw 0x90
        movlb 0x00
        movwf 0x4A
        movlw 0x23
        movwf 0x4B
        movlw 0x0C
        movwf 0x49
        clrf 0x4C
L_1382:
        movf 0x49, 0
        subwf 0x4C, 0
        btfsc 0x03, 0               ; STATUS
        return
        call L_1473
        movlp 0x13
        addfsr FSR1L, 2
        decfsz 0x01, 0              ; INDF1
        goto L_13BC
        call L_1473
        movlp 0x13
        addfsr FSR1L, 2
        clrf 0x01                   ; INDF1
        goto L_13AE
L_1390:
        call L_1473
        movlp 0x13
        addfsr FSR1L, 4
        movf 0x01, 0                ; INDF1
        movwf 0x3D
        call L_149C
        movlp 0x13
        call L_1452
        movlp 0x13
        goto L_13BC
L_139A:
        call L_1473
        movlp 0x13
        addfsr FSR1L, 4
        movf 0x01, 0                ; INDF1
        movwf 0x3D
        call L_149C
        movlp 0x1F
        call L_1F7B
        movlp 0x13
        goto L_13BC
L_13A4:
        call L_1473
        movlp 0x13
        addfsr FSR1L, 4
        call L_1493
        movlp 0x13
        call L_149C
        movlp 0x13
        call L_140F
        movlp 0x13
        goto L_13BC
L_13AE:
        call L_1473
        movlp 0x13
        addfsr FSR1L, 1
        movf 0x01, 0                ; INDF1
        xorlw 0x01
        btfsc 0x03, 2               ; STATUS
        goto L_1390
        xorlw 0x03
        btfsc 0x03, 2               ; STATUS
        goto L_13A4
        xorlw 0x06
        btfsc 0x03, 2               ; STATUS
        goto L_139A
        goto L_13BC
L_13BC:
        incf 0x4C, 1
        goto L_1382
L_13BE:
        movlp 0x1B
        call L_1BFC
        movlp 0x13
        movf 0x01, 0                ; INDF1
        movwf 0x3D
        movlw 0x01
        movlp 0x1F
        call L_1F7B
        movlp 0x13
        call L_14AD
        movf 0x01, 0                ; INDF1
        movwf 0x3D
        movlw 0x65
        movlp 0x1F
        call L_1F7B
        movlp 0x13
        movlp 0x1C
        call L_1C0A
        movlp 0x13
        movf 0x01, 0                ; INDF1
        movwf 0x3D
        movlw 0x66
        movlp 0x1F
        call L_1F7B
        movlp 0x13
        movlp 0x0D
        call L_0DF0
        movlp 0x13
        call L_1493
        movlp 0x13
        movlw 0x67
        call L_140F
        movlp 0x13
        movlw 0xB4
        call L_1487
        movlp 0x13
        movlw 0x68
        call L_140F
        movlp 0x13
        movlw 0xBC
        call L_1487
        movlp 0x13
        movlw 0x69
        call L_140F
        movlp 0x13
        movlw 0xC4
        call L_1487
        movlp 0x13
        movlw 0x6A
        call L_140F
        movlp 0x13
        movlw 0xCC
        call L_1487
        movlp 0x13
        movlw 0x6B
        call L_140F
        movlp 0x0C
        call L_0C0D
        movlp 0x13
        movwf 0x3D
        movlw 0x6C
        movlp 0x1F
        call L_1F7B
        movlp 0x13
        movlw 0xDC
        call L_1487
        movlp 0x13
        movlw 0x6D
        call L_140F
        movlp 0x13
        movlw 0xE4
        call L_14B3
        movlp 0x13
        movlw 0x6E
        call L_1452
        movlp 0x13
        movlw 0xEC
        call L_14B3
        movlp 0x13
        movlw 0x6F
        goto L_1452
L_140F:
        movwf 0x41
        clrf 0x42
        movwf 0x34
        movf 0x42, 0
        call L_1444
        movlp 0x13
        movwf 0x42
        movlw 0x02
        movwf 0x34
        movf 0x42, 0
        call L_1444
        movlp 0x13
        movwf 0x42
        clrf 0x34
        call L_1444
        movlp 0x13
        movwf 0x42
        movlw 0x04
        movwf 0x34
        movf 0x42, 0
        call L_1444
        movlp 0x13
        movwf 0x42
        movf 0x40, 0
        movwf 0x34
        movf 0x42, 0
        call L_1444
        movlp 0x13
        movwf 0x42
        movf 0x3F, 0
        movwf 0x34
        movf 0x42, 0
        call L_1444
        movlp 0x13
        movwf 0x42
        movf 0x3E, 0
        movwf 0x34
        movf 0x42, 0
        call L_1444
        movlp 0x13
        movwf 0x42
        movf 0x3D, 0
        movwf 0x34
        movf 0x42, 0
        call L_1444
        movwf 0x42
        movlw 0x03
        movwf 0x39
        movf 0x42, 0
        movwf 0x3A
        movlw 0x07
        movlp 0x1F
        goto L_1FA2
L_1444:
        movwf 0x36
        movlw 0x26
        movwf 0x35
        movf 0x36, 0
        addwf 0x35, 1
        movf 0x35, 0
        movwf 0x06                  ; FSR1L
        movlw 0x02
        movwf 0x07                  ; FSR1H
        movf 0x34, 0
        movwf 0x01                  ; INDF1
        incf 0x36, 1
        movf 0x36, 0
        return
L_1452:
        movwf 0x3E
        clrf 0x3F
        movwf 0x34
        movf 0x3F, 0
        call L_1444
        movlp 0x13
        movwf 0x3F
        clrf 0x34
        incf 0x34, 1
        call L_1444
        movlp 0x13
        movwf 0x3F
        clrf 0x34
        call L_1444
        movlp 0x13
        movwf 0x3F
        clrf 0x34
        incf 0x34, 1
        call L_1444
        movlp 0x13
        movwf 0x3F
        movf 0x3D, 0
        movwf 0x34
        movf 0x3F, 0
        call L_1444
        movwf 0x3F
        movlw 0x03
        movwf 0x39
        movf 0x3F, 0
        movwf 0x3A
        movlw 0x07
        movlp 0x1F
        goto L_1FA2
L_1473:
        movf 0x4C, 0
        movwf 0x43
        clrf 0x44
        lslf 0x43, 1
        rlf 0x44, 1
        lslf 0x43, 1
        rlf 0x44, 1
        lslf 0x43, 1
        rlf 0x44, 1
        movf 0x43, 0
        addwf 0x4A, 0
        movwf 0x45
        movf 0x44, 0
        addwfc 0x4B, 0
        movwf 0x46
        movf 0x45, 0
        movwf 0x06                  ; FSR1L
        movf 0x46, 0
        movwf 0x07                  ; FSR1H
        return
L_1487:
        movwf 0x06                  ; FSR1L
        movlw 0x23
        movwf 0x07                  ; FSR1H
        moviw 0[FSR1]
        movwf 0x3D
        moviw 1[FSR1]
        movwf 0x3E
        moviw 2[FSR1]
        movwf 0x3F
        moviw 3[FSR1]
        movwf 0x40
        return
L_1493:
        moviw 0[FSR1]
        movwf 0x3D
        moviw 1[FSR1]
        movwf 0x3E
        moviw 2[FSR1]
        movwf 0x3F
        moviw 3[FSR1]
        movwf 0x40
        return
L_149C:
        movf 0x4C, 0
        movwf 0x47
        clrf 0x48
        lslf 0x47, 1
        rlf 0x48, 1
        lslf 0x47, 1
        rlf 0x48, 1
        lslf 0x47, 1
        rlf 0x48, 1
        movf 0x47, 0
        addwf 0x4A, 0
        movwf 0x06                  ; FSR1L
        movf 0x48, 0
        addwfc 0x4B, 0
        movwf 0x07                  ; FSR1H
        movf 0x01, 0                ; INDF1
        return
L_14AD:
        movlw 0x90
        movwf 0x06                  ; FSR1L
        movlw 0x23
        movwf 0x07                  ; FSR1H
        addfsr FSR1L, 12
        return
L_14B3:
        movwf 0x06                  ; FSR1L
        movlw 0x23
        movwf 0x07                  ; FSR1H
        movf 0x01, 0                ; INDF1
        movwf 0x3D
        return
L_14B9:
        movlb 0x00
        clrf 0x6C
        goto L_14CC
L_14BC:
        call L_15B6
        movlp 0x14
        xorlw 0x00
        btfsc 0x03, 2               ; STATUS
        goto L_14D0
        call L_15BB
        movlp 0x14
        movwf 0x62
        movf 0x6D, 0
        addlw 0xA0
        movwf 0x06                  ; FSR1L
        movlw 0x01
        movwf 0x07                  ; FSR1H
        movf 0x62, 0
        movwf 0x01                  ; INDF1
        incf 0x6D, 1
L_14CC:
        movlw 0x4A
        subwf 0x6D, 0
        btfss 0x03, 0               ; STATUS
        goto L_14BC
L_14D0:
        movlw 0x0A
        subwf 0x6D, 0
        btfss 0x03, 0               ; STATUS
        return
L_14D4:
        movf 0x6D, 0
        movwf 0x62
        clrf 0x63
        movf 0x63, 0
        movwf 0x65
        movf 0x6C, 0
        subwf 0x62, 0
        movwf 0x64
        btfss 0x03, 0               ; STATUS
        decf 0x65, 1
        movf 0x65, 0
        xorlw 0x80
        movwf 0x66
        movlw 0x80
        subwf 0x66, 0
        btfss 0x03, 2               ; STATUS
        goto L_14E7
        movlw 0x0A
        subwf 0x64, 0
L_14E7:
        btfss 0x03, 0               ; STATUS
        goto L_15A4
        movlb 0x00
        call L_1629
        movlp 0x14
        btfsc 0x03, 2               ; STATUS
        goto L_14F7
        movf 0x6C, 0
        addlw 0xA0
        movwf 0x06                  ; FSR1L
        movlw 0xFD
        xorwf 0x01, 0               ; INDF1
        btfsc 0x03, 2               ; STATUS
        goto L_14F7
L_14F5:
        incf 0x6C, 1
        goto L_14D4
L_14F7:
        call L_1629
        movlp 0x14
        btfss 0x03, 2               ; STATUS
        goto L_1513
        movf 0x6C, 0
        addlw 0xA1
        movwf 0x06                  ; FSR1L
        movlw 0xF3
        xorwf 0x01, 0               ; INDF1
        btfss 0x03, 2               ; STATUS
        goto L_14F5
        movf 0x6C, 0
        addlw 0xA2
        movwf 0x06                  ; FSR1L
        movlw 0xF2
        xorwf 0x01, 0               ; INDF1
        btfss 0x03, 2               ; STATUS
        goto L_14F5
        movf 0x6C, 0
        addlw 0xA3
        movwf 0x06                  ; FSR1L
        movlw 0xF1
        xorwf 0x01, 0               ; INDF1
        btfss 0x03, 2               ; STATUS
        goto L_14F5
        clrf 0x69
        incf 0x69, 1
        goto L_152B
L_1513:
        movf 0x6C, 0
        addlw 0xA1
        movwf 0x06                  ; FSR1L
        movlw 0x01
        movwf 0x07                  ; FSR1H
        movlw 0xFC
        xorwf 0x01, 0               ; INDF1
        btfss 0x03, 2               ; STATUS
        goto L_14F5
        movf 0x6C, 0
        addlw 0xA2
        movwf 0x06                  ; FSR1L
        movlw 0xFB
        xorwf 0x01, 0               ; INDF1
        btfss 0x03, 2               ; STATUS
        goto L_14F5
        movf 0x6C, 0
        addlw 0xA3
        movwf 0x06                  ; FSR1L
        movlw 0xFA
        xorwf 0x01, 0               ; INDF1
        btfss 0x03, 2               ; STATUS
        goto L_14F5
        clrf 0x69
L_152B:
        movf 0x6C, 0
        addlw 0xA4
        movwf 0x06                  ; FSR1L
        movlw 0x01
        movwf 0x07                  ; FSR1H
        movf 0x01, 0                ; INDF1
        movwf 0x6A
        call L_1639
        movlp 0x14
        xorlw 0x80
        movwf 0x64
        movlw 0x80
        subwf 0x64, 0
        btfss 0x03, 2               ; STATUS
        goto L_153C
        movlw 0x4B
        subwf 0x62, 0
L_153C:
        btfss 0x03, 0               ; STATUS
        goto L_1541
L_153E:
        movlw 0x04
        movlb 0x00
        goto L_15A2
L_1541:
        movlb 0x00
        movf 0x6A, 0
        call L_1639
        movlp 0x14
        movf 0x6D, 0
        movwf 0x64
        clrf 0x65
        movf 0x65, 0
        movwf 0x67
        movf 0x6C, 0
        subwf 0x64, 0
        movwf 0x66
        btfss 0x03, 0               ; STATUS
        decf 0x67, 1
        movf 0x67, 0
        xorlw 0x80
        movwf 0x68
        movf 0x63, 0
        xorlw 0x80
        subwf 0x68, 0
        btfss 0x03, 2               ; STATUS
        goto L_1559
        movf 0x62, 0
        subwf 0x66, 0
L_1559:
        btfss 0x03, 0               ; STATUS
        goto L_15A4
        movlb 0x00
        movf 0x6C, 0
        addwf 0x6A, 0
        addlw 0x06
        movwf 0x6B
        movf 0x69, 0
        btfsc 0x03, 2               ; STATUS
        goto L_157D
        call L_1640
        movlp 0x14
        movlw 0xF8
        xorwf 0x01, 0               ; INDF1
        btfss 0x03, 2               ; STATUS
        goto L_153E
        movf 0x6B, 0
        addlw 0xA1
        movwf 0x06                  ; FSR1L
        movlw 0xF7
        xorwf 0x01, 0               ; INDF1
        btfss 0x03, 2               ; STATUS
        goto L_153E
        movf 0x6B, 0
        addlw 0xA2
        movwf 0x06                  ; FSR1L
        movlw 0xF6
        xorwf 0x01, 0               ; INDF1
        btfss 0x03, 2               ; STATUS
        goto L_153E
        movf 0x6B, 0
        addlw 0xA3
        movwf 0x06                  ; FSR1L
        movlw 0xF5
        xorwf 0x01, 0               ; INDF1
        goto L_1595
L_157D:
        call L_1640
        movlp 0x14
        movlw 0x04
        xorwf 0x01, 0               ; INDF1
        btfss 0x03, 2               ; STATUS
        goto L_153E
        movf 0x6B, 0
        addlw 0xA1
        movwf 0x06                  ; FSR1L
        movlw 0x03
        xorwf 0x01, 0               ; INDF1
        btfss 0x03, 2               ; STATUS
        goto L_153E
        movf 0x6B, 0
        addlw 0xA2
        movwf 0x06                  ; FSR1L
        movlw 0x02
        xorwf 0x01, 0               ; INDF1
        btfss 0x03, 2               ; STATUS
        goto L_153E
        movf 0x6B, 0
        addlw 0xA3
        movwf 0x06                  ; FSR1L
        decf 0x01, 0                ; INDF1
L_1595:
        btfss 0x03, 2               ; STATUS
        goto L_153E
        movf 0x6C, 0
        movwf 0x4C
        clrf 0x4D
        movf 0x6A, 0
        movwf 0x4E
        movlp 0x0C
        call L_0C13
        movlp 0x14
        movlb 0x00
        movf 0x6A, 0
        addlw 0x0A
L_15A2:
        addwf 0x6C, 1
        goto L_14D4
L_15A4:
        movlb 0x00
        movf 0x6C, 0
        subwf 0x6D, 1
        movf 0x6D, 0
        btfsc 0x03, 2               ; STATUS
        return
        movlw 0xA0
        movwf 0x34
        movlw 0x01
        movwf 0x35
        movf 0x6C, 0
        addlw 0xA0
        movwf 0x36
        movlw 0x01
        movwf 0x37
        movf 0x6D, 0
        movwf 0x38
        goto L_15CF
L_15B6:
        movf 0x6F, 0
        xorwf 0x79, 0               ; common 0x79
        btfss 0x03, 2               ; STATUS
        retlw 0x01
        retlw 0x00
L_15BB:
        movf 0x79, 0                ; common 0x79
        movlb 0x00
        xorwf 0x6F, 0
        btfsc 0x03, 2               ; STATUS
        goto L_15CD
        movlw 0xCA
        subwf 0x79, 0               ; common 0x79
        btfss 0x03, 0               ; STATUS
        goto L_15C6
        movlw 0xA0
        movwf 0x79                  ; common 0x79
L_15C6:
        movf 0x79, 0                ; common 0x79
        movwf 0x06                  ; FSR1L
        movlw 0x02
        movwf 0x07                  ; FSR1H
        movf 0x01, 0                ; INDF1
        movwf 0x34
        incf 0x79, 1                ; common 0x79
L_15CD:
        movf 0x34, 0
        return
L_15CF:
        movf 0x35, 0
        subwf 0x37, 0
        btfss 0x03, 2               ; STATUS
        goto L_15D5
        movf 0x34, 0
        subwf 0x36, 0
L_15D5:
        btfsc 0x03, 0               ; STATUS
        goto L_15E2
        movf 0x38, 0
        call L_1631
        movlp 0x14
        movf 0x35, 0
        subwf 0x3C, 0
        btfss 0x03, 2               ; STATUS
        goto L_15E0
        movf 0x34, 0
        subwf 0x3B, 0
L_15E0:
        btfsc 0x03, 0               ; STATUS
        goto L_1604
L_15E2:
        clrf 0x44
L_15E3:
        movf 0x38, 0
        subwf 0x44, 0
        btfsc 0x03, 0               ; STATUS
        return
        movf 0x37, 0
        movwf 0x3A
        movf 0x36, 0
        movwf 0x39
        movf 0x44, 0
        addwf 0x39, 0
        movwf 0x04                  ; FSR0L
        movf 0x3A, 0
        btfsc 0x03, 0               ; STATUS
        incf 0x3A, 0
        movwf 0x05                  ; FSR0H
        movf 0x00, 0                ; INDF0
        movwf 0x3B
        movf 0x44, 0
        movwf 0x3C
        clrf 0x3D
        addwf 0x34, 0
        movwf 0x3E
        movf 0x3D, 0
        addwfc 0x35, 0
        movwf 0x3F
        movf 0x3E, 0
        movwf 0x06                  ; FSR1L
        movf 0x3F, 0
        movwf 0x07                  ; FSR1H
        movf 0x3B, 0
        movwf 0x01                  ; INDF1
        incf 0x44, 1
        goto L_15E3
L_1604:
        movf 0x38, 0
        movwf 0x44
L_1606:
        movf 0x44, 0
        btfsc 0x03, 2               ; STATUS
        return
        call L_1631
        movlp 0x14
        movlw 0xFF
        addwf 0x3B, 0
        movwf 0x04                  ; FSR0L
        movlw 0xFF
        addwfc 0x3C, 0
        movwf 0x05                  ; FSR0H
        movf 0x00, 0                ; INDF0
        movwf 0x3D
        movf 0x44, 0
        movwf 0x3E
        clrf 0x3F
        addwf 0x34, 0
        movwf 0x40
        movf 0x3F, 0
        addwfc 0x35, 0
        movwf 0x41
        movf 0x40, 0
        addlw 0xFF
        movwf 0x42
        movlw 0xFF
        addwfc 0x41, 0
        movwf 0x43
        movf 0x42, 0
        movwf 0x06                  ; FSR1L
        movf 0x43, 0
        movwf 0x07                  ; FSR1H
        movf 0x3D, 0
        movwf 0x01                  ; INDF1
        decf 0x44, 1
        goto L_1606
L_1629:
        movf 0x6C, 0
        addlw 0xA0
        movwf 0x06                  ; FSR1L
        movlw 0x01
        movwf 0x07                  ; FSR1H
        movlw 0xF4
        xorwf 0x01, 0               ; INDF1
        return
L_1631:
        movwf 0x39
        clrf 0x3A
        addwf 0x36, 0
        movwf 0x3B
        movf 0x3A, 0
        addwfc 0x37, 0
        movwf 0x3C
        return
L_1639:
        addlw 0x0A
        movwf 0x62
        movlw 0x00
        btfsc 0x03, 0               ; STATUS
        movlw 0x01
        movwf 0x63
        return
L_1640:
        movf 0x6B, 0
        addlw 0xA0
        movwf 0x06                  ; FSR1L
        movlw 0x01
        movwf 0x07                  ; FSR1H
        return
L_1646:
        movwf 0x62
        addlw 0x45
        movwf 0x06                  ; FSR1L
        movlw 0x01
        movwf 0x07                  ; FSR1H
        movf 0x01, 0                ; INDF1
        movwf 0x5C
        goto L_16E0
L_164E:
        movlp 0x13
        goto L_135D
L_1650:
        goto L_170D
L_1651:
        goto L_1707
L_1652:
        movlw 0x03
        movwf 0x39
        clrf 0x3A
        movlp 0x1F
        call L_1FA2
        movlp 0x16
        call L_17ED
        movlp 0x16
        movwf 0x5F
        movlw 0x02
        subwf 0x5F, 0
        btfsc 0x03, 0               ; STATUS
        goto L_166D
        movlb 0x01
        movlw 0xAA
        clrf 0x41
        clrf 0x42
        movwf 0x24
        call L_16FE
        movlp 0x16
        movf 0x4D, 0
        btfss 0x03, 2               ; STATUS
        goto L_166B
        movlw 0x03
        goto L_17FB
L_166B:
        movlw 0x0F
        goto L_17FB
L_166D:
        movf 0x5F, 0
        movlb 0x01
        movwf 0x5D
        movlw 0x02
        subwf 0x5D, 0
        btfss 0x03, 0               ; STATUS
        return
        movlw 0xAA
        xorwf 0x24, 0
        btfss 0x03, 2               ; STATUS
        return
        movlw 0xE4
        clrf 0x4D
        clrf 0x24
        incf 0x24, 1
        movlp 0x0D
        call L_0DDA
        movlp 0x16
        movwf 0x56
        moviw 1[FSR1]
        movwf 0x57
        moviw 2[FSR1]
        movwf 0x58
        moviw 3[FSR1]
        movwf 0x59
        iorwf 0x58, 0
        iorwf 0x57, 0
        iorwf 0x56, 0
        btfsc 0x03, 2               ; STATUS
        goto L_168F
L_168B:
        movlb 0x01
        clrf 0x2D
        incf 0x2D, 1
        return
L_168F:
        movlb 0x01
        clrf 0x2D
        return
L_1692:
        movf 0x62, 0
        addlw 0x47
        movwf 0x06                  ; FSR1L
        movlw 0x01
        movwf 0x07                  ; FSR1H
        movf 0x62, 0
        addlw 0x46
        movwf 0x04                  ; FSR0L
        movlw 0x01
        movwf 0x05                  ; FSR0H
        movf 0x00, 0                ; INDF0
        movwf 0x5B
        movf 0x01, 0                ; INDF1
        movwf 0x5A
        clrf 0x60
        clrf 0x61
L_16A2:
        movf 0x5B, 0
        subwf 0x61, 0
        btfss 0x03, 2               ; STATUS
        goto L_16A8
        movf 0x5A, 0
        subwf 0x60, 0
L_16A8:
        btfsc 0x03, 0               ; STATUS
        return
        movlw 0x4A
        call L_17F4
        movlp 0x16
        movlw 0x01
        movwf 0x07                  ; FSR1H
        movf 0x01, 0                ; INDF1
        movwf 0x5E
        movlw 0x4B
        clrf 0x5D
        call L_17F4
        movlp 0x16
        movf 0x01, 0                ; INDF1
        addwf 0x5D, 1
        btfsc 0x03, 0               ; STATUS
        incf 0x5E, 1
        movf 0x62, 0
        addlw 0x48
        addwf 0x60, 0
        call L_17A8
        movlp 0x16
        movlb 0x00
        movf 0x5D, 0
        addlw 0x04
        movwf 0x56
        movlw 0x00
        addwfc 0x5E, 0
        movwf 0x57
        movf 0x56, 0
        addwf 0x60, 1
        movf 0x57, 0
        addwfc 0x61, 1
        goto L_16A2
L_16CA:
        movlp 0x13
        goto L_13BE
L_16CC:
        movlp 0x0E
        call L_0E6B
        reset
        return
L_16D0:
        call L_17ED
        movlp 0x16
        movlb 0x01
        movwf 0x5B
        movf 0x5B, 0
        btfss 0x03, 2               ; STATUS
        goto L_168B
        movlw 0x02
        movwf 0x28
        movwf 0x2A
        movwf 0x2D
        return
L_16DC:
        call L_17ED
        movlb 0x01
        movwf 0x5D
        return
L_16E0:
        movf 0x5C, 0
        xorlw 0x00
        btfsc 0x03, 2               ; STATUS
        goto L_164E
        xorlw 0x01
        btfsc 0x03, 2               ; STATUS
        goto L_1650
        xorlw 0x03
        btfsc 0x03, 2               ; STATUS
        goto L_1651
        xorlw 0x01
        btfsc 0x03, 2               ; STATUS
        goto L_1652
        xorlw 0x05
        btfsc 0x03, 2               ; STATUS
        goto L_1692
        xorlw 0x0E
        btfsc 0x03, 2               ; STATUS
        goto L_16CA
        xorlw 0x02
        btfsc 0x03, 2               ; STATUS
        goto L_16CC
        xorlw 0x04
        btfsc 0x03, 2               ; STATUS
        goto L_16D0
        xorlw 0x25
        btfsc 0x03, 2               ; STATUS
        goto L_16DC
        goto L_16FD
L_16FD:
        return
L_16FE:
        movlp 0x10
        call L_1017
        movlp 0x16
        movlp 0x0E
        call L_0ECF
        clrf 0x26
        incf 0x26, 1
        clrf 0x21
        return
L_1707:
        movlw 0x03
        movwf 0x39
        movlw 0x02
        clrf 0x3A
        movlp 0x1F
        goto L_1FA2
L_170D:
        movlw 0x2B
        clrf 0x4A
        movwf 0x45
        movlw 0xA0
        movwf 0x46
        movlw 0x2B
        movwf 0x34
        movlw 0xA0
        movwf 0x35
        call L_177D
        movlp 0x16
        movwf 0x47
        movf 0x4A, 0
        call L_1793
        movlp 0x16
        movwf 0x4A
        movlw 0x12
        movwf 0x45
        movlw 0xA0
        movwf 0x46
        movlw 0x12
        movwf 0x34
        movlw 0xA0
        movwf 0x35
        call L_177D
        movlp 0x16
        movwf 0x47
        movf 0x4A, 0
        call L_1793
        movlp 0x16
        movwf 0x4A
        movlw 0x23
        movwf 0x45
        movlw 0xA0
        movwf 0x46
        movlw 0x23
        movwf 0x34
        movlw 0xA0
        movwf 0x35
        call L_177D
        movlp 0x16
        movwf 0x47
        movf 0x4A, 0
        call L_1793
        movlp 0x16
        movwf 0x4A
        movlw 0x39
        movwf 0x45
        movlw 0xA0
        movwf 0x46
        movlw 0x39
        movwf 0x34
        movlw 0xA0
        movwf 0x35
        call L_177D
        movlp 0x16
        movwf 0x47
        movf 0x4A, 0
        call L_1793
        movlp 0x16
        movwf 0x4A
        movlw 0x32
        movwf 0x45
        movlw 0xA0
        movwf 0x46
        movlw 0x32
        movwf 0x34
        movlw 0xA0
        movwf 0x35
        call L_177D
        movlp 0x16
        movwf 0x47
        movf 0x4A, 0
        call L_1793
        movlp 0x16
        movwf 0x4A
        movlw 0x3F
        movwf 0x45
        movlw 0xA0
        movwf 0x46
        movlw 0x3F
        movwf 0x34
        movlw 0xA0
        movwf 0x35
        call L_177D
        movlp 0x16
        movwf 0x47
        movf 0x4A, 0
        call L_1793
        movlp 0x16
        movwf 0x4A
        movlw 0x41
        movwf 0x45
        movlw 0xA0
        movwf 0x46
        movlw 0x41
        movwf 0x34
        movlw 0xA0
        movwf 0x35
        call L_177D
        movlp 0x16
        movwf 0x47
        movf 0x4A, 0
        call L_1793
        movwf 0x4A
        movlw 0x03
        movwf 0x39
        movf 0x4A, 0
        movwf 0x3A
        movlw 0x01
        movlp 0x1F
        goto L_1FA2
L_177D:
        movf 0x34, 0
        iorwf 0x35, 0
        btfsc 0x03, 2               ; STATUS
        retlw 0x00
        clrf 0x39
L_1782:
        movf 0x35, 0
        movwf 0x37
        movf 0x34, 0
        movwf 0x36
        incf 0x34, 1
        btfsc 0x03, 2               ; STATUS
        incf 0x35, 1
        movwf 0x04                  ; FSR0L
        movf 0x37, 0
        movwf 0x05                  ; FSR0H
        moviw FSR0++
        btfsc 0x03, 2               ; STATUS
        goto L_1791
        incf 0x39, 1
        goto L_1782
L_1791:
        movf 0x39, 0
        return
L_1793:
        movwf 0x49
        movlw 0x26
        movwf 0x48
        movf 0x49, 0
        addwf 0x48, 1
        movf 0x48, 0
        movwf 0x34
        movlw 0x02
        movwf 0x35
        movf 0x46, 0
        movwf 0x37
        movf 0x45, 0
        movwf 0x36
        movf 0x47, 0
        movwf 0x38
        movlp 0x15
        call L_15CF
        movf 0x47, 0
        addwf 0x49, 1
        movf 0x49, 0
        return
L_17A8:
        movwf 0x55
        movwf 0x06                  ; FSR1L
        movlw 0x01
        movwf 0x07                  ; FSR1H
        movf 0x01, 0                ; INDF1
        movwf 0x54
        movf 0x55, 0
        movwf 0x06                  ; FSR1L
        moviw 1[FSR1]
        movwf 0x52
        movf 0x55, 0
        movwf 0x06                  ; FSR1L
        moviw 3[FSR1]
        movwf 0x53
        movf 0x54, 0
        call L_17D0
        movlp 0x16
        movwf 0x51
        movwf 0x4F
        movlw 0x01
        clrf 0x50
        lslf 0x4F, 1
        rlf 0x50, 1
        addwf 0x4F, 0
        movwf 0x04                  ; FSR0L
        movlw 0xA0
        addwfc 0x50, 0
        movwf 0x05                  ; FSR0H
        movf 0x00, 0                ; INDF0
        xorwf 0x52, 0
        btfss 0x03, 2               ; STATUS
        return
        movf 0x55, 0
        addlw 0x04
        movwf 0x48
        movf 0x53, 0
        movwf 0x49
        movf 0x54, 0
        movlp 0x07
        goto L_0753
L_17D0:
        movwf 0x36
        call L_17EC
        movlp 0x16
        movwf 0x37
        clrf 0x38
L_17D5:
        movf 0x37, 0
        subwf 0x38, 0
        movf 0x38, 0
        btfsc 0x03, 0               ; STATUS
        return
        movwf 0x34
        movlw 0x00
        clrf 0x35
        lslf 0x34, 1
        rlf 0x35, 1
        addwf 0x34, 0
        movwf 0x04                  ; FSR0L
        movlw 0xA0
        addwfc 0x35, 0
        movwf 0x05                  ; FSR0H
        movf 0x00, 0                ; INDF0
        xorwf 0x36, 0
        btfsc 0x03, 2               ; STATUS
        goto L_17EA
        incf 0x38, 1
        goto L_17D5
L_17EA:
        movf 0x38, 0
        return
L_17EC:
        retlw 0x09
L_17ED:
        movf 0x62, 0
        addlw 0x48
        movwf 0x06                  ; FSR1L
        movlw 0x01
        movwf 0x07                  ; FSR1H
        movf 0x01, 0                ; INDF1
        return
L_17F4:
        addwf 0x62, 0
        movwf 0x56
        movf 0x60, 0
        addwf 0x56, 0
        movwf 0x57
        movwf 0x06                  ; FSR1L
        return
L_17FB:
        movwf 0x28
        movwf 0x2A
        movlw 0x02
        movwf 0x2D
        return
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
L_1AFD:
        clrwdt
        movlb 0x03
        clrf 0x1D                   ; MISC0
        movlw 0x55
        movlb 0x01
        movwf 0x17                  ; WDTCON
        return
L_1B04:
        clrwdt
L_1B05:
        movlw 0x01
        clrf 0x00                   ; INDF0
        addfsr FSR0L, 1
        subwf 0x7E, 1               ; common 0x7E
        movlw 0x00
        subwfb 0x7F, 1              ; common 0x7F
        movf 0x7F, 0                ; common 0x7F
        iorwf 0x7E, 0               ; common 0x7E
        btfsc 0x03, 2               ; STATUS
        retlw 0x00
        goto L_1B05
L_1B10:
        movwf 0x7E                  ; common 0x7E
L_1B11:
        moviw FSR0++
        movwi FSR1++
        movlw 0x01
        subwf 0x7E, 1               ; common 0x7E
        movlw 0x00
        subwfb 0x7F, 1              ; common 0x7F
        movf 0x7F, 0                ; common 0x7F
        iorwf 0x7E, 0               ; common 0x7E
        btfsc 0x03, 2               ; STATUS
        retlw 0x00
        goto L_1B11
L_1B1C:
        movlb 0x02
        clrf 0x18                   ; EPS0
        movlw 0x01
        movwf 0x19                  ; EPS1
        clrf 0x1E                   ; ITYPE0
        movlw 0x02
        movwf 0x1F                  ; ITYPE1
        movlw 0x10
        movlb 0x01
        movwf 0x14                  ; EPIE0
        movlw 0xFF
        movlb 0x00
        movwf 0x14                  ; EPIF0
        return
L_1B2A:
        movlb 0x01
        bsf 0x1A, 2                 ; SFR 0x09A
        bsf 0x15, 5                 ; CKOCON
        movlw 0x30
        movlb 0x06
        iorwf 0x1F, 1               ; TCKSRC
        movlw 0x84
        movwf 0x0C                  ; TIM2CR1
        movlw 0x01
        movwf 0x0D                  ; TIM2IER
        movlw 0x0D
        movwf 0x19                  ; TIM2ARRH
        movlw 0x20
        movwf 0x1A                  ; TIM2ARRL
        return
L_1B39:
        bsf 0x1A, 5
        bsf 0x0C, 7
        bcf 0x0C, 6
        movlw 0x23
        movlb 0x09
        movwf 0x0E                  ; UR1IER
        movlw 0x01
        movwf 0x0F                  ; UR1LCR
        movlw 0x18
        movwf 0x11                  ; UR1MCR
        movlw 0x68
        movwf 0x14                  ; UR1DLL
        clrf 0x15                   ; UR1DLH
        bsf 0x1C, 0                 ; UR1TC
        movlb 0x04
        bsf 0x1F, 0                 ; ODCON0
        return
L_1B4A:
        movlb 0x01
        bsf 0x1A, 0                 ; SFR 0x09A
        movlb 0x03
        bsf 0x17, 2                 ; ANSELA
        movlw 0xE4
        movlb 0x01
        movwf 0x1E                  ; ADCON1
        movlw 0x20
        movwf 0x1D                  ; ADCON0
        movlw 0x80
        movwf 0x1F                  ; ADCON2
        movlb 0x08
        clrf 0x1A                   ; ADCON3
        movlb 0x00
        clrf 0x1F                   ; SFR 0x01F
        movlb 0x08
        clrf 0x1B                   ; ADCMPH
        return
L_1B5C:
        movwf 0x76                  ; common 0x76
        movf 0x79, 0                ; common 0x79
        movwf 0x75                  ; common 0x75
        movlb 0x00
        movf 0x6F, 0
        subwf 0x75, 1               ; common 0x75
        decfsz 0x75, 0              ; common 0x75
        goto L_1B65
        return
L_1B65:
        movf 0x6F, 0
        subwf 0x79, 0               ; common 0x79
        btfsc 0x03, 0               ; STATUS
        goto L_1B6F
        movf 0x79, 0                ; common 0x79
        subwf 0x6F, 0
        xorlw 0x80
        addlw 0x56
        btfsc 0x03, 0               ; STATUS
        return
L_1B6F:
        movlw 0xCA
        subwf 0x6F, 0
        btfss 0x03, 0               ; STATUS
        goto L_1B75
        movlw 0xA0
        movwf 0x6F
L_1B75:
        movf 0x6F, 0
        movwf 0x06                  ; FSR1L
        movlw 0x02
        movwf 0x07                  ; FSR1H
        movf 0x76, 0                ; common 0x76
        movwf 0x01                  ; INDF1
        incf 0x6F, 1
        return
L_1B7D:
        movwf 0x76                  ; common 0x76
        movlb 0x01
        movf 0x5A, 0
        movwf 0x75                  ; common 0x75
        movf 0x59, 0
        subwf 0x75, 1               ; common 0x75
        decfsz 0x75, 0              ; common 0x75
        goto L_1B86
        return
L_1B86:
        movf 0x59, 0
        subwf 0x5A, 0
        btfsc 0x03, 0               ; STATUS
        goto L_1B90
        movf 0x5A, 0
        subwf 0x59, 0
        xorlw 0x80
        addlw 0x69
        btfsc 0x03, 0               ; STATUS
        return
L_1B90:
        movlw 0x6E
        subwf 0x59, 0
        btfss 0x03, 0               ; STATUS
        goto L_1B96
        movlw 0x57
        movwf 0x59
L_1B96:
        movf 0x59, 0
        movwf 0x06                  ; FSR1L
        movlw 0x02
        movwf 0x07                  ; FSR1H
        movf 0x76, 0                ; common 0x76
        movwf 0x01                  ; INDF1
        incf 0x59, 1
        return
L_1B9E:
        movlw 0x71
        movwf 0x19
        clrf 0x0B                   ; INTCON
        movlb 0x03
        clrf 0x0C                   ; WPUA
        movlw 0x18
        movwf 0x0D                  ; WPUB
        clrf 0x0E                   ; WPUC
        movlb 0x04
        clrf 0x0C                   ; WPDA
        clrf 0x0D                   ; WPDB
        clrf 0x0E                   ; WPDC
        movlb 0x01
        movwf 0x0C                  ; TRISA
        movlw 0x90
        movwf 0x0D                  ; TRISB
        movlw 0x01
        movwf 0x0E                  ; TRISC
        movlw 0xFF
        movlb 0x02
        movwf 0x1A                  ; PSRC0
        movwf 0x1B                  ; PSRC1
        movlw 0x0F
        movwf 0x1C                  ; PSRC
        movlw 0xFF
        movlb 0x03
        movwf 0x1A                  ; PSINK0
        movwf 0x1B                  ; PSINK1
        movlw 0x03
        movwf 0x1C                  ; PSINK2
        movlb 0x00
        clrf 0x0C                   ; PORTA
        movlw 0x08
        movwf 0x0D                  ; PORTB
        clrf 0x0E                   ; PORTC
        movlb 0x03
        clrf 0x17                   ; ANSELA
        return
L_1BC4:
        movlw 0xDC
        movlp 0x0D
        call L_0DDA
        movlp 0x1B
        movwf 0x44
        moviw 1[FSR1]
        movwf 0x45
        moviw 2[FSR1]
        movwf 0x46
        moviw 3[FSR1]
        movwf 0x47
        movlw 0x05
        subwf 0x44, 1
        movlw 0x00
        subwfb 0x45, 1
        subwfb 0x46, 1
        subwfb 0x47, 1
        movlw 0x0A
        movwf 0x34
        clrf 0x35
        clrf 0x36
        clrf 0x37
        movf 0x47, 0
        movwf 0x3B
        movf 0x46, 0
        movwf 0x3A
        movf 0x45, 0
        movwf 0x39
        movf 0x44, 0
        movwf 0x38
        movlp 0x0B
        call L_0BAD
        movf 0x37, 0
        movwf 0x47
        movf 0x36, 0
        movwf 0x46
        movf 0x35, 0
        movwf 0x45
        movf 0x34, 0
        movwf 0x44
        movf 0x47, 0
        movwf 0x43
        movf 0x46, 0
        movwf 0x42
        movf 0x45, 0
        movwf 0x41
        movf 0x44, 0
        movwf 0x40
        return
L_1BF5:
        movwf 0x07                  ; FSR1H
        movlw 0x00
        movwi 0[FSR1]
        movwi 1[FSR1]
        movwi 2[FSR1]
        movwi 3[FSR1]
        return
L_1BFC:
        movlw 0x90
        movwf 0x06                  ; FSR1L
        movlw 0x23
        movwf 0x07                  ; FSR1H
        addfsr FSR1L, 4
        return
L_1C02:
        movlw 0xE2
        movwf 0x06                  ; FSR1L
        movlw 0x01
        movwf 0x01                  ; INDF1
        movlb 0x00
        movlw 0x0F
        clrf 0x36
        return
L_1C0A:
        movlw 0x90
        movwf 0x06                  ; FSR1L
        movlw 0x23
        movwf 0x07                  ; FSR1H
        addfsr FSR1L, 20
        return
L_1C10:
        movwf 0x06                  ; FSR1L
        movlw 0x00
        movwi 0[FSR1]
        movwi 1[FSR1]
        movwi 2[FSR1]
        movwi 3[FSR1]
        return
L_1C17:
        addfsr FSR1L, 20
        movwi 0[FSR1]
        movlw 0x00
        movwi 1[FSR1]
        movwi 2[FSR1]
        movwi 3[FSR1]
        return
L_1C1E:
        movlw 0x00
        movlb 0x00
        btfsc 0x0D, 7               ; PORTB
        movlw 0x01
        movlb 0x01
        return
L_1C24:
        movwf 0x06                  ; FSR1L
        movlw 0x23
        movwf 0x07                  ; FSR1H
        movlw 0x01
        movwf 0x01                  ; INDF1
        return
L_1C2A:
        movf 0x50, 0
        btfss 0x03, 2               ; STATUS
        return
        movf 0x2C, 0
        xorwf 0x2D, 0
        btfsc 0x03, 2               ; STATUS
        goto L_1C4C
        movf 0x2D, 0
        movwf 0x2C
        decfsz 0x2C, 0
        goto L_1C47
        movlw 0xEC
        movlp 0x0D
        call L_0DDA
        movlp 0x1C
        movwf 0x34
        moviw 1[FSR1]
        movwf 0x35
        moviw 2[FSR1]
        movwf 0x36
        moviw 3[FSR1]
        movwf 0x37
        iorwf 0x36, 0
        iorwf 0x35, 0
        iorwf 0x34, 0
        btfsc 0x03, 2               ; STATUS
        goto L_1C4C
        bsf 0x0D, 6
        goto L_1C4C
L_1C47:
        movf 0x2C, 0
        btfss 0x03, 2               ; STATUS
        goto L_1C4C
        movlb 0x00
        bcf 0x0D, 6                 ; PORTB
L_1C4C:
        movlw 0x02
        movlb 0x01
        xorwf 0x2C, 0
        btfss 0x03, 2               ; STATUS
        return
        movlb 0x00
        btfsc 0x0D, 6               ; PORTB
        goto L_1C5F
        movlb 0x01
        incf 0x2B, 1
        movf 0x2A, 0
        subwf 0x2B, 0
        btfss 0x03, 0               ; STATUS
        return
        movlb 0x00
        bsf 0x0D, 6                 ; PORTB
        movlb 0x01
        clrf 0x29
        return
L_1C5F:
        btfss 0x0D, 6
        return
        movlb 0x01
        incf 0x29, 1
        movf 0x28, 0
        subwf 0x29, 0
        btfss 0x03, 0               ; STATUS
        return
        movlb 0x00
        bcf 0x0D, 6                 ; PORTB
        movlb 0x01
        clrf 0x2B
        return
        retlw 0x3C
        retlw 0x3C
        retlw 0x23
        retlw 0x19
        retlw 0x0F
        retlw 0x0F
        retlw 0x0F
        retlw 0x0F
        retlw 0x14
        retlw 0x3E
        retlw 0x3E
        retlw 0x25
        retlw 0x25
        retlw 0x1B
        retlw 0x1B
        retlw 0x11
        retlw 0x11
        retlw 0x11
        retlw 0x41
        retlw 0x41
        retlw 0x28
        retlw 0x28
        retlw 0x1E
        retlw 0x1E
        retlw 0x14
        retlw 0x14
        retlw 0x14
        retlw 0x43
        retlw 0x43
        retlw 0x2A
        retlw 0x2A
        retlw 0x20
        retlw 0x20
        retlw 0x16
        retlw 0x16
        retlw 0x16
        retlw 0x46
        retlw 0x46
        retlw 0x2D
        retlw 0x2D
        retlw 0x23
        retlw 0x23
        retlw 0x19
        retlw 0x19
        retlw 0x19
        retlw 0x48
        retlw 0x48
        retlw 0x2F
        retlw 0x2F
        retlw 0x25
        retlw 0x25
        retlw 0x1B
        retlw 0x1B
        retlw 0x1B
        retlw 0x4B
        retlw 0x4B
        retlw 0x32
        retlw 0x32
        retlw 0x28
        retlw 0x28
        retlw 0x1E
        retlw 0x1E
        retlw 0x1E
        retlw 0x50
        retlw 0x50
        retlw 0x37
        retlw 0x37
        retlw 0x2D
        retlw 0x2D
        retlw 0x23
        retlw 0x23
        retlw 0x23
        retlw 0x50
        retlw 0x50
        retlw 0x32
        retlw 0x19
        retlw 0x0A
        retlw 0x0A
        retlw 0x0A
        retlw 0x0A
        retlw 0x0F
        retlw 0x3E
        retlw 0x3E
        retlw 0x25
        retlw 0x1B
        retlw 0x11
        retlw 0x0C
        retlw 0x0C
        retlw 0x0C
        retlw 0x0C
        retlw 0x41
        retlw 0x41
        retlw 0x28
        retlw 0x1E
        retlw 0x14
        retlw 0x0F
        retlw 0x0F
        retlw 0x0F
        retlw 0x0F
        retlw 0x43
        retlw 0x43
        retlw 0x2A
        retlw 0x20
        retlw 0x16
        retlw 0x11
        retlw 0x11
        retlw 0x11
        retlw 0x11
        retlw 0x46
        retlw 0x46
        retlw 0x2D
        retlw 0x23
        retlw 0x19
        retlw 0x14
        retlw 0x14
        retlw 0x14
        retlw 0x14
        retlw 0x48
        retlw 0x48
        retlw 0x2F
        retlw 0x25
        retlw 0x1B
        retlw 0x16
        retlw 0x16
        retlw 0x16
        retlw 0x16
        retlw 0x4B
        retlw 0x4B
        retlw 0x32
        retlw 0x28
        retlw 0x1E
        retlw 0x19
        retlw 0x19
        retlw 0x19
        retlw 0x19
        retlw 0x50
        retlw 0x50
        retlw 0x37
        retlw 0x2D
        retlw 0x23
        retlw 0x23
        retlw 0x1E
        retlw 0x1E
        retlw 0x1E
L_1CFC:
        decfsz 0x45, 0
        return
        movlb 0x02
        clrf 0x21
        clrf 0x20
        incf 0x20, 1
        clrf 0x22
        movlb 0x04
        bsf 0x11, 0                 ; TIM1CR1
        movlb 0x01
        movlw 0x03
        incf 0x46, 1
        subwf 0x46, 0
        btfss 0x03, 0               ; STATUS
        return
        movlw 0xFE
        movlb 0x02
        xorwf 0x2A, 0
        btfsc 0x03, 2               ; STATUS
        goto L_1D14
        call L_1D19
        movlp 0x1C
        movlw 0x02
        goto L_1D1C
L_1D14:
        movlb 0x01
        clrf 0x45
        clrf 0x47
        clrf 0x4E
        return
L_1D19:
        movlb 0x01
        clrf 0x45
        return
L_1D1C:
        movlb 0x00
        movwf 0x35
        clrf 0x36
        movf 0x35, 0
        btfss 0x03, 2               ; STATUS
        goto L_1D24
        movlw 0xA2
        goto L_1D2D
L_1D24:
        decfsz 0x35, 0
        goto L_1D28
        movlw 0xA3
        goto L_1D2D
L_1D28:
        movlw 0x02
        xorwf 0x35, 0
        btfss 0x03, 2               ; STATUS
        return
        movlw 0xFE
L_1D2D:
        movwf 0x34
        movlw 0xFD
        movlb 0x02
        movwf 0x24
        movlb 0x00
        incf 0x36, 1
        movf 0x36, 0
        movlp 0x0A
        call L_0A0F
        movlp 0x1C
        call L_1D62
        movlp 0x1C
        movlw 0xFB
        call L_1D62
        movlp 0x1C
        movlw 0xFA
        call L_1D62
        movlp 0x1C
        movlw 0x02
        call L_1D62
        movlp 0x1C
        clrf 0x01                   ; INDF1
        incf 0x36, 1
        movf 0x36, 0
        addlw 0x24
        movwf 0x06                  ; FSR1L
        movf 0x34, 0
        call L_1D62
        movlp 0x1C
        clrf 0x01                   ; INDF1
        incf 0x36, 1
        movf 0x36, 0
        addlw 0x24
        movwf 0x06                  ; FSR1L
        movlw 0x04
        call L_1D62
        movlp 0x1C
        movlw 0x03
        call L_1D62
        movlp 0x1C
        movlw 0x02
        call L_1D62
        clrf 0x01                   ; INDF1
        incf 0x01, 1                ; INDF1
        incf 0x36, 1
        movlp 0x0A
        call L_0A08
        movlp 0x1C
        movf 0x36, 0
        movlp 0x0A
        call L_0A23
        movlp 0x09
        goto L_09CF
L_1D62:
        movwf 0x01                  ; INDF1
        incf 0x36, 1
        movf 0x36, 0
        addlw 0x24
        movwf 0x06                  ; FSR1L
        return
L_1D68:
        clrf 0x3D
        btfss 0x37, 7
        goto L_1D78
        comf 0x34, 1
        comf 0x35, 1
        comf 0x36, 1
        comf 0x37, 1
        incf 0x34, 1
        btfsc 0x03, 2               ; STATUS
        incf 0x35, 1
        btfsc 0x03, 2               ; STATUS
        incf 0x36, 1
        btfsc 0x03, 2               ; STATUS
        incf 0x37, 1
        clrf 0x3D
        incf 0x3D, 1
L_1D78:
        btfss 0x3B, 7
        goto L_1D87
        comf 0x38, 1
        comf 0x39, 1
        comf 0x3A, 1
        comf 0x3B, 1
        incf 0x38, 1
        btfsc 0x03, 2               ; STATUS
        incf 0x39, 1
        btfsc 0x03, 2               ; STATUS
        incf 0x3A, 1
        btfsc 0x03, 2               ; STATUS
        incf 0x3B, 1
        movlw 0x01
        xorwf 0x3D, 1
L_1D87:
        clrf 0x3E
        clrf 0x3F
        clrf 0x40
        clrf 0x41
        movf 0x37, 0
        iorwf 0x36, 0
        iorwf 0x35, 0
        iorwf 0x34, 0
        btfsc 0x03, 2               ; STATUS
        goto L_1DBD
        clrf 0x3C
L_1D92:
        incf 0x3C, 1
        btfsc 0x37, 7
        goto L_1D9A
        lslf 0x34, 1
        rlf 0x35, 1
        rlf 0x36, 1
        rlf 0x37, 1
        goto L_1D92
L_1D9A:
        lslf 0x3E, 1
        rlf 0x3F, 1
        rlf 0x40, 1
        rlf 0x41, 1
        movf 0x37, 0
        subwf 0x3B, 0
        btfss 0x03, 2               ; STATUS
        goto L_1DAC
        movf 0x36, 0
        subwf 0x3A, 0
        btfss 0x03, 2               ; STATUS
        goto L_1DAC
        movf 0x35, 0
        subwf 0x39, 0
        btfss 0x03, 2               ; STATUS
        goto L_1DAC
        movf 0x34, 0
        subwf 0x38, 0
L_1DAC:
        btfss 0x03, 0               ; STATUS
        goto L_1DB7
        movf 0x34, 0
        subwf 0x38, 1
        movf 0x35, 0
        subwfb 0x39, 1
        movf 0x36, 0
        subwfb 0x3A, 1
        movf 0x37, 0
        subwfb 0x3B, 1
        bsf 0x3E, 0
L_1DB7:
        lsrf 0x37, 1
        rrf 0x36, 1
        rrf 0x35, 1
        rrf 0x34, 1
        decfsz 0x3C, 1
        goto L_1D9A
L_1DBD:
        movf 0x3D, 0
        btfsc 0x03, 2               ; STATUS
        goto L_1DCB
        comf 0x3E, 1
        comf 0x3F, 1
        comf 0x40, 1
        comf 0x41, 1
        incf 0x3E, 1
        btfsc 0x03, 2               ; STATUS
        incf 0x3F, 1
        btfsc 0x03, 2               ; STATUS
        incf 0x40, 1
        btfsc 0x03, 2               ; STATUS
        incf 0x41, 1
L_1DCB:
        movf 0x41, 0
        movwf 0x37
        movf 0x40, 0
        movwf 0x36
        movf 0x3F, 0
        movwf 0x35
        movf 0x3E, 0
        movwf 0x34
        return
L_1DD4:
        clrf 0x69
        goto L_1DE6
L_1DD6:
        call L_1E74
        movlp 0x1D
        xorlw 0x00
        btfsc 0x03, 2               ; STATUS
        goto L_1DEA
        call L_1E5D
        movlp 0x1D
        movwf 0x63
        movf 0x74, 0                ; common 0x74
        addlw 0x42
        movwf 0x06                  ; FSR1L
        movlw 0x01
        movwf 0x07                  ; FSR1H
        movf 0x63, 0
        movwf 0x01                  ; INDF1
        incf 0x74, 1                ; common 0x74
L_1DE6:
        movlw 0x27
        subwf 0x74, 0               ; common 0x74
        btfss 0x03, 0               ; STATUS
        goto L_1DD6
L_1DEA:
        movlw 0x07
        subwf 0x74, 0               ; common 0x74
        btfss 0x03, 0               ; STATUS
        return
L_1DEE:
        movf 0x74, 0                ; common 0x74
        movlb 0x00
        call L_1E7A
        movlp 0x1D
        btfss 0x03, 2               ; STATUS
        goto L_1DF6
        movlw 0x07
        subwf 0x65, 0
L_1DF6:
        btfss 0x03, 0               ; STATUS
        goto L_1E4A
        movlb 0x00
        movf 0x69, 0
        addlw 0x42
        movwf 0x06                  ; FSR1L
        movlw 0x01
        movwf 0x07                  ; FSR1H
        movlw 0x55
        xorwf 0x01, 0               ; INDF1
        btfss 0x03, 2               ; STATUS
        goto L_1E10
        movf 0x69, 0
        addlw 0x43
        movwf 0x06                  ; FSR1L
        movlw 0xAA
        xorwf 0x01, 0               ; INDF1
        btfss 0x03, 2               ; STATUS
        goto L_1E10
        movf 0x69, 0
        addlw 0x44
        movwf 0x06                  ; FSR1L
        movf 0x01, 0                ; INDF1
        btfsc 0x03, 2               ; STATUS
        goto L_1E12
        incf 0x69, 1
L_1E10:
        incf 0x69, 1
        goto L_1DEE
L_1E12:
        clrf 0x68
        movf 0x69, 0
        addlw 0x47
        movwf 0x06                  ; FSR1L
        movlw 0x01
        movwf 0x07                  ; FSR1H
        movf 0x01, 0                ; INDF1
        addlw 0x07
        addwf 0x68, 1
        movlw 0x2F
        subwf 0x68, 0
        btfss 0x03, 0               ; STATUS
        goto L_1E21
L_1E1F:
        movlw 0x03
        goto L_1E48
L_1E21:
        movf 0x74, 0                ; common 0x74
        call L_1E7A
        movlp 0x1D
        btfss 0x03, 2               ; STATUS
        goto L_1E28
        movf 0x68, 0
        subwf 0x65, 0
L_1E28:
        btfss 0x03, 0               ; STATUS
        goto L_1E4A
        movlw 0x41
        movlb 0x00
        addwf 0x68, 0
        movwf 0x63
        movf 0x69, 0
        addwf 0x63, 0
        movwf 0x64
        movwf 0x04                  ; FSR0L
        movlw 0x01
        movwf 0x05                  ; FSR0H
        movf 0x69, 0
        addlw 0x42
        movwf 0x34
        movlw 0x01
        movwf 0x35
        movf 0x68, 0
        addlw 0xFF
        movwf 0x36
        movlp 0x1F
        call L_1FCD
        movlp 0x1D
        xorwf 0x00, 0               ; INDF0
        btfss 0x03, 2               ; STATUS
        goto L_1E1F
        movf 0x69, 0
        movlp 0x16
        call L_1646
        movlp 0x1D
        movlb 0x00
        movf 0x68, 0
L_1E48:
        addwf 0x69, 1
        goto L_1DEE
L_1E4A:
        movlb 0x00
        movf 0x69, 0
        subwf 0x74, 1               ; common 0x74
        movf 0x74, 0                ; common 0x74
        btfsc 0x03, 2               ; STATUS
        return
        movlw 0x42
        movwf 0x34
        movlw 0x01
        movwf 0x35
        movf 0x69, 0
        addlw 0x42
        movwf 0x36
        movlw 0x01
        movwf 0x37
        movf 0x74, 0                ; common 0x74
        movwf 0x38
        movlp 0x15
        goto L_15CF
L_1E5D:
        movlb 0x01
        movf 0x5A, 0
        xorwf 0x59, 0
        btfsc 0x03, 2               ; STATUS
        goto L_1E71
        movlw 0x6E
        subwf 0x5A, 0
        btfss 0x03, 0               ; STATUS
        goto L_1E68
        movlw 0x57
        movwf 0x5A
L_1E68:
        movf 0x5A, 0
        movwf 0x06                  ; FSR1L
        movlw 0x02
        movwf 0x07                  ; FSR1H
        movf 0x01, 0                ; INDF1
        movlb 0x00
        movwf 0x34
        movlb 0x01
        incf 0x5A, 1
L_1E71:
        movlb 0x00
        movf 0x34, 0
        return
L_1E74:
        movlb 0x01
        movf 0x59, 0
        xorwf 0x5A, 0
        btfss 0x03, 2               ; STATUS
        retlw 0x01
        retlw 0x00
L_1E7A:
        movwf 0x63
        clrf 0x64
        movf 0x64, 0
        movwf 0x66
        movf 0x69, 0
        subwf 0x63, 0
        movwf 0x65
        btfss 0x03, 0               ; STATUS
        decf 0x66, 1
        movf 0x66, 0
        xorlw 0x80
        movwf 0x67
        movlw 0x80
        subwf 0x67, 0
        return
L_1E89:
        movlb 0x01
        clrf 0x58
        clrf 0x51
        clrf 0x52
        clrf 0x53
        movlp 0x1B
        call L_1B9E
        movlp 0x1E
        movlp 0x1B
        call L_1B1C
        movlp 0x1E
        movlp 0x1B
        call L_1B4A
        movlp 0x1E
        movlp 0x1A
        call L_1AFD
        movlp 0x1E
        movlp 0x10
        call L_1017
        movlp 0x1E
        movlp 0x10
        call L_10EF
        movlp 0x1E
        movlp 0x1B
        call L_1B39
        movlp 0x1E
        movlp 0x07
        call L_07ED
        movlp 0x1E
        movlp 0x1B
        call L_1B2A
        movlp 0x1E
        movlp 0x08
        call L_0801
        movlp 0x1E
        movlw 0xC0
        iorwf 0x0B, 1               ; INTCON
        movlp 0x10
        call L_1001
        movlp 0x1E
        movlw 0x94
        movwf 0x06                  ; FSR1L
        movlw 0x23
        movlp 0x1B
        call L_1BF5
        movlp 0x1E
        movlw 0xE4
        movlp 0x1C
        call L_1C10
        movlp 0x1E
L_1EBB:
        movlp 0x14
        call L_14B9
        movlp 0x1E
        movlp 0x1D
        call L_1DD4
        movlp 0x1E
        movlw 0x0A
        movlb 0x01
        subwf 0x4A, 0
        btfss 0x03, 0               ; STATUS
        goto L_1EDC
        clrf 0x4A
        movlp 0x1C
        call L_1CFC
        movlp 0x1E
        clrwdt
        movlb 0x01
        movf 0x21, 0
        btfss 0x03, 2               ; STATUS
        goto L_1EDC
        movlw 0x05
        incf 0x52, 1
        subwf 0x52, 0
        btfss 0x03, 0               ; STATUS
        goto L_1EDC
        clrf 0x52
        clrf 0x21
        incf 0x21, 1
        clrf 0x4E
        incf 0x4E, 1
        movlp 0x08
        call L_089E
        movlp 0x1E
L_1EDC:
        movf 0x4B, 0
        btfsc 0x03, 2               ; STATUS
        goto L_1EF0
        clrf 0x4B
        incf 0x51, 1
        movlp 0x1C
        call L_1C2A
        movlp 0x1E
        movlb 0x01
        incfsz 0x5D, 0
        goto L_1EF0
        movlw 0x32
        incf 0x53, 1
        subwf 0x53, 0
        btfss 0x03, 0               ; STATUS
        goto L_1EF0
        clrf 0x53
        movlp 0x1F
        call L_1F43
        movlp 0x1E
L_1EF0:
        movlw 0x00
        movlb 0x01
        subwf 0x3E, 0
        movlw 0x05
        btfsc 0x03, 2               ; STATUS
        subwf 0x3D, 0
        btfss 0x03, 0               ; STATUS
        goto L_1EBB
        clrf 0x3D
        clrf 0x3E
        movlp 0x0F
        call L_0FA3
        movlp 0x1E
        movlb 0x01
        movf 0x50, 0
        btfsc 0x03, 2               ; STATUS
        goto L_1F05
        movlp 0x0A
        call L_0A5F
        movlp 0x1E
        goto L_1EBB
L_1F05:
        movf 0x2F, 0
        xorwf 0x30, 0
        btfsc 0x03, 2               ; STATUS
        goto L_1F24
        movf 0x30, 0
        movwf 0x2F
        decfsz 0x2F, 0
        goto L_1F26
        movlb 0x00
        bsf 0x0C, 2                 ; PORTA
        movlb 0x01
        decfsz 0x24, 0
        goto L_1F14
        clrf 0x2D
        incf 0x2D, 1
L_1F14:
        movlw 0xE4
        movlp 0x0F
        call L_0F79
        movlp 0x1E
        movwi 0[FSR1]
        movlw 0x00
        movwi 1[FSR1]
        movwi 2[FSR1]
        movwi 3[FSR1]
        movlp 0x1C
        call L_1C02
        movlp 0x1E
        incf 0x36, 1
        movlp 0x0E
        call L_0E58
        movlp 0x1E
L_1F24:
        movlp 0x12
        goto L_1263
L_1F26:
        movlw 0x02
        xorwf 0x2F, 0
        btfss 0x03, 2               ; STATUS
        goto L_1F3D
        movlb 0x00
        bcf 0x0C, 2                 ; PORTA
        movlb 0x01
        decfsz 0x24, 0
        goto L_1F30
        clrf 0x2D
L_1F30:
        movlw 0xE4
        movwf 0x06                  ; FSR1L
        movlw 0x23
        movlp 0x1B
        call L_1BF5
        movlp 0x1E
        movlp 0x1C
        call L_1C02
        movlp 0x1E
        movlp 0x0E
        call L_0E58
        movlp 0x1E
        goto L_1F24
L_1F3D:
        movlw 0x03
        xorwf 0x2F, 0
        btfss 0x03, 2               ; STATUS
        goto L_1F24
        clrf 0x58
        goto L_1F24
L_1F43:
        movlw 0x03
        movlb 0x00
        movwf 0x39
        movlw 0x2B
        clrf 0x3A
        goto L_1FA2
L_1F49:
        movwf 0x44
        movwf 0x40
        movlw 0x90
        clrf 0x41
        clrf 0x42
        clrf 0x43
        movwf 0x06                  ; FSR1L
        movlw 0x23
        movwf 0x07                  ; FSR1H
        addfsr FSR1L, 12
        movf 0x40, 0
        movwi 0[FSR1]
        movf 0x41, 0
        movwi 1[FSR1]
        movf 0x42, 0
        movwi 2[FSR1]
        movf 0x43, 0
        movwi 3[FSR1]
        movf 0x44, 0
        movwf 0x36
        movlw 0x0E
        movlp 0x0E
        call L_0E58
        movlp 0x1F
        movlb 0x00
        decfsz 0x44, 0
        goto L_1F6E
        movlb 0x01
        decfsz 0x2F, 0
        goto L_1F6B
        call L_1FFA
        movlp 0x1F
        incf 0x31, 1
        goto L_1F76
L_1F6B:
        movlw 0x03
        movwf 0x30
        goto L_1F76
L_1F6E:
        movlb 0x01
        movf 0x31, 0
        btfss 0x03, 2               ; STATUS
        clrf 0x31
        movlw 0x03
        xorwf 0x30, 0
        btfsc 0x03, 2               ; STATUS
        clrf 0x30
L_1F76:
        movlb 0x00
        movf 0x44, 0
        movwf 0x3D
        movlw 0x65
        goto L_1F7B
L_1F7B:
        movwf 0x3E
        clrf 0x3F
        movwf 0x34
        movf 0x3F, 0
        movlp 0x14
        call L_1444
        movlp 0x1F
        movwf 0x3F
        movlw 0x04
        movwf 0x34
        movf 0x3F, 0
        movlp 0x14
        call L_1444
        movlp 0x1F
        movwf 0x3F
        clrf 0x34
        movlp 0x14
        call L_1444
        movlp 0x1F
        movwf 0x3F
        clrf 0x34
        incf 0x34, 1
        movlp 0x14
        call L_1444
        movlp 0x1F
        movwf 0x3F
        movf 0x3D, 0
        movwf 0x34
        movf 0x3F, 0
        movlp 0x14
        call L_1444
        movlp 0x1F
        movwf 0x3F
        movlw 0x03
        movwf 0x39
        movf 0x3F, 0
        movwf 0x3A
        movlw 0x07
        goto L_1FA2
L_1FA2:
        movwf 0x3B
        movlw 0x55
        movlb 0x04
        movwf 0x20
        movlw 0xAA
        movwf 0x21
        movlb 0x00
        movf 0x39, 0
        movlb 0x04
        movwf 0x22
        movlb 0x00
        movf 0x3B, 0
        movlb 0x04
        movwf 0x23
        clrf 0x24
        movlb 0x00
        movf 0x3A, 0
        movlb 0x04
        movwf 0x25
        movlw 0x07
        movlb 0x00
        addwf 0x3A, 1
        movlw 0x20
        movwf 0x34
        movlw 0x02
        movwf 0x35
        movf 0x3A, 0
        addlw 0xFF
        movwf 0x36
        call L_1FCD
        movlp 0x1F
        movwf 0x3C
        movf 0x3A, 0
        addlw 0x1F
        movwf 0x06                  ; FSR1L
        movlw 0x02
        movwf 0x07                  ; FSR1H
        movf 0x3C, 0
        movwf 0x01                  ; INDF1
        movf 0x3A, 0
        movwf 0x35
        movlw 0x20
        goto L_1FE0
L_1FCD:
        clrf 0x38
        clrf 0x37
L_1FCF:
        movf 0x36, 0
        subwf 0x37, 0
        btfsc 0x03, 0               ; STATUS
        goto L_1FDE
        movf 0x34, 0
        movwf 0x06                  ; FSR1L
        movf 0x35, 0
        movwf 0x07                  ; FSR1H
        movf 0x01, 0                ; INDF1
        addwf 0x38, 1
        incf 0x34, 1
        btfsc 0x03, 2               ; STATUS
        incf 0x35, 1
        incf 0x37, 1
        goto L_1FCF
L_1FDE:
        movf 0x38, 0
        return
L_1FE0:
        movwf 0x36
L_1FE1:
        decf 0x35, 1
        incfsz 0x35, 0
        goto L_1FE5
        return
L_1FE5:
        movf 0x36, 0
        movwf 0x06                  ; FSR1L
        movlw 0x02
        movwf 0x07                  ; FSR1H
        movf 0x01, 0                ; INDF1
        call L_1FEF
        movlp 0x1F
        movlb 0x00
        incf 0x36, 1
        goto L_1FE1
L_1FEF:
        movwf 0x34
        movlb 0x09
        btfss 0x12, 5               ; UR1LSR
        return
        movlb 0x00
        movf 0x34, 0
        movlb 0x09
        movwf 0x0C                  ; UR1DATAL
L_1FF7:
        btfsc 0x12, 5
        return
        goto L_1FF7
L_1FFA:
        clrf 0x34
        clrf 0x35
        clrf 0x36
        clrf 0x37
        clrf 0x31
        return
        retlw 0x65
        retlw 0x04
        retlw 0x67
        retlw 0x02
        retlw 0x68
        retlw 0x02
        retlw 0x69
        retlw 0x02
        retlw 0x6A
        retlw 0x02
        retlw 0x6C
        retlw 0x04
        retlw 0x6D
        retlw 0x02
        retlw 0x6E
        retlw 0x01
        retlw 0x6F
        retlw 0x01
        retlw 0x6F
        retlw 0x39
        retlw 0x61
        retlw 0x36
        retlw 0x61
        retlw 0x74
        retlw 0x39
        retlw 0x63
        retlw 0x79
        retlw 0x66
        retlw 0x63
        retlw 0x68
        retlw 0x62
        retlw 0x34
        retlw 0x37
        retlw 0x79
        retlw 0x00
        retlw 0x22
        retlw 0x2C
        retlw 0x22
        retlw 0x76
        retlw 0x22
        retlw 0x3A
        retlw 0x22
        retlw 0x00
        retlw 0x7B
        retlw 0x22
        retlw 0x70
        retlw 0x22
        retlw 0x3A
        retlw 0x22
        retlw 0x00
        retlw 0x22
        retlw 0x2C
        retlw 0x22
        retlw 0x6D
        retlw 0x22
        retlw 0x3A
        retlw 0x00
        retlw 0x31
        retlw 0x2E
        retlw 0x30
        retlw 0x2E
        retlw 0x35
        retlw 0x00
        retlw 0x31
        retlw 0x00
        retlw 0x7D
        retlw 0x00

        end
