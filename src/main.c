/* PS10 open MCU firmware.
 *
 * Runs behind the stock bootloader (linked at 0x600). Talks Tuya MCU protocol
 * to the BK7231N (ESPHome tuya:) on USART1 at 9600, drives the triac and LED,
 * reads the button, switch input, radar OUT and LDR, and relays the LD2410C's
 * serial link to ESPHome in datapoint 202 (docs/radar-passthrough.md), so
 * ESPHome's ld2410: component configures and reads the radar itself.
 *
 * Datapoints:
 *    1  presence        bool   ro   radar OUT pin
 *  101  output          bool   rw   triac
 *  102  LED mode        enum   rw   0 off, 1 follows output, 2 on, 3 follows presence
 *  103  auto            bool   rw   output follows presence (gated by 105)
 *  104  light           value  ro   LDR, raw 12-bit ADC (direction not yet checked)
 *  105  light threshold value  rw   auto only switches on below this; 0 = always
 *  106  switch input    bool   ro   true while PC0 is active (low)
 *  107  button          enum   ro   event: 0 short press, 1 long press (>= 3 s)
 *  108  switch mode     enum   rw   0 report only, 1 toggle on press, 2 toggle on any change
 *  202  radar relay     raw    rw   bytes to/from the LD2410C
 *
 * Updates: 0x0A writes FF to data EEPROM 0x00/0x01 (so the bootloader's CRC
 * check fails) and resets into the bootloader. Holding the button while
 * powering up for 3 s does the same, as a way back if anything goes wrong.
 * Settings live in data EEPROM 0x20-0x27; the stock firmware's (0x02-0x0F,
 * 0x7F) are left alone so a rollback finds them as they were.
 */
#include "ft61e0a5.h"
#include "board.h"
#include "radar.h"
#include "tuya.h"

#ifndef VERSION
#define VERSION "0.2.0"
#endif

BOOTLOADER_RAM;

static const char product[] = "{\"p\":\"ps10open\",\"v\":\"" VERSION "\",\"m\":0}";

enum {
    DP_PRESENCE = 1,
    DP_OUTPUT = 101,
    DP_LED = 102,
    DP_AUTO = 103,
    DP_LIGHT = 104,
    DP_THRESHOLD = 105,
    DP_SWITCH = 106,
    DP_BUTTON = 107,
    DP_SWITCH_MODE = 108,
    DP_RADAR = 202,
};

#define RELAY_CHUNK 48          /* radar bytes per DP 202 report */
#define RELAY_IDLE_MS 3         /* send a partial chunk after this gap */
#define LIGHT_PERIOD_MS 5000
#define LIGHT_DELTA 32
#define DEBOUNCE_MS 30
#define LONG_PRESS_MS 3000

/* --- settings (data EEPROM) ----------------------------------------------- */
#define EE_BASE 0x20
#define EE_MAGIC 0x5A
static struct {
    uint8_t led_mode, auto_on, switch_mode;
    uint16_t threshold;
} cfg;

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

static void cfg_load(void)
{
    if (ee_read(EE_BASE) != EE_MAGIC) {
        cfg.led_mode = 1;
        cfg.auto_on = 0;
        cfg.switch_mode = 1;
        cfg.threshold = 0;
        return;
    }
    cfg.led_mode = ee_read(EE_BASE + 1) & 3;
    cfg.auto_on = ee_read(EE_BASE + 2) & 1;
    cfg.switch_mode = ee_read(EE_BASE + 3);
    if (cfg.switch_mode > 2) cfg.switch_mode = 1;
    cfg.threshold = ee_read(EE_BASE + 4) | ((uint16_t)ee_read(EE_BASE + 5) << 8);
}

static void cfg_save(void)
{
    ee_write(EE_BASE + 1, cfg.led_mode);
    ee_write(EE_BASE + 2, cfg.auto_on);
    ee_write(EE_BASE + 3, cfg.switch_mode);
    ee_write(EE_BASE + 4, (uint8_t)cfg.threshold);
    ee_write(EE_BASE + 5, (uint8_t)(cfg.threshold >> 8));
    ee_write(EE_BASE, EE_MAGIC);
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

void uart_tx(uint8_t b)
{
    while (!(UR1LSR & UR1_TXEF)) clrwdt();
    UR1DATAL = b;
}

/* --- time ----------------------------------------------------------------- */
static volatile uint8_t ticks;  /* 1 ms ticks not yet processed */

void __interrupt() isr(void)
{
    if ((UR1IER & UR1_RXNE) && (UR1LSR & UR1_RXNEF)) {
        uint8_t b = UR1DATAL;
        uint8_t next = (urx_head + 1) & (URXQ - 1);
        if (next != urx_tail) {
            urxq[urx_head] = b;
            urx_head = next;
        }
    }
    radar_isr();
    if (TIM4SR & TIM_U) {
        TIM4SR = TIM_U;
        ticks++;
    }
}

/* --- state ---------------------------------------------------------------- */
static uint8_t online;          /* tuya: has asked for the datapoints */
static uint8_t heartbeat_seen;
static uint8_t output, presence, switch_active;
static uint16_t light;
static uint16_t light_reported = 0xFFFF;
static uint16_t light_timer;

static void led_update(void)
{
    uint8_t on = cfg.led_mode == 2 || (cfg.led_mode == 1 && output) || (cfg.led_mode == 3 && presence);
    if (on) LED_PORT |= 1u << LED_BIT;
    else LED_PORT &= (uint8_t)~(1u << LED_BIT);
}

static void set_output(uint8_t on, uint8_t report)
{
    output = on ? 1 : 0;
    if (output) OUT_PORT |= 1u << OUT_BIT;
    else OUT_PORT &= (uint8_t)~(1u << OUT_BIT);
    led_update();
    if (report && online) tuya_report_bool(DP_OUTPUT, output);
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
    tuya_report_bool(DP_PRESENCE, presence);
    tuya_report_bool(DP_OUTPUT, output);
    tuya_report_enum(DP_LED, cfg.led_mode);
    tuya_report_bool(DP_AUTO, cfg.auto_on);
    tuya_report_value(DP_LIGHT, light);
    tuya_report_value(DP_THRESHOLD, cfg.threshold);
    tuya_report_bool(DP_SWITCH, switch_active);
    tuya_report_enum(DP_SWITCH_MODE, cfg.switch_mode);
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

static uint32_t be32(const uint8_t *p)
{
    return ((uint32_t)p[0] << 24) | ((uint32_t)p[1] << 16) | ((uint16_t)p[2] << 8) | p[3];
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
            set_output(v[0], 0);
            tuya_report_bool(DP_OUTPUT, output);
            break;
        case DP_LED:
            if (v[0] <= 3) { cfg.led_mode = v[0]; cfg_save(); led_update(); }
            tuya_report_enum(DP_LED, cfg.led_mode);
            break;
        case DP_AUTO:
            cfg.auto_on = v[0] ? 1 : 0;
            cfg_save();
            tuya_report_bool(DP_AUTO, cfg.auto_on);
            break;
        case DP_THRESHOLD:
            if (n == 4) {
                uint32_t t = be32(v);
                cfg.threshold = t > 4095 ? 4095 : (uint16_t)t;
                cfg_save();
            }
            tuya_report_value(DP_THRESHOLD, cfg.threshold);
            break;
        case DP_SWITCH_MODE:
            if (v[0] <= 2) { cfg.switch_mode = v[0]; cfg_save(); }
            tuya_report_enum(DP_SWITCH_MODE, cfg.switch_mode);
            break;
        case DP_RADAR:
            if (type == DP_RAW)
                for (uint8_t k = 0; k < n; k++) radar_write(v[k]);
            relay_send(RELAY_CHUNK);   /* tuya: waits for a 0x07 after each 0x06 */
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
static uint8_t btn_cnt, btn_down, sw_cnt, sw_level, pres_cnt;
static uint16_t btn_ms;

static void auto_output(void)
{
    if (!cfg.auto_on) return;
    if (presence && !output && (cfg.threshold == 0 || light < cfg.threshold)) set_output(1, 1);
    else if (!presence && output) set_output(0, 1);
}

static void inputs_1ms(void)
{
    /* button: debounced, short press toggles the output, long press reported */
    uint8_t pressed = !((BTN_PORT >> BTN_BIT) & 1);
    if (pressed != btn_down) {
        if (++btn_cnt >= DEBOUNCE_MS) {
            btn_cnt = 0;
            btn_down = pressed;
            if (pressed) {
                btn_ms = 0;
            } else if (btn_ms < LONG_PRESS_MS) {
                set_output(!output, 1);
                if (online) tuya_report_enum(DP_BUTTON, 0);
            }
        }
    } else {
        btn_cnt = 0;
    }
    if (btn_down && btn_ms < LONG_PRESS_MS && ++btn_ms == LONG_PRESS_MS && online)
        tuya_report_enum(DP_BUTTON, 1);

    /* switch input */
    uint8_t active = !((SW_PORT >> SW_BIT) & 1);
    if (active != switch_active) {
        if (++sw_cnt >= DEBOUNCE_MS) {
            sw_cnt = 0;
            switch_active = active;
            if (online) tuya_report_bool(DP_SWITCH, switch_active);
            if (cfg.switch_mode == 2 || (cfg.switch_mode == 1 && active)) set_output(!output, 1);
        }
    } else {
        sw_cnt = 0;
    }

    /* radar OUT */
    uint8_t p = (RDR_PORT >> RDR_BIT) & 1;
    if (p != presence) {
        if (++pres_cnt >= DEBOUNCE_MS) {
            pres_cnt = 0;
            presence = p;
            if (online) tuya_report_bool(DP_PRESENCE, presence);
            led_update();
            auto_output();
        }
    } else {
        pres_cnt = 0;
    }

    /* light */
    if (++light_timer >= LIGHT_PERIOD_MS) {
        light_timer = 0;
        light = adc_read(LDR_CHANNEL);
        if (online && (light_reported == 0xFFFF ||
                       (light > light_reported ? light - light_reported : light_reported - light) >= LIGHT_DELTA)) {
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

    LATA = 0;
    LATB = LATB_INIT;
    LATC = 0;
    TRISA = TRISA_INIT;
    TRISB = TRISB_INIT;
    TRISC = TRISC_INIT;
    WPUB = WPUB_INIT;
    ANSELA = ANSELA_INIT;

    /* USART1: 9600 8N1, as stock; receive interrupt only */
    UR1LCR = 0x01;
    UR1MCR = 0x18;
    UR1DLL = 0x68;
    UR1DLH = 0;
    UR1TC = 0x01;
    ODCON0 |= 0x01;
    UR1IER = UR1_RXNE;

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
    btn_down = 0;
    LED_PORT &= (uint8_t)~(1u << LED_BIT);
}

void main(void)
{
    boot_app_flag |= 0x01;      /* keep the bootloader passing interrupts to us */
    hw_init();
    cfg_load();
    INTCON = GIE | PEIE;
    boot_escape();
    presence = (RDR_PORT >> RDR_BIT) & 1;
    switch_active = !((SW_PORT >> SW_BIT) & 1);
    light = adc_read(LDR_CHANNEL);
    set_output(0, 0);

    uint8_t idle = 0;
    for (;;) {
        clrwdt();
        while (urx_tail != urx_head) {
            uint8_t b = urxq[urx_tail];
            urx_tail = (urx_tail + 1) & (URXQ - 1);
            uint8_t len, cmd = tuya_feed(b, &len);
            idle = 0;
            if (cmd != 0xFF) handle(cmd, len);
        }
        while (ticks) {
            ticks--;
            radar_tick_1ms();
            inputs_1ms();
            if (++idle == 200) tuya_resync();   /* 200 ms gap inside a frame */
        }
        if (online) {
            uint8_t n = radar_rx_count();
            if (n >= RELAY_CHUNK || (n && radar_rx_idle_ms >= RELAY_IDLE_MS)) relay_send(RELAY_CHUNK);
        } else {
            while (radar_rx_count()) radar_rx_get();   /* nobody to send them to */
        }
    }
}
