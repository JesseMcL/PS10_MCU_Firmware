# PS10 MCU pinout (estimate)

Board NAS-PS10W6-MOS-V5, MCU U3 = FMD FT61E0A5-NRT (QFN20). Functions are
**inferred from the stock 1.0.5 firmware** (disassembly, plus running it in
`tools/emu.py` with `tools/stock_probe.py`) and checked against the
datasheet's pin functions, not measured. Pin numbers are the datasheet's QFN20
pinout (pin 1 at the dot, counter-clockwise; exposed pad = GND).

**Verify with a meter before driving anything.** The dump firmware doesn't
configure or drive any of these, only the Wi-Fi UART.

| QFN20 pin | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 |
|---|---|---|---|---|---|---|---|---|---|---|
| | PA7 | PB7 | GND | PB6 | VDD | PB5 | PB0 | PB1 | PB2 | PB4 |
| **pin** | **11** | **12** | **13** | **14** | **15** | **16** | **17** | **18** | **19** | **20** |
| | PB3 | PA0 | PA1 | PA2 | PA3 | PA4 | PC1 | PC0 | PA6 | PA5 |

| Function | Port | Dir | Confidence | Evidence |
|---|---|---|---|---|
| Triac drive (MOC3020 → BTB24) | **PA2** (pin 14, ISPCLK) | out, high = on | high | Set/cleared when DP 110 (Output) changes; state saved to EEPROM. Also blinks at boot until the button is released. |
| Status LED | **PB6** (pin 4, ISPDAT) | out, high = on | high | Follows the output while DP 111 (Status LED) is on; DP 111 off turns it off. Blinks with PA2 at boot and in pairing. |
| Button | **PA3** (pin 15) | in, active low | high | Emulated: a press toggles the output (PA2, DP 110 report); a long hold (somewhere between 2.4 and 6 s, at the 0.2 ms TIM4 tick) sends Tuya `0x04` (reset Wi-Fi / pairing) instead. Boot blinks PA2/PB6 until PA3 reads high. |
| External switch input | **PC0** (pin 18) | in, active low | medium-high | Separate from the button. Emulated: a low pulse toggles the output. Consistent with the S-terminal input. The firmware treats it as a DC level, so any opto/RC front end filters the mains. PC0 can also be MCLR, but that's off by default (`MCLRE`). |
| Radar OUT (LD2410C presence) | **PB7** (pin 2) | in, high = target | medium | 32-bit "time since low" counters reset while high; used for hold/output timing. |
| Radar UART TX (MCU → LD2410C RX) | **PB3** (pin 11) | out, idle high | high | Software UART: TIM1 interrupt shifts out a byte LSB first (start bit `bcf PB3`, stop bit `bsf PB3`). Carries the `FD FC FB FA` config commands. |
| Radar UART RX (LD2410C TX → MCU) | **PB4** (pin 10) | in | high | External interrupt EINT4 (`EPS1` selects PB4) catches the start bit, then TIM2 samples 8 bits into the frame buffer parsed for `F4 F3 F2 F1` / `FD FC FB FA`. |
| Wi-Fi UART TX (MCU → BK7231N) | **PA6** (pin 19) | out, open drain | high | USART1 at 9600 8N1; `AFP0` left at reset = PA6, `UR1OD` set. In emulation this UART answers ESPHome's `tuya:` exactly as on the device. |
| Wi-Fi UART RX (BK7231N → MCU) | **PA7** (pin 1) | in | high | USART1, `AFP1` left at reset = PA7. |
| LDR (light sensor) | **PA4** (pin 16), AN2 | analog in | high | ADC CHS = 2 = AN2 = PA4 (`ANSELA` bit 2), 5-sample average, compared against DP 108. |
| Zero crossing | none | | high | No pin is used for timing the triac: PA2 is held high while on. The MOC3020 is the non-zero-crossing type, so none is needed. |

Other pins are outputs driven low at init: PA0, PA1, PA5, PB0-PB2, PB5, PC1
(pins 12, 13, 20, 7-9, 6, 17). Not connected, or something left off; check the
board. Stock also sets weak pull-ups on PB3/PB4 and maximum drive strength on
every pin.

## Radar UART speed

**9600 8N1.** The radar link is a timer-driven software UART. TIM1 (TX) and
TIM2 (RX) are clocked from 2 × HIRC = 32 MHz (`TCKSRC` = 0x33) with auto-reload
0x0D10 and 0x0D20: 32 MHz / 3345 = 9567 baud and 32 MHz / 3361 = 9521 baud,
both within 1 % of 9600. The stock firmware never sends the LD2410C "set baud"
command, so the module must ship set to 9600 (its default is 256000).

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

## What the stock firmware configures on the radar

Every LD2410C command the 1.0.5 firmware can send:

| Command | When |
|---|---|
| `0x00FF` enable config, `0x0060` max gates / no-one duration, `0x0064` sensitivity × 9 gates, `0x00FE` end config | each configuration pass (boot, settings changes) |
| `0x00A9` Bluetooth password **`123465`** | at the end of the next configuration pass after it's armed (below) |
| `0x00A2` factory reset, `0x00A3` restart | never: they're in the same routine as end-config, which is only ever called for end-config |
| `0x00A1` set baud, `0x00A4` Bluetooth on/off | not present |

The password is armed (RAM flag 0x0A6, set by the routine at 0x16FE that
also restarts the radar configuration) in two cases:

- **The Wi-Fi module reports status `0x00` or `0x01`** (`0x03` command: smart-config
  or AP pairing). Confirmed in emulation. So any unit that has been through
  Tuya pairing, or a factory test that puts the module in pairing mode, gets the
  password. ESPHome's `tuya:` only ever reports `0x02`-`0x04`, so it never arms it.
- **The radar acknowledges a factory reset** (`0x01A2`), which this firmware never
  sends: handling for a reset done some other way (e.g. over Bluetooth).

The radar's baud is never set: the LD2410C has to come from the factory at
9600. Since the firmware re-applies the password after a radar factory reset
but has no way to change the baud, the radar's own factory default is
probably 9600 too (an OEM variant). That's worth confirming before relying on
a factory reset to recover a radar.
