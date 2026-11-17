# Passing the LD2410C through to ESPHome's `ld2410:` component

## Where the radar is
The LD2410C talks to the MCU, not the BK7231N: a **software UART on PB3 (to the
radar) / PB4 (from the radar)** at **9600 8N1** (see
[pinout.md](pinout.md#radar-uart-speed)). The FT61E0A has one USART (USART2
exists only on the FT64E0A), and it's the Tuya link to the BK7231N, also 9600
baud. The radar's OUT pin goes to PB7.

## Options

### 1. Tunnel the bytes in a raw datapoint (recommended)
Custom MCU firmware forwards radar bytes both ways inside Tuya frames:

- **Radar → ESPHome:** the MCU collects bytes from PB4 and reports them as raw
  DP 202 (`0x07`), flushing at 48 bytes or after ~3 ms of silence (a 9600-baud
  character takes ~1 ms, so a gap of 3 is the end of an LD2410 frame).
- **ESPHome → radar:** a raw DP 202 delivery (`0x06`) is written out on PB3. The
  MCU answers every `0x06` with a `0x07` straight away: ESPHome's `tuya:` waits
  for one (up to 300 ms) before sending the next command.

On the ESPHome side, a small external component (`tuya_uart_tunnel`) is a
`uart::UARTComponent` whose bytes come from `tuya:`'s public API:
`register_listener(202, …)` fills an RX ring buffer, and writes are collected
during a loop iteration and sent with one `force_set_raw_datapoint_value(202, …)`
(the `ld2410` component writes a command in several pieces; one DP per piece
would be slow). No protected `tuya:` members are needed. Then:

```yaml
tuya_uart_tunnel:
  id: radar_uart
  tuya_id: tuya_mcu
  datapoint: 202
  baud_rate: 9600        # informational; must be present for ld2410's checks
  stop_bits: 1
  parity: NONE

ld2410:
  uart_id: radar_uart
```

`ld2410`'s final validation only checks the referenced UART's parity and stop
bits (and pins, but only for native UART classes), so a tunnel UART passes, as
`usb_uart` does.

**Bandwidth.** 9600 baud is ~960 B/s each way. Normal LD2410 reports (~23 B at
~10 Hz) become ~35 B Tuya frames: ~350 B/s, about a third of the link. Engineering
mode (~45 B frames) is ~570 B/s: it fits, with less headroom for other DPs.
Raising the link speed would need the bootloader to follow, and it runs at 9600.

**Must-haves in the MCU firmware:**
- Drop LD2410 **set baud** (`0x00A1`) and **factory reset** (`0x00A2`) and answer
  them with a failure ACK. Either would move the radar to a rate a software
  UART can't follow (factory reset means 256000), and only reprogramming the
  radar's baud over a fast UART would get it back. The `ld2410` component's
  baud-rate select and factory-reset button shouldn't be configured.
- Keep the `0x0A` handler first in the UART loop, so DFU and rollback always work.
- Keep local control (radar OUT → triac, button, switch input) working when
  ESPHome is offline, or decide explicitly not to.

`tuya:` logs every DP report at DEBUG; set `logger: logs: tuya: INFO` to avoid
~10 lines a second.

### 2. Transparent bridge mode
The MCU stops speaking Tuya and copies bytes between the two UARTs, and ESPHome
uses `ld2410` directly on its Tuya UART. Simple, but the output, LED, button and
switch input lose their channel, and DFU needs a way back into Tuya mode
(a timeout, or a magic sequence). Not recommended.

### 3. Hardware
Wire the LD2410C TX/RX to free BK7231N pins (e.g. UART2) and leave PB3/PB4 as
inputs. ESPHome's `ld2410` then runs natively at 9600 (or switch the radar to
256000 once it's off the MCU). Needs a free UART on the module and a board mod.

## Status
1. MCU side: done in the open firmware (`src/radar.c`, `src/main.c`), including
   the 0x00A1/0x00A2 filter, which answers with
   `FD FC FB FA 04 00 <cmd> 01 01 00 04 03 02 01` (status 1 = failed).
   Tested in the emulator (`tools/test_open.py`), not yet on hardware.
2. ESPHome side: `tuya_uart_tunnel` still to write (fits alongside `tuya_mcu_dfu`).
   Until then DP 202 is unused and the radar keeps whatever configuration it has;
   presence comes from the OUT pin (DP 1).
