# PS10 MCU firmware

Open firmware work for the MCU in the Tuya PS10 mmWave presence sensor (board
NAS-PS10W6-MOS-V5): FMD **FT61E0A5** (PIC16F1-compatible core) between the
BK7231N Wi-Fi module and an LD2410C radar. Installed and rolled back over the
Tuya serial link with [`tuya_mcu_dfu`](../esphome_tuya_mcu_dfu), through the
stock bootloader, so no programmer is needed.

This is the **open firmware**: Tuya MCU protocol to ESPHome's `tuya:`,
the triac, LED, button, switch input, radar OUT and LDR as datapoints, and the
LD2410C's serial link relayed in DP 202 so ESPHome's `ld2410:` can configure and
read the radar. Written in C (XC8).

| Branch / tag | |
|---|---|
| `main` | open firmware |
| `dump` | `ps10_dump` in C: reads out the bootloader, configuration space and EEPROM |
| `v0.1.0-dump` | the assembler dump firmware that produced the first dump |
| `release/factory_1.0.5` | the stock 1.0.5 application as assembler source, builds byte-identical to the official image |

| | |
|---|---|
| [docs/pinout.md](docs/pinout.md) | Pin functions estimated from the stock firmware: triac, LED, button, switch input, radar UART/OUT, LDR, Wi-Fi UART |
| [docs/bootloader.md](docs/bootloader.md) | The stock bootloader, from a dump: boot-time CRC check, updater, EEPROM use |
| [docs/ft61e0a5.md](docs/ft61e0a5.md) | The chip: encoding, memory, registers used, bootloader contract, recovery |
| [docs/references.md](docs/references.md) | Datasheet and other FMD documents and tools |
| [docs/radar-passthrough.md](docs/radar-passthrough.md) | Getting the LD2410C to ESPHome's `ld2410:` component |

## Status and risk

**Not yet run on hardware.** It passes the emulator test (`tools/test_open.py`),
but unlike the dump firmware it **drives pins**: the triac (PA2), LED (PB6) and
radar TX (PB3), configured exactly as the stock firmware configures them. Those
assignments come from the stock firmware, not from measurement
([docs/pinout.md](docs/pinout.md)): check them on a board before flashing.

Ways back if something's wrong:
- `0x0A` (any `tuya_mcu_dfu` update) hands over to the bootloader, as stock.
- **Hold the button while powering up for 3 s** (the LED blinks): the firmware
  clears the bootloader's CRC and resets, so the bootloader stays resident for
  an update. Doesn't help if the firmware never starts.
- Otherwise ICSP on PA2/PB6.

## Datapoints

| DP | Type | | |
|---|---|---|---|
| 1 | bool | ro | presence (radar OUT, PB7) |
| 101 | bool | rw | output (triac) |
| 102 | enum | rw | LED: 0 off, 1 follows output, 2 on, 3 follows presence |
| 103 | bool | rw | auto: output follows presence |
| 104 | value | ro | light (LDR, raw 12-bit ADC; reported every 5 s on a change of 32+) |
| 105 | value | rw | auto only switches on below this light level; 0 = always |
| 106 | bool | ro | switch input (PC0) active |
| 107 | enum | ro | button event: 0 short press, 1 long press (3 s) |
| 108 | enum | rw | switch input: 0 report only, 1 toggle on press, 2 toggle on any change |
| 202 | raw | rw | radar serial relay ([docs/radar-passthrough.md](docs/radar-passthrough.md)) |

A short button press toggles the output, without ESPHome. Settings (102, 103,
105, 108) are kept in data EEPROM 0x20-0x25; the stock firmware's (0x02-0x0F,
0x7F) are left alone, so a rollback to 1.0.5 finds them. The output starts off
after a power cut. Product info: `{"p":"ps10open","v":"0.2.0","m":0}`.

[`esphome/ps10-mcu.yaml`](esphome/ps10-mcu.yaml) is an ESPHome package with
entities for all of these. DP 202 needs the `tuya_uart_tunnel` component, which
isn't written yet; until then the radar keeps its current configuration.

## Build

Needs Python 3, **MPLAB XC8** (v4.00 used here; the free licence is enough)
and Microchip's **PIC16F1xxxx device pack** (DFP 1.32.471). XC8 compiles for a
PIC16F18346, which has the same core as the FT61E0A5 (5-bit bank select,
16-level stack); `tools/build.py` keeps the code in 0x600-0x27FF and the RAM in
banks 0-12, then converts the opcodes to the FMD encoding. The chip's own
registers come from `src/ft61e0a5.h`, never from the PIC part's headers.

```
python tools/build.py              # build/<name>-<version>.bin + hashes + tuya_mcu_dfu block
python tools/test_open.py          # run it in the emulator (about 2 minutes)
```

**Toolchain:**
- **XC8:** install from microchip.com (Windows or Linux installer). `build.py`
  finds `xc8-cc` on PATH or in the default install folder
  (`C:\Program Files\Microchip\xc8\v4.00`, `/opt/microchip/xc8/v4.00`), or set
  `XC8_CC` to it.
- **Device pack:** download `Microchip.PIC16F1xxxx_DFP.1.32.471.atpack` from
  packs.download.microchip.com, unzip it (it's a zip), and set `XC8_DFP` to its
  `xc8` folder. MPLAB X's pack manager location is found automatically.

In VS Code: **Terminal → Run Build Task** (build), or **Run Task** for the
emulator tests.

**GitHub Actions** downloads both (pinned by version and SHA-256), caches the
installed toolchain (`actions/cache`, so later runs restore it in seconds),
builds, runs the emulator tests, and on a `v*` tag publishes a release with the
image and a `tuya_mcu_dfu` manifest.

PlatformIO isn't used: it has no toolchain for these parts, and a custom
platform would only wrap the same calls.

## Install and roll back

1. Copy `build/ps10-mcu-0.2.0.bin` next to the device YAML and point
   `tuya_mcu_dfu` at it (the build prints the block):
   ```yaml
   update:
     - platform: tuya_mcu_dfu
       name: MCU firmware
       firmware:
         path: ps10-mcu-0.2.0.bin
         version: "0.2.0"
         sha256: <from the build output>
   ```
   Add [`esphome/ps10-mcu.yaml`](esphome/ps10-mcu.yaml) as a package, install,
   then run the MCU update.
2. Roll back to stock by pointing `tuya_mcu_dfu` at the official image and
   updating again (Home Assistant hides Install for an older version; the
   `update.install` action works):
   ```yaml
       firmware:
         url: https://images.tuyaeu.com/smart/firmware/upgrade/ay1503986080106Gppjy/178244149610c6c194500.bin
         version: "1.0.5"
         sha256: b22da68400c00d23a60747b6a6a8c4f9f69875059bd531789db32d6fcd878872
   ```
   Some devices may expect or require a power cycle to work properly after an update.

## Layout

```
src/main.c                 open firmware: Tuya handling, datapoints, inputs, settings
src/radar.c, radar.h       software UART to the LD2410C (TIM1/TIM2/EINT4) and the command filter
src/board.h                pin assignments and port set-up
src/tuya.c, tuya.h         Tuya MCU protocol framing
src/ft61e0a5.h             FT61E0A5 registers (from the datasheet)
tools/build.py             compile, convert to FMD encoding, lay out the 20480-byte image
tools/fmd.py               FMD <-> PIC encoding, image helpers
tools/emu.py               PIC16F1 emulator with the inferred FT61E0A5 peripherals
tools/mcu.py               FT61E0A5 peripherals for the emulator: pins, timers, EINT4, ADC
tools/test_open.py         emulator test of the open firmware
tools/stock_probe.py       runs the stock image, shows pin activity per command
esphome/ps10-mcu.yaml      ESPHome package: entities for the datapoints
reference/ps10-mcu-1.0.5.bin  official 1.0.5 image (md5 9bd5f57f…)
```
