"""The 8 tracks' data decoded, as BuildTrack ($5AE46) reads it (docs/TRACKS.md).

  python3 original/tools/tracks.py [TRACK...] [--check DIR] [--map OUT.png]

Prints each track (all 8, or those named: 0-7 or a file's name) - its header, its pieces (the grid
square, the direction, the shape, the two height profiles and what they make: the sections, the
distance from the start, the heights where it starts) and the tables after them. The shapes and
the profiles are the game's own (Data6502, HeightProfiles): the game is assembled for them (vasm, as
build.py does, with a listing for the labels).

--check DIR: compared with the game's own tables just after BuildTrack, from scremu snapshots
DIR/t0.mem-t7.mem (tools/track_snapshots.py makes them): every table BuildTrack writes, byte for byte.
--map OUT.png: the 8 tracks drawn on their 16 x 16 grids (needs Pillow).
"""
import os, re, sys

HERE = os.path.dirname(os.path.abspath(__file__))
ORIG = os.path.normpath(os.path.join(HERE, '..'))
NAMES = ['little_ramp', 'stepping_stones', 'hump_back', 'big_ramp', 'ski_jump', 'draw_bridge',
         'high_jump', 'roller_coaster']
TITLES = ['Little Ramp', 'Stepping Stones', 'Hump Back', 'Big Ramp', 'Ski Jump', 'Draw Bridge',
          'High Jump', 'Roller Coaster']


def assemble():
    """the game assembled (vasm, as build.py does) with a listing: (its bytes, its labels)"""
    import subprocess, tempfile
    vasm = os.environ.get('VASM', 'vasmm68k_mot')
    d = tempfile.mkdtemp()
    subprocess.run([vasm, '-Fbin', '-m68000', '-no-opt', '-quiet', '-L', os.path.join(d, 'game.lst'),
                    '-o', os.path.join(d, 'game.bin'), 'scr_game.s'], cwd=ORIG, check=True)
    sym = {}
    for line in open(os.path.join(d, 'game.lst'), errors='replace'):
        p = line.split()
        if len(p) == 2 and p[1][:2] in ('A:', 'E:') and len(p[1]) == 10:
            sym[p[0]] = int(p[1][2:], 16)
    return open(os.path.join(d, 'game.bin'), 'rb').read(), sym


class Game:
    """the game's memory as loaded (assembled from its org, $E700) and its labels"""
    def __init__(self):
        self.m, self.sym = assemble()
        self.org = int(re.search(r'^\s*org\s+\$([0-9A-Fa-f]+)', open(os.path.join(ORIG, 'scr_game.s')).read(), re.M).group(1), 16)

    def b(self, a): return self.m[a - self.org]
    def w(self, a): return self.b(a) << 8 | self.b(a + 1)

    def d6502(self, ptr):
        """a 6502 address (as the data holds it: low byte first) as the game's address"""
        p = ((ptr & 0xFF) << 8 | ptr >> 8) - 0xB100
        return self.sym['Data6502'] + (p & 0xFFFF)


def build(g, data, opp_line_base=None):
    """BuildTrack on a track's bytes: the tables it makes (a dict). opp_line_base: dat_63CE1 (set by
    SetOpponentSkill, from Random) - the opponent's lines on bends depend on it"""
    pos = [0]

    def rd():
        v = data[pos[0]]; pos[0] += 1; return v
    t = {}
    count = 0
    hdr = [rd() for _ in range(4)]
    count, t['starting_piece'], t['lap_count_piece'], t['start_piece'] = hdr
    t['count'] = count
    lo = rd(); hi = rd()
    acc_a = acc_b = hi << 8 | lo                     # dat_1BBF6 and dat_1BBF8: the two profiles' heights so far
    t['start_height'] = acc_a
    flags, grid, kinds, heights = [0] * count, [0] * count, [0] * count, [0] * count
    base_a, base_b, dist = [0] * count, [0] * count, [0] * count
    sections = [0] * count
    parity = 0                                       # dat_1BBDC
    total = 0                                        # dat_1BC2A: the sections so far
    repeat = 0                                       # dat_1BB48
    prev_flags = 0                                   # dat_1BC55
    prev_grid = 0                                    # dat_1BB8B
    start_a, start_b = [0] * count, [0] * count
    d1 = 0
    while d1 < count:
        if repeat:
            repeat -= 1
            f = prev_flags
            flags[d1] = f
            w5 = f ^ 0xC0 if f & 0x10 else f
            g_ = step_grid(prev_grid, w5)
        else:
            f = rd()
            flags[d1] = f
            if f & 0xF == 0xF:
                repeat = f >> 4
                continue
            w5 = f
            prev_flags = f
            g_ = rd()
        grid[d1] = g_
        prev_grid = g_
        w6 = (parity >> 1 & 1) << 7
        shape = w5 & 0xF
        if shape >= 0xC:                             # (kinds 12-14: from the bytes at l_5B2B8 + 12)
            flags[d1] &= 0xF0
            tab = g.sym['l_5B2B8']
            kinds[d1] = g.b(tab + shape)
            h = g.b(tab + 2 + shape)
        else:
            kinds[d1] = rd()
            h = kinds[d1] if w5 & 0x20 else rd()
        heights[d1] = (h & 0x7F) | w6
        dist[d1] = (total * 32) & 0xFFFF
        lp = load_piece(g, flags[d1], kinds[d1], heights[d1])
        parity = (lp['parity'] + lp['points'] - 2) & 2
        sections[d1] = lp['sections']
        total += lp['sections']
        start_a[d1], start_b[d1] = acc_a, acc_b
        a0 = profile(g, lp['profile_a'], kinds[d1], 0)
        base_a[d1] = (acc_a - a0) & 0xFFFF
        acc_a = (base_a[d1] + profile(g, lp['profile_a'], kinds[d1], lp['sections'])) & 0xFFFF
        b0 = profile(g, lp['profile_b'], kinds[d1], 0)
        base_b[d1] = (acc_b - b0) & 0xFFFF
        acc_b = (base_b[d1] + profile(g, lp['profile_b'], kinds[d1], lp['sections'])) & 0xFFFF
        d1 += 1
    t.update(flags=flags, grid=grid, kinds=kinds, heights=heights, base_a=base_a, base_b=base_b,
             dist=dist, sections=sections, start_a=start_a, start_b=start_b)
    lap = t['lap_count_piece'] + 1
    t['lap_start'] = lap if lap < count else 0
    t['length'] = (total * 32) & 0xFFFF
    t['extra'] = [rd() for _ in range(6)]            # OpponentSetting-NoRestartCount
    npairs, nlist = t['extra'][4], t['extra'][5]
    t['line_pieces'], t['line_values'] = [], []
    for _ in range(npairs):
        t['line_pieces'].append(rd()); t['line_values'].append(rd())
    t['no_restart'] = [rd() for _ in range(nlist)]
    t['bytes'] = pos[0]
    if opp_line_base is not None:
        t['opp_lines'] = opponent_lines(g, t, opp_line_base)
    return t


def step_grid(sq, f):
    """StepGrid: the next grid square in the direction of flags f (bit 7: back, bit 6: x, else y)"""
    d = 1 if f & 0x40 else 0x10
    return (sq - d if f & 0x80 else sq + d) & 0xFF


def load_piece(g, flags, kind, height):
    """what LoadPiece works out for a piece (the parts BuildTrack uses)"""
    shapes = g.sym['HeightProfiles']
    out = {'profile_a': g.d6502(g.w(shapes + (kind << 1 & 0xFF))),
           'profile_b': g.d6502(g.w(shapes + (height << 1 & 0xFF))),
           'parity': (height >> 7) << 1}
    typ = flags & 0xF
    p = g.d6502(g.w(g.sym['Data6502'] + 2 * typ))
    off = g.b(p)
    pts = g.b(p + off)
    out['points'] = pts
    out['sections'] = (pts >> 1) - 1 & 0xFF
    out['shape'] = p
    out['direction'] = g.b(p + 1)
    return out


def profile(g, p, kind, i):
    """TrackDataEntry: entry i of a height profile at p - one byte (kind's bit 7 clear) or two"""
    if kind & 0x80:
        return (g.b(p + 2 * i) & 0x7F) << 8 | g.b(p + 2 * i + 1)
    v = g.b(p + i)
    return (v & 0xF) << 8 | (v << 1 & 0xE0)


def opponent_lines(g, t, base):
    """BuildTrack's last part: each piece's line for the opponent (PieceOpponentLines), from the
    track's own pairs or, by the piece's shape (ShapeTurns), from the last one +/- 10"""
    count = t['count']
    out = [0] * count
    hold = 0                                         # dat_1BB48
    w6 = 0x7C
    tab = g.sym['ShapeTurns']
    for d1 in range(count - 1, -1, -1):
        hit = [k for k in range(len(t['line_pieces']) - 1, -1, -1) if t['line_pieces'][k] == d1]
        if hit:
            d0 = t['line_values'][hit[0]]
            out[d1] = d0
            if d0 & 0x80:
                hold = 3
            w6 = d0 & 0x7F
            continue
        s = g.b(tab + (t['flags'][d1] & 0xF))
        if s & 0x80:
            w6 = (base - 0xA) & 0xFF
            d0 = base
        else:
            v = (w6 + 0xA) & 0xFF
            if not v & 0x80:
                w6 = v
            d0 = w6
        if hold:
            hold -= 1
            d0 |= 0x80
        out[d1] = d0
    return out


def show(g, n, t):
    print(f'== {n}: {TITLES[n]} ({NAMES[n]}.bin, {t["bytes"]} bytes)')
    print(f'   {t["count"]} pieces; the cars start on piece {t["starting_piece"]}, the laps count from piece '
          f'{t["lap_start"]}, the start and finish piece {t["start_piece"]}; heights from {t["start_height"]:#06x}; '
          f'length {t["length"]:#06x} ({t["length"] // 32} sections)')
    print('   piece  grid   flags  shape dir rev  prof A  prof B  sections  distance  starts at: side A  side B')
    for i in range(t['count']):
        f = t['flags'][i]
        x, y = t['grid'][i] & 0xF, t['grid'][i] >> 4
        d = {0x00: 'y+', 0x40: 'x+', 0x80: 'y-', 0xC0: 'x-'}[f & 0xC0]
        print(f'   {i:5}  {x:2},{y:<2}  {f:#04x}  {f & 0xF:5}  {d:3} {"yes" if f & 0x10 else "":3}  '
              f'{t["kinds"][i]:#04x}    {t["heights"][i]:#04x}  {t["sections"][i]:8}  {t["dist"][i]:#08x}  '
              f'         {t["start_a"][i]:#06x}  {t["start_b"][i]:#06x}')
    e = t['extra']
    print(f'   the opponent\'s setting {e[0]} ({e[1]} in the super league), the boost {e[2]} ({e[3]}); the opponent\'s lines set: '
          + ', '.join(f'piece {p} {v:#04x}' for p, v in zip(t['line_pieces'], t['line_values']))
          + f'; not restarted on: {" ".join(str(b) for b in t["no_restart"]) or "none"}')


def check(g, n, t, mem):
    """t against the game's tables in a snapshot taken just after BuildTrack: the differences"""
    s = g.sym
    c = t['count']
    bad = []

    def cmp(name, addr, want, size=1):
        got = [mem[addr + size * i] if size == 1 else mem[addr + 2 * i] << 8 | mem[addr + 2 * i + 1] for i in range(len(want))]
        if got != list(want):
            bad.append(f'{name}: {sum(a != b for a, b in zip(got, want))} differ')
    cmp('TrackPieceCount', s['TrackPieceCount'], [c])
    cmp('StartingPiece', s['StartingPiece'], [t['starting_piece']])
    cmp('LapCountPiece', s['LapCountPiece'], [t['lap_count_piece']])
    cmp('StartPiece', s['StartPiece'], [t['start_piece']])
    cmp('TrackPieceFlags', s['TrackPieceFlags'], t['flags'])
    cmp('TrackPieceGrid', s['TrackPieceGrid'], t['grid'])
    cmp('TrackPieceProfileA', s['TrackPieceProfileA'], t['kinds'])
    cmp('TrackPieceProfileB', s['TrackPieceProfileB'], t['heights'])
    cmp('PieceDistances', s['PieceDistances'], t['dist'], 2)
    cmp('PieceHeightBaseA', s['PieceHeightBaseA'], t['base_a'], 2)
    cmp('PieceHeightBaseB', s['PieceHeightBaseB'], t['base_b'], 2)
    cmp('LapStartPiece', s['LapStartPiece'], [t['lap_start']])
    cmp('TrackLength', s['TrackLength'], [t['length']], 2)
    cmp('OpponentSetting-NoRestartCount', s['OpponentSetting'], t['extra'])
    cmp('OpponentLinePieces', s['OpponentLinePieces'], t['line_pieces'])
    cmp('OpponentLineValues', s['OpponentLineValues'], t['line_values'])
    cmp('NoRestartPieces', s['NoRestartPieces'], t['no_restart'])
    cmp('PieceOpponentLines', s['PieceOpponentLines'], t['opp_lines'])
    return bad


def draw_maps(g, tracks, out):
    from PIL import Image, ImageDraw
    cell, pad = 22, 24
    W = 4 * (16 * cell + pad) + pad
    H = 2 * (16 * cell + pad + 18) + pad
    im = Image.new('RGB', (W, H), (250, 250, 247))
    dr = ImageDraw.Draw(im)
    for k, (n, t) in enumerate(tracks):
        ox = pad + (k % 4) * (16 * cell + pad)
        oy = pad + 18 + (k // 4) * (16 * cell + pad + 18)
        dr.text((ox, oy - 16), f'{n} {TITLES[n]} ({t["count"]} pieces)', fill=(40, 40, 40))
        for i in range(17):
            dr.line([ox + i * cell, oy, ox + i * cell, oy + 16 * cell], fill=(225, 225, 220))
            dr.line([ox, oy + i * cell, ox + 16 * cell, oy + i * cell], fill=(225, 225, 220))
        hs = [max(t['start_a'][i], t['start_b'][i]) for i in range(t['count'])]
        lo, hi = min(hs), max(hs)
        for i in range(t['count']):
            x, y = t['grid'][i] & 0xF, t['grid'][i] >> 4
            v = 0 if hi == lo else (hs[i] - lo) / (hi - lo)
            col = (int(70 + 160 * v), int(120 + 60 * (1 - v)), int(200 - 150 * v))
            if t['flags'][i] & 0xF not in (0, 1):
                col = tuple(c - 40 for c in col)
            dr.rectangle([ox + x * cell + 2, oy + y * cell + 2, ox + x * cell + cell - 2, oy + y * cell + cell - 2], fill=col)
            if i == t['start_piece']:
                dr.rectangle([ox + x * cell, oy + y * cell, ox + x * cell + cell, oy + y * cell + cell], outline=(220, 30, 30), width=2)
        pts = [(ox + (t['grid'][i] & 0xF) * cell + cell // 2, oy + (t['grid'][i] >> 4) * cell + cell // 2) for i in range(t['count'])]
        dr.line(pts + pts[:1], fill=(30, 30, 30), width=1)
    im.save(out)


def main():
    if '-h' in sys.argv or '--help' in sys.argv:
        sys.exit(__doc__)
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    chk = sys.argv[sys.argv.index('--check') + 1] if '--check' in sys.argv else None
    mp = sys.argv[sys.argv.index('--map') + 1] if '--map' in sys.argv else None
    args = [a for a in args if a not in (chk, mp)]
    which = [int(a) if a.isdigit() else NAMES.index(a) for a in args] or list(range(8))
    g = Game()
    failed = False
    done = []
    for n in which:
        data = open(os.path.join(ORIG, 'tracks', NAMES[n] + '.bin'), 'rb').read()
        mem = open(os.path.join(chk, f't{n}.mem'), 'rb').read() if chk else None
        t = build(g, data, mem[g.sym['dat_63CE1']] if mem else 0)
        if t['bytes'] != len(data):
            print(f'{NAMES[n]}: {t["bytes"]} bytes read of {len(data)}')
            failed = True
        done.append((n, t))
        if chk:
            bad = check(g, n, t, mem)
            print(f'{TITLES[n]}: ' + ('the same as the game\'s' if not bad else '; '.join(bad)))
            failed |= bool(bad)
        else:
            show(g, n, t)
    if mp:
        draw_maps(g, done, mp)
    sys.exit(1 if failed else 0)


if __name__ == '__main__':
    main()
