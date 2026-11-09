"""Check that the race goes exactly as before a change to the game's code: the cars' physics,
the opponent and the race's state, step by step.

  python3 enhanced/tools/test_physics.py [--base REF] [--keep DIR]

Two games are built: this checkout's enhanced/src and the one at git REF (default: HEAD - so
the uncommitted changes are what is checked; the workflow gives the last commit whose race this
one must reproduce, so that a change meant to be exact - src/physfast.i - is checked against the
game before it). Both are run in scremu with the CPU 20 times an A500's (cpumult 20), so that
every step and its picture are done within the first vertical blank of the six a step takes and
the two games keep the same time to the vertical blank whatever their speed. Each race is driven
the same way in both: the benchmark's way to the race, the track chosen at the preview, then
random controls (the stick and fire held 8-40 vertical blanks at a time, up - the accelerator -
more than half the time). The race's variables (RaceSettings to TrackGrid, and TrackGrid itself)
are recorded at the end of every vertical blank and compared; so is the memory below the game at
the end of the race (the work areas below the game, $400-$E6FF: not the game's own image, whose
copper lists and supervisor stack hold addresses of code that moves when the code changes size). The race's
variables must be where they were. Fails on any difference.

The races: each of the 8 tracks, with the release's timing (F8: a step and a picture each frame,
each at the start of its six vertical blanks). The enhanced game's own timing (src/interp.i)
draws pictures between the steps as fast as the CPU can, so its variables at a vertical blank
depend on the speed.
"""
import io, os, random, subprocess, sys, tarfile, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ENH = os.path.normpath(os.path.join(HERE, '..'))
ROOT = os.path.normpath(os.path.join(ENH, '..'))
ORIG = os.path.join(ROOT, 'original')
sys.path.insert(0, HERE)
import bench

CPUMULT = 20
GAME_ORG = 0xE700                   # where the game is loaded
VBLANKS = 3000                      # each race's (10 minutes of the game at 6 a step: 500 steps)


def assemble(src, work, name):
    game = os.path.join(work, name + '.bin')
    vasm = os.environ.get('VASM', 'vasmm68k_mot')
    subprocess.run([vasm, '-Fbin', '-m68000', '-no-opt', '-quiet', '-I', src, '-I', ORIG,
                    '-L', game[:-4] + '.lst', '-o', game, os.path.join(src, 'scr_game.s')], check=True)
    # its helper block too: the keys' flags (src/helper_c0.s) have moved between versions of the game
    subprocess.run([vasm, '-Fbin', '-m68000', '-no-opt', '-quiet', '-I', src, '-o', game[:-4] + '.helper',
                    os.path.join(src, 'helper_c0.s')], check=True)
    return game


def base_src(ref, work):
    """enhanced/src as it is at git ref, in work/base_src"""
    out = os.path.join(work, 'base_src')
    os.makedirs(out, exist_ok=True)
    tar = subprocess.run(['git', 'archive', ref, 'enhanced/src'], cwd=ROOT, check=True, capture_output=True).stdout
    with tarfile.open(fileobj=io.BytesIO(tar)) as t:
        for m in t.getmembers():
            if m.isfile():
                m.name = os.path.basename(m.name)
                t.extract(m, out, filter='data') if hasattr(tarfile, 'data_filter') else t.extract(m, out)
    return out


def preview_addr(lst):
    """the address of the race set-up's read of CurrentTrack for BuildTrack (the release's $5D2C2)"""
    for line in open(lst, errors='replace'):
        if line.rstrip().endswith('; 5D2C2') and line.startswith('00:'):
            return int(line.split()[0][3:], 16)
    sys.exit('the track preview not found in ' + lst)


def race_script(lst, track, interp, seed, rec, snap):
    """the benchmark's way to the race (track chosen at the preview), then VBLANKS vertical blanks of
    random controls, the variables appended to rec after each"""
    sys.argv = ['bench.py', '--cpumult', str(CPUMULT)] + (['--interp'] if interp else [])
    L = bench.script(10, snap, lst=lst).split('\n')
    season = L.index('joy d')
    second = [k for k, l in enumerate(L) if l == 'joy f' and k > season][1]
    sym = bench.symbols(lst)
    L = (L[:second + 3] + [f'until {preview_addr(lst):#x} 400', f'poke {sym["CurrentTrack"]:#x} {track} b',
                                  # Random's state set before BuildTrack (SetRaceLimits: the opponent's
                                  # speeds) - the menus call Random as they wait, so many times as the
                                  # CPU is fast
                                  f'poke {sym["RandomSeed"]:#x} {0x5EED1234 + track:#x} l',
                                  f'poke {sym["dat_625A4"]:#x} 0x4321 w', f'poke {sym["dat_625A6"]:#x} 0x55 b'] +
         L[second + 3:])
    sc = '\n'.join(L).split('joy f\nframes 10')[0] + 'joy f\nframes 60\n'   # to the race's start
    lo, hi = sym['RaceSettings'], sym['TrackGrid'] + 256
    rnd = random.Random(seed)
    n = 0
    while n < VBLANKS:
        joy = rnd.choice(['u', 'u', 'ul', 'ur', 'uf', 'ulf', 'urf', 'd', 'dl', 'dr', 'l', 'r', '', 'f'])
        hold = min(rnd.randint(8, 40), VBLANKS - n)
        sc += f'joy {joy}\nrecord {lo:#x} {hi:#x} {rec} {hold}\n'
        n += hold
    sc += f'joy\nsnap {snap}\n'
    return sc, hi - lo


def run(game, lst, track, interp, seed, work, tag):
    rec, snap = os.path.join(work, tag + '.rec'), os.path.join(work, tag)
    if os.path.exists(rec):
        os.remove(rec)
    sc, size = race_script(lst, track, interp, seed, rec, snap)
    txt = os.path.join(work, tag + '.txt')
    open(txt, 'w').write(sc)
    out = subprocess.run([bench.EMU, game, game[:-4] + '.helper', os.path.join(ORIG, 'bin', 'loadpic_78000.bin'), txt],
                         check=True, capture_output=True, text=True).stdout
    if out.count(': reached') < 3:
        sys.exit(f'{tag}: the race not reached\n{out}')
    return rec, snap + '.mem', size


def label_at(sym, addr):
    best = max(((v, k) for k, v in sym.items() if v <= addr and not k.startswith(('l_', '.'))), default=(0, '?'))
    return f'{best[1]}+{addr - best[0]:#x}' if addr != best[0] else best[1]


def main():
    ref = bench.arg('--base', 'HEAD')
    work = bench.arg('--keep') or tempfile.mkdtemp()
    os.makedirs(work, exist_ok=True)
    if not os.path.exists(bench.EMU):
        subprocess.run(['sh', os.path.join(bench.EMU_DIR, 'build.sh')], check=True)
    new = assemble(os.path.join(ENH, 'src'), work, 'new')
    old = assemble(base_src(ref, work), work, 'old')
    s_new, s_old = bench.symbols(new[:-4] + '.lst'), bench.symbols(old[:-4] + '.lst')
    if s_new['RaceSettings'] != s_old['RaceSettings'] or s_new['TrackGrid'] != s_old['TrackGrid']:
        sys.exit('the race\'s variables have moved: the records cannot be compared byte for byte')
    code_lo = min(s_new['RaceSettings'], s_old['RaceSettings'])
    failed = False
    races = [(t, False, 100 + t) for t in range(8)]
    for track, interp, seed in races:
        name = f'track {track}' + (', the pictures between steps' if interp else '')
        ro, mo, size = run(old, old[:-4] + '.lst', track, interp, seed, work, f'o{track}{int(interp)}')
        rn, mn, _ = run(new, new[:-4] + '.lst', track, interp, seed, work, f'n{track}{int(interp)}')
        a, b = open(ro, 'rb').read(), open(rn, 'rb').read()
        frames = len(a) // size
        bad = None
        for f in range(frames):
            x, y = a[f * size:(f + 1) * size], b[f * size:(f + 1) * size]
            if x != y:
                d = [i for i in range(size) if x[i] != y[i]]
                bad = (f, d)
                break
        ma, mb = open(mo, 'rb').read(), open(mn, 'rb').read()
        # the work areas below the game (from $400; the telemetry's $3700-$3D80 left out) - not the
        # game's own image from $E700, whose copper lists and supervisor stack ($EAD2 down) hold
        # addresses of code that moves when code changes size
        low = [i for i in range(0x400, min(code_lo, GAME_ORG)) if ma[i] != mb[i] and not 0x3700 <= i < 0x3D80]
        moved = len(set(a[i * size + (s_new['PlayerPiece'] - code_lo)] for i in range(frames)))
        if bad:
            f, d = bad
            failed = True
            print(f'{name}: FAILED at vertical blank {f} of the race: ' +
                  ', '.join(f'{label_at(s_new, code_lo + i)} {a[f*size+i]:02X}/{b[f*size+i]:02X}' for i in d[:12]))
        elif low:
            failed = True
            print(f'{name}: the variables the same, but memory below them differs: ' +
                  ', '.join(f'{i:#x}' for i in low[:12]))
        else:
            print(f'{name}: {frames} records of {size} bytes the same ({moved} pieces driven on) - ok')
    sys.exit(1 if failed else 0)


if __name__ == '__main__':
    main()
