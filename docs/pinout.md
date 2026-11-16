# PS10 MCU pinout (estimate)

Board NAS-PS10W6-MOS-V5, MCU U3 = FMD FT61E0A5 (QFN20). Everything below is
**inferred from the stock 1.0.5 firmware** (static disassembly plus running it
in `tools/emu.py` with `tools/stock_probe.py`), not measured. Port names are
the firmware's (`PORTA`/`PORTB`/`PORTC` at 0x00C/0x00D/0x00E, `TRISx` at
0x08C-0x08E). Physical pin numbers need the datasheet's pin table; the two
known ones are from the ISP pinout.

**Verify with a meter before driving anything.** The dump firmware doesn't
configure or drive any of these, only the Wi-Fi UART.

| Function | Port | Dir | Confidence | Evidence |
|---|---|---|---|---|
| Triac drive (MOC3020 → BTB24) | **PA2** (pin 14, ISPCK) | out, high = on | high | Set/cleared when DP 110 (Output) changes; state saved to EEPROM. Also blinks at boot until the button is released. |
| Status LED | **PB6** (pin 4, ISPDAT) | out, high = on | high | Follows the output while DP 111 (Status LED) is on; DP 111 off turns it off. Blinks with PA2 at boot and in pairing. |
| Button | **PA3** | in, active low | high | Emulated: a press toggles the output (PA2, DP 110 report); a long hold sends Tuya `0x04` (reset Wi-Fi / pairing) instead. The hold time in emulation is ~25 s, assuming the tick is 1 ms. Boot blinks PA2/PB6 until PA3 reads high. |
| External switch input | **PC0** | in, active low | medium-high | Separate from the button. Emulated: a low pulse toggles the output. Consistent with the S-terminal input. The firmware treats it as a DC level, so any opto/RC front end filters the mains. |
| Radar OUT (LD2410C presence) | **PB7** | in, high = target | medium | 32-bit "time since low" counters reset while high; used for hold/output timing. |
| Radar UART TX (MCU → LD2410C RX) | **PB3** | out, idle high | high | Software UART: timer interrupt shifts out a byte LSB first (start bit `bcf PB3`, stop bit `bsf PB3`). Carries the `FD FC FB FA` config commands. |
| Radar UART RX (LD2410C TX → MCU) | **PB4** | in | high | Interrupt-on-change (PIR4 bit 4) catches the start bit, then a timer samples 8 bits into the frame buffer parsed for `F4 F3 F2 F1` / `FD FC FB FA`. |
| Wi-Fi UART TX (MCU → BK7231N) | **PA6** | out | medium-high | Hardware UART (bank 9 registers); the UART init clears TRISA.6 and sets TRISA.7. In emulation this UART answers ESPHome's `tuya:` exactly as on the device. |
| Wi-Fi UART RX (BK7231N → MCU) | **PA7** | in | medium-high | As above. |
| LDR (light sensor) | ADC channel 2, likely **PA4** | analog in | low (pin) / high (channel) | ADC read with CHS = 2, 5-sample average, compared against DP 108. PA4 is the only pin set as input that the firmware never reads digitally. |
| Zero crossing | none | | high | No pin is used for timing the triac: PA2 is held high while on. The MOC3020 is the non-zero-crossing type, so none is needed. |

Other port bits are outputs driven low at init: PA0, PA1, PA5, PB0-PB2, PB5,
PC1 and up (not connected, or something enabled by default; check the board).

## Radar UART speed

The radar link is a timer-driven software UART, so it can't run at the LD2410C's
256000 baud default; the stock firmware never sends the LD2410C "set baud"
command, so the module must be factory-set to the slower rate. The bit timers
are loaded with 0x0D10 (TX) and 0x0D20 (RX), about 3340 counts: 9600 baud with
a 32 MHz timer clock. The only other plausible reading (16 MHz, 4800 baud) isn't
a rate the LD2410C supports. **Expect 9600 8N1**; if your mock-LD2410 capture
already ran at a known rate, that settles it.

## Stock data EEPROM layout

| Address | Use |
|---|---|
| 0x00, 0x01 | Application-valid flag for the bootloader. The app's `0x0A` handler writes `FF FF` and resets; the bootloader then stays resident and takes the update. |
| 0x04-0x0F | Settings (DP 101 at 0x0E, DP 111 at 0x09, output state, ...). |
| 0x7F | `AA` once the settings have been initialised. |

## Stock datapoints

1 presence (enum), 101 output mode, 102 motion state, 103 hold time, 104 detection
distance, 105 motion sensitivity, 106 micro-motion sensitivity, 107 current
distance, 108 light threshold, 109 output timer, 110 output, 111 status LED.
