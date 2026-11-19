# PS10 MCU firmware

Open firmware work for the MCU in the Tuya PS10 mmWave presence sensor (board
NAS-PS10W6-MOS-V5): FMD **FT61E0A5** (PIC16F1-compatible core) between the
BK7231N Wi-Fi module and an LD2410C radar. Installed and rolled back over the
Tuya serial link with [`tuya_mcu_dfu`](../esphome_tuya_mcu_dfu), through the
stock bootloader, so no programmer is needed.

This is the **open firmware**, in C (XC8). It only does I/O: it sets the triac
and LED when told, reports the button, switch input, radar OUT pin and LDR as
they are, and relays the LD2410C's serial link in DP 202 so ESPHome's `ld2410:`
reads and configures the radar itself. Every behaviour (what the button does,
what the LED shows, when the output switches) lives in ESPHome, where it's easy
to inspect and change.

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

Numbers are the stock firmware's where the function is the same.

| DP | Type | | |
|---|---|---|---|
| 1 | enum | ro | radar OUT pin (PB7): 0 none, 1 presence |
| 110 | bool | rw | output (triac, PA2), reported as read back from the pin |
| 111 | bool | rw | status LED (PB6), reported as read back from the pin. Stock: "LED follows the output"; here the LED itself |
| 112 | value | ro | light: LDR (PA4/AN2), raw 12-bit ADC, sampled every second, sent when it changes |
| 113 | bool | ro | switch input (PC0) active (low), 30 ms debounce |
| 114 | bool | ro | button (PA3) pressed, 30 ms debounce |
| 202 | raw | rw | radar serial relay, in chunks of any size ([docs/radar-passthrough.md](docs/radar-passthrough.md)) |

Values are raw: no scaling, averaging or thresholds. The debounce on the two
contacts is the only filtering. Inputs are reported when they change and on a
status query (`0x08`). The output and LED start off after a power cut. Nothing
is written to the data EEPROM except the bootloader hand-over, so the stock
settings (0x02-0x0F, 0x7F) are still there for a rollback to 1.0.5. Product
info: `{"p":"ps10open","v":"0.2.8","m":0}`.

### ESPHome

[`esphome/ps10-mcu.yaml`](esphome/ps10-mcu.yaml) is a package with entities
for the I/O, the default behaviour (button click and switch input toggle the
output, LED follows the output; an Output mode select makes the output follow
presence), `ld2410:` on a
[virtual UART](https://github.com/JesseMcL/esphome_virtual_uart) carried by
DP 202, and Home Assistant actions to set the radar's gate thresholds, range and
timeout, Bluetooth password, and to calibrate it.

Radar tuning lives on the device's own web page, not in Home Assistant:

- **Radar engineering mode** (switch) streams the per-gate energies into the
  ESPHome log, tag `ps10_gates`. With
  [`esphome/ps10-gates.js`](esphome/ps10-gates.js) next to the device's YAML
  (`web_server: js_include`), the page draws them as a live chart: a moving
  and a still bar per gate, the peak since you last reset it, and each gate's
  threshold. A gate detects when its bar crosses its line.
- **Radar calibrate** (button, or the `radar_calibrate` action with a start
  delay, duration and margin) turns engineering mode on, waits for you to
  leave the room (10 s from the button), records each gate's highest energy
  for 30 s, then sets every threshold to that peak + 10 and reads them back.
- **Moving range** and **Still range** (sliders, 150–600 cm in 75 cm gates)
  set the farthest gate that counts for each kind of target; the chart fades
  the gates beyond them.
- LD2410 frames have no checksum, so the package passes ld2410 only whole
  frames whose length field matches, and logs a warning for anything it
  drops.
- The gate energies and thresholds are internal: none of them reach Home
  Assistant. The switch and button are config entities, disabled there by
  default.

## Build

Needs Python 3, **MPLAB XC8** (v4.00 used here; the free licence is enough)
and Microchip's **PIC16F1xxxx device pack** (DFP 1.32.471). XC8 compiles for a
PIC16F18346, which has the same core as the FT61E0A5 (5-bit bank select,
16-level stack); `tools/build.py` keeps the code in 0x600-0x27FF and the RAM in
banks 0-12, then converts the opcodes to the FMD encoding. The chip's own
registers come from `src/ft61e0a5.h`, never from the PIC part's headers.

```
python tools/build.py              # build/<name>-<version>.bin + hashes + tuya_mcu_dfu block
python tools/test_open.py          # run it in the emulator (a few minutes);
                                   # PS10_TEST_ALL=1 adds the slow, low-value checks (CI runs them);
                                   # PS10_TIM1_DIR0=up runs TIM1 counting up
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

1. Copy `build/ps10-mcu-0.2.8.bin` next to the device YAML and point
   `tuya_mcu_dfu` at it (the build prints the block):
   ```yaml
   update:
     - platform: tuya_mcu_dfu
       name: MCU firmware
       firmware:
         path: ps10-mcu-0.2.8.bin
         version: "0.2.8"
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
src/main.c                 open firmware: Tuya handling, datapoints, inputs
src/radar.c, radar.h       software UART to the LD2410C (TIM1/TIM2/EINT4), command filter and pacing
src/board.h                pin assignments and port set-up
src/tuya.c, tuya.h         Tuya MCU protocol framing
src/ft61e0a5.h             FT61E0A5 registers (from the datasheet)
tools/build.py             compile, convert to FMD encoding, lay out the 20480-byte image
tools/fmd.py               FMD <-> PIC encoding, image helpers
tools/emu.py               PIC16F1 emulator with the inferred FT61E0A5 peripherals
tools/mcu.py               FT61E0A5 peripherals for the emulator: pins, timers, EINT4, ADC
tools/test_open.py         emulator test of the open firmware
tools/stock_probe.py       runs the stock image, shows pin activity per command
esphome/ps10-mcu.yaml      ESPHome package: I/O entities, behaviour, ld2410 over DP 202, radar actions, calibration
esphome/ps10-gates.js      web page chart of the radar's gate energies and thresholds (web_server js_include)
reference/ps10-mcu-1.0.5.bin  official 1.0.5 image (md5 9bd5f57f…)
```
