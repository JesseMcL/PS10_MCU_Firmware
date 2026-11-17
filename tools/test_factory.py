#!/usr/bin/env python3
"""Run the built factory image in the emulator: it must answer ESPHome's
tuya: init and hand over to the bootloader on 0x0A.  python tools/test_factory.py"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import fmd
from emu import Cpu, frame, parse, Reset

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
img = os.path.join(ROOT, 'build', 'ps10-mcu-factory-1.0.5.bin')
cpu = Cpu([fmd.fmd_to_pic(w) for w in fmd.load_words(img)], eeprom=[0xFF] * 128)
cpu.inputs[0x00C] = (0x08, 0x08)            # button (PA3) released
cpu.add_timer(0x112, 0, 0x113, 0, 1600)     # TIM4 0.2 ms tick at 8 MIPS
fails = 0


def xfer(cmd, data=b'', ms=300):
    cpu.tx.clear()
    cpu.rx.extend(frame(cmd, data))
    cpu.run(8000 * ms)
    return [(c, d) for v, c, d, ok in parse(bytes(cpu.tx)) if ok]


def check(cond, what):
    global fails
    print(('ok   ' if cond else 'FAIL ') + what)
    fails += not cond


cpu.run(8000 * 1500)
check(xfer(0x00) == [(0x00, b'\x00')], 'heartbeat -> [00]')
r = xfer(0x01)
check(r == [(0x01, b'{"p":"o9a6at9cyfchb47y","v":"1.0.5","m":1}')], 'product info 1.0.5')
check(xfer(0x02) == [(0x02, b'')], 'working mode')
check(xfer(0x03, b'\x04') == [(0x03, b'')], 'wifi status')
r = xfer(0x08)
check(len(r) >= 1 and all(c == 0x07 for c, _ in r) and any(d[0] == 110 for _, d in r), 'status query -> datapoints')
cpu.ee_writes.clear()
try:
    xfer(0x0A, b'\x00\x00\x50\x00')
    check(False, '0x0A resets')
except Reset:
    check(cpu.ee_writes == [(0, 0xFF), (1, 0xFF)], '0x0A: EEPROM 0/1 = FF, then RESET')
print('\nall passed' if not fails else '\n%d FAILED' % fails)
sys.exit(1 if fails else 0)
