#!/usr/bin/env python3
"""Run the open firmware in the emulator (tools/emu.py + tools/mcu.py)
against a scripted `tuya:` conversation, with the radar's serial link, the
inputs and the LDR simulated.  python tools/test_open.py [image.bin]"""
import glob, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import fmd
from emu import frame, parse, Reset
from mcu import Mcu, SoftUartWire, decode_uart

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
img = sys.argv[1] if len(sys.argv) > 1 else sorted(glob.glob(os.path.join(ROOT, 'build', 'ps10-mcu-[0-9]*.bin')))[-1]
words = [fmd.fmd_to_pic(w) for w in fmd.load_words(img)]
flash = [0x3FFF] * 0x600 + words[0x600:]     # the bootloader's stub is modelled in mcu.py
fails = 0


def check(cond, what):
    global fails
    print(('ok   ' if cond else 'FAIL ') + what)
    fails += not cond


def boot(ee=None, pins=None):
    cpu = Mcu(flash, eeprom=list(ee or [0xFF] * 128))
    cpu.adc[2] = 1000
    for (port, bit), lvl in (pins or {}).items():
        cpu.set_pin(port, bit, lvl)
    return cpu


def xfer(cpu, raw, ms=30):
    cpu.tx.clear()
    cpu.rx.extend(raw)
    cpu.ms(ms)
    return parse(bytes(cpu.tx))


def dps(frames):
    """DP reports (cmd 0x07) -> {dp: value bytes}, in order (later wins)."""
    out = {}
    for ver, cmd, data, ok in frames:
        assert ok and cmd == 7, (cmd, data)
        i = 0
        while i < len(data):
            n = data[i + 2] << 8 | data[i + 3]
            out[data[i]] = (data[i + 1], data[i + 4:i + 4 + n])
            i += 4 + n
    return out


def dp(n, typ, val):
    return bytes([n, typ, 0, len(val)]) + bytes(val)


def outputs(cpu):
    return cpu.pin('A', 2), cpu.pin('B', 6)


# --- start-up and Tuya handshake --------------------------------------------
cpu = boot()
cpu.ms(5)
check((cpu.mem[0x08C], cpu.mem[0x08D], cpu.mem[0x08E]) == (0x98, 0x90, 0x01), 'TRIS as stock (outputs PA2 triac, PA6 TX, PB3 radar TX, PB6 LED)')
check(outputs(cpu) == (0, 0) and cpu.pin('B', 3) == 1, 'triac and LED off, radar TX idle high')
check(xfer(cpu, frame(0x00)) == [(3, 0, b'\x00', True)], 'first heartbeat -> [00]')
check(xfer(cpu, frame(0x00)) == [(3, 0, b'\x01', True)], 'next heartbeat -> [01]')
r = xfer(cpu, frame(0x01), 60)
check(r == [(3, 1, b'{"p":"ps10open","v":"0.2.0","m":0}', True)], 'product info %r' % r)
check(xfer(cpu, frame(0x02)) == [(3, 2, b'', True)], 'working mode -> empty 0x02')
check(xfer(cpu, frame(0x03, b'\x04')) == [(3, 3, b'', True)], 'wifi state -> empty 0x03')
r = dps(xfer(cpu, frame(0x08), 80))
check(r == {1: (1, b'\x00'), 101: (1, b'\x00'), 102: (4, b'\x01'), 103: (1, b'\x00'),
            104: (2, (1000).to_bytes(4, 'big')), 105: (2, bytes(4)), 106: (1, b'\x00'), 108: (4, b'\x01')},
      'status query reports every DP with defaults: %r' % r)

# --- output, LED, settings --------------------------------------------------
r = dps(xfer(cpu, frame(0x06, dp(101, 1, [1]))))
check(r == {101: (1, b'\x01')} and outputs(cpu) == (1, 1), 'DP 101 on -> triac on, LED follows')
dps(xfer(cpu, frame(0x06, dp(102, 4, [0]))))
check(outputs(cpu) == (1, 0), 'DP 102 = 0 -> LED off')
dps(xfer(cpu, frame(0x06, dp(101, 1, [0]))))
dps(xfer(cpu, frame(0x06, dp(102, 4, [2]))))
check(outputs(cpu) == (0, 1), 'DP 102 = 2 -> LED on with output off')
r = dps(xfer(cpu, frame(0x06, dp(105, 2, (300).to_bytes(4, 'big')))))
check(r == {105: (2, (300).to_bytes(4, 'big'))}, 'DP 105 threshold 300 echoed')
r = dps(xfer(cpu, frame(0x06, dp(108, 4, [7]))))
check(r == {108: (4, b'\x01')}, 'DP 108 out of range rejected (stays 1)')
check(cpu.ee[0x20:0x26] == [0x5A, 2, 0, 1, 300 & 0xFF, 300 >> 8], 'settings saved at EEPROM 0x20: %r' % cpu.ee[0x20:0x26])
check(cpu.ee[0:0x20] == [0xFF] * 0x20, 'EEPROM 0x00-0x1F untouched')
r = xfer(cpu, frame(0x06, dp(150, 1, [1])))
check(r == [(3, 7, dp(150, 1, [1]), True)], 'unknown DP echoed back')

# --- inputs ---------------------------------------------------------------
cpu.tx.clear()
cpu.set_pin('B', 7, 1)
cpu.ms(60)
r = dps(parse(bytes(cpu.tx)))
check(r == {1: (1, b'\x01')}, 'radar OUT high -> DP 1 true')
dps(xfer(cpu, frame(0x06, dp(103, 1, [1]))))       # auto on, threshold 300, light 1000
cpu.set_pin('B', 7, 0); cpu.ms(60); cpu.set_pin('B', 7, 1); cpu.tx.clear(); cpu.ms(60)
check(outputs(cpu)[0] == 0, 'auto: presence while brighter than the threshold -> stays off')
dps(xfer(cpu, frame(0x06, dp(105, 2, bytes(4)))))  # threshold 0 = always
cpu.set_pin('B', 7, 0); cpu.ms(60); cpu.tx.clear(); cpu.set_pin('B', 7, 1); cpu.ms(60)
r = dps(parse(bytes(cpu.tx)))
check(outputs(cpu)[0] == 1 and r.get(101) == (1, b'\x01'), 'auto: presence -> output on and reported')
cpu.tx.clear(); cpu.set_pin('B', 7, 0); cpu.ms(60)
r = dps(parse(bytes(cpu.tx)))
check(outputs(cpu)[0] == 0 and r == {1: (1, b'\x00'), 101: (1, b'\x00')}, 'auto: presence gone -> output off')
dps(xfer(cpu, frame(0x06, dp(103, 1, [0]))))

cpu.tx.clear(); cpu.set_pin('A', 3, 0); cpu.ms(100); cpu.set_pin('A', 3, 1); cpu.ms(60)
r = dps(parse(bytes(cpu.tx)))
check(outputs(cpu)[0] == 1 and r == {101: (1, b'\x01'), 107: (4, b'\x00')}, 'button short press -> toggles output, DP 107 = 0: %r' % r)
cpu.tx.clear(); cpu.set_pin('C', 0, 0); cpu.ms(60)
r = dps(parse(bytes(cpu.tx)))
check(outputs(cpu)[0] == 0 and r == {106: (1, b'\x01'), 101: (1, b'\x00')}, 'switch closed (mode 1) -> DP 106 true, output toggles: %r' % r)
cpu.tx.clear(); cpu.set_pin('C', 0, 1); cpu.ms(60)
r = dps(parse(bytes(cpu.tx)))
check(outputs(cpu)[0] == 0 and r == {106: (1, b'\x00')}, 'switch opened (mode 1) -> reported only')

# --- radar relay ------------------------------------------------------------
wire = SoftUartWire(cpu, 'B', 4)
log0 = len(cpu.pin_log)
read_fw = bytes.fromhex('FDFCFBFA 0200 A000 04030201'.replace(' ', ''))
r = xfer(cpu, frame(0x06, dp(202, 0, read_fw)), 40)
check(r == [(3, 7, dp(202, 0, b''), True)], 'DP 202 write -> immediate empty DP 202 reply')
sent = decode_uart(cpu.pin_log[log0:], 'B', 3)
check(sent == read_fw, 'bytes forwarded to the radar on PB3 at 9600: %s' % sent.hex())

ack = bytes.fromhex('FDFCFBFA 0C00 A001 0000 0001 0702 1609 2422 04030201'.replace(' ', ''))
cpu.tx.clear()
wire.send(ack)
cpu.ms(35)
got = b''
for ver, cmd, data, ok in parse(bytes(cpu.tx)):
    assert ok and cmd == 7 and data[0] == 202, data
    got += data[4:]
check(got == ack, 'radar reply relayed in DP 202: %s' % got.hex())

stream = bytes(range(100))
cpu.tx.clear()
wire.send(stream)
cpu.ms(120)
chunks = [data[4:] for ver, cmd, data, ok in parse(bytes(cpu.tx))]
check(b''.join(chunks) == stream and max(map(len, chunks)) <= 48,
      'long burst relayed in chunks of <= 48 (%s)' % [len(c) for c in chunks])

for cmd in (0xA1, 0xA2):
    log0 = len(cpu.pin_log)
    bad = bytes.fromhex('FDFCFBFA 0400 %02X00 0700 04030201' % cmd)
    good = bytes.fromhex('FDFCFBFA 0200 A300 04030201')
    cpu.tx.clear()
    cpu.rx.extend(frame(0x06, dp(202, 0, bad + good)))
    cpu.ms(60)
    sent = decode_uart(cpu.pin_log[log0:], 'B', 3)
    got = b''.join(data[4:] for ver, c, data, ok in parse(bytes(cpu.tx)))
    nak = bytes.fromhex('FDFCFBFA 0400 %02X01 0100 04030201' % cmd)
    check(sent == good, 'command 0x%04X not sent to the radar (sent %s)' % (cmd, sent.hex()))
    check(got == nak, 'command 0x%04X answered with a failure ACK: %s' % (cmd, got.hex()))

# --- light, long press ------------------------------------------------------
cpu.adc[2] = 2000
cpu.tx.clear()
cpu.set_pin('A', 3, 0)
cpu.ms(5100)
cpu.set_pin('A', 3, 1)
cpu.ms(60)
r = dps(parse(bytes(cpu.tx)))
check(r.get(104) == (2, (2000).to_bytes(4, 'big')), 'light change reported within 5 s')
check(r.get(107) == (4, b'\x01') and outputs(cpu)[0] == 0, 'long press -> DP 107 = 1, output unchanged')

# --- update hand-over --------------------------------------------------------
cpu.rx.extend(frame(0x0A, bytes(4)))
try:
    cpu.ms(30)
    check(False, '0x0A resets')
except Reset:
    check(cpu.ee[0] == 0xFF and cpu.ee[1] == 0xFF, '0x0A -> EEPROM 0x00/0x01 = FF, RESET')

ee = [0x12, 0x34] + [0xFF] * 126
cpu = boot(ee, {('A', 3): 0})
try:
    cpu.ms(3200)
    check(False, 'button held at power-up resets into the bootloader')
except Reset:
    check(cpu.ee[0] == 0xFF and cpu.ee[1] == 0xFF, 'button held 3 s at power-up -> EEPROM 0x00/0x01 = FF, RESET')

ee = [0x12, 0x34] + [0xFF] * 30 + [0x5A, 0, 1, 2, 0x10, 0x00] + [0xFF] * 90
cpu = boot(ee)
cpu.ms(5)
r = dps(xfer(cpu, frame(0x08), 80))
check(r[102] == (4, b'\x00') and r[103] == (1, b'\x01') and r[108] == (4, b'\x02') and r[105] == (2, (16).to_bytes(4, 'big')),
      'settings restored from EEPROM')
check(cpu.ee[:2] == [0x12, 0x34], 'bootloader CRC bytes left alone in normal running')

print('\n%d failure(s)' % fails)
sys.exit(1 if fails else 0)
