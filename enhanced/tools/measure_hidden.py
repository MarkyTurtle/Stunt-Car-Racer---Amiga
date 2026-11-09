"""How much of what the race view draws is hidden by nearer rows: the drawing's overdraw by row, for
the question of drawing front to back (enhanced/TODO.md, "The view drawn another way").

  python3 enhanced/tools/measure_hidden.py [--vblanks N] [--tracks 0,1,..] [--keep DIR]

Each of the 8 tracks is raced as test_physics.py does (the benchmark's way to the race, then random
controls, up - the accelerator - more than half the time), with the CPU's writes to plane 0 of the
two screens logged (scremu's writelog and writelogp0) beside a trace of each routine that starts a
part of the drawing. A frame's writes are then grouped by the row being drawn (DrawFarRows and
DrawNearRows' loops, far to near), and every 16-pixel word of the view is followed through the
frame. For each row:

  * its words are the plane-0 words its fills and lines wrote;
  * a word is *covered* (certainly hidden) when a later row writes the whole word (a run's whole
    words, not the edges' partial ones), and *touched* when a later row writes any of it - an upper
    bound on what a front-to-back drawing could skip, the covered a lower bound;
  * a row is hidden when all its words are covered (or touched, for the upper bound).

The CPU's writes only: the sky and ground are the blitter's. Prints, for each track and for all, the
rows drawn a frame, the words written, the share covered and touched, the rows wholly hidden, and
the frames with the most hidden words (the hills).
"""
import collections, os, re, subprocess, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ENH = os.path.normpath(os.path.join(HERE, '..'))
ROOT = os.path.normpath(os.path.join(ENH, '..'))
sys.path.insert(0, HERE)
import bench
import test_physics

VIEW_LINE, VIEW_WORD, LINES, WORDS = 16, 2, 128, 16         # the view: lines 16-143, words 2-17 of 20
SCREEN_STEP = 0x7D00                                         # the two screens, apart


def build(work):
    game, lst = os.path.join(work, 'game.bin'), os.path.join(work, 'game.lst')
    subprocess.run([os.environ.get('VASM', 'vasmm68k_mot'), '-Fbin', '-m68000', '-no-opt', '-quiet', '-I',
                    os.path.join(ENH, 'src'), '-I', os.path.join(ROOT, 'original'), '-L', lst, '-o', game,
                    os.path.join(ENH, 'src', 'scr_game.s')], check=True)
    return game, lst


def routines(sym):
    """the markers (what starts a part of the drawing) and the partial-word writers' address range"""
    rows = [sym['DrawFarRows'], sym['l_68F3C']]
    parts = {sym[n]: n for n in ('FillRowSurface', 'FillRowsLeftSide', 'FillRowsRightSide', 'FillFarRowLeftSide',
                                 'FillFarRowRightSide', 'DrawRowsLeftEdges', 'DrawRowsRightEdges', 'DrawOpponentCar',
                                 'DrawMountains', 'DrawHorizon')}
    partial = (min(sym[f'PlotWord{i}'] for i in range(1, 16)), max(sym[f'PlotWord{i}'] for i in range(1, 16)) + 0x10)
    return rows, parts, partial


def race(game, lst, track, vblanks, work, tag):
    sym = bench.symbols(lst)
    rec, snap = os.path.join(work, tag + '.rec'), os.path.join(work, tag)
    sc, _ = test_physics.race_script(lst, track, False, 100 + track, rec, snap)
    sc = re.sub(r'record \S+ \S+ \S+ (\d+)', r'frames \1', sc)
    rows, parts, _ = routines(sym)
    log = os.path.join(work, tag + '.log')
    base = sym['Screens']
    head, tail = sc.split('joy f\nframes 60\n')
    marks = ''.join(f'trace {a:#x}\n' for a in rows + list(parts))
    # the random controls, cut to the vblanks wanted
    lines, n, out = tail.split('\n'), 0, []
    for l in lines:
        if l.startswith('frames '):
            k = min(int(l.split()[1]), vblanks - n)
            n += k
            if k <= 0:
                continue
            l = f'frames {k}'
        out.append(l)
    sc = (head + 'joy f\nframes 60\n' + f'log {log}\n' + marks + f'writelog {base:#x} {base + 2 * SCREEN_STEP:#x}\nwritelogp0 1\n' +
          '\n'.join(out))
    txt = os.path.join(work, tag + '.txt')
    open(txt, 'w').write(sc)
    subprocess.run([bench.EMU, game, bench.helper(), os.path.join(ROOT, 'original', 'bin', 'loadpic_78000.bin'), txt],
                   check=True, capture_output=True)
    return log, sym, base


def read_frames(log, sym, base):
    """the log as frames: each a list of rows, each a list of (screen, line, word, whole) writes"""
    rows, parts, partial = routines(sym)
    rowset = set(rows)
    mark = re.compile(r'frame \d+ line \d+: pc \$([0-9A-F]+)')
    wr = re.compile(r'(\d+) (\d+) ([0-9A-F]+) ([0-9A-F]+) ([0-9A-F]+)/(\d)')
    frames, cur, row = [], None, None
    for l in open(log):
        m = mark.match(l)
        if m:
            pc = int(m.group(1), 16)
            if pc == sym['DrawHorizon']:                        # a frame's drawing starts
                cur = []
                frames.append(cur)
                row = None
            elif pc in rowset and cur is not None:
                row = []
                cur.append(row)
            continue
        m = wr.match(l)
        if not m or row is None:
            continue
        pc, addr, size = int(m.group(3), 16), int(m.group(4), 16), int(m.group(6))
        off = addr - base
        scr, off = divmod(off, SCREEN_STEP)
        if scr not in (0, 1) or off >= 8000:
            continue
        line, w = divmod(off, 40)
        w //= 2
        if not (VIEW_LINE <= line < VIEW_LINE + LINES and VIEW_WORD <= w < VIEW_WORD + WORDS):
            continue
        whole = size >= 2 and not (partial[0] <= pc < partial[1])
        for k in range(size // 2 if size >= 2 else 1):
            row.append((scr, line, w + k, whole and size >= 2))
    return frames


def analyse(frame):
    """(rows, words, covered words, touched words, rows hidden by covered, rows hidden by touched)"""
    full, any_ = {}, {}                                         # word -> the latest row to write it whole / at all
    for i, row in enumerate(frame):
        for scr, line, w, whole in row:
            any_[(scr, line, w)] = i
            if whole:
                full[(scr, line, w)] = i
    words = cov = tou = hid_c = hid_t = nrows = 0
    for i, row in enumerate(frame):
        ws = {(scr, line, w) for scr, line, w, _ in row}
        if not ws:
            continue
        nrows += 1
        c = sum(1 for k in ws if full.get(k, -1) > i)
        t = sum(1 for k in ws if any_.get(k, -1) > i)
        words += len(ws)
        cov += c
        tou += t
        hid_c += c == len(ws)
        hid_t += t == len(ws)
    return nrows, words, cov, tou, hid_c, hid_t


def main():
    vbl = int(bench.arg('--vblanks', 1500))
    tracks = [int(t) for t in bench.arg('--tracks', '0,1,2,3,4,5,6,7').split(',')]
    work = bench.arg('--keep') or tempfile.mkdtemp()
    os.makedirs(work, exist_ok=True)
    if not os.path.exists(bench.EMU):
        subprocess.run(['sh', os.path.join(bench.EMU_DIR, 'build.sh')], check=True)
    game, lst = build(work)
    tot = [0] * 6
    nframes = 0
    print(f'{"track":6s}{"frames":>7s}{"rows":>6s}{"words":>8s}{"covered":>9s}{"touched":>9s}{"rows hidden":>13s}{"(upper)":>9s}')
    for t in tracks:
        log, sym, base = race(game, lst, t, vbl, work, f't{t}')
        frames = [f for f in read_frames(log, sym, base) if len(f) > 3]
        res = [analyse(f) for f in frames]
        s = [sum(r[i] for r in res) for i in range(6)]
        n = max(1, len(frames))
        print(f'{t:<6d}{len(frames):7d}{s[0] / n:6.1f}{s[1] / n:8.0f}{100 * s[2] / max(1, s[1]):8.1f}%{100 * s[3] / max(1, s[1]):8.1f}%'
              f'{s[4] / n:7.1f} ({100 * s[4] / max(1, s[0]):.0f}%){100 * s[5] / max(1, s[0]):6.0f}%')
        for i in range(6):
            tot[i] += s[i]
        nframes += len(frames)
        worst = sorted(res, key=lambda r: -r[5])[:3]
        print('       most hidden (upper): ' + '; '.join(f'{r[5]} of {r[0]} rows' for r in worst))
    n = max(1, nframes)
    print(f'{"all":<6s}{nframes:7d}{tot[0] / n:6.1f}{tot[1] / n:8.0f}{100 * tot[2] / max(1, tot[1]):8.1f}%'
          f'{100 * tot[3] / max(1, tot[1]):8.1f}%{tot[4] / n:7.1f} ({100 * tot[4] / max(1, tot[0]):.0f}%){100 * tot[5] / max(1, tot[0]):6.0f}%')


if __name__ == '__main__':
    main()
