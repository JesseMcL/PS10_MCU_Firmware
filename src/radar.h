/* LD2410C link: software UART (9600 8N1) on PB3/PB4 and the relay to ESPHome. */
#ifndef RADAR_H
#define RADAR_H

#include <stdint.h>

#define RADAR_BAUD_ARR 3332   /* 32 MHz / 3333 = 9601 baud */

void radar_init(void);

/* called from the interrupt handler */
void radar_isr(void);

/* bytes received from the radar */
uint8_t radar_rx_count(void);
uint8_t radar_rx_get(void);
/* ms since the last byte from the radar (saturates at 255) */
extern volatile uint8_t radar_rx_idle_ms;
void radar_tick_1ms(void);

/* bytes from ESPHome for the radar: filtered (no baud change / factory reset),
 * then queued. Returns 0 if the queue is full. */
uint8_t radar_write(uint8_t b);
/* free space in that queue */
uint8_t radar_tx_free(void);
/* moves queued bytes to the transmitter, one command at a time; call often */
void radar_pump(void);

/* counters, for diagnostics */
extern uint8_t radar_rx_overflows, radar_frame_errors, radar_blocked;

#endif
