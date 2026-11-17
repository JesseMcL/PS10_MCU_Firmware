#!/usr/bin/env python3
"""Disassemble an FT61E0A5 (FMD-encoded) image into gpasm source that
reassembles to the same words.

  python tools/disasm.py image.bin > image.asm

Operands are numeric; call/goto/bra targets get labels (L_xxxx). A call or goto
only encodes the low 11 bits of its target, so its label is chosen from the
nearest preceding movlp in the same straight-line code, or the current page:
either way the encoding is the same. Erased words (0x3FFF) are skipped with org. File register operands are
commented with the datasheet name where the bank is known from a preceding
movlb in straight-line code (tools/ft61e0a5_sfr.json).
"""
import json, os, re, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import fmd

BYTE_OPS = {2: 'subwf', 3: 'decf', 4: 'iorwf', 5: 'andwf', 6: 'xorwf', 7: 'addwf', 8: 'movf', 9: 'comf',
            10: 'incf', 11: 'decfsz', 12: 'rrf', 13: 'rlf', 14: 'swapf', 15: 'incfsz'}
LIT_OPS = {0: 'movlw', 4: 'retlw', 8: 'iorlw', 9: 'andlw', 10: 'xorlw', 12: 'sublw', 14: 'addlw'}
F3_OPS = {5: 'lslf', 6: 'lsrf', 7: 'asrf', 11: 'subwfb', 13: 'addwfc'}
BIT_OPS = ['bcf', 'bsf', 'btfsc', 'btfss']
SIMPLE = {0x0000: 'nop', 0x0001: 'reset', 0x0008: 'return', 0x0009: 'retfie', 0x000A: 'callw',
          0x000B: 'brw', 0x0062: 'option', 0x0063: 'sleep', 0x0064: 'clrwdt'}


def s6(k):
    return k - 64 if k & 0x20 else k


def decode(w, addr, page):
    """-> (text, branch target or None). page: PCLATH<6:3> guess for call/goto."""
    top = w >> 12
    if top == 0:
        if w in SIMPLE:
            return SIMPLE[w], None
        if 0x10 <= w <= 0x1F:
            n, mm = (w >> 2) & 1, w & 3
            op = 'movwi' if w & 8 else 'moviw'
            fsr = 'FSR%d' % n
            return '%s %s' % (op, ['++' + fsr, '--' + fsr, fsr + '++', fsr + '--'][mm]), None
        if 0x20 <= w <= 0x3F:
            return 'movlb 0x%02X' % (w & 0x1F), None
        if 0x65 <= w <= 0x67:
            return 'tris 0x%X' % (w & 7), None
        if w & 0x3F80 == 0x0080:
            return 'movwf 0x%02X' % (w & 0x7F), None
        if w & 0x3F80 == 0x0100 and w == 0x0100:
            return 'clrw', None
        if w & 0x3F80 == 0x0180:
            return 'clrf 0x%02X' % (w & 0x7F), None
        sub = (w >> 8) & 0xF
        if sub in BYTE_OPS:
            return '%s 0x%02X, %d' % (BYTE_OPS[sub], w & 0x7F, (w >> 7) & 1), None
        return None, None
    if top == 1:
        return '%s 0x%02X, %d' % (BIT_OPS[(w >> 10) & 3], w & 0x7F, (w >> 7) & 7), None
    if top == 2:
        k = w & 0x7FF
        return ('call' if not w & 0x800 else 'goto'), (page << 11) | k
    sub = (w >> 8) & 0xF
    if sub in LIT_OPS:
        return '%s 0x%02X' % (LIT_OPS[sub], w & 0xFF), None
    if sub == 1:
        if w & 0x80:
            return 'movlp 0x%02X' % (w & 0x7F), None
        return 'addfsr FSR%dL, %d' % ((w >> 6) & 1, s6(w & 0x3F)), None
    if sub in (2, 3):
        k = w & 0x1FF
        k = k - 512 if k & 0x100 else k
        return 'bra', addr + 1 + k
    if sub in F3_OPS:
        return '%s 0x%02X, %d' % (F3_OPS[sub], w & 0x7F, (w >> 7) & 1), None
    if sub == 15:
        op = 'movwi' if w & 0x80 else 'moviw'
        return '%s %d[FSR%d]' % (op, s6(w & 0x3F), (w >> 6) & 1), None
    return None, None


CORE = ['INDF0', 'INDF1', 'PCL', 'STATUS', 'FSR0L', 'FSR0H', 'FSR1L', 'FSR1H', 'BSR', 'WREG', 'PCLATH', 'INTCON']
SFR = {int(k, 16): v for k, v in json.load(open(os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                                              'ft61e0a5_sfr.json'))).items()}


def reg_name(f, bank):
    if f < 0x0C:
        return CORE[f]
    if f >= 0x70:
        return 'common 0x%02X' % f
    if bank is None:
        return None
    a = bank * 0x80 + f
    if f < 0x20:
        return SFR.get(a, 'SFR 0x%03X' % a)
    return None


def main():
    words = [fmd.fmd_to_pic(w) for w in fmd.load_words(sys.argv[1])]
    # pass 1: decode, with a movlp guess for call/goto targets
    out, targets, page = [], set(), None
    for a, w in enumerate(words):
        if w == 0x3FFF:
            out.append(None)
            page = None
            continue
        text, tgt = decode(w, a, page if page is not None else (a >> 11))
        if text is None:
            out.append(('dw 0x%04X' % w, None))
            continue
        if tgt is not None:
            targets.add(tgt)
        out.append((text, tgt))
        if text.startswith('movlp'):
            page = (int(text.split()[1], 16) >> 3) & 0xF
        elif text in ('return', 'retfie', 'brw', 'callw') or text.startswith(('retlw', 'goto', 'bra')):
            page = None
    print('; FT61E0A5 image, reassembles to the original words (tools/disasm.py)')
    print('        processor 16f1789   ; any PIC16F1 with >= 10K words; only the core matters')
    print('        radix   dec')
    print('        errorlevel -302, -306, -202')
    print('FSR0    equ 0           ; moviw/movwi operand')
    print('FSR1    equ 1')
    print('FSR0L   equ 4           ; addfsr operand')
    print('FSR1L   equ 6\n')
    expect, bank = None, None
    for a, item in enumerate(out):
        if item is None:
            bank = None
            continue
        if a != expect:
            print('\n        org 0x%04X' % a)
            bank = None
        if a in targets:
            print('L_%04X:' % a)
            bank = None
        text, tgt = item
        comment = ''
        m = re.match(r'(\w+) 0x([0-9A-F]{2})(,|$)', text)
        if m and m.group(1) not in ('movlw', 'retlw', 'iorlw', 'andlw', 'xorlw', 'sublw', 'addlw', 'movlb', 'movlp'):
            name = reg_name(int(m.group(2), 16), bank)
            if name:
                comment = '    ; ' + name
        if tgt is not None:
            text = '%s L_%04X' % (text, tgt)
        print('        %-24s%s' % (text, comment) if comment else '        ' + text)
        if text.startswith('movlb'):
            bank = int(text.split()[1], 16)
        elif text.startswith(('call', 'callw')):
            bank = None
        expect = a + 1
    # labels that fall on erased words or outside the image still need a value
    for t in sorted(targets):
        if t >= len(out) or out[t] is None:
            print('L_%04X  equ 0x%04X' % (t, t))
    print('\n        end')


if __name__ == '__main__':
    main()
