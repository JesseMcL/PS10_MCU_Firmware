#!/usr/bin/env python3
"""Build the firmware with Microchip XC8 into a DFU image for tuya_mcu_dfu.

  python tools/build.py [--version X]

Compiles src/*.c for a PIC16F1 part with the same core (PIC16F18346: 5-bit
bank select, 16K words), linked at 0x600 behind the stock bootloader, RAM
limited to what the FT61E0A5 has (banks 0-12). Then converts the opcodes to the
FMD encoding and lays out the 20480-byte image like the stock one: words
0x000-0x5FF copied from the stock image (the bootloader discards them), the
application from 0x600.

Finds XC8 (xc8-cc) and the PIC16F1xxxx device pack (DFP) from XC8_CC / XC8_DFP,
PATH, or the usual install locations; see README.md.
"""
import argparse, glob, hashlib, os, re, shutil, subprocess, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, 'tools'))
import fmd  # noqa: E402

NAME = 'ps10-mcu'                      # image name
DEFAULT_VERSION = '0.2.0'
SOURCES = ['src/main.c', 'src/radar.c', 'src/tuya.c']

CPU = '16F18346'
STOCK = os.path.join(ROOT, 'reference', 'ps10-mcu-1.0.5.bin')
STOCK_MD5 = '9bd5f57fc1efad47a285cd7e0d951c7b'


def newest(pattern):
    found = sorted(glob.glob(pattern), key=lambda p: [int(x) if x.isdigit() else x for x in re.split(r'(\d+)', p)])
    return found[-1] if found else None


def find_xc8():
    if os.environ.get('XC8_CC'):
        return os.environ['XC8_CC']
    for cand in (shutil.which('xc8-cc'), newest('/opt/microchip/xc8/v*/bin/xc8-cc'),
                 newest('C:/Program Files/Microchip/xc8/v*/bin/xc8-cc.exe'),
                 newest(os.path.expanduser('~/xc8/v*/bin/xc8-cc'))):
        if cand:
            return cand
    sys.exit('xc8-cc not found: install MPLAB XC8 or set XC8_CC (see README.md)')


def find_dfp():
    if os.environ.get('XC8_DFP'):
        return os.environ['XC8_DFP']
    pats = ['/opt/microchip/packs/Microchip.PIC16F1xxxx_DFP/*/xc8',
            os.path.expanduser('~/.mchp_packs/Microchip/PIC16F1xxxx_DFP/*/xc8'),
            'C:/Program Files/Microchip/MPLABX/*/packs/Microchip/PIC16F1xxxx_DFP/*/xc8',
            os.path.join(ROOT, '.dfp', '*', 'xc8')]
    for p in pats:
        d = newest(p)
        if d:
            return d
    sys.exit('PIC16F1xxxx device pack not found: unzip the .atpack and set XC8_DFP to its xc8 folder (see README.md)')


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--version', default=DEFAULT_VERSION)
    ap.add_argument('--out', default=os.path.join(ROOT, 'build'))
    a = ap.parse_args()
    if not re.fullmatch(r'[0-9A-Za-z.+-]{1,20}', a.version):
        sys.exit('version: 1-20 characters of [0-9A-Za-z.+-]')
    stock = open(STOCK, 'rb').read()
    if hashlib.md5(stock).hexdigest() != STOCK_MD5:
        sys.exit('%s is not the stock 1.0.5 image' % STOCK)
    xc8, dfp = find_xc8(), find_dfp()

    os.makedirs(a.out, exist_ok=True)
    obj = os.path.join(a.out, 'obj')
    os.makedirs(obj, exist_ok=True)
    stem = os.path.join(a.out, '%s-%s' % (NAME, a.version))
    cmd = [xc8, '-mcpu=' + CPU, '-mdfp=' + dfp, '-O2', '-std=c99',
           '-mcodeoffset=0x600',              # reset 0x600, interrupt 0x604
           '-mrom=default,-2800-3FFF',        # 10K words
           '-mram=default,-670-CBF',          # banks 0-12 only
           '-Wl,-Map=' + stem + '.map', '-mwarn=0',
           '-DVERSION="%s"' % a.version, '-o', os.path.join(obj, NAME + '.hex')] + \
          [os.path.join(ROOT, s) for s in SOURCES]
    r = subprocess.run(cmd, capture_output=True, text=True, cwd=obj)
    out = (r.stdout + r.stderr).strip()
    if out:
        print(out)
    if r.returncode:
        sys.exit('xc8 failed')

    app = {k: v for k, v in fmd.read_ihex(os.path.join(obj, NAME + '.hex')).items() if k < 0x8000}
    if min(app) < fmd.APP_START or max(app) >= fmd.WORDS:
        sys.exit('code must stay in 0x600-0x27FF, got 0x%X-0x%X' % (min(app), max(app)))
    words = fmd.load_words(STOCK)[:fmd.APP_START] + [0x3FFF] * (fmd.WORDS - fmd.APP_START)
    for addr, w in app.items():
        words[addr] = fmd.pic_to_fmd(w)
    fmd.save_words(stem + '.bin', words)
    shutil.copy(os.path.join(obj, NAME + '.hex'), stem + '.hex')
    img = open(stem + '.bin', 'rb').read()
    md5, sha = hashlib.md5(img).hexdigest(), hashlib.sha256(img).hexdigest()
    print('\n%s.bin: %d bytes, code 0x%03X-0x%04X (%d words)' % (stem, len(img), min(app), max(app), len(app)))
    print('md5    %s\nsha256 %s' % (md5, sha))
    print('\ntuya_mcu_dfu:\n  firmware:\n    path: %s\n    version: "%s"\n    sha256: %s'
          % (os.path.basename(stem) + '.bin', a.version, sha))


if __name__ == '__main__':
    main()
