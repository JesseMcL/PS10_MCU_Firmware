"""FMD FT61E0Ax <-> PIC16F1 instruction encoding, and image helpers.

The FT61E0A5 executes the PIC16F1 (enhanced mid-range) instruction set with
opcode bits 13:12 rotated: FMD = (PIC + 1) mod 4. Everything else is identical.
Erased words (0x3FFF) are left alone. Images are 14-bit words, little endian.
"""
import struct

WORDS = 0x2800          # 10K words of program flash
APP_START = 0x600       # the stock bootloader lives below this


def pic_to_fmd(w):
    if w == 0x3FFF:
        return w
    return ((((w >> 12) + 1) & 3) << 12) | (w & 0xFFF)


def fmd_to_pic(w):
    if w == 0x3FFF:
        return w
    return ((((w >> 12) - 1) & 3) << 12) | (w & 0xFFF)


def load_words(path):
    d = open(path, 'rb').read()
    return list(struct.unpack('<%dH' % (len(d) // 2), d))


def save_words(path, words):
    open(path, 'wb').write(struct.pack('<%dH' % len(words), *words))


def read_ihex(path):
    """Intel HEX (byte addresses, as gpasm writes for 14-bit parts) -> {word addr: word}"""
    data, base = {}, 0
    for line in open(path):
        line = line.strip()
        if not line.startswith(':'):
            continue
        b = bytes.fromhex(line[1:])
        n, addr, typ = b[0], b[1] << 8 | b[2], b[3]
        if typ == 0:
            for i in range(n):
                data[base + addr + i] = b[4 + i]
        elif typ == 4:
            base = (b[4] << 8 | b[5]) << 16
    words = {}
    for a in sorted(data):
        if a % 2 == 0 and a + 1 in data:
            words[a // 2] = data[a] | data[a + 1] << 8
    return words


if __name__ == '__main__':
    import sys
    a = sys.argv[1:]
    if len(a) < 2:
        sys.exit('usage: fmd.py in.bin out.bin [--reverse]   (FMD -> PIC, or PIC -> FMD with --reverse)')
    conv = pic_to_fmd if '--reverse' in a else fmd_to_pic
    save_words(a[1], [conv(w) for w in load_words(a[0])])
