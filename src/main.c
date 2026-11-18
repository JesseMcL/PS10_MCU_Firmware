/* PS10 open MCU firmware.
 *
 * Runs behind the stock bootloader (linked at 0x600). Talks Tuya MCU protocol
 * to the BK7231N (ESPHome tuya:) on USART1 at 9600. It only does I/O: it sets
 * the triac and LED when told, reports the inputs as they are, and relays the
 * LD2410C's serial link in datapoint 202. Every behaviour (what the button
 * does, what the LED shows, when the output switches) belongs in ESPHome.
 *
 * Datapoints (numbers as the stock firmware where the function is the same):
 *    1  presence   enum   ro   radar OUT pin: 0 none, 1 presence
 *  110  output     bool   rw   triac, reported as read back from the pin
 *  111  status LED bool   rw   LED, read back likewise (stock: LED follows the output)
 *  112  light      value  ro   LDR, raw 12-bit ADC, sampled every second
 *  113  switch     bool   ro   switch input (PC0) active, 30 ms debounce
 *  114  button     bool   ro   button (PA3) pressed, 30 ms debounce
 *  202  radar      raw    rw   bytes to/from the LD2410C, any chunking up to
 *                              128 bytes per write
 *  203  radar relay bool   rw   1 (start-up): radar bytes go to ESPHome in DP 202.
 *                              0: they're discarded; DP 202 writes still reach the
 *                              radar and are still answered (empty).
 *  250  diagnostics raw   ro   link counters, every 2 s (layout at diag_send)
 *
 * Inputs are reported when they change, and all of them on a status query.
 * The output and LED start off.
 *
 * Updates: 0x0A writes FF to data EEPROM 0x00/0x01 (so the bootloader's CRC
 * check fails) and resets into the bootloader. Holding the button while
 * powering up for 3 s does the same, as a way back if anything goes wrong.
 * Nothing else is written to the EEPROM, so the stock settings stay for a
 * rollback.
 */
#include "ft61e0a5.h"
#include "board.h"
#include "radar.h"
#include "tuya.h"

#ifndef VERSION
#define VERSION "0.2.5"
#endif

BOOTLOADER_RAM;

static const char product[] = "{\"p\":\"ps10open\",\"v\":\"" VERSION "\",\"m\":0}";

enum {
    DP_PRESENCE = 1,
    DP_OUTPUT = 110,
    DP_LED = 111,
    DP_LIGHT = 112,
    DP_SWITCH = 113,
    DP_BUTTON = 114,
    DP_RADAR = 202,
    DP_RELAY = 203,
    DP_DIAG = 250,
};

#define RELAY_CHUNK 48          /* radar bytes per DP 202 report */
#define RELAY_IDLE_MS 3         /* send a partial chunk after this gap */
#define LIGHT_PERIOD_MS 1000
#define DEBOUNCE_MS 30
#define DIAG_PERIOD_MS 2000

/* --- data EEPROM: only the bootloader hand-over ----------------------------- */
static uint8_t ee_read(uint8_t a)
{
    EEADRL = a;
    EEADRH = 0;
    EECON1 = 0;
    EECON1 |= EE_RD;
    nop(); nop(); nop(); nop();     /* data valid after 4 cycles */
    return EEDATL;
}

static void ee_write(uint8_t a, uint8_t v)
{
    if (ee_read(a) == v) return;
    EEADRL = a;
    EEADRH = 0;
    EEDATL = v;
    EECON1 = EE_WREN;
    uint8_t gie = INTCON & GIE;
    INTCON &= (uint8_t)~GIE;
    EECON2 = 0x55;
    EECON2 = 0xAA;
    EECON1 |= EE_WR;
    nop(); nop(); nop(); nop();
    INTCON |= gie;
    while (EECON1 & EE_WR) clrwdt();
    EECON1 = 0;
}

static void enter_bootloader(void)
{
    INTCON = 0;
    ee_write(0x00, 0xFF);
    ee_write(0x01, 0xFF);
    reset();
}

/* --- Tuya UART ------------------------------------------------------------ */
#define URXQ 128
static volatile uint8_t urxq[URXQ], urx_head, urx_tail;

/* receive diagnostics (DP 250) */
static volatile uint16_t rx_bytes, rx_fe, rx_pe, rx_ovr, rx_bk, rx_polled, rx_qfull;
static volatile uint8_t rx_errs_seen;      /* every error flag seen, ORed */
#define RAWQ 32
static volatile uint8_t rawq[RAWQ], raw_head;   /* the last bytes received, as received */
static volatile uint16_t isr_count;        /* interrupt entries, for the per-second rate */

/* Take what USART1 has: clear any receive error flag (they're write-0-to-
 * clear; writing 1 leaves a flag alone), then read the byte if there is one.
 * A macro, not a function: it runs in the interrupt and, as a backup, in the
 * main loop with interrupts off, and XC8 would otherwise duplicate it. */
#define UART_SERVICE() do {                                         \
        uint8_t lsr_ = UR1LSR;                                      \
        uint8_t err_ = lsr_ & UR1_ERRS;                             \
        if (err_) {                                                 \
            UR1LSR = (uint8_t)~err_;                                \
            rx_errs_seen |= err_;                                   \
            if (err_ & UR1_FEF) rx_fe++;                            \
            if (err_ & UR1_PEF) rx_pe++;                            \
            if (err_ & UR1_OVERF) rx_ovr++;                         \
            if (err_ & UR1_BKF) rx_bk++;                            \
        }                                                           \
        if (lsr_ & UR1_RXNEF) {                                     \
            uint8_t b_ = UR1DATAL;                                  \
            uint8_t next_ = (urx_head + 1) & (URXQ - 1);            \
            rx_bytes++;                                             \
            rawq[raw_head] = b_;                                    \
            raw_head = (raw_head + 1) & (RAWQ - 1);                 \
            if (next_ != urx_tail) {                                \
                urxq[urx_head] = b_;                                \
                urx_head = next_;                                   \
            } else rx_qfull++;                                      \
        }                                                           \
    } while (0)

void uart_tx(uint8_t b)
{
    while (!(UR1LSR & UR1_TXEF)) clrwdt();
    UR1DATAL = b;
}

/* --- time ----------------------------------------------------------------- */
static volatile uint8_t ticks;  /* 1 ms ticks not yet processed */

void __interrupt() isr(void)
{
    isr_count++;
    UART_SERVICE();
    radar_isr();
    if (TIM4SR & TIM_U) {
        TIM4SR = TIM_U;
        ticks++;
    }
}

/* --- state ---------------------------------------------------------------- */
static uint8_t online;          /* tuya: has asked for the datapoints */
static uint8_t heartbeat_seen;
static uint8_t output, led, presence, switch_on, button;
static uint16_t light, light_reported;
static uint16_t light_timer;
static uint16_t diag_timer, uptime_ms, uptime_s;
static uint8_t reset_flags;     /* PCON at start-up */
static uint8_t max_backlog;     /* most 1 ms ticks the main loop has fallen behind */
static uint8_t rx_waiting;      /* a received byte was waiting at the last 1 ms check */
static uint8_t relay = 1;       /* DP 203 */
static uint16_t loops, loops_last, loops_min = 0xFFFF;  /* main-loop passes per second */
static uint16_t isr_last, isr_max;                      /* interrupts per second */
static uint8_t urxq_high, radar_rxq_high;               /* most bytes ever waiting */

static void set_output(uint8_t on)
{
    output = on ? 1 : 0;
    if (output) OUT_PORT |= 1u << OUT_BIT;
    else OUT_PORT &= (uint8_t)~(1u << OUT_BIT);
}

/* DP 110/111 report the pin as read back (PORTx reads the pin itself), not
 * the value asked for: if the pin isn't driven, ESPHome sees it. */
static uint8_t output_pin(void) { return (OUT_PORT >> OUT_BIT) & 1; }
static uint8_t led_pin(void) { return (LED_PORT >> LED_BIT) & 1; }

static void set_led(uint8_t on)
{
    led = on ? 1 : 0;
    if (led) LED_PORT |= 1u << LED_BIT;
    else LED_PORT &= (uint8_t)~(1u << LED_BIT);
}

static uint16_t adc_read(uint8_t channel)
{
    ADCON0 = (uint8_t)(channel << 4) | 0x01;   /* channel, ADON */
    for (uint8_t i = 0; i < 100; i++) nop();   /* acquisition */
    ADCON0 |= AD_GO;
    while (ADCON0 & AD_GO) clrwdt();
    uint16_t v = ((uint16_t)ADRESH << 8) | ADRESL;
    ADCON0 = 0;
    return v;
}

static void report_all(void)
{
    tuya_report_enum(DP_PRESENCE, presence);
    tuya_report_bool(DP_OUTPUT, output_pin());
    tuya_report_bool(DP_LED, led_pin());
    tuya_report_value(DP_LIGHT, light);
    tuya_report_bool(DP_SWITCH, switch_on);
    tuya_report_bool(DP_BUTTON, button);
    tuya_report_bool(DP_RELAY, relay);
    light_reported = light;
}

/* DP 202 report with up to n pending radar bytes (also the reply to a 0x06) */
static void relay_send(uint8_t n)
{
    uint8_t have = radar_rx_count();
    if (n > have) n = have;
    tuya_report_raw_begin(DP_RADAR, n);
    while (n--) tuya_byte(radar_rx_get());
    tuya_end();
}

/* DP 250, raw, 82 bytes:
 *   0 layout (2)      1 PCON at start-up  2 receive error flags ever seen
 *   3 UR1LSR now      4 UR1IER now        5 UR1MCR now
 *   6 Tuya parser state now (0 = idle)    7 longest main-loop lag, ms
 * then 16-bit big-endian, counters since start-up (wrapping) unless noted:
 *   8 uptime s        10 bytes received   12 frames accepted
 *  14 bad checksums   16 frames too long  18 partial frames dropped
 *  20 framing errors  22 parity errors    24 overruns   26 breaks
 *  28 bytes the main loop had to fetch (left by the interrupt over 1 ms)
 *  30 bytes lost to a full receive queue
 *  32 bytes skipped looking for 55 AA
 *  34 interrupts in the last second       36 most in any second
 *  38 main-loop passes in the last second 40 fewest in any second (saturate)
 * then 8-bit:
 *  42 most bytes waiting in the Tuya receive queue (of 127)
 *  43 most bytes waiting in the radar receive queue (of 127)
 *  44 most bytes waiting to go to the radar (of 255)
 *  45 radar bytes lost to a full queue   46 radar framing errors
 *  47 radar commands refused (queue full) 48 radar commands blocked (A1/A2)
 *  49 DP 203 (relay on)
 *  50..81 the last 32 bytes received on the Tuya UART, oldest first */
static void put16(uint16_t v)
{
    tuya_byte((uint8_t)(v >> 8));
    tuya_byte((uint8_t)v);
}

static void diag_send(void)
{
    uint16_t c[7];
    uint8_t raw[RAWQ], seen;
    INTCON &= (uint8_t)~GIE;        /* a consistent snapshot of the ISR's counters */
    c[0] = rx_bytes; c[1] = rx_fe; c[2] = rx_pe; c[3] = rx_ovr; c[4] = rx_bk; c[5] = rx_polled; c[6] = rx_qfull;
    seen = rx_errs_seen;
    for (uint8_t i = 0; i < RAWQ; i++) raw[i] = rawq[(raw_head + i) & (RAWQ - 1)];
    INTCON |= GIE;
    tuya_report_raw_begin(DP_DIAG, 82);
    tuya_byte(2);
    tuya_byte(reset_flags);
    tuya_byte(seen);
    tuya_byte(UR1LSR);
    tuya_byte(UR1IER);
    tuya_byte(UR1MCR);
    tuya_byte(tuya_state());
    tuya_byte(max_backlog);
    put16(uptime_s);
    put16(c[0]);
    put16(tuya_frames);
    put16(tuya_bad_sum);
    put16(tuya_too_long);
    put16(tuya_resyncs);
    for (uint8_t i = 1; i < 7; i++) put16(c[i]);
    put16(tuya_hunted);
    put16(isr_last);
    put16(isr_max);
    put16(loops_last);
    put16(loops_min);
    tuya_byte(urxq_high);
    tuya_byte(radar_rxq_high);
    tuya_byte(radar_pq_high);
    tuya_byte(radar_rx_overflows);
    tuya_byte(radar_frame_errors);
    tuya_byte(radar_overflows);
    tuya_byte(radar_blocked);
    tuya_byte(relay);
    tuya_bytes(raw, RAWQ);
    tuya_end();
}

static void dp_deliver(uint8_t len)
{
    uint8_t i = 0;
    while (i + 4 <= len) {
        uint8_t dp = tuya_rx[i], type = tuya_rx[i + 1];
        uint8_t n = tuya_rx[i + 3];
        const uint8_t *v = &tuya_rx[i + 4];
        if (tuya_rx[i + 2] != 0 || i + 4 + n > len) break;
        switch (dp) {
        case DP_OUTPUT:
            set_output(v[0]);
            nop();                     /* let the pin settle before reading it */
            tuya_report_bool(DP_OUTPUT, output_pin());
            break;
        case DP_LED:
            set_led(v[0]);
            nop();
            tuya_report_bool(DP_LED, led_pin());
            break;
        case DP_RELAY:
            relay = v[0] ? 1 : 0;
            tuya_report_bool(DP_RELAY, relay);
            break;
        case DP_RADAR:
            if (type == DP_RAW)
                for (uint8_t k = 0; k < n; k++) radar_write(v[k]);
            /* answered at once: the 0x07 only says the frame arrived. A
             * command the queue can't take gets a failure ACK from the radar
             * side instead (radar.c), so the Tuya link never waits on it. */
            relay_send(relay ? RELAY_CHUNK : 0);
            break;
        default:                       /* unknown: echo, so tuya: isn't left waiting */
            tuya_begin(TUYA_DP_REPORT, 4u + n);
            tuya_bytes(&tuya_rx[i], 4 + n);
            tuya_end();
            break;
        }
        i += 4 + n;
    }
}

static void handle(uint8_t cmd, uint8_t len)
{
    switch (cmd) {
    case TUYA_HEARTBEAT:
        tuya_begin(TUYA_HEARTBEAT, 1);
        tuya_byte(heartbeat_seen);
        tuya_end();
        heartbeat_seen = 1;
        break;
    case TUYA_PRODUCT:
        tuya_begin(TUYA_PRODUCT, sizeof(product) - 1);
        for (uint8_t i = 0; i < sizeof(product) - 1; i++) tuya_byte(product[i]);
        tuya_end();
        break;
    case TUYA_CONF:
    case TUYA_WIFI_STATE:
        tuya_begin(cmd, 0);
        tuya_end();
        break;
    case TUYA_DP_QUERY:
        online = 1;
        report_all();
        break;
    case TUYA_DP_DELIVER:
        dp_deliver(len);
        break;
    case TUYA_OTA_START:
        enter_bootloader();
        break;
    }
}

/* --- inputs (every ms) ----------------------------------------------------- */
static uint8_t btn_cnt, sw_cnt;

/* debounced input: reports when the level has been different for DEBOUNCE_MS */
static uint8_t debounce(uint8_t now, uint8_t *state, uint8_t *cnt)
{
    if (now == *state) {
        *cnt = 0;
        return 0;
    }
    if (++*cnt < DEBOUNCE_MS) return 0;
    *cnt = 0;
    *state = now;
    return 1;
}

static void inputs_1ms(void)
{
    if (debounce(!((BTN_PORT >> BTN_BIT) & 1), &button, &btn_cnt) && online)
        tuya_report_bool(DP_BUTTON, button);
    if (debounce(!((SW_PORT >> SW_BIT) & 1), &switch_on, &sw_cnt) && online)
        tuya_report_bool(DP_SWITCH, switch_on);

    uint8_t p = (RDR_PORT >> RDR_BIT) & 1;   /* a clean logic output: no debounce */
    if (p != presence) {
        presence = p;
        if (online) tuya_report_enum(DP_PRESENCE, presence);
    }

    if (++light_timer >= LIGHT_PERIOD_MS) {
        light_timer = 0;
        light = adc_read(LDR_CHANNEL);
        if (online && light != light_reported) {
            tuya_report_value(DP_LIGHT, light);
            light_reported = light;
        }
    }
}

/* --- start-up ---------------------------------------------------------------- */
static void hw_init(void)
{
    INTCON = 0;
    OSCCON = 0x71;              /* 16 MHz HIRC */
    MISC0 = 0;
    WDTCON = 0x55;              /* ~4 s */
    clrwdt();
    PCKEN = PCKEN_ADC | PCKEN_TIM4 | PCKEN_UART1;

    PORTA = 0;                  /* levels first, so the pins come up right */
    PORTB = PORTB_INIT;
    PORTC = 0;
    TRISA = TRISA_INIT;
    TRISB = TRISB_INIT;
    TRISC = TRISC_INIT;
    PORTA = 0;                  /* and again after, in the order stock uses */
    PORTB = PORTB_INIT;
    PORTC = 0;
    WPUB = WPUB_INIT;
    ANSELA = ANSELA_INIT;

    /* USART1: 9600 8N1, as stock; receive and receive-error interrupts */
    UR1LCR = 0x01;
    UR1MCR = 0x18;
    UR1DLL = 0x68;
    UR1DLH = 0;
    UR1TC = 0x01;
    ODCON0 |= 0x01;
    UR1LSR = (uint8_t)~UR1_ERRS;  /* clear anything left from the bootloader */
    UR1IER = UR1_RXNE | UR1_RXSE;

    PSINK0 = 0xFF;              /* 62 mA sink on every pin, as stock */
    PSINK1 = 0xFF;
    PSINK2 = 0x03;

    /* ADC as stock (right-justified) */
    ADCON1 = 0xE4;
    ADCON2 = 0x80;
    ADCON0 = 0;

    /* TIM4: 16 MHz / 64 / 250 = 1 kHz */
    TIM4PSCR = 6;
    TIM4ARR = 249;
    TIM4CNTR = 0;
    TIM4SR = TIM_U;
    TIM4IER = TIM_U;
    TIM4CR1 = TIM_URS | TIM_CEN;

    radar_init();
}

static void boot_escape(void)
{
    /* button held at power-up for 3 s: back to the bootloader */
    uint16_t ms = 0;
    while (!((BTN_PORT >> BTN_BIT) & 1)) {
        clrwdt();
        if (ticks) {
            ticks--;
            if ((ms & 0x7F) == 0) LED_PORT ^= 1u << LED_BIT;
            if (++ms >= 3000) enter_bootloader();
        }
    }
    set_led(0);
}

void main(void)
{
    boot_app_flag |= 0x01;      /* keep the bootloader passing interrupts to us */
    reset_flags = PCON;
    PCON = 0x0F;                /* clear the error flags, re-arm the reset ones */
    hw_init();
    INTCON = GIE | PEIE;
    boot_escape();
    presence = (RDR_PORT >> RDR_BIT) & 1;
    switch_on = !((SW_PORT >> SW_BIT) & 1);
    light = adc_read(LDR_CHANNEL);
    set_output(0);
    set_led(0);

    uint8_t idle = 0;
    for (;;) {
        clrwdt();
        if (loops != 0xFFFF) loops++;
        {
            uint8_t n = (urx_head - urx_tail) & (URXQ - 1);
            if (n > urxq_high) urxq_high = n;
            n = radar_rx_count();
            if (n > radar_rxq_high) radar_rxq_high = n;
        }
        while (urx_tail != urx_head) {
            uint8_t b = urxq[urx_tail];
            urx_tail = (urx_tail + 1) & (URXQ - 1);
            uint8_t len, cmd = tuya_feed(b, &len);
            idle = 0;
            if (cmd != 0xFF) handle(cmd, len);
        }
        if (ticks > max_backlog) max_backlog = ticks;
        while (ticks) {
            ticks--;
            /* backup, once a ms: an error flag the interrupt hasn't cleared, or
             * a byte it has left waiting a whole character time. Neither should
             * happen; rx_polled counts the bytes. */
            INTCON &= (uint8_t)~GIE;
            uint8_t lsr = UR1LSR;
            if ((lsr & UR1_ERRS) || ((lsr & UR1_RXNEF) && rx_waiting)) {
                if (lsr & UR1_RXNEF) rx_polled++;
                UART_SERVICE();
                lsr = 0;
            }
            rx_waiting = lsr & UR1_RXNEF;
            INTCON |= GIE;
            if (++uptime_ms >= 1000) {
                uptime_ms = 0;
                uptime_s++;
                INTCON &= (uint8_t)~GIE;
                isr_last = isr_count;
                isr_count = 0;
                INTCON |= GIE;
                if (isr_last > isr_max) isr_max = isr_last;
                loops_last = loops;
                if (loops < loops_min) loops_min = loops;
                loops = 0;
            }
            if (++diag_timer >= DIAG_PERIOD_MS) { diag_timer = 0; if (online) diag_send(); }
            radar_tick_1ms();
            inputs_1ms();
            if (++idle == 200) tuya_resync();   /* 200 ms gap inside a frame */
        }
        radar_pump();
        if (online && relay) {
            uint8_t n = radar_rx_count();
            if (n >= RELAY_CHUNK || (n && radar_rx_idle_ms >= RELAY_IDLE_MS)) relay_send(RELAY_CHUNK);
        } else {
            while (radar_rx_count()) radar_rx_get();   /* nobody to send them to, or relay off */
        }
    }
}
