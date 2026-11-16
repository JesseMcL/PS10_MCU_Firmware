#!/usr/bin/env python3
"""Turn ESPHome logs from esphome/ps10-mcu-dump.yaml into binary files.

  python tools/dump2bin.py logs.txt [-o dump]

Writes, for whatever the log contains:
  flash.bin       program flash 0x0000-0x27FF as read (FMD encoding, 14-bit LE words,
                  same format as the Tuya MCU images)
  flash_pic.bin   the same in PIC16F1 encoding, for gpdasm -p p16f1829
  bootloader.asm  gpdasm listing of 0x000-0x5FF, if gpdasm is on PATH
  config.bin      configuration space 0x8000-0x80FF (LE words)
  eeprom.bin      data EEPROM 0x00-0x7F
Missing chunks are reported and left as 0x3FFF / 0xFF.
"""
import argparse, hashlib, os, re, shutil, subprocess, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import fmd

LINE = re.compile(r'\[ps10dump(?::\d+)?\]:\s+([FCE]) ([0-9A-F]{4}) ([0-9A-F]+)\s*$')
SIZES = {'F': fmd.WORDS, 'C': 0x100, 'E': 0x80}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('log', nargs='+')
    ap.add_argument('-o', '--out', default='dump')
    a = ap.parse_args()
    mem = {'F': {}, 'C': {}, 'E': {}}
    for path in a.log:
        for line in open(path, encoding='utf-8', errors='replace'):
            m = LINE.search(re.sub(r'\x1b\[[0-9;]*m', '', line))
            if not m:
                continue
            sp, addr, data = m.group(1), int(m.group(2), 16), bytes.fromhex(m.group(3))
            if sp == 'E':
                for i, b in enumerate(data):
                    mem[sp][addr + i] = b
            else:
                for i in range(0, len(data) - 1, 2):
                    mem[sp][addr + i // 2] = data[i] | data[i + 1] << 8
    os.makedirs(a.out, exist_ok=True)
    for sp, name in (('F', 'flash'), ('C', 'config'), ('E', 'eeprom')):
        got = mem[sp]
        if not got:
            continue
        size = SIZES[sp]
        missing = [x for x in range(size) if x not in got]
        if sp == 'E':
            out = bytes(got.get(x, 0xFF) for x in range(size))
            open(os.path.join(a.out, name + '.bin'), 'wb').write(out)
        else:
            words = [got.get(x, 0x3FFF) for x in range(size)]
            fmd.save_words(os.path.join(a.out, name + '.bin'), words)
        print('%-7s %4d/%d %s%s' % (name, size - len(missing), size, 'words' if sp != 'E' else 'bytes',
                                   '' if not missing else ', missing from 0x%04X' % missing[0]))
        if sp == 'F':
            fmd.save_words(os.path.join(a.out, 'flash_pic.bin'), [fmd.fmd_to_pic(w) for w in words])
            boot = words[:fmd.APP_START]
            print('        bootloader 0x000-0x5FF: %d non-erased words, md5 %s' % (
                sum(w != 0x3FFF for w in boot), hashlib.md5(fmd.struct.pack('<%dH' % len(boot), *boot)).hexdigest()))
            app = words[fmd.APP_START:]
            img = fmd.struct.pack('<%dH' % len(app), *app)
            print('        application 0x600-0x27FF md5 %s' % hashlib.md5(img).hexdigest())
            disasm(a.out, words)


def disasm(out, words):
    gpdasm = shutil.which('gpdasm')
    if not gpdasm:
        return
    hexf = os.path.join(out, 'bootloader_pic.hex')
    lines = []
    for a in range(0, fmd.APP_START, 8):
        chunk = b''.join(fmd.struct.pack('<H', fmd.fmd_to_pic(w)) for w in words[a:a + 8])
        rec = bytes([len(chunk), (a * 2) >> 8 & 0xFF, (a * 2) & 0xFF, 0]) + chunk
        lines.append(':' + rec.hex().upper() + '%02X' % (-sum(rec) & 0xFF))
    open(hexf, 'w').write('\n'.join(lines + [':00000001FF']) + '\n')
    r = subprocess.run([gpdasm, '-p', 'p16f1829', '-n', hexf], capture_output=True, text=True)
    open(os.path.join(out, 'bootloader.asm'), 'w').write(r.stdout)
    print('        bootloader.asm written (PIC16F1829 register names are only a guess for this chip)')


if __name__ == '__main__':
    main()
