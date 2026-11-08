"""Check src/physfast.i's LoadPiece call by call: the game assembled with PHYS_CHECK, where each
LoadPiece from the table is also done the release's way from the same state and the 20 variables
and the registers compared (src/physfast.i), raced on each of the 8 tracks with random controls.

  python3 enhanced/tools/test_physfast.py [--keep DIR]

Counts at $3770 (the calls compared) and $3774 (those that differ) read at the end of each race.
Fails on any difference, or on a race with no calls compared.
"""
import os, re, struct, subprocess, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ENH = os.path.normpath(os.path.join(HERE, '..'))
ROOT = os.path.normpath(os.path.join(ENH, '..'))
sys.path.insert(0, HERE)
import bench
import test_physics


def main():
    work = bench.arg('--keep') or tempfile.mkdtemp()
    os.makedirs(work, exist_ok=True)
    if not os.path.exists(bench.EMU):
        subprocess.run(['sh', os.path.join(bench.EMU_DIR, 'build.sh')], check=True)
    vasm = os.environ.get('VASM', 'vasmm68k_mot')
    game, lst = os.path.join(work, 'check.bin'), os.path.join(work, 'check.lst')
    subprocess.run([vasm, '-Fbin', '-m68000', '-no-opt', '-quiet', '-DPHYS_CHECK', '-I', os.path.join(ENH, 'src'),
                    '-I', os.path.join(ROOT, 'original'), '-L', lst, '-o', game,
                    os.path.join(ENH, 'src', 'scr_game.s')], check=True)
    failed = False
    for track in range(8):
        snap = os.path.join(work, f'end{track}')
        sc, _ = test_physics.race_script(lst, track, False, 100 + track, os.path.join(work, 'r.rec'), snap)
        sc = re.sub(r'record \S+ \S+ \S+ (\d+)', r'frames \1', sc)          # no records needed
        txt = os.path.join(work, 'race.txt')
        open(txt, 'w').write(sc)
        subprocess.run([bench.EMU, game, bench.helper(), os.path.join(ROOT, 'original', 'bin', 'loadpic_78000.bin'), txt],
                       check=True, capture_output=True)
        mem = open(snap + '.mem', 'rb').read()
        calls, bad = struct.unpack('>I', mem[0x3770:0x3774])[0], struct.unpack('>I', mem[0x3774:0x3778])[0]
        ok = calls and not bad
        failed |= not ok
        print(f'track {track}: {calls} LoadPiece calls from the table compared with the release\'s, {bad} differ'
              f' - {"ok" if ok else "FAILED"}')
    sys.exit(1 if failed else 0)


if __name__ == '__main__':
    main()
