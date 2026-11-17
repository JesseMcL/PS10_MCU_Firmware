# Stock bootloader (0x000-0x5FF)

From a dump of a PS10 (`ps10_dump` 0.1.0, 2026-11-17), disassembled and run in
`tools/emu.py`. The dump itself isn't in this repository: it's the vendor's code.

## Boot decision
1. Clear RAM, `OSCCON` = 0x71 (16 MHz), PA3 input, PB6 (LED) output low.
2. **CRC-16 over the application**, words 0x600-0x27FF, each word low byte then
   high byte as stored (FMD encoding): reflected polynomial 0x8408, initial
   value 0, no final XOR (CRC-16/KERMIT bit order). About 2.5 M instructions,
   ~0.3 s at 8 MIPS.
3. Compare with **data EEPROM 0x00 (high byte) and 0x01 (low byte)**:
   - equal → jump to the application at 0x600;
   - EEPROM 0x00/0x01 = `55 AA` → jump to the application without checking;
   - anything else → stay in the bootloader.

There's no time window or button check before the jump. An application with a
valid CRC that never answers `0x0A` can only be recovered by ICSP, so open
firmware should check `0x0A` first thing in its UART handling (and could offer
"button held at power-up → clear EEPROM 0x00/0x01 and reset" as a fallback).

The interrupt vector checks a RAM flag (0x020 bit 0, set when the application
is started) and jumps to the application's vector at 0x604; otherwise it
handles the bootloader's own UART receive and TIM4 tick.

## In the bootloader
Speaks Tuya at 9600 on USART1, frame version 3:

| Command | Reply |
|---|---|
| `0x00` heartbeat | `00` once, then `01` |
| `0x01` product info | `{"p":"o9a6at9cyfchb47y","v":"1.0.0","m":1}` |
| `0x02` working mode | empty |
| `0x03` Wi-Fi status | empty; status 0/1 (pairing) makes the LED blink; after status 5 it also sends `0x04` |
| `0x0A` start | `00`: 256-byte packets, 4-byte offsets |
| `0x0B` data | acknowledged; see below |

The LED (PB6) blinks while it waits. Holding the button (PA3) sends Tuya
`0x04` (reset Wi-Fi), as the application does.

## Programming
- Writes start at word 0x600 and advance sequentially; the offset in each
  `0x0B` is only compared, not used as an address. **Image bytes below offset
  0xC00 (words 0x000-0x5FF) are acknowledged and discarded**, so the
  bootloader can't overwrite itself.
- Each 256-byte packet is programmed as two 64-word halves (page erase, write,
  read back and compare).
- The end frame (offset = size, no data) makes it compute the CRC above over
  what it programmed, write it to EEPROM 0x00/0x01, acknowledge, wait for the
  UART to finish and `RESET` into the new application.
- The image size is only compared in its low 16 bits.

So the CRC covers what was written to flash, not what was sent: a corrupted
frame is caught by the Tuya frame checksum, not by the CRC.

## Data EEPROM as found (1.0.5-era settings, dump firmware installed)
`00-01` = `58 84` (CRC of the dump firmware), `02` = `58`, `05-0F` = stock
settings, `7F` = `AA` (stock "initialised" marker), rest `FF`.

## Configuration space (0x8000-0x80FF)
Raw words in the dump; the datasheet doesn't give the UCFG layout. 0x8000-0x8007
hold `0FD3 046F 0F05 0DFF 00FF 00FF 02FF 0511`, more values at 0x8041-0x804A,
0x8060-0x8062 and 0x8080 up.
