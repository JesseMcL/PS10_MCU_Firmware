/* Tuya MCU serial protocol, MCU side: 55 AA ver cmd len_hi len_lo data... sum */
#ifndef TUYA_H
#define TUYA_H

#include <stdint.h>

#define TUYA_RX_MAX 136 /* longest payload kept (a 128-byte DP 202 chunk + its header); longer frames are dropped */

#define TUYA_HEARTBEAT   0x00
#define TUYA_PRODUCT     0x01
#define TUYA_CONF        0x02
#define TUYA_WIFI_STATE  0x03
#define TUYA_DP_DELIVER  0x06
#define TUYA_DP_REPORT   0x07
#define TUYA_DP_QUERY    0x08
#define TUYA_OTA_START   0x0A
#define TUYA_OTA_DATA    0x0B

#define DP_RAW   0x00
#define DP_BOOL  0x01
#define DP_VALUE 0x02
#define DP_ENUM  0x04

extern uint8_t tuya_rx[TUYA_RX_MAX];

/* Feed one received byte; returns the command of a complete, valid frame
 * (its payload in tuya_rx[0..*len-1]) or 0xFF. */
uint8_t tuya_feed(uint8_t b, uint8_t *len);
/* Drop a partial frame (call after a gap in the byte stream). */
void tuya_resync(void);
/* Parser state (0 = waiting for 55) and counters, for diagnostics: frames
 * accepted, dropped for a bad checksum, dropped as too long, partial frames
 * dropped by tuya_resync(). */
uint8_t tuya_state(void);
extern uint16_t tuya_frames, tuya_bad_sum, tuya_too_long, tuya_resyncs;

/* Sending: tuya_begin(cmd, payload length), the bytes, tuya_end(). */
void tuya_begin(uint8_t cmd, uint16_t len);
void tuya_byte(uint8_t b);
void tuya_bytes(const uint8_t *p, uint8_t n);
void tuya_end(void);

/* Datapoint report helpers (each sends one 0x07 frame). */
void tuya_report_bool(uint8_t dp, uint8_t v);
void tuya_report_enum(uint8_t dp, uint8_t v);
void tuya_report_value(uint8_t dp, uint32_t v);
/* raw: header only; follow with n bytes and tuya_end() */
void tuya_report_raw_begin(uint8_t dp, uint8_t n);

/* Provided by the application: send one byte on the Tuya UART. */
void uart_tx(uint8_t b);

#endif
