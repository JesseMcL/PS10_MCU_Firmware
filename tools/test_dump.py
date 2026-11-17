#!/usr/bin/env python3
"""Run the dump firmware in the emulator (tools/emu.py) against a scripted
`tuya:` / tuya_mcu_dfu conversation.  python tools/test_dump.py [image.bin]"""
import glob, os, random, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import fmd
from emu import Cpu, frame, parse, Reset

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
img = sys.argv[1] if len(sys.argv) > 1 else sorted(glob.glob(os.path.join(ROOT, 'build', 'ps10-mcu-dump-*.bin')))[-1]
words = [fmd.fmd_to_pic(w) for w in fmd.load_words(img)]
rnd = random.Random(1)
boot = [rnd.randrange(0x4000) for _ in range(0x600)]      # stands in for the bootloader
flash = boot + words[0x600:]
ee = [rnd.randrange(256) for _ in range(128)]
cfg = {a: rnd.randrange(0x4000) for a in range(0x20)}

cpu = Cpu(flash, eeprom=list(ee), config=cfg)
ALLOWED = {0x099, 0x19D, 0x097, 0x09A, 0x08C, 0x48E, 0x48F, 0x491, 0x494, 0x495, 0x49C, 0x21F,
           0x191, 0x192, 0x193, 0x194, 0x195, 0x196, 0x48C}
cpu.trace_sfr = {b * 128 + f for b in range(32) for f in range(0x0C, 0x20)}
fails = 0


def check(cond, what):
    global fails
    print(('ok   ' if cond else 'FAIL ') + what)
    fails += not cond


def xfer(raw, steps=60000):
    cpu.tx.clear()
    cpu.rx.extend(raw)
    for _ in range(steps):
        cpu.step()
        if not cpu.rx and len(parse(bytes(cpu.tx))) and cpu.pc == cpu_loop:
            break
    return parse(bytes(cpu.tx))


cpu.run(200)
cpu_loop = cpu.pc          # parked in the poll loop
for _ in range(50):
    cpu.step()

r = xfer(frame(0x00))
check(r == [(3, 0, b'\x00', True)], 'first heartbeat -> [00]')
r = xfer(frame(0x00))
check(r == [(3, 0, b'\x01', True)], 'next heartbeat -> [01]')
r = xfer(frame(0x01))
check(len(r) == 1 and r[0][1] == 1 and r[0][2].startswith(b'{"p":"ps10dump","v":"') and r[0][3], 'product info %r' % (r[0][2] if r else None))
check(xfer(frame(0x02)) == [(3, 2, b'', True)], 'working mode -> empty 0x02')
check(xfer(frame(0x03, b'\x04')) == [(3, 3, b'', True)], 'wifi state -> empty 0x03')
check(xfer(frame(0x08)) == [(3, 7, bytes([200, 0, 0, 4, 0, 0, 0, 0]), True)], 'status query -> DP 200')


def req(space, addr, n):
    r = xfer(frame(0x06, bytes([200, 0, 0, 4, ord(space), addr >> 8, addr & 0xFF, n])))
    assert len(r) == 1 and r[0][1] == 7 and r[0][3], r
    p = r[0][2]
    assert p[:3] == bytes([201, 0, 0]) and p[3] == len(p) - 4, p[:8]
    v = p[4:]
    assert v[:3] == bytes([ord(space), addr >> 8, addr & 0xFF]), v[:4]
    return v[3], v[4:]


got = []
for a in range(0, 0x2800, 32):
    n, d = req('F', a, 32)
    assert n == 32
    got += [d[i] | d[i + 1] << 8 for i in range(0, 64, 2)]
check(got == [fmd.pic_to_fmd(w) for w in flash], 'flash dump 0x0000-0x27FF matches, in FMD encoding (bootloader area included)')
n, d = req('C', 0, 32)
check(n == 32 and [d[i] | d[i + 1] << 8 for i in range(0, 64, 2)] == [cfg[a] for a in range(32)], 'config space dump')
e = []
for a in (0, 64):
    n, d = req('E', a, 64)
    e += list(d)
check(e == ee, 'EEPROM dump')
w1234 = fmd.pic_to_fmd(flash[0x1234])
check(req('F', 0x1234, 1) == (1, bytes([w1234 & 0xFF, w1234 >> 8])), 'single word')
check(req('F', 0, 0) == (0, b''), 'count 0 rejected')
check(req('F', 0, 33) == (0, b''), '33 words rejected')
check(req('E', 0, 65) == (0, b''), '65 EEPROM bytes rejected')
check(req('X', 0, 1) == (0, b''), 'unknown space rejected')

r = xfer(frame(0x06, bytes([110, 1, 0, 1, 1])))
check(r == [(3, 7, bytes([110, 1, 0, 1, 1]), True)], 'other DP echoed')
r = xfer(b'\x12\x55\x55' + frame(0x00)[1:])
check(r == [(3, 0, b'\x01', True)], 'resync on 55 55 AA')
bad = bytearray(frame(0x00)); bad[-1] ^= 1
r = xfer(bytes(bad) + frame(0x00))
check(r == [(3, 0, b'\x01', True)], 'bad checksum dropped')
r = xfer(frame(0x06, bytes(100)) + frame(0x00))
check(r == [(3, 0, b'\x01', True)], 'oversized frame dropped')
r = xfer(frame(0x0B, b'\0\0\0\0'))
check(r == [], '0x0B ignored by the application')

writes = {e[2] for e in cpu.sfr_log if e[0] == 'w'}
check(writes <= ALLOWED, 'only UART/NVM/clock/WDT registers written: %s' % sorted(hex(a) for a in writes - ALLOWED))
trisa = [e[3] for e in cpu.sfr_log if e[0] == 'w' and e[2] == 0x08C]
check(all(v & 0x3F == 0 for v in trisa), 'TRISA: only bits 6/7 touched')
check(cpu.ee_writes == [], 'no EEPROM writes before 0x0A')

try:
    xfer(frame(0x0A, b'\x00\x00\x50\x00'))
    check(False, '0x0A resets')
except Reset:
    check(cpu.ee_writes == [(0, 0xFF), (1, 0xFF)], '0x0A: EEPROM 0/1 = FF, then RESET')
check(cpu.flash == flash, 'program flash untouched')
print('\n%s' % ('all passed' if not fails else '%d FAILED' % fails))
sys.exit(1 if fails else 0)
