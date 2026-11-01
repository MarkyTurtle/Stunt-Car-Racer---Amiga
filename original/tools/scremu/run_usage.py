"""Play the game in scremu for a long while and record what memory it uses (and which routines it
calls, how often): the measurements behind docs/MEMORY.md.

  python3 original/tools/scremu/run_usage.py OUTDIR [FRAMES]     (default 300000 random frames)

Runs from the start, past the start-up checksum (its reads of the whole game are left out: the map
is cleared once it is done), through the title menu (fire), the driver's name (typed) and the
divisions into a racing season (scripted), then FRAMES frames of random joystick (held 8-40
frames at a time, fire included), which race, crash, finish races and wander the menus.
Writes OUTDIR/usage.bin (the memory-use map), OUTDIR/calls.txt (routine: times called),
OUTDIR/cover.bin, snapshots OUTDIR/snapNN every 10,000 frames; then prints usage.py's summary.
Needs scremu built (tools/scremu/build.sh)."""
import os, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
ORIG = os.path.normpath(os.path.join(HERE, '..', '..'))
EMU = os.path.join(HERE, 'scremu')


def script(out, frames):
    L = ['until 0xE730 100', 'usageclear', 'calls 1',
         'frames 400', 'joy f', 'frames 5', 'joy', 'frames 150']                 # title: 1. Single Player League
    for k in ('37', '20', '13', '27', '44'):                                         # the name: MARK, Return
        L += ['key ' + k, 'frames 10']
    L += ['frames 150', 'joy f', 'frames 5', 'joy', 'frames 150',                 # the divisions -> the menu
          'joy d', 'frames 8', 'joy', 'frames 30', 'joy f', 'frames 5', 'joy', 'frames 200']   # 3. the season
    for i in range(0, frames, 10000):
        L += [f'random {min(10000, frames - i)} {100 + i // 10000}', f'snap {out}/snap{i // 10000:02d}']
    L += [f'usage {out}/usage.bin', f'callsdump {out}/calls.txt', f'cover {out}/cover.bin']
    return '\n'.join(L) + '\n'


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    out = os.path.abspath(sys.argv[1])
    frames = int(sys.argv[2]) if len(sys.argv) > 2 else 300000
    os.makedirs(out, exist_ok=True)
    sc = os.path.join(out, 'script.txt')
    open(sc, 'w').write(script(out, frames))
    subprocess.run([EMU, os.path.join(ORIG, 'disk', 'files', 't010-083_game.bin'), os.path.join(ORIG, 'bin', 'lowmem_c0.bin'),
                    os.path.join(ORIG, 'bin', 'loadpic_78000.bin'), sc], check=True)
    subprocess.run([sys.executable, os.path.join(HERE, 'usage.py'), os.path.join(out, 'usage.bin')], check=True)


if __name__ == '__main__':
    main()
