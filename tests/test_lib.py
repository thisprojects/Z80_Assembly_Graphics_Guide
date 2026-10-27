"""Behavioural tests for lib/*.asm, run on an emulated Z80.  See tests/README.md."""
import os, re, subprocess, random, sys, tempfile
import z80

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
S = tempfile.mkdtemp(prefix='z80tests_')

# ---- build every lib file into one image ---------------------------------
# row_table is supplied by the program that uses build_row_table/get_row_addr
with open(f'{S}/all.asm', 'w') as f:
    f.write('row_table EQU $B000\n    ORG $8000\n')
    for name in sorted(os.listdir(f'{ROOT}/lib')):
        if name.endswith('.asm'): f.write(f'    INCLUDE "lib/{name}"\n')
subprocess.run(['sjasmplus', '--nologo', f'--sym={S}/all.sym', f'--raw={S}/all.bin', f'{S}/all.asm'],
               check=True, capture_output=True, cwd=ROOT)
SYM = {}
for l in open(f'{S}/all.sym'):
    m = re.match(r'(\w+):\s+EQU\s+0x([0-9A-Fa-f]+)', l)
    if m: SYM[m.group(1)] = int(m.group(2), 16)
CODE = open(f'{S}/all.bin', 'rb').read()

RET_ADDR = 0x1000
STACK = 0xFFF0


class Sim:
    def __init__(self):
        self.m = z80.Z80Machine()
        self.v = self.m.get_state_view()
        self.m.set_memory_block(0x8000, CODE)
        self.m.set_breakpoint(RET_ADDR)
        self.out = []
        self.m.set_output_callback(lambda p, val: self.out.append((p, val)))

    # memory (state view layout: 44 bytes of state, then 64K RAM)
    def rd(self, a): return self.v[44 + a]
    def wr(self, a, val): self.m.set_memory_block(a, bytes([val & 255]))
    def block(self, a, n): return bytes(self.v[44 + a:44 + a + n])
    def put(self, a, data): self.m.set_memory_block(a, bytes(data))
    def zero(self, a, n): self.put(a, bytes(n))

    def call(self, label, ticks=50_000_000, **regs):
        m = self.m
        for k, val in regs.items(): setattr(m, k, val)
        m.sp = STACK
        self.put(STACK, [RET_ADDR & 255, RET_ADDR >> 8])
        m.pc = SYM[label] if isinstance(label, str) else label
        total = 0
        while m.pc != RET_ADDR:
            m.ticks_to_stop = 10_000_000
            m.run()
            total += 1
            assert total < 500, f'{label}: runaway (pc={m.pc:#06x})'
        assert m.pc == RET_ADDR, f'{label}: did not return (pc={m.pc:#06x})'
        assert m.sp == STACK + 2, f'{label}: SP not restored ({m.sp:#06x})'
        return m

    # screen helpers
    def pix(self, x, y, base=0x4000):
        a = base + ((y & 0xC0) << 5) + ((y & 7) << 8) + ((y & 0x38) << 2) + (x >> 3)
        return (self.rd(a) >> (7 - (x & 7))) & 1

    def bitmap(self, base=0x4000):
        return {(x, y) for y in range(192) for x in range(256) if self.pix(x, y, base)}

    def clear_screen(self):
        self.zero(0x4000, 6144)


def screen_addr(x, y):
    return 0x4000 + ((y & 0xC0) << 5) + ((y & 7) << 8) + ((y & 0x38) << 2) + (x >> 3)


RESULTS = []
def test(fn):
    try:
        fn(); RESULTS.append((fn.__name__, True, ''))
    except Exception as e:
        RESULTS.append((fn.__name__, False, f'{type(e).__name__}: {e}'))
    return fn


# ---- address / attribute -------------------------------------------------
@test
def calc_pixel_addr():
    s = Sim()
    for y in range(192):
        for x in range(256):
            m = s.call('calc_pixel_addr', b=y, c=x)
            assert m.hl == screen_addr(x, y), (x, y, hex(m.hl))
            assert m.a == 0x80 >> (x & 7), (x, y, m.a)
            assert m.c == x, 'C not preserved'

@test
def calc_attr_addr():
    s = Sim()
    for y in range(192):
        for x in range(0, 256, 3):
            m = s.call('calc_attr_addr', b=y, c=x)
            assert m.hl == 0x5800 + (y >> 3) * 32 + (x >> 3), (x, y, hex(m.hl))

@test
def set_attr():
    s = Sim(); s.zero(0x5800, 768)
    s.call('set_attr', b=100, c=77, a=0x47)
    assert s.rd(0x5800 + 12 * 32 + 9) == 0x47
    assert sum(s.block(0x5800, 768)) == 0x47

@test
def fill_screen_attr_both():
    for name in ('fill_screen_attr', 'fill_screen_attr_fast'):
        s = Sim(); s.zero(0x5800, 768); s.wr(0x5B00, 0xAA)
        s.call(name, a=0x38)
        assert s.block(0x5800, 768) == bytes([0x38]) * 768, name
        assert s.rd(0x5B00) == 0xAA, name + ' overran'

@test
def fill_attr_cells():
    s = Sim(); s.zero(0x5800, 768)
    s.call('fill_attr_cells', a=0x12, b=5, c=3, e=10)
    exp = bytearray(768)
    for i in range(10): exp[5 * 32 + 3 + i] = 0x12
    assert s.block(0x5800, 768) == bytes(exp)
    s.call('fill_attr_cells', a=0x34, b=0, c=0, e=0)   # 0 does nothing
    assert s.block(0x5800, 768) == bytes(exp)

# ---- pixels ---------------------------------------------------------------
@test
def pixel_ops():
    s = Sim()
    random.seed(1)
    pts = [(random.randrange(256), random.randrange(192)) for _ in range(400)] + [(0, 0), (255, 191), (255, 0), (0, 191)]
    for x, y in pts:
        s.clear_screen(); s.call('set_pixel', b=y, c=x)
        assert s.bitmap() == {(x, y)}, ('set', x, y)
        s.call('toggle_pixel', b=y, c=x); assert s.bitmap() == set(), ('toggle', x, y)
        s.call('toggle_pixel', b=y, c=x); assert s.bitmap() == {(x, y)}
        s.call('clear_pixel', b=y, c=x); assert s.bitmap() == set(), ('clear', x, y)
    # clear must not disturb neighbours
    s.put(0x4000, [0xFF]); s.call('clear_pixel', b=0, c=3)
    assert s.rd(0x4000) == 0xEF

# ---- lines / shapes -------------------------------------------------------
@test
def draw_hline():
    s = Sim()
    for (y, x1, x2) in [(0, 0, 255), (10, 5, 5), (50, 3, 4), (100, 7, 8), (191, 0, 7), (77, 13, 200), (130, 250, 255), (5, 8, 15), (5, 1, 16)]:
        s.clear_screen(); s.call('draw_hline', b=y, c=x1, d=x2)
        assert s.bitmap() == {(x, y) for x in range(x1, x2 + 1)}, (y, x1, x2)

@test
def draw_vline():
    s = Sim()
    for (x, y1, y2) in [(0, 0, 191), (10, 5, 5), (255, 7, 8), (100, 3, 70), (33, 60, 130), (128, 190, 191), (5, 0, 63), (5, 64, 127)]:
        s.clear_screen(); s.call('draw_vline', b=y1, c=x, d=y2)
        assert s.bitmap() == {(x, y) for y in range(y1, y2 + 1)}, (x, y1, y2)

def bres(x1, y1, x2, y2):
    pts = []; dx = abs(x2 - x1); dy = abs(y2 - y1)
    sx = 1 if x1 < x2 else -1; sy = 1 if y1 < y2 else -1
    err = dx - dy; x, y = x1, y1
    while True:
        pts.append((x, y))
        if (x, y) == (x2, y2): break
        e2 = 2 * err
        if e2 > -dy: err -= dy; x += sx
        if e2 < dx: err += dx; y += sy
    return set(pts)

@test
def draw_line():
    s = Sim(); random.seed(2)
    cases = [(0, 0, 255, 191), (255, 191, 0, 0), (0, 191, 255, 0), (10, 10, 10, 10), (5, 5, 200, 5), (5, 5, 5, 150),
             (0, 0, 191, 191), (20, 100, 20, 30), (100, 20, 30, 20)]
    cases += [(random.randrange(256), random.randrange(192), random.randrange(256), random.randrange(192)) for _ in range(60)]
    for x1, y1, x2, y2 in cases:
        s.clear_screen(); s.call('draw_line', b=y1, c=x1, d=y2, e=x2)
        got = s.bitmap(); ref = bres(x1, y1, x2, y2)
        assert (x1, y1) in got and (x2, y2) in got, ('endpoints', x1, y1, x2, y2)
        # connected, one pixel per major-axis step, and hugs the ideal line
        major = max(abs(x2 - x1), abs(y2 - y1)) + 1
        assert len(got) == major, ('pixel count', (x1, y1, x2, y2), len(got), major)
        for (px, py) in got:
            dx, dy = x2 - x1, y2 - y1
            dist = abs(dy * (px - x1) - dx * (py - y1)) / max(1, (dx * dx + dy * dy) ** .5)
            assert dist <= 0.75, ('off line', (x1, y1, x2, y2), px, py, dist)

@test
def draw_rect():
    s = Sim()
    for (x1, y1, x2, y2) in [(10, 10, 100, 80), (0, 0, 255, 191), (30, 30, 30, 60), (5, 5, 5, 5), (7, 20, 9, 22)]:
        s.clear_screen(); s.call('draw_rect', b=y1, c=x1, d=y2, e=x2)
        ref = {(x, y) for x in range(x1, x2 + 1) for y in range(y1, y2 + 1) if x in (x1, x2) or y in (y1, y2)}
        assert s.bitmap() == ref, (x1, y1, x2, y2)

@test
def fill_rect():
    s = Sim()
    for (x1, y1, x2, y2) in [(10, 10, 100, 80), (0, 0, 255, 191), (30, 30, 30, 60), (5, 5, 5, 5), (7, 20, 9, 22), (3, 62, 77, 66)]:
        s.clear_screen(); s.call('fill_rect', b=y1, c=x1, d=y2, e=x2)
        assert s.bitmap() == {(x, y) for x in range(x1, x2 + 1) for y in range(y1, y2 + 1)}, (x1, y1, x2, y2)

@test
def draw_circle():
    s = Sim()
    for (cx, cy, r) in [(128, 96, 50), (100, 90, 1), (100, 90, 2), (60, 60, 30), (128, 96, 95), (30, 30, 20), (200, 150, 40)]:
        s.clear_screen(); s.call('draw_circle', b=cy, c=cx, d=r)
        got = s.bitmap()
        assert got, 'nothing drawn'
        assert {(cx + r, cy), (cx - r, cy), (cx, cy + r), (cx, cy - r)} <= got, ('cardinal points', cx, cy, r)
        for (x, y) in got:
            d = ((x - cx) ** 2 + (y - cy) ** 2) ** .5
            assert abs(d - r) <= 0.8, ('off circle', cx, cy, r, x, y, d)
        # symmetric
        assert all((2 * cx - x, y) in got and (x, 2 * cy - y) in got for x, y in got), ('asymmetric', cx, cy, r)

@test
def flood_fill():
    s = Sim()
    s.clear_screen()
    s.call('draw_rect', b=20, c=20, d=40, e=60)
    border = s.bitmap()
    s.call('flood_fill', b=30, c=40)
    got = s.bitmap()
    assert got == {(x, y) for x in range(20, 61) for y in range(20, 41)}
    # seed on already-set pixel, and off-screen seed: no change
    before = s.block(0x4000, 6144)
    s.call('flood_fill', b=20, c=20); s.call('flood_fill', b=200, c=5)
    assert s.block(0x4000, 6144) == before
    # enclosed region touching the left edge (x must not wrap to 255)
    s.clear_screen(); s.call('draw_vline', b=0, c=4, d=7); s.call('draw_hline', b=7, c=0, d=4)
    s.call('flood_fill', b=3, c=0)
    assert s.bitmap() == {(x, y) for x in range(0, 5) for y in range(0, 8)} - set(), s.bitmap()

# ---- sprites --------------------------------------------------------------
def ref_sprite(screen, y, x, w, rows, fn):
    """apply fn(old, sprite_byte, rowi, coli)->new to a dict addr->byte"""
    for r in range(rows):
        for c in range(w):
            a = screen_addr(x + 8 * c, y + r)
            screen[a] = fn(screen.get(a, 0), r, c)

@test
def draw_sprite_and_xor():
    s = Sim(); random.seed(3)
    for (y, x, w, h) in [(0, 0, 1, 8), (64, 80, 2, 8), (60, 8, 3, 17), (180, 248, 1, 12), (7, 16, 4, 65), (120, 0, 32, 3)]:
        h = min(h, 192 - y); w = min(w, 32 - x // 8)
        data = [random.randrange(256) for _ in range(w * h)]
        spr = 0x9000; s.put(spr, [h, w] + data)
        bg = [random.randrange(256) for _ in range(6144)]
        s.put(0x4000, bg)
        s.call('draw_sprite', b=y, c=x, ix=spr)
        exp = bytearray(bg)
        for r in range(h):
            for c in range(w):
                a = screen_addr(x + 8 * c, y + r) - 0x4000
                exp[a] |= data[r * w + c]
        assert s.block(0x4000, 6144) == bytes(exp), ('draw_sprite', y, x, w, h)
        # xor
        s.put(0x4000, bg)
        s.call('draw_sprite_xor', b=y, c=x, ix=spr)
        exp = bytearray(bg)
        for r in range(h):
            for c in range(w):
                exp[screen_addr(x + 8 * c, y + r) - 0x4000] ^= data[r * w + c]
        assert s.block(0x4000, 6144) == bytes(exp), ('xor', y, x, w, h)
        s.call('draw_sprite_xor', b=y, c=x, ix=spr)
        assert s.block(0x4000, 6144) == bytes(bg), ('xor twice must restore', y, x, w, h)
    # height 0 draws nothing
    s.put(0x9000, [0, 2]); s.put(0x4000, bytes(6144)); s.call('draw_sprite', b=0, c=0, ix=0x9000)
    assert s.block(0x4000, 6144) == bytes(6144)
    s.call('draw_sprite_xor', b=0, c=0, ix=0x9000)
    assert s.block(0x4000, 6144) == bytes(6144)

@test
def draw_sprite_masked():
    s = Sim(); random.seed(4)
    for (y, x, w, h) in [(0, 0, 1, 8), (64, 80, 2, 8), (60, 8, 3, 17), (180, 248, 1, 12), (7, 16, 4, 65)]:
        h = min(h, 192 - y)
        data = []
        for _ in range(w * h):
            data += [random.randrange(256), random.randrange(256)]
        s.put(0x9000, [h, w] + data)
        bg = [random.randrange(256) for _ in range(6144)]
        s.put(0x4000, bg); s.call('draw_sprite_masked', b=y, c=x, ix=0x9000)
        exp = bytearray(bg)
        for r in range(h):
            for c in range(w):
                i = (r * w + c) * 2
                a = screen_addr(x + 8 * c, y + r) - 0x4000
                exp[a] = (exp[a] & data[i]) | data[i + 1]
        assert s.block(0x4000, 6144) == bytes(exp), (y, x, w, h)

@test
def draw_sprite_masked_buf():
    s = Sim(); random.seed(5)
    for off in (0x00, 0x60, 0x80):
        s.wr(SYM['draw_offset'], off)
        for (y, x, w, h) in [(0, 0, 1, 8), (60, 8, 3, 17), (180, 248, 1, 12)]:
            data = []
            for _ in range(w * h): data += [random.randrange(256), random.randrange(256)]
            s.put(0x9000, [h, w] + data)
            base = 0x4000 + off * 256
            bg = [random.randrange(256) for _ in range(6144)]
            s.put(base, bg); s.call('draw_sprite_masked_buf', b=y, c=x, ix=0x9000)
            exp = bytearray(bg)
            for r in range(h):
                for c in range(w):
                    i = (r * w + c) * 2
                    a = screen_addr(x + 8 * c, y + r) - 0x4000
                    exp[a] = (exp[a] & data[i]) | data[i + 1]
            assert s.block(base, 6144) == bytes(exp), (off, y, x, w, h)

@test
def draw_sprite_clipped():
    s = Sim(); random.seed(6)
    guard_lo, guard_hi = 0x3F00, 0x5800
    cases = [(0, 0, 2, 8), (64, 80, 2, 8),            # fully visible
             (184, 0, 2, 16), (190, 8, 1, 10), (150, 0, 3, 100),  # clipped bottom
             (10, 240, 4, 8), (100, 248, 3, 20), (170, 232, 5, 40),  # clipped right (and bottom)
             (191, 248, 6, 6), (192, 0, 2, 8), (255, 0, 2, 8)]  # edge and off-screen
    for (y, x, w, h) in cases:
        data = [random.randrange(1, 256) for _ in range(w * h)]
        s.put(0x9000, [h, w] + data)
        bg = [random.randrange(256) for _ in range(6144)]
        s.put(0x4000, bg); s.put(0x5800, [0x55] * 768)
        s.call('draw_sprite_clipped', b=y, c=x, ix=0x9000)
        exp = bytearray(bg)
        if y < 192:
            for r in range(h):
                if y + r >= 192: break
                for c in range(w):
                    if x // 8 + c >= 32: continue
                    exp[screen_addr(x + 8 * c, y + r) - 0x4000] |= data[r * w + c]
        assert s.block(0x4000, 6144) == bytes(exp), ('screen', y, x, w, h)
        assert s.block(0x5800, 768) == bytes([0x55]) * 768, ('attr corrupted', y, x, w, h)

# ---- scrolling ------------------------------------------------------------
def rand_screen(s, seed):
    random.seed(seed)
    d = [random.randrange(256) for _ in range(6144)]
    s.put(0x4000, d)
    return d

def to_img(d):
    # rows[y] = 32 bytes
    img = [None] * 192
    for y in range(192):
        a = screen_addr(0, y) - 0x4000
        img[y] = list(d[a:a + 32])
    return img

def from_img(img):
    d = bytearray(6144)
    for y in range(192):
        a = screen_addr(0, y) - 0x4000
        d[a:a + 32] = bytes(img[y])
    return bytes(d)

@test
def scroll_up_char():
    s = Sim(); d = rand_screen(s, 7); s.put(0x5800, [0x66] * 768)
    s.call('scroll_up_char')
    img = to_img(d)
    exp = from_img(img[8:] + [[0] * 32] * 8)
    assert s.block(0x4000, 6144) == exp
    assert s.block(0x5800, 768) == bytes([0x66]) * 768

@test
def scroll_up_char_attr():
    s = Sim(); rand_screen(s, 8); random.seed(9)
    at = [random.randrange(256) for _ in range(768)]; s.put(0x5800, at)
    scr = s.block(0x4000, 6144)
    s.call('scroll_up_char_attr')
    assert s.block(0x5800, 768) == bytes(at[32:] + [0] * 32)
    assert s.block(0x4000, 6144) == scr

@test
def scroll_up_pixel():
    s = Sim(); d = rand_screen(s, 10); img = to_img(d)
    s.call('scroll_up_pixel')
    assert s.block(0x4000, 6144) == from_img(img[1:] + [[0] * 32])

@test
def scroll_right_left_pixel():
    s = Sim(); d = rand_screen(s, 11); img = to_img(d)
    def shift(row, right):
        n = int.from_bytes(bytes(row), 'big')
        n = (n >> 1) if right else ((n << 1) & ((1 << 256) - 1))
        return list(n.to_bytes(32, 'big'))
    s.call('scroll_right_pixel')
    assert s.block(0x4000, 6144) == from_img([shift(r, True) for r in img]), 'right'
    rand_screen(s, 11)
    s.call('scroll_left_pixel')
    assert s.block(0x4000, 6144) == from_img([shift(r, False) for r in img]), 'left'

# ---- text -----------------------------------------------------------------
def cell_addr(row, col, line=0):
    return 0x4000 + ((row & 0x18) << 8) + ((row & 7) << 5) + col + (line << 8)

@test
def draw_glyph_and_print():
    s = Sim(); random.seed(12)
    s.zero(0x4000, 6144)
    glyph = bytes(range(0xA0, 0xA8))
    s.put(0x9100, glyph)
    for (row, col) in [(0, 0), (7, 31), (8, 5), (23, 31), (15, 16), (16, 0)]:
        s.call('draw_glyph', de=0x9100, b=row, c=col)
        for ln in range(8): assert s.rd(cell_addr(row, col, ln)) == glyph[ln], ('glyph', row, col, ln)
    # font: 96 glyphs at 0x9200; charset_ptr = font - 256
    font = bytes(random.randrange(256) for _ in range(768))
    s.put(0x9200, font); s.put(SYM['charset_ptr'], [0x00, 0x91])  # 0x9200 - 256
    s.zero(0x4000, 6144)
    s.call('print_char', a=65, b=3, c=4)
    for ln in range(8): assert s.rd(cell_addr(3, 4, ln)) == font[(65 - 32) * 8 + ln], 'print_char'
    s.zero(0x4000, 6144)
    text = b'Hello, world! 0123456789 ABCDEFGHIJKLMNOPQRSTUV'
    s.put(0x9000, text + b'\x00')
    s.call('print_string', hl=0x9000, b=2, c=25)
    for i, ch in enumerate(text):
        pos = 25 + i; row = 2 + pos // 32; col = pos % 32
        for ln in range(8):
            assert s.rd(cell_addr(row, col, ln)) == font[(ch - 32) * 8 + ln], ('print_string', i, chr(ch))
    # empty string draws nothing
    s.zero(0x4000, 6144); s.put(0x9000, [0]); s.call('print_string', hl=0x9000, b=0, c=0)
    assert s.block(0x4000, 6144) == bytes(6144)

@test
def make_bold():
    s = Sim(); random.seed(13)
    rom = bytes(random.randrange(256) for _ in range(768))
    s.put(0x3D00, rom)
    s.call('make_bold', hl=0x9000)
    exp = bytes(b | (b >> 1) for b in rom)
    assert s.block(0x9000, 768) == exp
    assert s.rd(0x9000 + 768) == 0

# ---- buffers / screen fills ---------------------------------------------
@test
def clear_buffer_and_screen_fast():
    s = Sim(); random.seed(14)
    for off in (0x00, 0x60, 0x80):
        s.wr(SYM['draw_offset'], off)
        base = 0x4000 + off * 256
        s.put(base, [0xFF] * 6144); s.put(base + 6144, [0xEE] * 4)
        s.call('clear_buffer')
        assert s.block(base, 6144) == bytes(6144), off
        assert s.block(base + 6144, 4) == bytes([0xEE] * 4), 'overran'
    s.put(0x4000, [0xFF] * 6144); s.put(0x5800, [0x77] * 8)
    s.call('clear_screen_fast')
    assert s.block(0x4000, 6144) == bytes(6144)
    assert s.block(0x5800, 8) == bytes([0x77] * 8)
    assert s.m.iff1, 'interrupts should be re-enabled'

@test
def copy_cells():
    s = Sim(); random.seed(15)
    s.wr(SYM['draw_offset'], 0x60)
    buf = [random.randrange(256) for _ in range(6144)]
    scr = [random.randrange(256) for _ in range(6144)]
    for (r, c, h, w) in [(0, 0, 1, 1), (3, 4, 5, 10), (0, 0, 24, 32), (10, 30, 14, 2), (7, 0, 2, 32)]:
        s.put(0xA000, buf); s.put(0x4000, scr)
        s.call('copy_cells', b=r, c=c, d=h, e=w)
        exp = bytearray(scr)
        for rr in range(r, r + h):
            for cc in range(c, c + w):
                for ln in range(8):
                    a = cell_addr(rr, cc, ln) - 0x4000
                    exp[a] = buf[a]
        assert s.block(0x4000, 6144) == bytes(exp), (r, c, h, w)
        assert s.block(0xA000, 6144) == bytes(buf), 'buffer modified'

@test
def page_flip():
    s = Sim()
    s.wr(0x5B5C, 0x10 | 0x20)
    s.call('init_page_flip')
    assert s.out[-1] == (0x7FFD, 0x37) or s.out[-1][1] == 0x37, s.out
    assert s.rd(SYM['draw_offset']) == 0x80
    s.call('flip_screen')
    assert s.out[-1][1] == 0x3F and s.rd(SYM['draw_offset']) == 0x00, (s.out, s.rd(SYM['draw_offset']))
    s.call('flip_screen')
    assert s.out[-1][1] == 0x37 and s.rd(SYM['draw_offset']) == 0x80

# ---- tables / misc ---------------------------------------------------------
@test
def row_table():
    s = Sim()
    s.call('build_row_table')
    for y in range(192):
        a = s.rd(0xB000 + 2 * y) | (s.rd(0xB000 + 2 * y + 1) << 8)
        assert a == screen_addr(0, y), (y, hex(a))
        m = s.call('get_row_addr', b=y)
        assert m.hl == screen_addr(0, y), ('get_row_addr', y)

@test
def draw_background():
    s = Sim(); s.put(0x4000, [0x5A] * 6144)
    s.call('draw_background')
    for row in range(24):
        v = 0xFF if row % 2 == 0 else 0x00
        for col in (0, 13, 31):
            for ln in range(8):
                assert s.rd(cell_addr(row, col, ln)) == v, (row, col, ln, s.rd(cell_addr(row, col, ln)))


if __name__ == '__main__':
    only = sys.argv[1:]
    bad = 0
    for name, ok, msg in RESULTS:
        if only and name not in only: continue
        print(('PASS ' if ok else 'FAIL ') + name + ('' if ok else '  -> ' + msg))
        bad += not ok
    print(f'\n{len(RESULTS) - bad}/{len(RESULTS)} passed')
    sys.exit(1 if bad else 0)
