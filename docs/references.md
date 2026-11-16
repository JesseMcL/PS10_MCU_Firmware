# References

## In this repository
- [`datasheets/FT61E0Ax_64E0Ax_DS_V1.02_en.pdf`](datasheets/FT61E0Ax_64E0Ax_DS_V1.02_en.pdf):
  FT61E0Ax / FT64E0Ax datasheet, Rev 1.02 (2024-02-02), English, 252 pages.
  FMD doesn't publish a separate family reference manual for these parts: the
  datasheet is the full reference (every register, peripheral chapters,
  instruction set, electrical specs). It doesn't give opcode encodings; see
  [ft61e0a5.md](ft61e0a5.md#core) for the PIC16F1 mapping.

  Useful sections: 1.1 pinouts (QFN20 p. 11), 2 I/O and pin remapping (AFPx,
  EPSx), 6 oscillators, 7.1 WDT, 7.2-7.4 timers, 10 EEPROM/PROM self-access and
  UCFG read, 15 USART, 16 protection, 17 SFR maps, 18 instruction set.

## Elsewhere (not copied here)
- **FMD IDE** (FMD's assembler/C compiler, simulator and per-chip headers,
  needed with an FMD-Link for on-chip debugging): fremontmicro.com download
  centre; also mirrored at [21ic](https://dl.21ic.com/download/ide-550546.html)
  (V2.0.6). Its FT61E0Ax header would give FMD's own register and bit names.
- **FMD-Link user manual** (FMD's programmer/debugger):
  [empere.in copy](https://empere.in/wp-content/uploads/2022/03/FMD-LINK-USER-MANUAL-1.pdf).
- **FMDWriter operation manual** (production programmer, per-chip ISP pin tables):
  [weixiaoic.com](https://www.weixiaoic.com/uploads/allimg/20250603/1-250603154149228.pdf).
- **DCProgrammer** (open hobbyist programmer for FMD parts over CH341A, FX2LP
  or FT232H; supports the FT61E0Ax, UCFG read): the
  [EEVblog thread](https://www.eevblog.com/forum/projects/fremont-micro-devices-microcontroller-programming/).
  The recovery route if an application ever stops answering `0x0A`.
