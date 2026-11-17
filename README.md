# PS10 MCU firmware

Open firmware work for the MCU in the Tuya PS10 mmWave presence sensor (board
NAS-PS10W6-MOS-V5): FMD **FT61E0A5** (PIC16F1-compatible core) between the
BK7231N Wi-Fi module and an LD2410C radar. Installed and rolled back over the
Tuya serial link with [`tuya_mcu_dfu`](../esphome_tuya_mcu_dfu), through the
stock bootloader, so no programmer is needed.

This branch (`dump`): **`ps10_dump`**, which reads out the parts of the chip
an update image doesn't contain: the bootloader (0x000-0x5FF), the
configuration space and the data EEPROM. Written in C (XC8) since 0.2.0; the
original assembler version (0.1.0, tag `v0.1.0-dump`) produced the first dump.

| | |
|---|---|
| [docs/pinout.md](docs/pinout.md) | Pin functions estimated from the stock firmware: triac, LED, button, switch input, radar UART/OUT, LDR, Wi-Fi UART |
| [docs/bootloader.md](docs/bootloader.md) | The stock bootloader, from a dump: boot-time CRC check, updater, EEPROM use |
| [docs/ft61e0a5.md](docs/ft61e0a5.md) | The chip: encoding, memory, registers used, bootloader contract, recovery |
| [docs/references.md](docs/references.md) | Datasheet and other FMD documents and tools |
| [docs/radar-passthrough.md](docs/radar-passthrough.md) | Getting the LD2410C to ESPHome's `ld2410:` component |

## Before you flash: risk

The dump firmware replaces the stock application. If it didn't start, the stock
bootloader would never get its `0x0A`, and only an ICSP programmer (on PA2/PB6,
the triac and LED lines) would recover the MCU. What reduces that risk:

- Every register it touches is checked against the datasheet, and its UART
  setup is the stock firmware's, value for value.
- It's tested in an emulator that also runs the **stock** image correctly
  (`tools/stock_probe.py`): same UART, same `tuya:` replies, same `0x0A`
  behaviour. The emulator enforces the datasheet's EEPROM/PROM read timing.
- It implements the bootloader contract exactly: `0x0A` → EEPROM 0x00/0x01 =
  `FF`, `RESET`.

The assembler version (0.1.0) has run on a PS10 and dumped everything,
bootloader included (it isn't read-protected). The C version (0.2.0) passes
the same emulator test, but hasn't run on hardware yet.

## What the dump firmware does

- Answers `tuya:`: heartbeat, product info `{"p":"ps10dump","v":"0.2.0-dump","m":0}`,
  working mode, Wi-Fi state, status query (DP 200).
- Dump requests in DP 200 (raw `[space, addr_hi, addr_lo, count]`), replies in
  DP 201: `F` program flash (words), `C` configuration space (words, `CFGS`),
  `E` data EEPROM (bytes).
- `0x0A`: hands over to the bootloader, for the next update or rollback.
- Doesn't drive any pin except the Wi-Fi UART, writes nothing, interrupts off,
  watchdog as stock.

## Build

Needs Python 3, **MPLAB XC8** (v4.00 used here; the free licence is enough)
and Microchip's **PIC16F1xxxx device pack** (DFP 1.32.471). XC8 compiles for a
PIC16F18346, which has the same core as the FT61E0A5 (5-bit bank select,
16-level stack); `tools/build.py` keeps the code in 0x600-0x27FF and the RAM in
banks 0-12, then converts the opcodes to the FMD encoding. The chip's own
registers come from `src/ft61e0a5.h`, never from the PIC part's headers.

```
python tools/build.py              # build/<name>-<version>.bin + hashes + tuya_mcu_dfu block
python tools/test_dump.py          # run it in the emulator
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

## Flash, dump, roll back

1. Copy `build/ps10-mcu-dump-0.2.0-dump.bin` next to the device YAML and point
   `tuya_mcu_dfu` at it (the build prints the block):
   ```yaml
   update:
     - platform: tuya_mcu_dfu
       name: MCU firmware
       firmware:
         path: ps10-mcu-dump-0.2.0-dump.bin
         version: "0.2.0-dump"
         sha256: <from the build output>
   ```
   Add [`esphome/ps10-mcu-dump.yaml`](esphome/ps10-mcu-dump.yaml) as a package.
   Install, then run the MCU update.
2. Press **MCU dump all**, with the device logs open at INFO or lower. Save the
   log to a file (flash takes about a minute).
3. `python tools/dump2bin.py saved.log -o dump` → `flash.bin` (same format as
   the update images), `flash_pic.bin`, `bootloader.asm`, `config.bin`,
   `eeprom.bin`. The app area of `flash.bin` should match the dump image
   itself, which checks the read path.
4. Roll back to stock by pointing `tuya_mcu_dfu` at the official image and
   updating again:
   ```yaml
       firmware:
         url: https://images.tuyaeu.com/smart/firmware/upgrade/ay1503986080106Gppjy/178244149610c6c194500.bin
         version: "1.0.5"
         sha256: b22da68400c00d23a60747b6a6a8c4f9f69875059bd531789db32d6fcd878872
   ```
   The dump firmware leaves the stock settings in EEPROM alone.
   Some devices may expect or require a power cycle to work properly after an update.

## Layout

```
src/dump.c                 dump firmware (XC8)
src/tuya.c, tuya.h         Tuya MCU protocol framing
src/ft61e0a5.h             FT61E0A5 registers (from the datasheet)
tools/build.py             compile, convert to FMD encoding, lay out the 20480-byte image
tools/fmd.py               FMD <-> PIC encoding, image helpers
tools/emu.py               PIC16F1 emulator with the inferred FT61E0A5 peripherals
tools/test_dump.py         emulator test of the dump firmware
tools/stock_probe.py       runs the stock image, shows pin activity per command
tools/dump2bin.py          ESPHome log -> binary files
esphome/ps10-mcu-dump.yaml ESPHome package: dump buttons and logging
reference/ps10-mcu-1.0.5.bin  official 1.0.5 image (md5 9bd5f57f…)
```
