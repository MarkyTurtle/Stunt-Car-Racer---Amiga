"""The 8 tracks' data decoded, as BuildTrack ($5AE46) reads it (docs/TRACKS.md).

  python3 original/tools/tracks.py [TRACK...] [--check DIR] [--map OUT.png] [--shapes OUT.png|-]

Prints each track (all 8, or those named: 0-7 or a file's name) - its header, its pieces (the grid
square, the direction, the shape, the two height profiles and what they make: the sections, the
distance from the start, the heights where it starts) and the tables after them. The shapes and
the profiles are the game's own (Data6502, HeightProfiles): the game is assembled for them (vasm, as
build.py does, with a listing for the labels).

--check DIR: compared with the game's own tables just after BuildTrack, from scremu snapshots
DIR/t0.mem-t7.mem (tools/track_snapshots.py makes them): every table BuildTrack writes, byte for byte.
--map OUT.png: the 8 tracks drawn on their 16 x 16 grids (needs Pillow).
--shapes OUT.png: the shapes the tracks use, their geometry printed and drawn (- prints only).
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


def build(g, data, bend_speed=None):
    """BuildTrack on a track's bytes: the tables it makes (a dict). bend_speed: OpponentBendSpeed (set by
    SetRaceLimits, within the track's limits) - the opponent's speeds on the bends and before them"""
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
    t['extra'] = [rd() for _ in range(6)]            # DamageSteps-NoRestartCount
    npairs, nlist = t['extra'][4], t['extra'][5]
    t['speed_pieces'], t['speed_values'] = [], []
    for _ in range(npairs):
        t['speed_pieces'].append(rd()); t['speed_values'].append(rd())
    t['no_restart'] = [rd() for _ in range(nlist)]
    t['bytes'] = pos[0]
    if bend_speed is not None:
        t['opp_speeds'] = opponent_speeds(g, t, bend_speed)
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


def opponent_speeds(g, t, base):
    """BuildTrack's last part: each piece's speed for the opponent (PieceOpponentSpeeds), from the last
    piece back - the track's own, or OpponentBendSpeed on a bend (ShapeTurns bit 7), else 10 more
    than the speed carried back from the next piece, up to $7F (bit 7: exact)"""
    count = t['count']
    out = [0] * count
    hold = 0                                         # dat_1BB48
    w6 = 0x7C
    tab = g.sym['ShapeTurns']
    for d1 in range(count - 1, -1, -1):
        hit = [k for k in range(len(t['speed_pieces']) - 1, -1, -1) if t['speed_pieces'][k] == d1]
        if hit:
            d0 = t['speed_values'][hit[0]]
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


SHAPES_USED = (0, 10, 4, 6, 7, 1, 3)


def shape(g, typ):
    """a shape's geometry from the 6502 data (Data6502 by the shape): its header read as LoadPiece,
    CarPiecePosition and ReadPiecePoints read it, and its points - each section's end a pair (side A,
    side B), (x, z) in the piece's own frame: a square 2048 across, entered at z = 0 going +z"""
    p = g.d6502(g.w(g.sym['Data6502'] + 2 * typ))
    off = g.b(p)

    def sw(a):
        v = g.b(a) | g.b(a + 1) << 8
        return v - 0x10000 if v & 0x8000 else v
    out = {'kind': g.b(p + 1), 'points': g.b(p + off), 'other_way': g.b(p + off + 1) & 1,
           'bytes_after': [g.b(p + off + k) for k in (2, 3, 6)]}
    out['sections'] = (out['points'] >> 1) - 1
    kind = out['kind'] & 0xC0
    if kind == 0x00:
        out['edge'] = sw(p + 2)                          # the track's side A, across (x)
    elif kind == 0x40:
        out['edge'] = sw(p + 2)                          # across the diagonal
        out['heading'] = sw(p + 4)                       # the piece's heading ($2000: 45 degrees)
        out['along_scale'] = g.b(p + 7)                  # (x + z) x it / 256: along
    else:
        out['centre'] = (sw(p + 2), sw(p + 4))           # the bend's centre
        out['start_angle'] = sw(p + 6) << 6 & 0xFFFF
        out['along_scale'] = g.b(p + 8)
        out['edge_radius'] = sw(p + 9)                   # side A's radius from the centre
    base = p + off + 7
    out['pts'] = [(sw(base + 4 * i), sw(base + 4 * i + 2)) for i in range(out['points'])]
    return out


def show_shapes(g):
    print('shape  kind  sections  geometry')
    for typ in SHAPES_USED:
        sh = shape(g, typ)
        c = [((sh['pts'][2 * i][0] + sh['pts'][2 * i + 1][0]) / 2, (sh['pts'][2 * i][1] + sh['pts'][2 * i + 1][1]) / 2) for i in range(sh['points'] // 2)]
        geo = f'from ({c[0][0]:.0f}, {c[0][1]:.0f}) to ({c[-1][0]:.0f}, {c[-1][1]:.0f})'
        if 'centre' in sh:
            r = ((c[0][0] - sh['centre'][0]) ** 2 + (c[0][1] - sh['centre'][1]) ** 2) ** 0.5
            geo += f', a bend about ({sh["centre"][0]}, {sh["centre"][1]}), radius {r:.0f} (side A {sh["edge_radius"]})'
        else:
            geo += f', side A across {sh["edge"]}'
        print(f'{typ:5}  {sh["kind"]:#04x}  {sh["sections"]:8}  {geo}')


def draw_shapes(g, out):
    from PIL import Image, ImageDraw
    sc, pad = 0.09, 30
    side = int(2600 * sc)
    im = Image.new('RGB', (len(SHAPES_USED) * (side + pad) + pad, side + 2 * pad + 10), (250, 250, 247))
    dr = ImageDraw.Draw(im)
    for k, typ in enumerate(SHAPES_USED):
        sh = shape(g, typ)
        ox, oy = pad + k * (side + pad) + int(300 * sc), pad + side - int(300 * sc)
        P = lambda x, z: (ox + x * sc, oy - z * sc)
        dr.rectangle([P(0, 2048), P(2048, 0)], outline=(200, 200, 195))
        pts = sh['pts']
        for i in range(0, len(pts) - 2, 2):
            dr.polygon([P(*pts[i]), P(*pts[i + 1]), P(*pts[i + 3]), P(*pts[i + 2])], fill=(110, 160, 210) if i // 2 % 2 else (70, 120, 180))
        dr.text((ox - int(300 * sc), oy + int(300 * sc) - 6), f'shape {typ}: {sh["sections"]} sections', fill=(40, 40, 40))
    im.save(out)


BRIDGE_PROFILE = 0x5F                                 # the draw bridge's leaves: profiles $5F-$62
BRIDGE_BYTES = 0x48


def bridge_profiles(g, phase):
    """UpdateDrawBridge: the bytes 2-$47 of the profiles $5F-$62 (the Draw Bridge's leaves, pieces 51,
    52, 54, 55: 2-byte entries) at a phase (BridgePhase) - each leaf a slope from its end, rising the
    same each section, the slope from the phase (a triangle: 32 steps); a dict offset: byte"""
    v = (phase & 0x1F) - 0x10
    if v < 0:
        v = -v - 1                                       # (not.w)
    slope = (v + 4) << 5
    acc = 0
    out = {}
    d2 = 2
    for _ in range(15):
        acc = (acc + slope) & 0xFFFF
        while True:
            hi = acc >> 8 | (0x80 if d2 == 0x20 else 0)
            out[d2], out[d2 + 1] = hi, acc & 0xFF        # from the first leaf's end
            d2 += 2
            m = BRIDGE_BYTES - d2
            out[m], out[m + 1] = hi, acc & 0xFF          # and the same from the second's
            if d2 != 0x12:
                break
    return out


def bridge_speeds(g, phase, held=False):
    """UpdateDrawBridge: the opponent's speeds for pieces 48-50 (the approach) and, when the bridge
    moves, 51-52 (the leaves) at a phase (a dict piece: speed with bit 7 set)"""
    out = {}
    d0 = (0xC + phase) & 0xFF if held else phase
    if not held:
        v = (phase & 0x1F) - 0x10
        v = -v - 1 if v < 0 else v
        out[51] = out[52] = g.b(g.sym['BridgeLeafSpeeds'] + v)
    i = (d0 & 0x1F) >> 1
    acc = 0xC6
    for k in range(3):
        acc = (acc + g.b(g.sym['BridgeApproachSteps'] + i)) & 0xFF
        out[48 + k] = acc
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
    print(f'   damage from {e[0]} steps of a hard landing ({e[1]} in the super league), the boost {e[2]} ({e[3]}); '
          f'the opponent\'s speeds set: ' + ', '.join(f'piece {p} {v & 0x7F}{" exact" if v & 0x80 else ""}' for p, v in zip(t['speed_pieces'], t['speed_values'])))
    if 'opp_speeds' in t:
        print('   the opponent\'s speeds (the leagues\' bend speed): ' + ' '.join(f'{v & 0x7F}{"!" if v & 0x80 else ""}' for v in t['opp_speeds']))
    print(
          f'   not restarted on: {" ".join(str(b) for b in t["no_restart"]) or "none"}')


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
    cmp('DamageSteps-NoRestartCount', s['DamageSteps'], t['extra'])
    cmp('OpponentSpeedPieces', s['OpponentSpeedPieces'], t['speed_pieces'])
    cmp('OpponentSpeedValues', s['OpponentSpeedValues'], t['speed_values'])
    cmp('NoRestartPieces', s['NoRestartPieces'], t['no_restart'])
    cmp('PieceOpponentSpeeds', s['PieceOpponentSpeeds'], t['opp_speeds'])
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
    shp = sys.argv[sys.argv.index('--shapes') + 1] if '--shapes' in sys.argv else None
    args = [a for a in args if a not in (chk, mp, shp)]
    if shp:
        g = Game()
        show_shapes(g)
        if shp != '-':
            draw_shapes(g, shp)
        return
    which = [int(a) if a.isdigit() else NAMES.index(a) for a in args] or list(range(8))
    g = Game()
    failed = False
    done = []
    for n in which:
        data = open(os.path.join(ORIG, 'tracks', NAMES[n] + '.bin'), 'rb').read()
        mem = open(os.path.join(chk, f't{n}.mem'), 'rb').read() if chk else None
        lim = g.sym['OpponentSpeedLimits']         # (the leagues' bend speed: its random mask is 0)
        t = build(g, data, mem[g.sym['OpponentBendSpeed']] if mem else g.b(lim + 0x18 + n))
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
