#!/usr/bin/env python3
"""Build the factory 1.0.5 firmware from source and check it is identical to
the official image.

  python tools/build.py

Needs gpasm (gputils) on PATH. Writes build/ps10-mcu-factory-1.0.5.bin (FMD
encoding, 20480 bytes) and fails unless it matches reference/ps10-mcu-1.0.5.bin
word for word.
"""
import hashlib, os, shutil, subprocess, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, 'tools'))
import fmd  # noqa: E402

SRC = os.path.join(ROOT, 'src', 'factory_1.0.5.asm')
REF = os.path.join(ROOT, 'reference', 'ps10-mcu-1.0.5.bin')
VERSION = '1.0.5'


def main():
    gpasm = shutil.which('gpasm')
    if not gpasm:
        sys.exit('gpasm not found: install gputils (https://gputils.sourceforge.io) and put it on PATH')
    out = os.path.join(ROOT, 'build')
    os.makedirs(out, exist_ok=True)
    stem = os.path.join(out, 'ps10-mcu-factory-' + VERSION)
    r = subprocess.run([gpasm, '-p', '16f1789', '-w', '2', '-o', stem + '.hex', SRC], capture_output=True, text=True)
    msg = '\n'.join(l for l in (r.stdout + r.stderr).splitlines() if 'superseded' not in l)
    if msg:
        print(msg)
    if r.returncode:
        sys.exit('gpasm failed')
    words = [0x3FFF] * fmd.WORDS
    for addr, w in fmd.read_ihex(stem + '.hex').items():
        if addr >= fmd.WORDS:
            sys.exit('code at 0x%X is outside program memory' % addr)
        words[addr] = fmd.pic_to_fmd(w)
    fmd.save_words(stem + '.bin', words)
    img, ref = open(stem + '.bin', 'rb').read(), open(REF, 'rb').read()
    diff = [i // 2 for i in range(0, len(ref), 2) if img[i:i + 2] != ref[i:i + 2]]
    print('%s.bin: %d bytes\nmd5    %s\nsha256 %s' % (stem, len(img), hashlib.md5(img).hexdigest(),
                                                    hashlib.sha256(img).hexdigest()))
    if diff:
        sys.exit('NOT identical to the official image: %d words differ, first at 0x%04X' % (len(diff), diff[0]))
    print('identical to the official 1.0.5 image')


if __name__ == '__main__':
    main()
