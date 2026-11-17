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
ee0 = [0x12, 0x34] + [0x5A] * 126           # stock settings stand-in
cpu = boot(ee0)
cpu.ms(5)
check((cpu.mem[0x08C], cpu.mem[0x08D], cpu.mem[0x08E]) == (0x98, 0x90, 0x01), 'TRIS as stock (outputs PA2 triac, PA6 TX, PB3 radar TX, PB6 LED)')
check(outputs(cpu) == (0, 0) and cpu.pin('B', 3) == 1, 'triac and LED off, radar TX idle high')
check(xfer(cpu, frame(0x00)) == [(3, 0, b'\x00', True)], 'first heartbeat -> [00]')
check(xfer(cpu, frame(0x00)) == [(3, 0, b'\x01', True)], 'next heartbeat -> [01]')
r = xfer(cpu, frame(0x01), 60)
check(r == [(3, 1, b'{"p":"ps10open","v":"0.2.1","m":0}', True)], 'product info %r' % r)
check(xfer(cpu, frame(0x02)) == [(3, 2, b'', True)], 'working mode -> empty 0x02')
check(xfer(cpu, frame(0x03, b'\x04')) == [(3, 3, b'', True)], 'wifi state -> empty 0x03')
r = dps(xfer(cpu, frame(0x08), 80))
check(r == {1: (4, b'\x00'), 110: (1, b'\x00'), 111: (1, b'\x00'), 112: (2, (1000).to_bytes(4, 'big')),
            113: (1, b'\x00'), 114: (1, b'\x00')},
      'status query reports every DP: %r' % r)

# --- outputs ----------------------------------------------------------------
r = dps(xfer(cpu, frame(0x06, dp(110, 1, [1]))))
check(r == {110: (1, b'\x01')} and outputs(cpu) == (1, 0), 'DP 110 on -> triac on, LED untouched')
r = dps(xfer(cpu, frame(0x06, dp(111, 1, [1]))))
check(r == {111: (1, b'\x01')} and outputs(cpu) == (1, 1), 'DP 111 on -> LED on')
dps(xfer(cpu, frame(0x06, dp(110, 1, [0]))))
check(outputs(cpu) == (0, 1), 'DP 110 off -> triac off, LED stays on')
dps(xfer(cpu, frame(0x06, dp(111, 1, [0]))))
check(outputs(cpu) == (0, 0), 'DP 111 off -> LED off')
r = xfer(cpu, frame(0x06, dp(150, 1, [1])))
check(r == [(3, 7, dp(150, 1, [1]), True)], 'unknown DP echoed back')

# --- inputs: reported raw, no behaviour ------------------------------------
cpu.tx.clear(); cpu.set_pin('B', 7, 1); cpu.ms(5)
check(dps(parse(bytes(cpu.tx))) == {1: (4, b'\x01')}, 'radar OUT high -> DP 1 = 1 within 5 ms')
cpu.tx.clear(); cpu.set_pin('B', 7, 0); cpu.ms(5)
check(dps(parse(bytes(cpu.tx))) == {1: (4, b'\x00')} and outputs(cpu) == (0, 0), 'radar OUT low -> DP 1 = 0, outputs untouched')
cpu.tx.clear(); cpu.set_pin('A', 3, 0); cpu.ms(40)
check(dps(parse(bytes(cpu.tx))) == {114: (1, b'\x01')}, 'button pressed -> DP 114 true')
cpu.tx.clear(); cpu.set_pin('A', 3, 1); cpu.ms(40)
check(dps(parse(bytes(cpu.tx))) == {114: (1, b'\x00')} and outputs(cpu) == (0, 0), 'button released -> DP 114 false, output untouched')
cpu.tx.clear(); cpu.set_pin('A', 3, 0); cpu.ms(10); cpu.set_pin('A', 3, 1); cpu.ms(40)
check(parse(bytes(cpu.tx)) == [], '10 ms bounce on the button not reported')
cpu.tx.clear(); cpu.set_pin('C', 0, 0); cpu.ms(40)
check(dps(parse(bytes(cpu.tx))) == {113: (1, b'\x01')} and outputs(cpu) == (0, 0), 'switch input active -> DP 113 true, output untouched')
cpu.tx.clear(); cpu.set_pin('C', 0, 1); cpu.ms(40)
check(dps(parse(bytes(cpu.tx))) == {113: (1, b'\x00')}, 'switch input released -> DP 113 false')
cpu.adc[2] = 1003
cpu.tx.clear(); cpu.ms(1000)
check(dps(parse(bytes(cpu.tx))) == {112: (2, (1003).to_bytes(4, 'big'))}, 'light: raw ADC change of 3 reported within 1 s')

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
    cpu.ms(150)
    sent = decode_uart(cpu.pin_log[log0:], 'B', 3)
    got = b''.join(data[4:] for ver, c, data, ok in parse(bytes(cpu.tx)))
    nak = bytes.fromhex('FDFCFBFA 0400 %02X01 0100 04030201' % cmd)
    check(sent == good, 'command 0x%04X not sent to the radar (sent %s)' % (cmd, sent.hex()))
    check(got == nak, 'command 0x%04X answered with a failure ACK: %s' % (cmd, got.hex()))


# pacing: two commands in one chunk, split across two DP writes, radar ACKs the first
enable = bytes.fromhex('FDFCFBFA 0400 FF00 0100 04030201'.replace(' ', ''))
query = bytes.fromhex('FDFCFBFA 0200 6100 04030201'.replace(' ', ''))
both = enable + query
log0 = len(cpu.pin_log)
cpu.rx.extend(frame(0x06, dp(202, 0, both[:9])))
cpu.ms(25)
cpu.rx.extend(frame(0x06, dp(202, 0, both[9:])))
cpu.ms(60)
sent = decode_uart(cpu.pin_log[log0:], 'B', 3)
check(sent == enable, 'partial frames joined; second command held while the first is unanswered (sent %s)' % sent.hex())
wire.send(bytes.fromhex('FDFCFBFA 0800 FF01 0000 0100 4000 04030201'.replace(' ', '')))
cpu.ms(40)
sent = decode_uart(cpu.pin_log[log0:], 'B', 3)
check(sent == both, 'second command sent once the radar acknowledged the first')

cpu.ms(150)                                 # the query above got no ACK: let that time out
log0 = len(cpu.pin_log)
cpu.rx.extend(frame(0x06, dp(202, 0, both)))
cpu.ms(60)
check(decode_uart(cpu.pin_log[log0:], 'B', 3) == enable, 'no ACK: second command held')
cpu.ms(130)                                 # DP arrives ~35 ms, enable sent by ~50, +100
check(decode_uart(cpu.pin_log[log0:], 'B', 3) == both, 'no ACK: second command sent after the 100 ms timeout')

# ld2410's set-up: seven commands written at once, so one 88-byte DP
setup = b''.join(bytes.fromhex(h) for h in [
    'FDFCFBFA0400FF00010004030201', 'FDFCFBFA0200A00004030201', 'FDFCFBFA0400A500010004030201',
    'FDFCFBFA0200AB0004030201', 'FDFCFBFA0200AE0004030201', 'FDFCFBFA0200610004030201', 'FDFCFBFA0200FE0004030201'])
cpu.ms(150)
log0 = len(cpu.pin_log)
r = xfer(cpu, frame(0x06, dp(202, 0, setup)), 150)   # ~100 ms to arrive at 9600
check(len(setup) == 88 and r == [(3, 7, dp(202, 0, b''), True)], '88-byte DP 202 write accepted and answered at once')
cpu.ms(900)
check(decode_uart(cpu.pin_log[log0:], 'B', 3) == setup, 'all seven commands reach the radar, one at a time (no ACKs: 100 ms apart)')

# a radar that doesn't answer: every write is still answered at once, and
# what the queue can't take is refused whole, with failure ACKs
burst = b''.join(bytes.fromhex('FDFCFBFA0200%02X0004030201' % (0x10 + i)) for i in range(10))
cpu.ms(200)
log0 = len(cpu.pin_log)
replies, got = [], b''
for k in range(3):
    cpu.tx.clear()
    c0 = cpu.cycles
    cpu.rx.extend(frame(0x06, dp(202, 0, burst)))
    for _ in range(30):
        cpu.ms(10)
        r = parse(bytes(cpu.tx))
        if r:
            replies.append((cpu.cycles - c0) * 1000 // 8_000_000)
            got += b''.join(d[4:] for _, c, d, ok in r)
            break
check(len(replies) == 3 and max(replies) <= 200, 'three 120-byte writes each answered on arrival (%s ms after sending started)' % replies)
cpu.tx.clear()
cpu.ms(3500)
got += b''.join(d[4:] for _, c, d, ok in parse(bytes(cpu.tx)))
sent = decode_uart(cpu.pin_log[log0:], 'B', 3)
frames = [sent[i:i + 12] for i in range(0, len(sent), 12)]
naks = [got[i:i + 14] for i in range(0, len(got), 14)]
check(all(f in burst for f in frames), 'only whole commands reach the radar')
check(all(n[:6] == bytes.fromhex('FDFCFBFA0400') and n[7:] == bytes.fromhex('01010004030201') for n in naks) and naks,
      'the rest refused with failure ACKs (%d sent, %d refused)' % (len(frames), len(naks)))
check(len(frames) + len(naks) == 30, 'every command either sent or refused')

# --- update hand-over --------------------------------------------------------
check(cpu.ee == ee0, 'EEPROM never written in normal running')
cpu.rx.extend(frame(0x0A, bytes(4)))
try:
    cpu.ms(30)
    check(False, '0x0A resets')
except Reset:
    check(cpu.ee[0] == 0xFF and cpu.ee[1] == 0xFF and cpu.ee[2:] == ee0[2:], '0x0A -> EEPROM 0x00/0x01 = FF (only), RESET')

cpu = boot(ee0, {('A', 3): 0})
try:
    cpu.ms(3200)
    check(False, 'button held at power-up resets into the bootloader')
except Reset:
    check(cpu.ee[0] == 0xFF and cpu.ee[1] == 0xFF, 'button held 3 s at power-up -> EEPROM 0x00/0x01 = FF, RESET')

print('\n%d failure(s)' % fails)
sys.exit(1 if fails else 0)
