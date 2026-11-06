"""Check that PrintCharNow's faster rows (src/textfast.i) draw what the release's loop drew.

  python3 enhanced/tools/test_text.py

The game is assembled with TEXT_CHECK: for every character printed, the release's loop (kept in
textfast.i) draws its 8 rows, then the bytes are put back and TextRows draws them again from the
same start; the bytes each wrote (both words of each row, 4 planes, both screens) and the
registers each left that the callers see (d2, d6, d7, a0-a6) are compared. Run in scremu through
the menus (the name typed, the divisions, the season: the proportional font and the menus'
colours) and races (the instruments, the readout); fails on any difference.
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
    subprocess.run([vasm, '-Fbin', '-m68000', '-no-opt', '-quiet', '-DTEXT_CHECK=1', '-I', os.path.join(ENH, 'src'),
                    '-I', os.path.join(ROOT, 'original'), '-o', game, os.path.join(ENH, 'src', 'scr_game.s')], check=True)
    if not os.path.exists(bench.EMU):
        subprocess.run(['sh', os.path.join(bench.EMU_DIR, 'build.sh')], check=True)
    failed = False
    for name, flags, tail in (('the menus and the benchmark race', [], 'frames 3000\n'),
                              ('random steering (crashes, messages)', [], 'frames 300\nrandom 4000 7\n'),
                              ('pictures between steps', ['--interp'], 'frames 300\nrandom 3000 5\n')):
        sys.argv = ['bench.py'] + flags
        snap = os.path.join(work, 'end')
        sc = bench.script(10, snap).split('joy f\nframes 10')[0] + 'joy f\n' + tail + f'snap {snap}\n'
        txt = os.path.join(work, 's.txt')
        open(txt, 'w').write(sc)
        subprocess.run([bench.EMU, game, bench.helper(), os.path.join(ROOT, 'original', 'bin', 'loadpic_78000.bin'), txt],
                       check=True, stdout=subprocess.DEVNULL)
        mem = open(snap + '.mem', 'rb').read()
        nbytes, chars, regs, prop, one, clear = struct.unpack_from('>6L', mem, 0x3740)
        ok = chars > 0 and nbytes == 0 and regs == 0
        failed |= not ok
        print(f'{name}: {chars} characters; {nbytes} bytes and {regs} registers differ from the release\'s loop - '
              f'{"ok" if ok else "FAILED"} ({prop} in the proportional font, {one} to one screen, {clear} without a background)')
    sys.exit(1 if failed else 0)


if __name__ == '__main__':
    main()
