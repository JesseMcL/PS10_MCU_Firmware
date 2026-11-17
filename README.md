# PS10 MCU firmware

Open firmware work for the MCU in the Tuya PS10 mmWave presence sensor (board
NAS-PS10W6-MOS-V5): FMD **FT61E0A5** (PIC16F1-compatible core) between the
BK7231N Wi-Fi module and an LD2410C radar. Installed and rolled back over the
Tuya serial link with [`tuya_mcu_dfu`](../esphome_tuya_mcu_dfu), through the
stock bootloader, so no programmer is needed.

First firmware: **`ps10_dump`**, which reads out the parts of the chip an
update image doesn't contain: the bootloader (0x000-0x5FF), the configuration
space and the data EEPROM.

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

What can't be tested without hardware: real timing, and anything the
bootloader checks that the stock image happens to satisfy. If the bootloader's
1K sector is read-protected (`FSECPB0`), its words read back as repeats of the
last value instead of the code; the rest of the dump still works.

## What the dump firmware does

- Answers `tuya:`: heartbeat, product info `{"p":"ps10dump","v":"0.1.0-dump","m":0}`,
  working mode, Wi-Fi state, status query (DP 200).
- Dump requests in DP 200 (raw `[space, addr_hi, addr_lo, count]`), replies in
  DP 201: `F` program flash (words), `C` configuration space (words, `CFGS`),
  `E` data EEPROM (bytes).
- `0x0A`: hands over to the bootloader, for the next update or rollback.
- Doesn't drive any pin except the Wi-Fi UART, writes nothing, interrupts off,
  watchdog as stock.

## Build

Needs Python 3 and [gputils](https://gputils.sourceforge.io) (`gpasm`) on PATH.

```
python tools/build.py              # build/ps10-mcu-dump-0.1.0-dump.bin + hashes
python tools/test_dump.py          # run it in the emulator
```

In VS Code: **Terminal → Run Build Task** (build), or **Run Task** for the
tests and the stock-firmware probe.

PlatformIO isn't used: it has no toolchain for 8-bit PIC/FMD parts, and a
custom platform would only wrap the same `gpasm` call.

## Flash, dump, roll back

1. Copy `build/ps10-mcu-dump-0.1.0-dump.bin` next to the device YAML and point
   `tuya_mcu_dfu` at it (the build prints the block):
   ```yaml
   update:
     - platform: tuya_mcu_dfu
       name: MCU firmware
       firmware:
         path: ps10-mcu-dump-0.1.0-dump.bin
         version: "0.1.0-dump"
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
src/ps10_dump.asm          dump firmware (gpasm, PIC16F1 syntax)
tools/build.py             assemble, convert to FMD encoding, lay out the 20480-byte image
tools/fmd.py               FMD <-> PIC encoding, image helpers
tools/emu.py               PIC16F1 emulator with the inferred FT61E0A5 peripherals
tools/test_dump.py         emulator test of the dump firmware
tools/stock_probe.py       runs the stock image, shows pin activity per command
tools/dump2bin.py          ESPHome log -> binary files
esphome/ps10-mcu-dump.yaml ESPHome package: dump buttons and logging
reference/ps10-mcu-1.0.5.bin  official 1.0.5 image (md5 9bd5f57f…)
```
