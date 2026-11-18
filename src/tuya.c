#include "tuya.h"

uint8_t tuya_rx[TUYA_RX_MAX];

static uint8_t state, cmd, sum, cnt, overflow;
static uint16_t remain;
static uint8_t tsum;
uint16_t tuya_frames, tuya_bad_sum, tuya_too_long, tuya_resyncs;

uint8_t tuya_state(void) { return state; }

void tuya_resync(void)
{
    if (state) tuya_resyncs++;  /* a partial frame dropped */
    state = 0;
}

uint8_t tuya_feed(uint8_t b, uint8_t *len)
{
    switch (state) {
    case 0:                     /* 55 */
        if (b == 0x55) { state = 1; sum = 0x55; }
        return 0xFF;
    case 1:                     /* AA (55 55 AA stays in sync) */
        if (b == 0xAA) { state = 2; sum += 0xAA; }
        else if (b != 0x55) state = 0;
        return 0xFF;
    case 2:                     /* version: anything */
        sum += b; state = 3;
        return 0xFF;
    case 3:
        cmd = b; sum += b; state = 4;
        return 0xFF;
    case 4:
        remain = (uint16_t)b << 8; sum += b; state = 5;
        return 0xFF;
    case 5:
        remain |= b; sum += b;
        cnt = 0;
        overflow = remain > TUYA_RX_MAX;
        state = remain ? 6 : 7;
        return 0xFF;
    case 6:
        sum += b;
        if (!overflow) tuya_rx[cnt++] = b;
        if (--remain == 0) state = 7;
        return 0xFF;
    default:                    /* checksum */
        state = 0;
        if (overflow) { tuya_too_long++; return 0xFF; }
        if (b != sum) { tuya_bad_sum++; return 0xFF; }
        tuya_frames++;
        *len = cnt;
        return cmd;
    }
}

static void put(uint8_t b)
{
    tsum += b;
    uart_tx(b);
}

void tuya_begin(uint8_t c, uint16_t len)
{
    tsum = 0;
    put(0x55);
    put(0xAA);
    put(0x03);                  /* protocol version, as the stock MCU */
    put(c);
    put((uint8_t)(len >> 8));
    put((uint8_t)len);
}

void tuya_byte(uint8_t b) { put(b); }

void tuya_bytes(const uint8_t *p, uint8_t n)
{
    while (n--) put(*p++);
}

void tuya_end(void) { uart_tx(tsum); }

static void dp_header(uint8_t dp, uint8_t type, uint8_t n)
{
    tuya_begin(TUYA_DP_REPORT, 4u + n);
    put(dp);
    put(type);
    put(0);
    put(n);
}

void tuya_report_bool(uint8_t dp, uint8_t v)
{
    dp_header(dp, DP_BOOL, 1);
    put(v ? 1 : 0);
    tuya_end();
}

void tuya_report_enum(uint8_t dp, uint8_t v)
{
    dp_header(dp, DP_ENUM, 1);
    put(v);
    tuya_end();
}

void tuya_report_value(uint8_t dp, uint32_t v)
{
    dp_header(dp, DP_VALUE, 4);
    put((uint8_t)(v >> 24));
    put((uint8_t)(v >> 16));
    put((uint8_t)(v >> 8));
    put((uint8_t)v);
    tuya_end();
}

void tuya_report_raw_begin(uint8_t dp, uint8_t n) { dp_header(dp, DP_RAW, n); }
