"""Minimal PIC16F1 (enhanced mid-range) core emulator with the few FT61E0A5
peripherals the PS10 firmware uses (register addresses per the FT61E0Ax
datasheet V1.02, docs/datasheets/).

Images are given in PIC encoding (convert FMD images with fmd2pic first).
Peripheral model (hypotheses, see docs/ft61e0a5-notes.md):
  USART1 (Tuya link): UR1DATAL 0x48C, UR1IER 0x48E (bit0 RXNE interrupt enable),
                    UR1LSR 0x492 (bit0 RXNEF, bit5 TXEF)
  NVM: EEADRL 0x191, EEADRH 0x192, EEDATL 0x193, EEDATH 0x194,
       EECON1 0x195 (RD 0, WR 1, WREN 2, CFGS 6, EEPGD 7), EECON2 0x196.
       Data is valid 2 instruction cycles after RD for PROM/UCFG and 4 for DATA
       EEPROM (datasheet 10.3.3 / 10.3.4); reading it earlier raises an error.
"""
import collections

INDF0, INDF1, PCL, STATUS, FSR0L, FSR0H, FSR1L, FSR1H, BSR, WREG, PCLATH, INTCON = range(12)
C, DC, Z = 0, 1, 2
UART_DATA, UART_IER, UART_STAT = 0x48C, 0x48E, 0x492
EEADRL, EEADRH, EEDATL, EEDATH, EECON1, EECON2 = 0x191, 0x192, 0x193, 0x194, 0x195, 0x196


class Reset(Exception):
    pass


class Cpu:
    def __init__(self, flash, eeprom=None, config=None, flash_size=0x2800):
        self.flash = list(flash) + [0x3FFF] * (flash_size - len(flash))
        self.ee = list(eeprom or [0xFF] * 128)
        self.cfg = dict(config or {})          # CFGS space: addr -> 14-bit word
        self.mem = [0] * 0x1000                 # traditional address space (banked)
        self.pc = 0x600
        self.stack = []
        self.rx = collections.deque()
        self.tx = bytearray()
        self.ee_unlock = 0
        self.resets = 0
        self.cycles = 0
        self.ee_writes = []
        self.rd_at = None                       # (cycle, cycles needed) of the last NVM read
        self.trace_sfr = set()
        self.sfr_log = []
        self.in_isr = False
        self.isr_vector = 0x604
        self.shadow = None
        self.inputs = {}                        # addr -> (mask, value) forced input bits
        self.timers = []                        # [enable addr, bit, flag addr, bit, period, next]

    # --- data memory ---------------------------------------------------
    def addr(self, f):
        if f >= 0x70:
            return f & 0x7F                      # common RAM 0x70..0x7F
        return ((self.mem[BSR] & 0x1F) << 7) | f

    def fsr(self, n):
        lo, hi = (FSR0L, FSR0H) if n == 0 else (FSR1L, FSR1H)
        return (self.mem[hi] << 8) | self.mem[lo]

    def set_fsr(self, n, v):
        v &= 0xFFFF
        lo, hi = (FSR0L, FSR0H) if n == 0 else (FSR1L, FSR1H)
        self.mem[lo], self.mem[hi] = v & 0xFF, v >> 8

    def lin(self, a):
        """FSR address -> ('mem', traditional addr) or ('flash', word)"""
        if a >= 0x8000:
            return 'flash', a & 0x7FFF
        if 0x2000 <= a < 0x29B0:
            o = a - 0x2000
            return 'mem', ((o // 80) << 7) + 0x20 + (o % 80)
        return 'mem', a & 0xFFF

    def rd_ind(self, a):
        kind, x = self.lin(a)
        if kind == 'flash':
            return self.flash[x] & 0xFF if x < len(self.flash) else 0xFF
        return self.read(x)

    def wr_ind(self, a, v):
        kind, x = self.lin(a)
        if kind == 'mem':
            self.write(x, v)

    def read(self, a):
        f = a & 0x7F
        if f == INDF0:
            return self.rd_ind(self.fsr(0))
        if f == INDF1:
            return self.rd_ind(self.fsr(1))
        if f < 0x0C:
            return self.mem[f] if f != PCL else self.pc & 0xFF
        if f >= 0x70:
            return self.mem[f]
        if a == UART_DATA:
            return self.rx.popleft() if self.rx else 0
        if a == UART_STAT:
            return (1 if self.rx else 0) | 0x20 | (self.mem[a] & ~0x21)
        if a in self.trace_sfr:
            self.sfr_log.append(('r', self.pc, a))
        if a in (EEDATL, EEDATH) and self.rd_at and self.cycles - self.rd_at[0] <= self.rd_at[1]:
            raise RuntimeError('EEDAT read %d cycles after RD at %04x (needs %d)'
                               % (self.cycles - self.rd_at[0] - 1, self.pc - 1, self.rd_at[1]))
        if a in self.inputs:
            return (self.mem[a] & ~self.inputs[a][0]) | self.inputs[a][1]
        return self.mem[a]

    def write(self, a, v):
        v &= 0xFF
        f = a & 0x7F
        if f == INDF0:
            return self.wr_ind(self.fsr(0), v)
        if f == INDF1:
            return self.wr_ind(self.fsr(1), v)
        if f < 0x0C or f >= 0x70:
            if f == PCL:
                self.pc = ((self.mem[PCLATH] & 0x7F) << 8) | v
                self.jumped = True
                return
            self.mem[f] = v
            return
        if a in self.trace_sfr:
            self.sfr_log.append(('w', self.pc, a, v))
        if a == UART_DATA:
            self.tx.append(v)
            return
        if a in getattr(self, 'w1c', ()):
            self.mem[a] &= ~v
            return
        if a == EECON2:
            self.ee_unlock = (self.ee_unlock << 8 | v) & 0xFFFF
            return
        if a == EECON1:
            old = self.mem[a]
            self.mem[a] = v & ~0x03
            if v & 0x01:                               # RD
                self.nvm_read()
            if v & 0x02 and not old & 0x02:            # WR
                if not v & 0x04 or self.ee_unlock != 0x55AA:
                    raise RuntimeError('EEPROM write without WREN/unlock at %04x' % self.pc)
                self.nvm_write()
            self.ee_unlock = 0
            return
        self.mem[a] = v

    def nvm_read(self):
        ad = self.mem[EEADRH] << 8 | self.mem[EEADRL]
        c = self.mem[EECON1]
        self.rd_at = (self.cycles, 2 if c & 0xC0 else 4)
        if c & 0x80 or c & 0x40:
            if c & 0x40:
                w = self.cfg.get(ad & 0xFF, 0x3FFF)
            else:
                # the stored word, i.e. FMD encoding (confirmed by a dump from hardware)
                w = self.flash[ad & 0x7FFF] if (ad & 0x7FFF) < len(self.flash) else 0x3FFF
                w = ((((w >> 12) + 1) & 3) << 12) | (w & 0xFFF) if w != 0x3FFF else w
            self.mem[EEDATL], self.mem[EEDATH] = w & 0xFF, (w >> 8) & 0x3F
        else:
            self.mem[EEDATL] = self.ee[self.mem[EEADRL] & 0x7F]

    def nvm_write(self):
        c = self.mem[EECON1]
        if c & 0xC0:
            raise RuntimeError('flash/config write attempted at %04x' % self.pc)
        a = self.mem[EEADRL] & 0x7F
        self.ee[a] = self.mem[EEDATL]
        self.ee_writes.append((a, self.mem[EEDATL]))

    # --- execution --------------------------------------------------------
    def add_timer(self, en, en_bit, flag, flag_bit, period):
        """Periodic interrupt source; the flag is write-1-to-clear (as the stock ISR treats it)."""
        self.timers.append([en, en_bit, flag, flag_bit, period, period])
        self.w1c = getattr(self, 'w1c', set()) | {flag}

    def irq_pending(self):
        for t in self.timers:
            if self.cycles >= t[5]:
                t[5] += t[4]
                if self.mem[t[0]] >> t[1] & 1:
                    self.mem[t[2]] |= 1 << t[3]
        ic = self.mem[INTCON]
        if not ic & 0x80:
            return False
        if ic & 0x40 and any(self.mem[t[0]] >> t[1] & 1 and self.mem[t[2]] >> t[3] & 1 for t in self.timers):
            return True
        if self.rx and self.mem[UART_IER] & 1 and ic & 0x40:
            return True
        return False

    def flags_zc(self, r):
        self.setb(Z, (r & 0xFF) == 0)

    def setb(self, bit, cond):
        if cond:
            self.mem[STATUS] |= 1 << bit
        else:
            self.mem[STATUS] &= ~(1 << bit)

    def push(self, ret):
        if len(self.stack) >= 16:
            raise RuntimeError('stack overflow at %04x' % self.pc)
        self.stack.append(ret)

    def step(self):
        if not self.in_isr and self.irq_pending():
            self.push(self.pc)
            self.shadow = [self.mem[r] for r in (WREG, STATUS, BSR, PCLATH, FSR0L, FSR0H, FSR1L, FSR1H)]
            self.mem[INTCON] &= ~0x80
            self.in_isr = True
            self.pc = self.isr_vector
            self.mem[PCLATH] = 0
        pc = self.pc
        w = self.flash[pc]
        self.pc = pc + 1
        self.jumped = False
        self.cycles += 1
        self.exec(w, pc)

    def alu_f(self, w, op):
        d = (w >> 7) & 1
        a = self.addr(w & 0x7F)
        return d, a

    def store(self, d, a, r):
        r &= 0xFF
        if d:
            self.write(a, r)
        else:
            self.mem[WREG] = r

    def skip(self):
        self.pc += 1

    def exec(self, w, pc):
        W = self.mem[WREG]
        top = w >> 12
        if top == 0:
            if w & 0x3F80 == 0x0080:                      # MOVWF
                self.write(self.addr(w & 0x7F), W); return
            if w < 0x80:
                if w == 0x0000: return
                if w == 0x0001: raise Reset()
                if w == 0x0008: self.pc = self.stack.pop(); return
                if w == 0x0009:
                    self.pc = self.stack.pop()
                    if self.shadow:
                        for r, v in zip((WREG, STATUS, BSR, PCLATH, FSR0L, FSR0H, FSR1L, FSR1H), self.shadow):
                            self.mem[r] = v
                    self.mem[INTCON] |= 0x80; self.in_isr = False; return
                if w == 0x000A:
                    self.push(self.pc); self.pc = ((self.mem[PCLATH] & 0x7F) << 8) | W; return
                if w == 0x000B:
                    self.pc = (((self.mem[PCLATH] & 0x7F) << 8) | 0) + ((pc + 1) & 0x7FFF) - (pc + 1) + pc + 1 + W
                    self.pc = (pc + 1 + W) & 0x7FFF; return
                if 0x10 <= w <= 0x1F:
                    n = (w >> 2) & 1; mm = w & 3; f = self.fsr(n)
                    if mm == 0: f += 1; addr = f
                    elif mm == 1: f -= 1; addr = f
                    elif mm == 2: addr = f; f += 1
                    else: addr = f; f -= 1
                    self.set_fsr(n, f)
                    if w & 0x08:
                        self.wr_ind(addr & 0xFFFF, W)
                    else:
                        v = self.rd_ind(addr & 0xFFFF); self.mem[WREG] = v; self.setb(Z, v == 0)
                    return
                if 0x20 <= w <= 0x3F: self.mem[BSR] = w & 0x1F; return
                if w == 0x0062 or 0x65 <= w <= 0x67: return
                if w == 0x0063: raise RuntimeError('SLEEP at %04x' % pc)
                if w == 0x0064: return
                raise RuntimeError('bad opcode %04x at %04x' % (w, pc))
            sub = (w >> 8) & 0xF
            if sub == 1:
                if w & 0x80: self.write(self.addr(w & 0x7F), 0)
                else: self.mem[WREG] = 0
                self.setb(Z, True); return
            d, a = self.alu_f(w, sub)
            f = self.read(a)
            if sub == 2:   # SUBWF
                r = f - W; self.setb(C, r >= 0); self.setb(DC, (f & 0xF) - (W & 0xF) >= 0); self.flags_zc(r); self.store(d, a, r)
            elif sub == 3: r = f - 1; self.flags_zc(r); self.store(d, a, r)
            elif sub == 4: r = f | W; self.flags_zc(r); self.store(d, a, r)
            elif sub == 5: r = f & W; self.flags_zc(r); self.store(d, a, r)
            elif sub == 6: r = f ^ W; self.flags_zc(r); self.store(d, a, r)
            elif sub == 7: r = f + W; self.setb(C, r > 0xFF); self.setb(DC, (f & 0xF) + (W & 0xF) > 0xF); self.flags_zc(r); self.store(d, a, r)
            elif sub == 8: self.flags_zc(f); self.store(d, a, f)
            elif sub == 9: r = ~f; self.flags_zc(r); self.store(d, a, r)
            elif sub == 10: r = f + 1; self.flags_zc(r); self.store(d, a, r)
            elif sub == 11:
                r = (f - 1) & 0xFF; self.store(d, a, r)
                if r == 0: self.skip()
            elif sub == 12:
                c = self.mem[STATUS] & 1; r = (f >> 1) | (c << 7); self.setb(C, f & 1); self.store(d, a, r)
            elif sub == 13:
                c = self.mem[STATUS] & 1; r = (f << 1) | c; self.setb(C, f & 0x80); self.store(d, a, r)
            elif sub == 14: self.store(d, a, ((f << 4) | (f >> 4)))
            elif sub == 15:
                r = (f + 1) & 0xFF; self.store(d, a, r)
                if r == 0: self.skip()
            else: raise RuntimeError('bad opcode %04x at %04x' % (w, pc))
            return
        if top == 1:
            b = (w >> 7) & 7; a = self.addr(w & 0x7F); kind = (w >> 10) & 3
            if kind == 0: self.write(a, self.read(a) & ~(1 << b))
            elif kind == 1: self.write(a, self.read(a) | (1 << b))
            elif kind == 2:
                if not self.read(a) >> b & 1: self.skip()
            else:
                if self.read(a) >> b & 1: self.skip()
            return
        if top == 2:
            k = w & 0x7FF; tgt = ((self.mem[PCLATH] & 0x78) << 8) | k
            if not w & 0x800: self.push(self.pc)
            self.pc = tgt; return
        # top == 3
        k = w & 0xFF; sub = (w >> 8) & 0xF
        if sub == 0: self.mem[WREG] = k; return
        if sub == 1:
            if w & 0x80: self.mem[PCLATH] = w & 0x7F; return
            n = (w >> 6) & 1; kk = w & 0x3F; kk = kk - 64 if kk & 0x20 else kk
            self.set_fsr(n, self.fsr(n) + kk); return
        if sub in (2, 3):
            kk = w & 0x1FF; kk = kk - 512 if kk & 0x100 else kk
            self.pc = (pc + 1 + kk) & 0x7FFF; return
        if sub == 4: self.mem[WREG] = k; self.pc = self.stack.pop(); return
        if sub in (5, 6, 7, 11, 13):
            d = (w >> 7) & 1; a = self.addr(w & 0x7F); f = self.read(a)
            if sub == 5: r = f << 1; self.setb(C, f & 0x80); self.flags_zc(r)
            elif sub == 6: r = f >> 1; self.setb(C, f & 1); self.flags_zc(r)
            elif sub == 7: r = (f >> 1) | (f & 0x80); self.setb(C, f & 1); self.flags_zc(r)
            elif sub == 11:
                c = self.mem[STATUS] & 1; r = f - W - (1 - c); self.setb(C, r >= 0); self.flags_zc(r)
            else:
                c = self.mem[STATUS] & 1; r = f + W + c; self.setb(C, r > 0xFF); self.flags_zc(r)
            self.store(d, a, r); return
        if sub == 8: r = W | k; self.flags_zc(r); self.mem[WREG] = r & 0xFF; return
        if sub == 9: r = W & k; self.flags_zc(r); self.mem[WREG] = r & 0xFF; return
        if sub == 10: r = W ^ k; self.flags_zc(r); self.mem[WREG] = r & 0xFF; return
        if sub == 12: r = k - W; self.setb(C, r >= 0); self.setb(DC, (k & 0xF) - (W & 0xF) >= 0); self.flags_zc(r); self.mem[WREG] = r & 0xFF; return
        if sub == 14: r = W + k; self.setb(C, r > 0xFF); self.setb(DC, (W & 0xF) + (k & 0xF) > 0xF); self.flags_zc(r); self.mem[WREG] = r & 0xFF; return
        if sub == 15:
            n = (w >> 6) & 1; kk = w & 0x3F; kk = kk - 64 if kk & 0x20 else kk
            a = (self.fsr(n) + kk) & 0xFFFF
            if w & 0x80: self.wr_ind(a, W)
            else:
                v = self.rd_ind(a); self.mem[WREG] = v; self.setb(Z, v == 0)
            return
        raise RuntimeError('bad opcode %04x at %04x' % (w, pc))

    def run(self, n):
        for _ in range(n):
            self.step()


def frame(cmd, data=b'', ver=0):
    f = bytes([0x55, 0xAA, ver, cmd, len(data) >> 8, len(data) & 0xFF]) + bytes(data)
    return f + bytes([sum(f) & 0xFF])


def parse(buf):
    out = []
    i = 0
    while True:
        i = buf.find(b'\x55\xaa', i)
        if i < 0 or len(buf) - i < 7: break
        n = buf[i + 4] << 8 | buf[i + 5]
        if len(buf) - i < 7 + n: break
        f = buf[i:i + 7 + n]
        out.append((f[2], f[3], bytes(f[6:6 + n]), sum(f[:-1]) & 0xFF == f[-1]))
        i += 7 + n
    return out
