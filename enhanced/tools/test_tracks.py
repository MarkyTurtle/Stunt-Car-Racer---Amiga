"""Check that original/tools/tracks.py reads the tracks as the game does (original/docs/TRACKS.md).

  python3 enhanced/tools/test_tracks.py [--keep DIR]

The original game (original/scr_game.s, assembled with a listing) is run in scremu the benchmark's
way to the race; at the track preview (the second press on the race's screens) CurrentTrack is
set to each of the 8 tracks in turn just before BuildTrack, and the memory is kept just after it.
tracks.py --check then compares every table BuildTrack writes with its own reading of the track's
bytes. Fails on any difference.
"""
import os, subprocess, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, '..', '..'))
ORIG = os.path.join(ROOT, 'original')
sys.path.insert(0, HERE)
import bench

BEFORE = 0x5D2C2        # TrackPreview: the jsr before CurrentTrack is read for BuildTrack (5D2C8)
AFTER = 0x5D2D4         # and the call after BuildTrack


def main():
    work = sys.argv[sys.argv.index('--keep') + 1] if '--keep' in sys.argv else tempfile.mkdtemp()
    os.makedirs(work, exist_ok=True)
    vasm = os.environ.get('VASM', 'vasmm68k_mot')
    lst, game = os.path.join(work, 'game.lst'), os.path.join(work, 'game.bin')
    subprocess.run([vasm, '-Fbin', '-m68000', '-no-opt', '-quiet', '-L', lst, '-o', game, 'scr_game.s'],
                   cwd=ORIG, check=True)
    if not os.path.exists(bench.EMU):
        subprocess.run(['sh', os.path.join(bench.EMU_DIR, 'build.sh')], check=True)
    sym = bench.symbols(lst)
    sys.argv = ['bench']
    L = bench.script(10, os.path.join(work, 'x'), lst=lst).split('\n')
    season = L.index('joy d')                      # the season chosen; then the race's screens' presses
    second = [k for k, l in enumerate(L) if l == 'joy f' and k > season][1]
    head = '\n'.join(L[:second + 3])              # through the 2nd press (fire, 5 frames, released)
    for t in range(8):
        sc = (head + f'\nuntil {BEFORE:#x} 400\npoke {sym["CurrentTrack"]:#x} {t} b\n'
              f'until {AFTER:#x} 100\nsnap {os.path.join(work, f"t{t}")}\n')
        open(os.path.join(work, 'tracks.txt'), 'w').write(sc)
        out = subprocess.run([bench.EMU, game, os.path.join(ORIG, 'bin', 'lowmem_c0.bin'),
                              os.path.join(ORIG, 'bin', 'loadpic_78000.bin'), os.path.join(work, 'tracks.txt')],
                             check=True, capture_output=True, text=True).stdout
        if out.count(': reached') < 3:
            sys.exit(f'track {t}: the track preview not reached\n{out}')
    r = subprocess.run([sys.executable, os.path.join(ORIG, 'tools', 'tracks.py'), '--check', work])
    sys.exit(r.returncode)


if __name__ == '__main__':
    main()
