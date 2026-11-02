"""The race benchmark: the telemetry build played in scremu, the same race the same way every time,
so that a change to the game's speed shows as a change in the figures.

  python3 enhanced/tools/bench.py [--vblanks N] [--json OUT] [--compare BASE.json] [--list] [--opponent] [--calibrate] [--chipbus] [--cpulost N] [--calibration REF.json] [--interp] [--half] [--nomountains] [--cpumult N] [--game BIN] [--helper BIN] [--keep DIR]

Builds the telemetry game (tools/build_disk.py --telemetry) unless --game names one, and scremu
(original/tools/scremu/build.sh) if it is not built. Then: the title (fire), the driver's name
(MARK), the season (Division 4, the first race: Little Ramp, against Jumpin' Jack), fire through
the screens before it, and N vertical blanks of the race (default 3,000: a minute)
with fire held (the throttle) and the stick left alone; the race begins with the drop.
Prints tools/telemetry.py's report of the race (--json, --compare, --calibration and --list are its
options). --opponent keeps the opponent one piece ahead of the player (its piece set from the player's every
25 vertical blanks): its car in view all the race - the drawing's worst case so far, about 9%
more than without. --calibrate presses F7 in the race: the calibration run (src/calibrate.i), whose figures
are the emulator's to compare with a real Amiga's. --chipbus rounds each instruction from chip
memory up to 4 cycles (scremu's chipbus: an older model, which does not fit the A500).

The times are the emulator's, fitted to an A500's: a 68000 at 7.09 MHz with the 68000's
cycles, 6 cycles of each raster line lost to DMA (scremu's cpulost) - the telemetry build's
calibration run on an A500 is matched within 1.2% (enhanced/measurements/). For comparing two
versions of the game the emulator's figures are exact and repeatable. --cpulost N changes the
DMA's share (0: none).

The race is run with the release's timing (a step and a picture each frame, at most every 6
vertical blanks: F8's flag set at the start), so that the figures measure the drawing as before.
--interp leaves the enhanced game's own timing on (src/interp.i: the steps to the clock, the
view drawn between them): the telemetry's frames are then its steps, each with the picture it
drew (or none, catching up). --half draws the view at half its height, doubled (src/halfres.i:
F9); --nomountains leaves the mountains out (F10). --cpumult N runs the CPU N times as fast (an accelerated Amiga:
scremu's cpumult). The blitter is timed (scremu's blittime: 2 CPU cycles for each of its
memory cycles, about one a channel a word): the CPU waiting for a blit waits as long as an A500's
would (its bus shared with the CPU is not modelled: the enhanced game waits for each of its blits).
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
    L = (['chipbus 1'] if '--chipbus' in sys.argv else []) + (['cpulost ' + arg('--cpulost')] if arg('--cpulost') else []) + \
        (['cpumult ' + arg('--cpumult')] if arg('--cpumult') else []) + \
        ['blittime 1',                                                                  # the blitter's time: the CPU waits for it
         'until 0xE730 100'] + \
        ([] if '--interp' in sys.argv else ['poke 0x174 1 b']) + \
        (['poke 0x175 1 b'] if '--half' in sys.argv else []) + \
        (['poke 0x176 1 b'] if '--nomountains' in sys.argv else []) + \
        ['frames 400', 'joy f', 'frames 5', 'joy', 'frames 150']                         # the title: fire
    for k in ('37', '20', '13', '27', '44'):                                           # MARK, Return
        L += [f'key {k}', 'frames 10']
    L += ['frames 160', 'joy f', 'frames 5', 'joy', 'frames 150',                      # the divisions
          'joy d', 'frames 8', 'joy', 'frames 30']                                      # 3. the season
    for _ in range(5):                                                                 # the race screen,
        L += ['joy f', 'frames 5', 'joy', 'frames 250']                                # the track, the drop
    if '--calibrate' in sys.argv:                                                     # F7 in the race: the
        L += ['joy f', 'frames 600', 'key 56', 'frames 120', 'joy f', f'frames {max(0, frames - 720)}']   # calibration run
    elif '--opponent' in sys.argv:                                                    # the opponent kept a
        sym = symbols()                                                               # piece ahead: in view
        L += ['joy f']
        for _ in range(0, frames, 25):
            L += [f'pokecopy {sym["OpponentPiece"]:#x} {sym["PlayerPiece"]:#x} 1', 'frames 25']
    else:
        L += ['joy f', f'frames {frames}']
    L += [f'snap {snap}']
    return '\n'.join(L) + '\n'


def symbols():
    """the telemetry game's symbols (its listing, tools/build_disk.py --telemetry)"""
    out = {}
    for line in open(os.path.join(ENH, 'build', 'game_telemetry.lst'), errors='replace'):
        p = line.split()
        if len(p) == 2 and p[1][:2] in ('A:', 'E:') and len(p[1]) == 10:
            out[p[0]] = int(p[1][2:], 16)
    return out


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
    work = arg('--keep') or tempfile.mkdtemp()                       # (the game built: its symbols for --opponent)
    os.makedirs(work, exist_ok=True)
    sc = os.path.join(work, 'bench.txt')
    open(sc, 'w').write(script(frames, os.path.join(work, 'race')))
    subprocess.run([EMU, game, helper(), os.path.join(ORIG, 'bin', 'loadpic_78000.bin'), sc],
                   check=True, stdout=subprocess.DEVNULL)
    sys.argv = (['telemetry.py', os.path.join(work, 'race.mem')] + sum(([o, arg(o)] for o in ('--json', '--compare', '--calibration') if arg(o)), []) +
                (['--list'] if '--list' in sys.argv else []))
    telemetry.main()


if __name__ == '__main__':
    main()
