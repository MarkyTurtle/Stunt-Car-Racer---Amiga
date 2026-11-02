"""Read the telemetry build's results (src/telemetry.i) and report them.

  python3 enhanced/tools/telemetry.py FILE [--json OUT] [--compare BASE.json] [--calibration REF.json] [--list]

FILE is either a whole 512K memory image (a scremu snapshot's .mem) or the telemetry saved on its
own (in WinUAE's debugger, Shift+F12): "S telemetry.bin 3780 500" - the calibration run's results
($3780, F7 in a race: src/calibrate.i) and the race's ($3800) - or, older, "S telemetry.bin 3800
480" (the race's only). --list lists the last 64 frames. --json writes the figures for --compare
(a later run against it: the change in each). --calibration REF.json compares the calibration
run with another's (a real Amiga's against the emulator's, say).
"""
import json, struct, sys

BASE, SIZE = 0x3800, 0x480
CAL_BASE, CAL_SIZE = 0x3780, 0x80
CAL_TESTS = [('regs', 'registers only: 2,000 add, eor, dbra'), ('mul', '400 mulu'),
             ('read', 'chip memory read: 2,000 words'), ('write', 'chip memory written: 2,000 longs'),
             ('rmw', 'chip memory read and written: 2,000 words'), ('cutout', 'DrawCutout: the cockpit\'s widest part, twice'),
             ('plotpixel', 'PlotPixel: 500 pixels'), ('fill', 'ClearWordPlanes/PlotWord: 500 words')]


def split(data):
    """the calibration block (or None) and the telemetry block, from what was saved"""
    if len(data) >= 0x80000:
        return data[CAL_BASE:CAL_BASE + CAL_SIZE], data[BASE:BASE + SIZE]
    if data[:4] == b'CALB' or len(data) >= CAL_SIZE + SIZE:
        return data[:CAL_SIZE], data[CAL_SIZE:CAL_SIZE + SIZE]
    return None, data


def calibration(cal):
    if not cal or cal[:4] != b'CALB':
        return None
    version, tests, runs = struct.unpack_from('>HHH', cal, 4)
    cycles = struct.unpack_from(f'>{tests}L', cal, 0x10)
    return {'runs': runs, 'cycles': {name: c for (name, _), c in zip(CAL_TESTS, cycles)}}


def calibration_report(c, ref=None):
    out = [f'the calibration run (F7, {c["runs"]} run(s); the last): CPU cycles' + (' - and against the reference' if ref else '')]
    for name, what in CAL_TESTS:
        v = c['cycles'].get(name)
        if v is None:
            continue
        line = f'  {name:10s} {v:8,d}'
        if ref and ref['cycles'].get(name):
            r = ref['cycles'][name]
            line += f'  {r:8,d}  x{v / r:.3f}'
        out.append(line + f'   {what}')
    return '\n'.join(out)
PHASES = ['input', 'cars', 'geometry', 'drawing', 'cockpit', 'rest', 'wait']
LINE_US = 1e6 / (313 * 49.92)          # a raster line: 64 us
FRAME_LINES = 313
NOTES = {'input': 'the controls, the car\'s physics, the engine',
         'cars': 'the cars placed on the track, the opponent',
         'geometry': 'the pieces in view: points rotated and projected, edges stepped',
         'drawing': 'sky and ground, mountains, the track\'s surfaces, the cars',
         'cockpit': 'the cockpit\'s parts drawn over the view',
         'rest': 'the drawbridge, the instruments',
         'wait': 'FrameLimiter: waiting for the 6th vertical blank'}


def parse(data):
    cal, data = split(data)
    if data[:4] != b'TELM':
        sys.exit('no telemetry there (no "TELM" at $3800): the telemetry build, after at least one race?')
    version, recsize, frames, index, ringlen = struct.unpack_from('>HHLHH', data, 4)
    if version != 1 or recsize != 16:
        sys.exit(f'telemetry version {version}, record size {recsize}: not known')
    sums = struct.unpack_from('>8L', data, 0x28)
    hist = struct.unpack_from('>16H', data, 0x48)
    shortest, longest = struct.unpack_from('>HH', data, 0x68)
    n = min(frames, ringlen)
    recs = [struct.unpack_from('>8H', data, 0x80 + 16 * ((index - n + i) % ringlen)) for i in range(n)]
    return {'frames': frames, 'phase_lines': dict(zip(PHASES, sums[:7])), 'total_lines': sums[7],
            'histogram_vblanks': list(hist), 'shortest_lines': shortest, 'longest_lines': longest,
            'last_frames': [{'lines': r[0], **dict(zip(PHASES, r[1:]))} for r in recs],
            'calibration': calibration(cal)}


def summary(t):
    f = t['frames'] or 1
    work = t['total_lines'] - t['phase_lines']['wait']
    return {'frames': t['frames'],
            'frame_ms': t['total_lines'] / f * LINE_US / 1000,
            'fps': f / (t['total_lines'] * LINE_US / 1e6) if t['total_lines'] else 0,
            'work_ms': work / f * LINE_US / 1000,
            'work_vblanks': work / f / FRAME_LINES,
            'phases_ms': {p: v / f * LINE_US / 1000 for p, v in t['phase_lines'].items()}}


def report(t, base=None):
    s = summary(t)
    out = [f"{s['frames']:,} race frames: {s['frame_ms']:.1f} ms a frame on average, {s['fps']:.2f} frames a second",
           f"the work (all but the wait): {s['work_ms']:.1f} ms, {s['work_vblanks']:.2f} vertical blanks "
           f"(FrameLimiter allows a frame every 6: {6 * FRAME_LINES * LINE_US / 1000:.1f} ms)",
           f"shortest {t['shortest_lines'] * LINE_US / 1000:.1f} ms, longest {t['longest_lines'] * LINE_US / 1000:.1f} ms", '',
           f"{'phase':10s} {'ms':>7s} {'share':>6s}" + ('   change' if base else '')]
    tot = sum(s['phases_ms'].values()) or 1
    for p in PHASES:
        v = s['phases_ms'][p]
        line = f"{p:10s} {v:7.2f} {100 * v / tot:5.1f}%"
        if base:
            b = base['summary']['phases_ms'][p]
            line += f"  {v - b:+7.2f} ({(v - b) / b * 100:+.1f}%)" if b else f"  {v - b:+7.2f}"
        out.append(line + f"   {NOTES[p]}")
    if base:
        b = base['summary']
        out += ['', f"frame: {b['frame_ms']:.2f} -> {s['frame_ms']:.2f} ms ({(s['frame_ms'] - b['frame_ms']) / b['frame_ms'] * 100:+.1f}%), "
                    f"work: {b['work_ms']:.2f} -> {s['work_ms']:.2f} ms ({(s['work_ms'] - b['work_ms']) / b['work_ms'] * 100:+.1f}%), "
                    f"{b['fps']:.2f} -> {s['fps']:.2f} frames a second"]
    out += ['', 'frames by length (vertical blanks): ' +
            ', '.join(f"{i}{'+' if i == 15 else ''}: {n}" for i, n in enumerate(t['histogram_vblanks']) if n)]
    return '\n'.join(out)


def main():
    a = sys.argv[1:]
    if not a or a[0].startswith('-'):
        sys.exit(__doc__)
    t = parse(open(a[0], 'rb').read())
    base = json.load(open(a[a.index('--compare') + 1])) if '--compare' in a else None
    print(report(t, base))
    if t['calibration']:
        ref = json.load(open(a[a.index('--calibration') + 1]))['calibration'] if '--calibration' in a else None
        print('\n' + calibration_report(t['calibration'], ref))
    if '--list' in a:
        print('\nthe last frames (lines):\n' + f"{'total':>6s} " + ' '.join(f'{p:>8s}' for p in PHASES))
        for r in t['last_frames']:
            print(f"{r['lines']:6d} " + ' '.join(f'{r[p]:8d}' for p in PHASES))
    if '--json' in a:
        json.dump({**t, 'summary': summary(t)}, open(a[a.index('--json') + 1], 'w'), indent=1)


if __name__ == '__main__':
    main()
