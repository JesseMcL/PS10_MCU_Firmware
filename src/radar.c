/* LD2410C link: a software UART on PB3 (to the radar) / PB4 (from it) at 9600
 * 8N1, as the stock firmware does it: TIM1 times transmitted bits, a falling
 * edge on PB4 (EINT4) starts TIM2, which samples the received bits mid-bit.
 * Both timers run from 2 x HIRC = 32 MHz.
 *
 * Bytes from ESPHome pass through a filter that drops the LD2410 commands a
 * software UART can't recover from: set baud rate (0x00A1) and factory reset
 * (0x00A2, which restores 256000 baud). They get a failure ACK instead. */
#include "ft61e0a5.h"
#include "board.h"
#include "radar.h"

#define RXQ 128                 /* power of two */
#define TXQ 128
#define HALF_BIT (RADAR_BAUD_ARR / 2)

static volatile uint8_t rxq[RXQ], rx_head, rx_tail;
static volatile uint8_t txq[TXQ], tx_head, tx_tail;
static volatile uint8_t tx_shift, tx_bit;   /* tx_bit 0 idle, 1..8 data, 9 stop, 10 stop sent */
static volatile uint8_t rx_shift, rx_bit;
volatile uint8_t radar_rx_idle_ms = 255;
uint8_t radar_rx_overflows, radar_frame_errors, radar_blocked;

#define TX_HIGH() (RTX_PORT |= (1u << RTX_BIT))
#define TX_LOW()  (RTX_PORT &= (uint8_t)~(1u << RTX_BIT))

static void rx_push(uint8_t b)
{
    uint8_t next = (rx_head + 1) & (RXQ - 1);
    if (next == rx_tail) {
        radar_rx_overflows++;
        return;
    }
    rxq[rx_head] = b;
    rx_head = next;
    radar_rx_idle_ms = 0;
}

void radar_init(void)
{
    PCKEN |= PCKEN_TIM1 | PCKEN_TIM2;
    TCKSRC = 0x33;              /* TIM1 and TIM2 on 2 x HIRC */
    TIM1CR1 = TIM_URS;
    TIM1PSCRH = 0;
    TIM1PSCRL = 0;
    TIM1ARRH = RADAR_BAUD_ARR >> 8;
    TIM1ARRL = RADAR_BAUD_ARR & 0xFF;
    TIM1SR1 = TIM_U;
    TIM1IER = TIM_U;
    TIM2CR1 = TIM_URS;
    TIM2PSCR = 0;
    TIM2ARRH = RADAR_BAUD_ARR >> 8;
    TIM2ARRL = RADAR_BAUD_ARR & 0xFF;
    TIM2SR1 = TIM_U;
    TIM2IER = TIM_U;
    TX_HIGH();
    /* EINT4 = PB4, falling edge */
    EPS1 = (EPS1 & 0xFC) | 0x01;
    ITYPE1 = (ITYPE1 & 0xFC) | 0x02;
    EPIF0 = 0x10;
    EPIE0 |= 0x10;
}

static void tx_next(void)       /* with the TIM1 interrupt masked or from it */
{
    if (tx_tail == tx_head) {
        TIM1CR1 &= (uint8_t)~TIM_CEN;
        tx_bit = 0;
        return;
    }
    tx_shift = txq[tx_tail];
    tx_tail = (tx_tail + 1) & (TXQ - 1);
    TX_LOW();                   /* start bit */
    tx_bit = 1;
}

void radar_isr(void)
{
    if (TIM1SR1 & TIM_U) {
        TIM1SR1 = TIM_U;
        if (tx_bit >= 1 && tx_bit <= 8) {
            if (tx_shift & 1) TX_HIGH(); else TX_LOW();
            tx_shift >>= 1;
            tx_bit++;
        } else if (tx_bit == 9) {
            TX_HIGH();          /* stop bit */
            tx_bit = 10;
        } else {
            tx_next();
        }
    }
    if ((EPIE0 & 0x10) && (EPIF0 & 0x10)) {
        /* start bit: first sample half a bit from now, then every bit */
        EPIE0 &= (uint8_t)~0x10;
        TIM2CNTRH = (RADAR_BAUD_ARR - HALF_BIT) >> 8;
        TIM2CNTRL = (RADAR_BAUD_ARR - HALF_BIT) & 0xFF;
        TIM2SR1 = TIM_U;
        TIM2CR1 |= TIM_CEN;
        rx_bit = 0;
    }
    if (TIM2SR1 & TIM_U) {
        uint8_t level = (RRX_PORT >> RRX_BIT) & 1;
        TIM2SR1 = TIM_U;
        if (rx_bit == 0) {
            if (level) goto done;   /* glitch, not a start bit */
            rx_bit = 1;
        } else if (rx_bit <= 8) {
            rx_shift = (uint8_t)(rx_shift >> 1) | (level ? 0x80 : 0);
            rx_bit++;
        } else {
            if (level) rx_push(rx_shift);
            else radar_frame_errors++;
            goto done;
        }
        return;
done:
        TIM2CR1 &= (uint8_t)~TIM_CEN;
        EPIF0 = 0x10;
        EPIE0 |= 0x10;
    }
}

void radar_tick_1ms(void)
{
    if (radar_rx_idle_ms != 255) radar_rx_idle_ms++;
}

uint8_t radar_rx_count(void) { return (rx_head - rx_tail) & (RXQ - 1); }

uint8_t radar_rx_get(void)
{
    uint8_t b = rxq[rx_tail];
    rx_tail = (rx_tail + 1) & (RXQ - 1);
    return b;
}

uint8_t radar_tx_free(void) { return (uint8_t)(TXQ - 1 - ((tx_head - tx_tail) & (TXQ - 1))); }

static uint8_t tx_put(uint8_t b)
{
    uint8_t next = (tx_head + 1) & (TXQ - 1);
    if (next == tx_tail) return 0;
    txq[tx_head] = b;
    tx_head = next;
    uint8_t gie = INTCON & GIE;
    INTCON &= (uint8_t)~GIE;
    if (tx_bit == 0) {
        tx_next();
        TIM1CNTRH = 0;
        TIM1CNTRL = 0;
        TIM1SR1 = TIM_U;
        TIM1CR1 |= TIM_CEN;
    }
    INTCON |= gie;
    return 1;
}

/* --- command filter ------------------------------------------------------ */
static const uint8_t header[4] = {0xFD, 0xFC, 0xFB, 0xFA};
static uint8_t held[8], nheld;
static uint8_t mode;            /* 0 scan, 1 pass rest of frame, 2 drop rest of frame */
static uint16_t remain;
static uint8_t dropped_cmd;

static void ack_failure(uint8_t cmd)
{
    /* FD FC FB FA | 04 00 | cmd|0x0100 | status 0001 (failure) | 04 03 02 01 */
    static const uint8_t pre[6] = {0xFD, 0xFC, 0xFB, 0xFA, 0x04, 0x00};
    static const uint8_t post[6] = {0x01, 0x00, 0x04, 0x03, 0x02, 0x01};
    uint8_t i, gie = INTCON & GIE;
    INTCON &= (uint8_t)~GIE;    /* rx_push also runs in the interrupt */
    for (i = 0; i < 6; i++) rx_push(pre[i]);
    rx_push(cmd);
    rx_push(0x01);
    for (i = 0; i < 6; i++) rx_push(post[i]);
    INTCON |= gie;
}

uint8_t radar_write(uint8_t b)
{
    uint8_t i;
    if (mode == 1) {
        if (--remain == 0) mode = 0;
        return tx_put(b);
    }
    if (mode == 2) {
        if (--remain == 0) {
            mode = 0;
            ack_failure(dropped_cmd);
        }
        return 1;
    }
    held[nheld++] = b;
    if (nheld <= 4 && b != header[nheld - 1]) {
        /* not a command frame: send what was held, but keep a new FD */
        uint8_t keep = (b == 0xFD) ? 1 : 0;
        for (i = 0; i < nheld - keep; i++)
            if (!tx_put(held[i])) { nheld = 0; return 0; }
        held[0] = 0xFD;
        nheld = keep;
        return 1;
    }
    if (nheld < 8) return 1;
    {
        uint16_t len = held[4] | ((uint16_t)held[5] << 8);   /* command word + value */
        uint16_t cmd = held[6] | ((uint16_t)held[7] << 8);
        remain = (len >= 2 ? len - 2 : 0) + 4;               /* rest of value + footer */
        nheld = 0;
        if (cmd == 0x00A1 || cmd == 0x00A2) {
            radar_blocked++;
            dropped_cmd = (uint8_t)cmd;
            mode = 2;
            return 1;
        }
        mode = 1;
        for (i = 0; i < 8; i++)
            if (!tx_put(held[i])) return 0;
        return 1;
    }
}
