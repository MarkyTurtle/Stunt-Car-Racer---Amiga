"""The race benchmark: the telemetry build played in scremu, the same race the same way every time,
so that a change to the game's speed shows as a change in the figures.

  python3 enhanced/tools/bench.py [--vblanks N] [--json OUT] [--compare BASE.json] [--list] [--opponent] [--calibrate] [--chipbus] [--cpulost N] [--calibration REF.json] [--interp] [--half] [--nomountains] [--farshort] [--renderer] [--cpumult N] [--blitcheck] [--game BIN [--lst LST]] [--helper BIN] [--keep DIR]

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
F9); --nomountains leaves the mountains out (F10); --farshort draws the track less far ahead (F4). --cpumult N runs the CPU N times as fast (an accelerated Amiga:
scremu's cpumult). The blitter is timed (scremu's blittime: 2 CPU cycles for each of its
memory cycles, about one a channel a word): the CPU waiting for a blit waits as long as an A500's
would (its bus shared with the CPU is not modelled). --blitcheck also runs scremu's blitcheck: each
CPU read or write of what a blit still running is to write - the order a real Amiga would get
wrong, which scremu (its blits done at once) would not show - is reported, and the run fails if
there is one (the blitter works beside the CPU: src/blitqueue.i).
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


RACE_WAIT = 224                     # vblanks from the race's start to the 4th press (as before)
RACE_SEED = 0x12345678              # Random's state for the race (the copy RestoreRandomSeed puts back)


def script(frames, snap, lst=None):
    """the benchmark's scremu script, for the game whose listing is lst (by default the telemetry
    build's). The race is started the same way whatever the menus took before it: the race's start
    (Race) waited for - from the start of a frame then - and Random's state for the race set there
    (dat_636B8: SaveRandomSeed keeps it after the title, RestoreRandomSeed puts it back as the race
    is set up; the menus call Random as they wait, so it would otherwise depend on how long they
    took - the opponent's place)"""
    sym = symbols(lst)
    L = (['chipbus 1'] if '--chipbus' in sys.argv else []) + (['cpulost ' + arg('--cpulost')] if arg('--cpulost') else []) + \
        (['cpumult ' + arg('--cpumult')] if arg('--cpumult') else []) + \
        ['blittime 1',                                                                  # the blitter's time: the CPU waits for it
         ] + (['blitcheck 1'] if '--blitcheck' in sys.argv else []) + [
         'until 0xE730 100'] + \
        ([] if '--interp' in sys.argv else [f'poke {sym.get("HelperInterpOff", 0x174):#x} 1 b']) + \
        ([f'poke {sym.get("HelperHalfRes", 0x175):#x} 1 b'] if '--half' in sys.argv else []) + \
        ([f'poke {sym.get("HelperMountainsOff", 0x176):#x} 1 b'] if '--nomountains' in sys.argv else []) + \
        ([f'poke {sym.get("HelperFarShort", 0x177):#x} 1 b'] if '--farshort' in sys.argv else []) + \
        ([f'poke {sym["HelperRenderer"]:#x} {renderer_arg()} b'] if '--renderer' in sys.argv else []) + \
        ['frames 400', 'joy f', 'frames 5', 'joy', 'frames 150']                         # the title: fire
    for k in ('37', '20', '13', '27', '44'):                                           # MARK, Return
        L += [f'key {k}', 'frames 10']
    L += ['frames 160', 'joy f', 'frames 5', 'joy', 'frames 150',                      # the divisions
          'joy d', 'frames 8', 'joy', 'frames 30']                                      # 3. the season
    for i in range(5):                                                                 # the race screen,
        L += ['joy f', 'frames 5', 'joy']                                              # the track, the drop:
        L += ([f'until {sym["Race"]:#x} 1000', f'poke {sym["dat_636B8"]:#x} {RACE_SEED:#x} l',   # the race's
               f'frames {RACE_WAIT}'] if i == 2 else ['frames 250'])                          # start
    if '--calibrate' in sys.argv:                                                     # F7 in the race: the
        L += ['joy f', 'frames 600', 'key 56', 'frames 120', 'joy f', f'frames {max(0, frames - 720)}']   # calibration run
    elif '--opponent' in sys.argv:                                                    # the opponent kept a
                                                                                      # piece ahead: in view
        L += ['joy f']
        for _ in range(0, frames, 25):
            L += [f'pokecopy {sym["OpponentPiece"]:#x} {sym["PlayerPiece"]:#x} 1', 'frames 25']
    else:
        L += (['callprof 1'] if '--callprof' in sys.argv else []) + (['profile 1'] if '--profile' in sys.argv else []) + ['joy f', f'frames {frames}']
    L += ([f'callprofdump {arg("--callprof")}'] if '--callprof' in sys.argv else []) + ([f'profdump {arg("--profile")}'] if '--profile' in sys.argv else []) + [f'snap {snap}']
    return '\n'.join(L) + '\n'


def renderer_arg():
    """--renderer [N]: the renderer F5 chooses (0-3); by default 1"""
    i = sys.argv.index('--renderer') + 1
    return int(sys.argv[i]) if i < len(sys.argv) and sys.argv[i].isdigit() else 1


def symbols(lst=None):
    """a game's symbols, from its listing: by default the telemetry build's (tools/build_disk.py --telemetry)"""
    out = {}
    for line in open(lst or os.path.join(ENH, 'build', 'game_telemetry.lst'), errors='replace'):
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
    game, lst = arg('--game'), arg('--lst')
    if game and not lst:
        lst = os.path.splitext(game)[0] + '.lst'                    # (its listing: the race's start)
    if not game:
        subprocess.run([sys.executable, os.path.join(HERE, 'build_disk.py'), '--telemetry'], check=True, stdout=subprocess.DEVNULL)
        game = os.path.join(ENH, 'build', 'game_telemetry.bin')
    if not os.path.exists(EMU):
        subprocess.run(['sh', os.path.join(EMU_DIR, 'build.sh')], check=True)
    work = arg('--keep') or tempfile.mkdtemp()                       # (the game built: its symbols for --opponent)
    os.makedirs(work, exist_ok=True)
    sc = os.path.join(work, 'bench.txt')
    open(sc, 'w').write(script(frames, os.path.join(work, 'race'), lst=lst))
    run = subprocess.run([EMU, game, helper(), os.path.join(ORIG, 'bin', 'loadpic_78000.bin'), sc],
                         check=True, capture_output=True, text=True)
    if '--blitcheck' in sys.argv:
        hz = [l for l in run.stdout.splitlines() if 'hazard' in l]
        print('\n'.join(hz), file=sys.stderr)
        if hz != ['blit hazards 0']:
            sys.exit('blit hazards: the CPU at a blit still running')
    sys.argv = (['telemetry.py', os.path.join(work, 'race.mem')] + sum(([o, arg(o)] for o in ('--json', '--compare', '--calibration') if arg(o)), []) +
                (['--list'] if '--list' in sys.argv else []))
    telemetry.main()


if __name__ == '__main__':
    main()
