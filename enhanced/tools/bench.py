"""The race benchmark: the telemetry build played in scremu, the same race the same way every time,
so that a change to the game's speed shows as a change in the figures.

  python3 enhanced/tools/bench.py [--vblanks N] [--json OUT] [--compare BASE.json] [--list] [--game BIN] [--helper BIN] [--keep DIR]

Builds the telemetry game (tools/build_disk.py --telemetry) unless --game names one, and scremu
(original/tools/scremu/build.sh) if it is not built. Then: the title (fire), the driver's name
(MARK), the season (Division 4, the first race: Little Ramp, against Jumpin' Jack), fire through
the screens before it, and N vertical blanks of the race (default 3,000: a minute)
with fire held (the throttle) and the stick left alone; the race begins with the drop.
Prints tools/telemetry.py's report of the race (--json, --compare and --list are its options).

The times are the emulator's: a 68000 at 7.09 MHz running every instruction for its documented
cycles, with no slowdown for chip memory shared with the display (4 bitplanes in low resolution
take no cycles the 68000 would use) - close to an A500, not exact. The same build in WinUAE
(cycle-exact A500) gives the real figures (enhanced/README.md); for comparing two versions of the
game, the emulator's figures are exact and repeatable.
"""
import os, subprocess, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ENH = os.path.normpath(os.path.join(HERE, '..'))
ROOT = os.path.normpath(os.path.join(ENH, '..'))
ORIG = os.path.join(ROOT, 'original')
EMU_DIR = os.path.join(ORIG, 'tools', 'scremu')
EMU = os.path.join(EMU_DIR, 'scremu')
sys.path.insert(0, HERE)
import telemetry


def script(frames, snap):
    L = ['until 0xE730 100', 'frames 400', 'joy f', 'frames 5', 'joy', 'frames 150']   # the title: fire
    for k in ('37', '20', '13', '27', '44'):                                           # MARK, Return
        L += [f'key {k}', 'frames 10']
    L += ['frames 160', 'joy f', 'frames 5', 'joy', 'frames 150',                      # the divisions
          'joy d', 'frames 8', 'joy', 'frames 30']                                      # 3. the season
    for _ in range(5):                                                                 # the race screen,
        L += ['joy f', 'frames 5', 'joy', 'frames 250']                                # the track, the drop
    L += ['joy f', f'frames {frames}', f'snap {snap}']
    return '\n'.join(L) + '\n'


def helper():
    """the helper block at $C0: the enhanced build's (src/helper_c0.s), or with --helper FILE that one"""
    h = arg('--helper') or os.path.join(ENH, 'build', 'helper_c0.bin')
    if not os.path.exists(h):
        subprocess.run([sys.executable, os.path.join(HERE, 'build_disk.py')], check=True, stdout=subprocess.DEVNULL)
    return h


def arg(name, default=None):
    return sys.argv[sys.argv.index(name) + 1] if name in sys.argv else default


def main():
    if '-h' in sys.argv or '--help' in sys.argv:
        sys.exit(__doc__)
    frames = int(arg('--vblanks', 3000))
    game = arg('--game')
    if not game:
        subprocess.run([sys.executable, os.path.join(HERE, 'build_disk.py'), '--telemetry'], check=True, stdout=subprocess.DEVNULL)
        game = os.path.join(ENH, 'build', 'game_telemetry.bin')
    if not os.path.exists(EMU):
        subprocess.run(['sh', os.path.join(EMU_DIR, 'build.sh')], check=True)
    work = arg('--keep') or tempfile.mkdtemp()
    os.makedirs(work, exist_ok=True)
    sc = os.path.join(work, 'bench.txt')
    open(sc, 'w').write(script(frames, os.path.join(work, 'race')))
    subprocess.run([EMU, game, helper(), os.path.join(ORIG, 'bin', 'loadpic_78000.bin'), sc],
                   check=True, stdout=subprocess.DEVNULL)
    sys.argv = (['telemetry.py', os.path.join(work, 'race.mem')] + sum(([o, arg(o)] for o in ('--json', '--compare') if arg(o)), []) +
                (['--list'] if '--list' in sys.argv else []))
    telemetry.main()


if __name__ == '__main__':
    main()
