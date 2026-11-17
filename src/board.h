/* PS10 board (NAS-PS10W6-MOS-V5) pin map, from the stock 1.0.5 firmware and
 * the datasheet (docs/pinout.md). QFN20 pin numbers in brackets. */
#ifndef BOARD_H
#define BOARD_H

/* outputs */
#define OUT_PORT   LATA     /* triac drive (MOC3020 -> BTB24), high = on   [14] PA2 */
#define OUT_BIT    2
#define LED_PORT   LATB     /* status LED, high = on                        [4]  PB6 */
#define LED_BIT    6
#define RTX_PORT   LATB     /* radar soft UART, MCU -> LD2410C RX, idle high [11] PB3 */
#define RTX_BIT    3

/* inputs */
#define BTN_PORT   PORTA    /* button, low = pressed                        [15] PA3 */
#define BTN_BIT    3
#define SW_PORT    PORTC    /* external switch input, low = active          [18] PC0 */
#define SW_BIT     0
#define RDR_PORT   PORTB    /* LD2410C OUT, high = target                    [2]  PB7 */
#define RDR_BIT    7
#define RRX_PORT   PORTB    /* radar soft UART, LD2410C TX -> MCU (EINT4)   [10] PB4 */
#define RRX_BIT    4
#define LDR_CHANNEL 2       /* LDR on AN2                                   [16] PA4 */

/* as stock: inputs PA3 PA4 PA7 / PB4 PB7 / PC0, everything else output */
#define TRISA_INIT 0x98
#define TRISB_INIT 0x90
#define TRISC_INIT 0x01
#define LATB_INIT  0x08     /* PB3 (radar TX) idle high */
#define WPUB_INIT  0x18     /* pull-ups on the radar UART lines, as stock */
#define ANSELA_INIT 0x04    /* AN2 analog */

#endif
