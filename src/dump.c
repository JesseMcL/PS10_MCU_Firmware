/* PS10 MCU dump firmware (C version of the original assembler one).
 *
 * Runs behind the stock bootloader (linked at 0x600) and speaks just enough
 * of the Tuya MCU protocol for ESPHome's tuya: and tuya_mcu_dfu:
 *
 *   0x00 heartbeat     -> [00] once after reset, then [01]
 *   0x01 product query -> {"p":"ps10dump","v":"<VERSION>","m":0}
 *   0x02, 0x03         -> empty acknowledgement
 *   0x08 status query  -> DP 200 raw [00 00 00 00]
 *   0x06 DP 200 raw    -> dump request; reply 0x07 DP 201 raw
 *   0x06 any other DP  -> echoed back as 0x07
 *   0x0A upgrade start -> data EEPROM 0x00/0x01 = FF (the CRC the bootloader
 *                         checks no longer matches), then RESET into it
 *
 * Dump request, DP 200: [space, addr_hi, addr_lo, count]
 *   'F' program flash (words, 1..32, stored FMD encoding, little endian)
 *   'C' configuration space, EECON1.CFGS = 1 (words, 1..32)
 *   'E' data EEPROM (bytes, 1..64)
 * Reply, DP 201: [space, addr_hi, addr_lo, count, data...]; count 0 = rejected.
 *
 * No side effects: memory is only read, no pin besides the Tuya UART is
 * configured, interrupts stay off. The watchdog is set up as the stock
 * firmware does (~4 s).
 */
#include "ft61e0a5.h"
#include "tuya.h"

#ifndef VERSION
#define VERSION "0.2.0-dump"
#endif

#define DP_REQUEST 200
#define DP_DATA    201

BOOTLOADER_RAM;

static const char product[] = "{\"p\":\"ps10dump\",\"v\":\"" VERSION "\",\"m\":0}";

void uart_tx(uint8_t b)
{
    while (!(UR1LSR & UR1_TXEF)) clrwdt();
    UR1DATAL = b;
}

static uint16_t nvm_read(uint8_t space, uint16_t addr)
{
    EEADRH = (uint8_t)(addr >> 8);
    EEADRL = (uint8_t)addr;
    EECON1 = space == 'E' ? 0 : space == 'C' ? (EE_EEPGD | EE_CFGS) : EE_EEPGD;
    EECON1 |= EE_RD;
    nop();      /* PROM/UCFG data after 2 instruction cycles, */
    nop();
    nop();      /* data EEPROM after 4 (datasheet 10.3.4) */
    nop();
    uint16_t v = EEDATL;
    if (space != 'E') v |= (uint16_t)EEDATH << 8;
    EECON1 = 0;
    return v;
}

static void ee_write_ff(uint8_t addr)
{
    EEADRL = addr;
    EEADRH = 0;
    EEDATL = 0xFF;
    EECON1 = EE_WREN;           /* data EEPROM, write enabled */
    EECON2 = 0x55;
    EECON2 = 0xAA;
    EECON1 |= EE_WR;
    nop(); nop(); nop(); nop();
    while (EECON1 & EE_WR) clrwdt();
    EECON1 = 0;
}

static void dump(void)
{
    uint8_t space = tuya_rx[4];
    uint16_t addr = ((uint16_t)tuya_rx[5] << 8) | tuya_rx[6];
    uint8_t n = tuya_rx[7];
    uint8_t width = space == 'E' ? 1 : 2;
    uint8_t max = space == 'E' ? 64 : 32;
    if ((space != 'F' && space != 'C' && space != 'E') || n == 0 || n > max)
        n = 0;
    uint8_t bytes = n * width;
    tuya_report_raw_begin(DP_DATA, 4 + bytes);
    tuya_byte(space);
    tuya_byte(tuya_rx[5]);
    tuya_byte(tuya_rx[6]);
    tuya_byte(n);
    while (n--) {
        uint16_t v = nvm_read(space, addr++);
        tuya_byte((uint8_t)v);
        if (width == 2) tuya_byte((uint8_t)(v >> 8));
    }
    tuya_end();
}

static void handle(uint8_t cmd, uint8_t len)
{
    static uint8_t heartbeat_seen;
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
        tuya_report_raw_begin(DP_REQUEST, 4);
        tuya_bytes((const uint8_t *)"\0\0\0\0", 4);
        tuya_end();
        break;
    case TUYA_DP_DELIVER:
        if (len == 8 && tuya_rx[0] == DP_REQUEST && tuya_rx[1] == DP_RAW && tuya_rx[2] == 0 && tuya_rx[3] == 4) {
            dump();
        } else {
            tuya_begin(TUYA_DP_REPORT, len);
            tuya_bytes(tuya_rx, len);
            tuya_end();
        }
        break;
    case TUYA_OTA_START:
        ee_write_ff(0);
        ee_write_ff(1);
        reset();
        break;
    }
}

void main(void)
{
    INTCON = 0;
    clrwdt();
    OSCCON = 0x71;              /* 16 MHz HIRC */
    MISC0 = 0;
    WDTCON = 0x55;              /* ~4 s */
    clrwdt();
    PCKEN |= PCKEN_UART1;
    TRISA |= 0x80;              /* PA7 = RX, PA6 = TX: as stock and the bootloader */
    TRISA &= (uint8_t)~0x40;
    UR1IER = 0x23;              /* as stock (interrupts stay off: GIE = 0) */
    UR1LCR = 0x01;
    UR1MCR = 0x18;              /* TXEN, RXEN */
    UR1DLL = 0x68;              /* 16 MHz / 16 / 104 = 9615 baud */
    UR1DLH = 0;
    UR1TC = 0x01;
    ODCON0 |= 0x01;             /* TX open drain, as stock */

    uint16_t idle = 0;
    for (;;) {
        clrwdt();
        if (UR1LSR & UR1_RXNEF) {
            uint8_t len;
            uint8_t cmd = tuya_feed(UR1DATAL, &len);
            idle = 0;
            if (cmd != 0xFF) handle(cmd, len);
        } else if (++idle == 0) {
            tuya_resync();      /* a long gap inside a frame */
        }
    }
}
