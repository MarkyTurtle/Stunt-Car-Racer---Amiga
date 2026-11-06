"""Measure the variables the race view's drawing half keeps for itself, and write src/interp_keep.i.

  python3 enhanced/tools/measure_keep.py [--check] [--fresh]

interp.i draws pictures between the race's steps by running RaceView again on a blended state,
then sets the variables block (dat_1BAF8-dat_1C280) back - all but those the drawing half keeps
from picture to picture (the drop's chains, the cockpit's sway, caches of its own). This finds
them: the game is assembled with a marker (a byte at $3700: 1 while RaceView's drawing half runs,
from l_64F80 to its end), run with the release's timing (F8's flag) in scremu with its phasetrack
and writelog over the block, for two races - the benchmark's (bench.py) and one with random
steering (crashes, the car put back) - and every byte of the block written by the drawing half
and by nothing else in the race loop is kept. To those are added the few the physics starts and
the drawing carries on (EXTRA: found by phasetrack's reads across pictures).

What a race covers depends on the game's speed and the race, so the list grows: a new
measurement is merged with the file's list (--fresh: not), less any byte the rest of the game
was seen to write. --check checks the file against a measurement instead: every byte the drawing
alone wrote is on the list, and no byte on it was written by anything else (which would let a
picture's values leak into the physics).
"""
import os, re, subprocess, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ENH = os.path.normpath(os.path.join(HERE, '..'))
ROOT = os.path.normpath(os.path.join(ENH, '..'))
sys.path.insert(0, HERE)
import bench

EXTRA = ['dat_1BBDA', 'dat_1BBE9', 'dat_1BBEA', 'dat_1BB6D', 'dat_1BB6E', 'dat_1BBD3']
OUT = os.path.join(ENH, 'src', 'interp_keep.i')


def syms(lst):
    out = {}
    for line in open(lst, errors='replace'):
        p = line.split()
        if len(p) == 2 and p[1][:2] in ('A:', 'E:') and len(p[1]) == 10:
            out[p[0]] = int(p[1][2:], 16)
    return out


def main():
    work = tempfile.mkdtemp()
    src = open(os.path.join(ENH, 'src', 'scr_game.s')).read()
    for old, new in (("l_64F80:\n", "l_64F80:\n        move.b  #1,($3700).w            ; (measure_keep.py: the drawing half)\n"),
                     ("        jsr     (sub_5E508).l                   ; 651B0\n        rts                                     ; 651B6\n",
                      "        jsr     (sub_5E508).l                   ; 651B0\n        clr.b   ($3700).w\n        rts                                     ; 651B6\n")):
        if src.count(old) != 1:
            sys.exit('the marker points (l_64F80, the end of RaceView) not found')
        src = src.replace(old, new)
    marked = os.path.join(ENH, 'src', '_measure_keep.s')
    open(marked, 'w').write(src)
    vasm = os.environ.get('VASM', 'vasmm68k_mot')
    try:
        subprocess.run([vasm, '-Fbin', '-m68000', '-no-opt', '-quiet', '-I', os.path.join(ENH, 'src'), '-I', os.path.join(ROOT, 'original'),
                        '-L', os.path.join(work, 'g.lst'), '-o', os.path.join(work, 'g.bin'), marked], check=True)
    finally:
        os.remove(marked)
    sy = syms(os.path.join(work, 'g.lst'))
    lo, hi = sy['dat_1BAF8'], sy['dat_1C280']
    sys.argv = ['bench.py']                         # (bench's script: the release's timing)
    base = bench.script(10, os.path.join(work, 'x'), lst=os.path.join(work, 'g.lst')).split('joy f\nframes 10')[0]
    if not os.path.exists(bench.EMU):
        subprocess.run(['sh', os.path.join(bench.EMU_DIR, 'build.sh')], check=True)
    helper = bench.helper()
    own = {}
    for n, tail in (('a', 'frames 3000\n'), ('b', 'frames 300\nrandom 3000 7\n')):
        log = os.path.join(work, n + '.log')
        open(log, 'w').close()
        sc = os.path.join(work, n + '.txt')
        open(sc, 'w').write(base + f'joy f\nphasetrack 0x3700 0x3701 0x3702\nlog {log}\nwritelog {lo:#x} {hi:#x}\n' + tail)
        subprocess.run([bench.EMU, os.path.join(work, 'g.bin'), helper, os.path.join(ROOT, 'original', 'bin', 'loadpic_78000.bin'), sc],
                       check=True, stdout=subprocess.DEVNULL)
        for line in open(log):
            p = line.split()
            if len(p) != 6:
                continue
            a, size = int(p[3], 16), int(p[4].split('/')[1])
            for b in range(a, a + size):
                own.setdefault(b, set()).add(p[5])
    drawn_only = {a for a, ph in own.items() if ph == {'1'}}
    others = {a for a, ph in own.items() if ph - {'1'}}
    extra = {sy[v] for v in EXTRA}
    listed = set()
    if os.path.exists(OUT) and '--fresh' not in sys.argv:
        for line in open(OUT):
            m = re.match(r'\s*dc\.w\s+(\w+)\+(\d+)-dat_1BAF8,(\d+)', line)
            if m:
                a = sy[m.group(1)] + int(m.group(2))
                listed.update(range(a, a + int(m.group(3))))
    if os.environ.get('MEASURE_KEEP') == '--check':
        missing = sorted(drawn_only - listed)
        wrong = sorted((listed - extra) & others)
        for what, l in (('written only by the drawing, not on the list', missing), ('on the list, written by the rest of the game', wrong)):
            if l:
                print(f'{len(l)} bytes {what}: ' + ', '.join(f'${a:X}' for a in l[:20]))
        print('interp_keep.i ' + ('agrees with the measurement' if not missing and not wrong else 'does not agree with the measurement'))
        sys.exit(1 if missing or wrong else 0)
    keep = sorted(((listed | drawn_only) - others) | extra)
    runs = []
    for a in keep:
        if runs and a == runs[-1][0] + runs[-1][1]:
            runs[-1][1] += 1
        else:
            runs.append([a, 1])
    labels = sorted((v, k) for k, v in sy.items() if lo <= v < hi and not k.startswith('l_'))
    def name(a):
        best = max((v, k) for v, k in labels if v <= a)
        return best[1], a - best[0]
    lines = ['; interp_keep.i - (generated by tools/measure_keep.py: do not edit) the variables of the block',
             '; (dat_1BAF8-dat_1C280) the drawing keeps from picture to picture: written only by the view\'s',
             '; drawing half in two races (the benchmark\'s and one with random steering, phasetrack and writelog',
             '; in scremu), and those the physics starts and the drawing carries on (the drop\'s chains, the',
             '; cockpit\'s sway, the messages\' timers, a text flag). Offset in the block, bytes; -1 ends it.',
             'InterpKeepList:']
    for a, n in runs:
        lab, off = name(a)
        lines.append(f'\tdc.w\t{lab}+{off}-dat_1BAF8,{n}')
    lines += ['\tdc.w\t-1', f'INTERP_KEEP_BYTES\tequ\t{len(keep)}']
    text = '\n'.join(lines) + '\n'
    open(OUT, 'w').write(text)
    print(f'{OUT}: {len(keep)} bytes in {len(runs)} runs')


if __name__ == '__main__':
    check = '--check' in sys.argv
    if check:
        os.environ['MEASURE_KEEP'] = '--check'
    main()
