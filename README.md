# PS10 MCU firmware: factory 1.0.5

This branch holds the **official Tuya PS10 MCU firmware 1.0.5** as assembler
source, `src/factory_1.0.5.asm`, disassembled from the official update image
with labels and datasheet register names. The build reassembles it and fails
unless the result is **identical, word for word**, to the official image
(`reference/ps10-mcu-1.0.5.bin`, md5 `9bd5f57fc1efad47a285cd7e0d951c7b`).

It's here for reference (how the stock firmware drives the hardware) and as a
known-good rollback target. Main development is on `main`.

| | |
|---|---|
| [src/factory_1.0.5.asm](src/factory_1.0.5.asm) | the firmware; the header lists landmarks (vectors, radar commands, Tuya dispatch, init) |
| [docs/pinout.md](docs/pinout.md) | pin functions, as this firmware uses them |
| [docs/bootloader.md](docs/bootloader.md) | the stock bootloader that installs it |
| [docs/ft61e0a5.md](docs/ft61e0a5.md) | the chip, encoding and registers |

## Build

Needs Python 3 and [gputils](https://gputils.sourceforge.io) (`gpasm`).

```
python tools/build.py          # build/ps10-mcu-factory-1.0.5.bin, checked against the official image
python tools/test_factory.py   # run it in the emulator
```

GitHub Actions does the same on every push to `release/**`. A `factory-*`
tag makes a release with the image.

## Install (rollback)

With `tuya_mcu_dfu`, the official copy on Tuya's CDN is the same file:

```yaml
firmware:
  url: https://images.tuyaeu.com/smart/firmware/upgrade/ay1503986080106Gppjy/178244149610c6c194500.bin
  version: "1.0.5"
  sha256: b22da68400c00d23a60747b6a6a8c4f9f69875059bd531789db32d6fcd878872
```

Home Assistant hides the Install button when 1.0.5 is older than what's
installed; call `update.install` on the entity instead.

## Regenerating the source

`python tools/disasm.py reference/ps10-mcu-1.0.5.bin` produces the same listing
(without the header). It works on any FT61E0A5 image, e.g. a dumped bootloader.
