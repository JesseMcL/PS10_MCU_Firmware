# Passing the LD2410C through to ESPHome's `ld2410:` component

## Where the radar is
The LD2410C talks to the MCU, not the BK7231N: a **software UART on PB3 (to the
radar) / PB4 (from the radar)** at **9600 8N1** (see
[pinout.md](pinout.md#radar-uart-speed)). The FT61E0A has one USART (USART2
exists only on the FT64E0A), and it's the Tuya link to the BK7231N, also 9600
baud. The radar's OUT pin goes to PB7.

## Options

### 1. Tunnel the bytes in a raw datapoint (what the open firmware does)
The MCU forwards radar bytes both ways inside Tuya frames, without
interpreting them:

- **Radar → ESPHome:** the MCU collects bytes from PB4 and reports them as raw
  DP 202 (`0x07`), at 48 bytes or after 3 ms of silence (a character takes
  ~1 ms at 9600, so 3 ms is the end of an LD2410 frame). Only once `tuya:` has
  queried the datapoints; before that they're discarded.
- **ESPHome → radar:** a raw DP 202 delivery (`0x06`) is written out on PB3.
  Chunks can split frames anywhere (the MCU works byte by byte) and hold up to
  128 bytes (`tx_chunk_size: 128` on the virtual UART). Each write becomes one
  Tuya frame, ~11 bytes of overhead, so batching matters: `virtual_uart`
  delivers everything written in one loop pass together, and `ld2410` writes
  a whole command (or its seven set-up commands) in one pass.
- **Flow control:** `tuya:` sends nothing more until it gets a `0x07` back.
  The MCU answers a DP 202 write (with whatever radar bytes are waiting, maybe
  none) once its 256-byte queue has room for another full write, or after
  100 ms, which keeps it inside `tuya:`'s 300 ms timeout.
- **Filter:** LD2410 **set baud** (`0x00A1`) and **factory reset** (`0x00A2`)
  are never sent. Either would move the radar to a rate a software UART can't
  follow (factory reset means 256000), and only reprogramming its baud over a
  fast UART would get it back. The MCU answers them itself with a failure ACK,
  `FD FC FB FA 04 00 <cmd> 01 01 00 04 03 02 01`.
- **Pacing:** after each command frame (footer `04 03 02 01`) the MCU holds the
  next one until the radar has acknowledged (its own `04 03 02 01`) or 100 ms
  have passed. ESPHome's `ld2410` writes several commands in one go (its
  set-up sends seven: enable configuration, version, MAC, resolution, light
  control, parameters, end), and they all arrive in one DP; the radar gets them
  one at a time, as on a direct UART.

On the ESPHome side, [`virtual_uart`](https://github.com/JesseMcL/esphome_virtual_uart)
is a UART with no hardware. `ld2410` uses it like any UART; its output comes out
of `on_tx` and goes into DP 202, and DP 202 reports are pushed into it. The two
are connected in YAML, so neither component knows about the other:

```yaml
tuya:
  id: tuya_mcu
  uart_id: mcu_uart              # explicit: there are two UARTs now
  on_datapoint_update:
    - sensor_datapoint: 202
      datapoint_type: raw
      then:
        - virtual_uart.push: { id: radar_uart, data: !lambda return x; }

virtual_uart:
  - id: radar_uart
    on_tx:
      - lambda: id(tuya_mcu).force_set_raw_datapoint_value(202, x);

ld2410:
  uart_id: radar_uart
```

`esphome/ps10-mcu.yaml` has this plus the entities and radar actions. Don't
configure `ld2410`'s baud-rate select or factory-reset button: the MCU blocks
both anyway.

**Bandwidth.** 9600 baud is ~960 B/s each way. Normal LD2410 reports (~23 B at
~10 Hz) become ~35 B Tuya frames: ~350 B/s, about a third of the link. Engineering
mode (~45 B frames) is ~570 B/s: it fits, with less headroom for other DPs.
Raising the link speed would need the bootloader to follow, and it runs at 9600.

**What stays out of the MCU:** it doesn't parse radar data, and doesn't act on
presence. The radar's OUT pin is reported as DP 1 for anyone who wants it, but
switching the output on presence is an ESPHome automation.

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
Both sides are written and tested separately: the MCU relay, filter and pacing
in the emulator (`tools/test_open.py`), `virtual_uart` with `ld2410` on ESPHome's
host platform. Not yet run together on a device.
