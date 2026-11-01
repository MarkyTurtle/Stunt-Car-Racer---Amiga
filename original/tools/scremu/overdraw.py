"""How many times each part of the 3D view is drawn in a race frame (overdraw), and by which
routines: the race benchmark (enhanced/tools/bench.py) played with scremu counting every write to
the screens.

  python3 original/tools/scremu/overdraw.py [GAME.bin] [--vblanks N] [--png OUT.png]

GAME.bin: the game to measure (default: original/scr_game.s assembled). Prints the writes a word
of the view takes each frame (plane 0; the planes are written alike), by bands of 8 lines and 16
pixels, and the writes to the screens by routine; --png draws the map (each 16-pixel word of the
view a cell: blue 1 write, green 2, yellow 3, red 4, white 6 or more). Writes are counted a word
at a time: a long write counts for its 2 words, a byte write (PlotPixel's bset) for its word.
"""
import bisect, collections, os, re, struct, subprocess, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ORIG = os.path.normpath(os.path.join(HERE, '..', '..'))
ROOT = os.path.normpath(os.path.join(ORIG, '..'))
sys.path.insert(0, os.path.join(ROOT, 'enhanced', 'tools'))
import bench

SCREENS = (0x6A594, 0x72294)            # the two screens (Screens; $7D00 apart)
LO, HI = SCREENS[0], SCREENS[1] + 0x7D00
VIEW_LINE, VIEW_WORD, LINES, WORDS = 16, 2, 128, 16     # the view: lines 16-143, pixels 32-287


def arg(n, d=None):
    return sys.argv[sys.argv.index(n) + 1] if n in sys.argv else d


def main():
    work = tempfile.mkdtemp()
    lst = os.path.join(work, 'game.lst')
    game = next((a for a in sys.argv[1:] if not a.startswith('-') and a not in (arg('--vblanks'), arg('--png'))), None)
    if not game:
        game = os.path.join(work, 'game.bin')
        r = subprocess.run([os.environ.get('VASM', 'vasmm68k_mot'), '-Fbin', '-m68000', '-no-opt', '-quiet', '-I', ORIG,
                            '-L', lst, '-o', game, os.path.join(ORIG, 'scr_game.s')], capture_output=True, text=True, cwd=ORIG)
        if r.returncode:
            sys.exit(r.stdout + r.stderr)
    if not os.path.exists(bench.EMU):
        subprocess.run(['sh', os.path.join(HERE, 'build.sh')], check=True)
    vbl = int(arg('--vblanks', 3000))
    pre = os.path.join(work, 'wc')
    sc = bench.script(vbl, os.path.join(work, 'snap')).replace(
        f'joy f\nframes {vbl}', f'calls 1\nwritecount {LO:#x} {HI:#x}\njoy f\nframes {vbl}\nwritecountdump {pre}\ncallsdump {pre}.calls')
    open(os.path.join(work, 's.txt'), 'w').write(sc)
    subprocess.run([bench.EMU, game, os.path.join(ORIG, 'bin', 'lowmem_c0.bin'), os.path.join(ORIG, 'bin', 'loadpic_78000.bin'),
                    os.path.join(work, 's.txt')], check=True, stdout=subprocess.DEVNULL)
    frames = next(int(n) for a, n in (l.split() for l in open(pre + '.calls')) if int(a, 16) == 0x5DAC0)   # FrameLimiter
    raw = open(pre + '.addr', 'rb').read()
    c = struct.unpack(f'<{len(raw) // 4}I', raw)
    grid = [[0.0] * WORDS for _ in range(LINES)]
    for s in SCREENS:                    # one of the two is drawn each frame
        for y in range(LINES):
            for w in range(WORDS):
                grid[y][w] += c[(s + (VIEW_LINE + y) * 40 + (VIEW_WORD + w) * 2 - LO) // 2] / frames
    flat = sorted(v for row in grid for v in row)
    print(f'{frames} race frames: a word of the view is written {sum(flat) / len(flat):.2f} times a frame on average '
          f'(least {flat[0]:.2f}, median {flat[len(flat) // 2]:.2f}, most {flat[-1]:.1f})')
    print('by 8 lines (rows) and 16 pixels (columns):')
    for b in range(0, LINES, 8):
        print(f'  {b:3d}-{b + 7:3d} ' + ' '.join(f'{sum(grid[y][x] for y in range(b, b + 8)) / 8:4.1f}' for x in range(WORDS)))
    if os.path.exists(lst):              # by routine
        syms = sorted((int(m.group(2), 16), m.group(1)) for m in
                      (re.match(r'^(\w+)\s+A:([0-9A-F]{8})\s*$', l) for l in open(lst, errors='replace'))
                      if m and not m.group(1).startswith(('l_', 'PlotPixelP')))
        ad = [a for a, _ in syms]
        by = collections.Counter()
        for l in open(pre + '.pc'):
            pc, n = l.split()
            by[syms[bisect.bisect_right(ad, int(pc, 16)) - 1][1]] += int(n)
        tot = sum(by.values())
        print(f'word writes to the screens a frame, by routine (4 planes; {tot / frames:,.0f} in all, the view once is {LINES * WORDS * 4:,}):')
        for r, n in by.most_common(10):
            print(f'  {r:20s} {n / frames:7,.0f}  {100 * n / tot:5.1f}%')
    if arg('--png'):
        from PIL import Image
        cols = [(0, 0, 0), (40, 70, 200), (40, 170, 70), (230, 210, 40), (230, 60, 40), (230, 60, 40), (255, 255, 255)]
        im = Image.new('RGB', (WORDS * 16, LINES))
        for y in range(LINES):
            for w in range(WORDS):
                col = cols[min(6, int(round(grid[y][w])))]
                for x in range(16):
                    im.putpixel((w * 16 + x, y), col)
        im.resize((WORDS * 32, LINES * 2), Image.NEAREST).save(arg('--png'))


if __name__ == '__main__':
    main()
