#!/usr/bin/env python3
"""Run the stock 1.0.5 MCU image in the emulator and show which registers and
port bits it touches, at boot and per Tuya command. A reverse-engineering aid
for checking the pinout estimate in docs/pinout.md.

  python tools/stock_probe.py [--ms 3000]

Model: RA3 held high (the firmware waits for it at boot), the 1 ms tick timer
(enable 0x112.0, flag 0x113.0) ticks every 4000 instruction cycles; radar soft
UART timers are not driven.
"""
import argparse, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import fmd
from emu import Cpu, frame, parse, Reset

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
NAMES = {0x00C: 'PORTA', 0x00D: 'PORTB', 0x00E: 'PORTC', 0x08C: 'TRISA', 0x08D: 'TRISB', 0x08E: 'TRISC'}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--ms', type=int, default=3000, help='simulated time per step')
    a = ap.parse_args()
    words = [fmd.fmd_to_pic(w) for w in fmd.load_words(os.path.join(ROOT, 'reference', 'ps10-mcu-1.0.5.bin'))]
    cpu = Cpu(words, eeprom=[0xFF] * 128)
    cpu.inputs[0x00C] = (0x08, 0x08)
    cpu.add_timer(0x112, 0, 0x113, 0, 4000)
    cpu.trace_sfr = set(NAMES)
    ports = {k: 0 for k in NAMES}

    def run(tag, data=None):
        cpu.sfr_log.clear()
        cpu.tx.clear()
        if data:
            cpu.rx.extend(data)
        try:
            cpu.run(a.ms * 4000)
        except Reset:
            print('   RESET')
        changes = []
        for e in cpu.sfr_log:
            if e[0] == 'w' and e[3] != ports[e[2]]:
                diff = e[3] ^ ports[e[2]]
                for b in range(8):
                    if diff >> b & 1:
                        changes.append('%s.%d=%d@%04x' % (NAMES[e[2]], b, e[3] >> b & 1, e[1]))
                ports[e[2]] = e[3]
        print('== %-22s %s' % (tag, ' '.join(dict.fromkeys(changes)) or '-'))
        for v, c, d, ok in parse(bytes(cpu.tx)):
            print('   <- 0x%02X %s' % (c, d.hex(' ')))

    run('boot')
    run('heartbeat', frame(0x00))
    run('wifi connected (0x03 04)', frame(0x03, b'\x04'))
    on, off = b'\x01\x00\x01\x01', b'\x01\x00\x01\x00'
    for name, dp in [('DP110 output on', b'\x6e' + on), ('DP111 LED off', b'\x6f' + off),
                     ('DP110 output off', b'\x6e' + off), ('DP110 output on', b'\x6e' + on),
                     ('DP111 LED on', b'\x6f' + on), ('DP110 output off', b'\x6e' + off)]:
        run(name, frame(0x06, dp))
    print('EEPROM writes:', ' '.join('%02X=%02X' % w for w in cpu.ee_writes))


if __name__ == '__main__':
    main()
