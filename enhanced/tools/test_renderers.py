"""How close renderer 1's picture is to renderer 0's (src/renderer.i: F5).

  python3 enhanced/tools/test_renderers.py [--tracks 0,1,..] [--shots N] [--max PERCENT] [--png DIR] [--half] [--nocockpit] [--vs RENDERER] [--keep DIR]

Each track is raced as test_physics.py does (the benchmark's way to the race, the track chosen at the
preview, then random controls) twice, once with each renderer (F5's flag, HelperRenderer, set at the
start), and the screen shown is taken at the same N vertical blanks of both races. The races go the
same way (the physics do not depend on the renderer; the timing is the release's, cpumult 20), so the
two pictures are of the same moment. The difference: the share of the view's pixels (256 x 128) whose
colour differs, per shot and on average, and its largest. With --png the pictures are written
(DIR/trackT_shotK_r0.png, _r1.png and _diff.png: the differing pixels in red on the first).

Fails if the average difference is over --max percent (default 5).
"""
import os, re, subprocess, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ENH = os.path.normpath(os.path.join(HERE, '..'))
ROOT = os.path.normpath(os.path.join(ENH, '..'))
sys.path.insert(0, HERE)
import bench
import test_physics

VIEW_X, VIEW_Y, VIEW_W, VIEW_H = 32, 16, 256, 128      # the view on the screen (pixels)


def run(game, lst, track, renderer, shots, vblanks, work, tag):
    """the race; a snapshot after each of `shots` equal parts of the vblanks. Returns the snapshot names"""
    flags = list(sys.argv)                  # (race_script sets sys.argv for bench's script)
    sym = bench.symbols(lst)
    sc, _ = test_physics.race_script(lst, track, False, 100 + track, os.path.join(work, 'r.rec'), os.path.join(work, tag))
    head, tail = sc.split('joy f\nframes 60\n')
    head += 'joy f\nframes 60\n'
    if renderer:
        head += f'poke {sym["HelperRenderer"]:#x} {renderer} b\n'
    if '--nocockpit' in flags:
        head += f'poke {sym["HelperCockpitOff"]:#x} 1 b\n'
    if '--half' in flags:
        head += f'poke {sym["HelperHalfRes"]:#x} 1 b\n'
    out, n, step, nxt, names = [], 0, vblanks // shots, 1, []
    for l in tail.split('\n'):
        m = re.match(r'record \S+ \S+ \S+ (\d+)', l)
        if not m:
            if l.startswith('snap '):
                continue
            out.append(l)
            continue
        k = int(m.group(1))
        while k > 0:
            take = min(k, nxt * step - n) if nxt <= shots else k
            out.append(f'frames {take}')
            n += take
            k -= take
            if nxt <= shots and n >= nxt * step:
                name = f'{tag}_{nxt}'
                out.append(f'snap {os.path.join(work, name)}')
                names.append(name)
                nxt += 1
    txt = os.path.join(work, tag + '.txt')
    open(txt, 'w').write(head + '\n'.join(out) + '\n')
    subprocess.run([bench.EMU, game, bench.helper(), os.path.join(ROOT, 'original', 'bin', 'loadpic_78000.bin'), txt],
                   check=True, capture_output=True)
    return names


def picture(work, name):
    sys.path.insert(0, os.path.join(ROOT, 'original', 'tools'))
    from screen import render
    mem, regs = open(os.path.join(work, name + '.mem'), 'rb').read(), open(os.path.join(work, name + '.regs'), 'rb').read()
    r = lambda o: regs[o] << 8 | regs[o + 1]
    cust = {o: r(o) for o in list(range(0x180, 0x1C0, 2)) + [0x100, 0x102, 0x108, 0x10A, 0x8E, 0x90, 0x92, 0x94]}
    return render(mem, r(0x80) << 16 | r(0x82), cust)


def main():
    import numpy as np
    from PIL import Image
    tracks = [int(t) for t in bench.arg('--tracks', '0,1,2,3,4,5,6,7').split(',')]
    shots = int(bench.arg('--shots', 12))
    vblanks = int(bench.arg('--vblanks', 3000))
    limit = float(bench.arg('--max', 5))
    work = bench.arg('--keep') or tempfile.mkdtemp()
    png = bench.arg('--png')
    vs = int(bench.arg('--vs', 1))
    os.makedirs(work, exist_ok=True)
    if png:
        os.makedirs(png, exist_ok=True)
    if not os.path.exists(bench.EMU):
        subprocess.run(['sh', os.path.join(bench.EMU_DIR, 'build.sh')], check=True)
    game, lst = os.path.join(work, 'game.bin'), os.path.join(work, 'game.lst')
    subprocess.run([os.environ.get('VASM', 'vasmm68k_mot'), '-Fbin', '-m68000', '-no-opt', '-quiet'] + os.environ.get('VASMOPT', '').split() + ['-I', os.path.join(ENH, 'src'),
                    '-I', os.path.join(ROOT, 'original'), '-L', lst, '-o', game, os.path.join(ENH, 'src', 'scr_game.s')], check=True)
    sys.argv += ['--cpumult', str(test_physics.CPUMULT)] if '--cpumult' not in sys.argv else []
    allpct = []
    for t in tracks:
        a = run(game, lst, t, 0, shots, vblanks, work, f't{t}r0')
        b = run(game, lst, t, vs, shots, vblanks, work, f't{t}r1')
        pcts = []
        for k, (x, y) in enumerate(zip(a, b), 1):
            ia, ib = picture(work, x), picture(work, y)
            va = np.asarray(ia.crop((VIEW_X, VIEW_Y, VIEW_X + VIEW_W, VIEW_Y + VIEW_H)))
            vb = np.asarray(ib.crop((VIEW_X, VIEW_Y, VIEW_X + VIEW_W, VIEW_Y + VIEW_H)))
            diff = (va != vb).any(axis=2)
            pcts.append(100.0 * diff.mean())
            if png:
                ia.save(os.path.join(png, f'track{t}_shot{k}_r0.png'))
                ib.save(os.path.join(png, f'track{t}_shot{k}_r1.png'))
                d = np.asarray(ia).copy()
                d[VIEW_Y:VIEW_Y + VIEW_H, VIEW_X:VIEW_X + VIEW_W][diff] = (255, 0, 0)
                Image.fromarray(d).save(os.path.join(png, f'track{t}_shot{k}_diff.png'))
        print(f'track {t}: the pictures differ in {sum(pcts) / len(pcts):.2f}% of the view on average, '
              f'{max(pcts):.2f}% at most ({len(pcts)} shots)')
        allpct += pcts
    avg = sum(allpct) / len(allpct)
    print(f'all: {avg:.2f}% on average (limit {limit}%)')
    sys.exit(1 if avg > limit else 0)


if __name__ == '__main__':
    main()
