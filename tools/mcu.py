"""FT61E0A5 peripherals on top of the core emulator (emu.Cpu), for testing the
C firmware: ports and pins, TIM1/TIM2/TIM4, external interrupt EINT4 (PB4),
ADC, paced USART1 receive, and the stock bootloader's interrupt stub.

Timing model: 16 MHz SysClk, 2T instruction cycle -> 8 M instructions/s.
TIM1/TIM2 on 2 x HIRC (32 MHz) = 4 counts per instruction when TCKSRC selects
it (011), else SysClk = 2; TIM4 on SysClk = 2. Registers per the datasheet.
"""
import collections
from emu import Cpu, INTCON, BSR, PCLATH

IPS = 8_000_000                       # instructions per second
PORT = {'A': 0x00C, 'B': 0x00D, 'C': 0x00E}
TRIS = {'A': 0x08C, 'B': 0x08D, 'C': 0x08E}
LAT = {'A': 0x10C, 'B': 0x10D, 'C': 0x10E}
ADDR_PORT = {v: k for k, v in list(PORT.items()) + list(LAT.items())}

UR1DATAL, UR1IER, UR1LSR = 0x48C, 0x48E, 0x492
EPIF0, EPIE0, EPS1, ITYPE1 = 0x014, 0x094, 0x119, 0x11F
TCKSRC, PCKEN = 0x31F, 0x09A
ADCON0, ADRESL, ADRESH = 0x09D, 0x09B, 0x09C


class Timer:
    def __init__(self, name, cr1, ier, sr, egr, cnt, arr, psc, psc_kind, clock):
        self.name, self.cr1, self.ier, self.sr, self.egr = name, cr1, ier, sr, egr
        self.cnt, self.arr, self.psc, self.psc_kind, self.clock = cnt, arr, psc, psc_kind, clock
        self.count = 0
        self.frac = 0


class Mcu(Cpu):
    def __init__(self, flash, boot_stub=True, **kw):
        super().__init__(flash, **kw)
        self.boot_stub = boot_stub
        self.mem[0x020] = 0x01        # set by the bootloader before it starts the application
        self.pins = {'A': 0xFF, 'B': 0x7F, 'C': 0xFF}  # input levels (PB7 radar OUT low = nobody)
        self.pin_fn = {}              # port -> f(cycles) -> byte, overrides pins[]
        self.pin_log = []             # (cycle, port, new LAT value) on every change
        self.lat = {'A': 0, 'B': 0, 'C': 0}
        self.adc = {}                 # channel -> 12-bit value
        self.adc_done_at = None
        self.uart_gap = IPS // 960    # one 10-bit character at 9600 baud
        self.uart_next = 0
        self.last_pb4 = 1
        self.timers = []
        self.timer16 = [
            Timer('TIM1', 0x211, 0x215, 0x216, 0x218, (0x28C, 0x28D), (0x290, 0x291), (0x28E, 0x28F), 'lin', 1),
            Timer('TIM2', 0x30C, 0x30D, 0x30E, 0x310, (0x316, 0x317), (0x319, 0x31A), (0x318,), 'pow2', 2),
            Timer('TIM4', 0x111, 0x112, 0x113, 0x114, (0x115,), (0x117,), (0x116,), 'pow2', 4),
        ]
        for t in self.timer16:
            for a in t.arr:
                self.mem[a] = 0xFF
        self.by_addr = {}
        for t in self.timer16:
            for a in (t.cr1, t.ier, t.sr, t.egr) + t.cnt + t.arr + t.psc:
                self.by_addr[a] = t

    # --- helpers for tests ------------------------------------------------
    def ms(self, n):
        self.run(int(n * IPS / 1000))

    def pin(self, port, bit):
        """Driven output level (LAT) of a pin."""
        return (self.lat[port] >> bit) & 1

    def set_pin(self, port, bit, level):
        self.pins[port] = (self.pins[port] & ~(1 << bit)) | ((1 if level else 0) << bit)

    def input_level(self, port):
        f = self.pin_fn.get(port)
        return f(self.cycles) if f else self.pins[port]

    # --- registers ----------------------------------------------------------
    def read(self, a):
        if a in (0x00C, 0x00D, 0x00E):
            port = ADDR_PORT[a]
            tris = self.mem[TRIS[port]]
            return (self.input_level(port) & tris) | (self.lat[port] & ~tris & 0xFF)
        if a in (0x10C, 0x10D, 0x10E):
            return self.lat[ADDR_PORT[a]]
        if a == UR1DATAL:
            return self.rx.popleft() if self.rx and self.cycles >= self.uart_next and \
                self._take_uart() else 0
        if a == UR1LSR:
            return (1 if self.rx and self.cycles >= self.uart_next else 0) | 0x20
        t = self.by_addr.get(a)
        if t is not None and a in t.cnt:
            return (t.count >> 8) & 0xFF if (len(t.cnt) == 2 and a == t.cnt[0]) else t.count & 0xFF
        return super().read(a)

    def _take_uart(self):
        self.uart_next = self.cycles + self.uart_gap
        return True

    def write(self, a, v):
        v &= 0xFF
        if a in ADDR_PORT:
            port = ADDR_PORT[a]
            if self.lat[port] != v:
                self.lat[port] = v
                self.pin_log.append((self.cycles, port, v))
            return
        t = self.by_addr.get(a)
        if t is not None:
            if a == t.sr:                     # write 1 to clear
                self.mem[a] &= ~v
                return
            if a == t.egr:
                if v & 1:
                    t.count, t.frac = 0, 0
                return
            if a in t.cnt:
                if len(t.cnt) == 2:
                    t.count = (v << 8) | (t.count & 0xFF) if a == t.cnt[0] else (t.count & 0xFF00) | v
                else:
                    t.count = v
                return
        if a == EPIF0:
            self.mem[a] &= ~v
            return
        if a == ADCON0 and v & 0x02 and v & 0x01:
            self.adc_done_at = self.cycles + 30
        super().write(a, v)

    # --- time -----------------------------------------------------------------
    def tick_peripherals(self):
        for t in self.timer16:
            cr1 = self.mem[t.cr1]
            if not cr1 & 1:
                continue
            if t.name == 'TIM4':
                per = 2
            else:
                src = (self.mem[TCKSRC] >> (0 if t.name == 'TIM1' else 4)) & 7
                per = 4 if src == 3 else 2
            if t.psc_kind == 'lin':
                div = ((self.mem[t.psc[0]] << 8) | self.mem[t.psc[1]]) + 1
            else:
                div = 1 << (self.mem[t.psc[0]] & 0xF)
            t.frac += per
            if t.frac < div:
                continue
            t.count += t.frac // div
            t.frac %= div
            arr = (self.mem[t.arr[0]] << 8) | self.mem[t.arr[1]] if len(t.arr) == 2 else self.mem[t.arr[0]]
            if t.count > arr:
                t.count -= arr + 1
                self.mem[t.sr] |= 1
                if cr1 & 0x08:                # one-pulse mode
                    self.mem[t.cr1] &= ~1
        if self.adc_done_at is not None and self.cycles >= self.adc_done_at:
            self.adc_done_at = None
            ch = (self.mem[ADCON0] >> 4) & 7
            v = self.adc.get(ch, 0)
            self.mem[ADRESH], self.mem[ADRESL] = v >> 8, v & 0xFF   # right-justified (ADFM = 1)
            self.mem[ADCON0] &= ~0x02
        # EINT4 on PB4 (EPS1 = 01), edge per ITYPE1[1:0]
        if self.mem[EPS1] & 3 == 1:
            lvl = (self.input_level('B') >> 4) & 1
            if lvl != self.last_pb4:
                edge = self.mem[ITYPE1] & 3
                if (edge == 2 and not lvl) or (edge == 1 and lvl) or edge == 3:
                    self.mem[EPIF0] |= 0x10
                self.last_pb4 = lvl

    def irq_pending(self):
        ic = self.mem[INTCON]
        if not ic & 0x80:
            return False
        if not ic & 0x40:
            return False
        if self.rx and self.cycles >= self.uart_next and self.mem[UR1IER] & 1:
            return True
        if self.mem[EPIE0] & self.mem[EPIF0]:
            return True
        return any(self.mem[t.ier] & self.mem[t.sr] & 1 for t in self.timer16)

    def step(self):
        self.tick_peripherals()
        if not self.in_isr and self.irq_pending() and self.boot_stub:
            # the stock bootloader's vector: it sends interrupts to 0x604 only
            # while RAM 0x020 bit 0 is set, and it sets bit 0 of 0x7E on the way
            if not self.mem[0x020] & 1:
                raise RuntimeError('interrupt with RAM 0x020 bit 0 clear: the bootloader would handle it')
            self.mem[0x7E] |= 1
        super().step()


class SoftUartWire:
    """Drives an input pin with UART frames (8N1) from a byte queue."""
    def __init__(self, cpu, port, bit, baud=9600):
        self.cpu, self.port, self.bit = cpu, port, bit
        self.bitc = IPS / baud
        self.frames = collections.deque()     # (start cycle, byte)
        self.free_at = 0
        cpu.pin_fn[port] = self.level

    def send(self, data, at=None):
        t = max(self.cpu.cycles if at is None else at, self.free_at)
        for b in data:
            self.frames.append((t, b))
            t += 10 * self.bitc
        self.free_at = t

    def level(self, cycles):
        base = self.cpu.pins[self.port]
        while self.frames and cycles >= self.frames[0][0] + 10 * self.bitc:
            self.frames.popleft()
        if not self.frames or cycles < self.frames[0][0]:
            return base | (1 << self.bit)
        start, b = self.frames[0]
        n = int((cycles - start) // self.bitc)
        lvl = 0 if n == 0 else ((b >> (n - 1)) & 1 if n <= 8 else 1)
        return (base & ~(1 << self.bit)) | (lvl << self.bit)


def decode_uart(pin_log, port, bit, baud=9600, idle=1):
    """Bytes sent on an output pin, from the LAT change log."""
    bitc = IPS / baud
    edges = [(c, (v >> bit) & 1) for c, p, v in pin_log if p == port]
    # collapse to level changes
    lv, out = idle, []
    changes = []
    for c, l in edges:
        if l != lv:
            changes.append((c, l))
            lv = l

    def level_at(t):
        l = idle
        for c, x in changes:
            if c > t:
                break
            l = x
        return l
    i = 0
    while i < len(changes):
        c, l = changes[i]
        if l == 0:                            # start bit
            b = 0
            for k in range(8):
                b |= level_at(c + (1.5 + k) * bitc) << k
            out.append(b)
            end = c + 9.5 * bitc
            while i < len(changes) and changes[i][0] < end:
                i += 1
            continue
        i += 1
    return bytes(out)
