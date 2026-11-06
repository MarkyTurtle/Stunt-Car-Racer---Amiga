"""Check that the opponent's distance readout leaves a character as it is only when the screen
already shows it (src/readout.i).

  python3 enhanced/tools/test_readout.py

The game is assembled with READOUT_CHECK: each character the readout would not print again is
printed anyway, and the bytes of its cells in both screens compared before and after - printing
it must change nothing - and the text cursor and PrintCharNow's work bytes the skip would have
left compared with printing's. Run for races in scremu (the benchmark's, random steering, at half
height, with the pictures between steps); fails on any difference.
"""
import os, struct, subprocess, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ENH = os.path.normpath(os.path.join(HERE, '..'))
ROOT = os.path.normpath(os.path.join(ENH, '..'))
sys.path.insert(0, HERE)
import bench


def main():
    work = tempfile.mkdtemp()
    game = os.path.join(work, 'game.bin')
    vasm = os.environ.get('VASM', 'vasmm68k_mot')
    subprocess.run([vasm, '-Fbin', '-m68000', '-no-opt', '-quiet', '-DREADOUT_CHECK=1', '-I', os.path.join(ENH, 'src'),
                    '-I', os.path.join(ROOT, 'original'), '-o', game, os.path.join(ENH, 'src', 'scr_game.s')], check=True)
    if not os.path.exists(bench.EMU):
        subprocess.run(['sh', os.path.join(bench.EMU_DIR, 'build.sh')], check=True)
    failed = False
    for name, flags, tail in (('the benchmark race', [], 'frames 3000\n'),
                              ('random steering', [], 'frames 300\nrandom 3000 7\n'),
                              ('half height, random steering', ['--half'], 'frames 300\nrandom 3000 3\n'),
                              ('pictures between steps', ['--interp'], 'frames 300\nrandom 3000 5\n')):
        sys.argv = ['bench.py'] + flags
        snap = os.path.join(work, 'end')
        sc = bench.script(10, snap).split('joy f\nframes 10')[0] + 'joy f\n' + tail + f'snap {snap}\n'
        txt = os.path.join(work, 's.txt')
        open(txt, 'w').write(sc)
        subprocess.run([bench.EMU, game, bench.helper(), os.path.join(ROOT, 'original', 'bin', 'loadpic_78000.bin'), txt],
                       check=True, stdout=subprocess.DEVNULL)
        mem = open(snap + '.mem', 'rb').read()
        changed, skipped, state = struct.unpack_from('>LLL', mem, 0x3720)
        ok = skipped > 0 and changed == 0 and state == 0
        failed |= not ok
        print(f'{name}: {skipped} characters left as they were; printing them anyway changed {changed} longs of the '
              f'screens, the cursor {state} times - {"ok" if ok else "FAILED"}')
    sys.exit(1 if failed else 0)


if __name__ == '__main__':
    main()
