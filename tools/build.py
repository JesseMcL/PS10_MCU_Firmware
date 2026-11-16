#!/usr/bin/env python3
"""Build the PS10 MCU dump firmware into a DFU image for tuya_mcu_dfu.

  python tools/build.py [--version 0.1.0-dump]

Needs gpasm (gputils) on PATH. Writes build/ps10-mcu-dump-<version>.bin: a
20480-byte image in FT61E0A5 (FMD) encoding laid out like the stock 1.0.5
image: words 0x000-0x5FF copied verbatim from the stock image (the bootloader
doesn't take them; they're kept identical to be safe), the application from
0x600, the rest erased.
"""
import argparse, hashlib, os, re, shutil, subprocess, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, 'tools'))
import fmd  # noqa: E402

STOCK = os.path.join(ROOT, 'reference', 'ps10-mcu-1.0.5.bin')
STOCK_MD5 = '9bd5f57fc1efad47a285cd7e0d951c7b'
SRC = os.path.join(ROOT, 'src', 'ps10_dump.asm')


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--version', default='0.1.0-dump')
    ap.add_argument('--out', default=os.path.join(ROOT, 'build'))
    a = ap.parse_args()
    if not re.fullmatch(r'[0-9A-Za-z.+-]{1,20}', a.version):
        sys.exit('version: 1-20 characters of [0-9A-Za-z.+-]')
    gpasm = shutil.which('gpasm')
    if not gpasm:
        sys.exit('gpasm not found: install gputils (https://gputils.sourceforge.io) and put it on PATH')
    stock = open(STOCK, 'rb').read()
    if hashlib.md5(stock).hexdigest() != STOCK_MD5:
        sys.exit('%s is not the stock 1.0.5 image' % STOCK)

    os.makedirs(a.out, exist_ok=True)
    stem = os.path.join(a.out, 'ps10-mcu-dump-%s' % a.version)
    r = subprocess.run([gpasm, '-p', '16f1829', '-w', '1', '-D', 'VERSION_STR="%s"' % a.version,
                        '-o', stem + '.hex', SRC], capture_output=True, text=True)
    out = '\n'.join(l for l in (r.stdout + r.stderr).splitlines() if 'superseded' not in l)
    if out:
        print(out)
    if r.returncode:
        sys.exit('gpasm failed')

    app = fmd.read_ihex(stem + '.hex')
    if min(app) < fmd.APP_START or max(app) >= 0x800:
        sys.exit('code must stay in 0x600-0x7FF (page 0), got 0x%X-0x%X' % (min(app), max(app)))
    words = fmd.load_words(STOCK)[:fmd.APP_START] + [0x3FFF] * (fmd.WORDS - fmd.APP_START)
    for addr, w in app.items():
        words[addr] = fmd.pic_to_fmd(w)
    fmd.save_words(stem + '.bin', words)
    img = open(stem + '.bin', 'rb').read()
    md5, sha = hashlib.md5(img).hexdigest(), hashlib.sha256(img).hexdigest()
    print('%s.bin: %d bytes, code 0x%03X-0x%03X (%d words)' % (stem, len(img), min(app), max(app), len(app)))
    print('md5    %s\nsha256 %s' % (md5, sha))
    print('\ntuya_mcu_dfu:\n  firmware:\n    path: %s\n    version: "%s"\n    sha256: %s'
          % (os.path.basename(stem) + '.bin', a.version, sha))


if __name__ == '__main__':
    main()
