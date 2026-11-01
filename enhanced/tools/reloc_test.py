"""Check that the game still works when its code moves: that src/scr_game.s has no address written
as a number where a label belongs (a pointer in a table, a patched instruction, an address
worked out from constants).

  python3 enhanced/tools/reloc_test.py [--vblanks N]

Assembles src/scr_game.s twice: as it is, and with 16 bytes put in after the entry (so that all the
rest - code, data, pictures - is 16 bytes later), then plays the benchmark's race (tools/bench.py:
the menus, the season's first race, N vertical blanks of it, default 3,000) in scremu with both, and
compares how often each routine was called. Any difference means something in the game still uses
an address that did not move with the code. (The game's load ends with its screens and the work
areas follow soon after: the code can be moved, but it cannot grow much - enhanced/TODO.md.)
"""
import os, subprocess, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import bench

SHIFT, AT = 16, '\nTrap0Handler:'


def calls(path, shift_from=None):
    out = {}
    for line in open(path):
        a, n = line.split()
        a = int(a, 16)
        if shift_from is not None and a >= shift_from + SHIFT:
            a -= SHIFT
        out[a] = int(n)
    return out


def main():
    vblanks = int(bench.arg('--vblanks', 2000))
    src = os.path.join(bench.ENH, 'src', 'scr_game.s')
    work = tempfile.mkdtemp()
    text = open(src).read()
    i = text.index(AT)
    moved = os.path.join(bench.ENH, 'src', '.reloc_test.s')         # beside the source: its includes
    open(moved, 'w').write(text[:i] + f'\n\tdcb.b\t{SHIFT},$AA\t; reloc_test.py' + text[i:])
    try:
        bins = []
        for name, s in (('as_is', src), ('moved', moved)):
            b = os.path.join(work, name + '.bin')
            bench_vasm(s, b)
            bins.append(b)
    finally:
        os.remove(moved)
    lst = os.path.join(work, 'as_is.lst')
    bench_vasm(src, os.path.join(work, 'x.bin'), lst)
    entry = next(int(l.split()[1][2:], 16) for l in open(lst, errors='replace') if l.startswith('Trap0Handler '))
    if not os.path.exists(bench.EMU):
        subprocess.run(['sh', os.path.join(bench.EMU_DIR, 'build.sh')], check=True)
    results = []
    for b in bins:
        sc = os.path.join(work, 'script.txt')
        txt = bench.script(vblanks, os.path.join(work, 'snap')).replace("joy f\nframes", "calls 1\njoy f\nframes", 1)
        lines = txt.split('\n')
        lines.insert(len(lines) - 2, f'callsdump {b}.calls')
        open(sc, 'w').write('\n'.join(lines))
        subprocess.run([bench.EMU, b, bench.helper(),
                        os.path.join(bench.ORIG, 'bin', 'loadpic_78000.bin'), sc], check=True, stdout=subprocess.DEVNULL)
        results.append(b + '.calls')
    a, m = calls(results[0]), calls(results[1], entry)
    diff = sorted(x for x in set(a) | set(m) if a.get(x) != m.get(x))
    print(f'{len(a)} routines called; moved {SHIFT} bytes: {len(diff)} differ')
    for x in diff[:20]:
        print(f'  ${x:05X}: {a.get(x, 0)} calls as it is, {m.get(x, 0)} moved')
    if diff:
        sys.exit('the game behaves differently when its code moves: an address in src/scr_game.s is not a label')


def bench_vasm(src, out, listing=None):
    cmd = [os.environ.get('VASM', 'vasmm68k_mot'), '-Fbin', '-m68000', '-no-opt', '-quiet', '-I', os.path.join(bench.ENH, 'src'),
           '-I', bench.ORIG] + (['-L', listing] if listing else []) + ['-o', out, src]
    r = subprocess.run(cmd, capture_output=True, text=True)
    if r.returncode:
        sys.exit(f'vasm {src}:\n{r.stdout}{r.stderr}')


if __name__ == '__main__':
    main()
