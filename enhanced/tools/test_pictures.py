"""Test the pictures the game loads from its disk while it runs (src/diskload.i), in the study
emulator (original/tools/scremu) with its quick disk: the game's byteloader calls answered at once
from the ADF (the real loader, reading MFM, is tested by tools/test_boot.py).

  python3 enhanced/tools/test_pictures.py [--png DIR]

Plays: the title, the driver's name, the divisions, the menu; then 1. Hall of Fame (its picture
loaded); then each picture shown after a race and at the end of a season (ShowTablePicture 1-4:
season_win, season_crowd, wreck, champion, called as the game would); then the wreck again with no
disk in (the game must ask for its disk and wait), with another disk in (the original's: asked for,
still waiting), and with its disk back (loaded). Checks the disk reads made, the picture in
DiskPicture after each, and the game's question on the screen. --png DIR draws the screens.
"""
import os, re, subprocess, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import bench

FILES = {3: 'hall_of_fame', 4: 'wreck', 5: 'season_win', 6: 'season_crowd', 7: 'champion'}
TABLE = {1: 5, 2: 6, 3: 4, 4: 7}           # PictureTable entry -> file


def symbols(lst):
    out = {}
    for line in open(lst, errors='replace'):
        p = line.split()
        if len(p) == 2 and p[1][:2] in ('A:', 'E:') and len(p[1]) == 10:
            out[p[0]] = int(p[1][2:], 16)
    return out


def main():
    subprocess.run([sys.executable, os.path.join(HERE, 'build_disk.py')], check=True, stdout=subprocess.DEVNULL)
    build = os.path.join(bench.ENH, 'build')
    sym = symbols(os.path.join(build, 'game.lst'))
    adf_path = os.path.join(build, 'scr.adf')
    adf = open(adf_path, 'rb').read()
    work = tempfile.mkdtemp()
    w = lambda n: os.path.join(work, n)
    open(w('ft.bin'), 'wb').write(adf[0x400:0x400 + 0x90])             # as the bootblock leaves it at $1C00
    other = os.path.join(bench.ORIG, 'build', 'scr_original.adf')       # another disk
    if not os.path.exists(other):
        subprocess.run([sys.executable, os.path.join(bench.ORIG, 'build.py')], check=True, stdout=subprocess.DEVNULL)
    os.symlink(adf_path, w('game.adf')); os.symlink(other, w('other.adf'))
    bl, stp = sym['ByteLoader'], sym['ShowTablePicture']
    fire = ['joy f', 'frames 5', 'joy']
    L = [f'log {w("log.txt")}', f'load {w("ft.bin")} 0x1C00', f'disk {bl:#x} {w("game.adf")}', 'crashwatch',
         'until 0xE730 100', 'frames 400'] + fire + ['frames 150']
    for k in ('37', '20', '13', '27', '44'):
        L += [f'key {k}', 'frames 10']
    L += ['frames 160'] + fire + ['frames 150', 'mark menu',
          'joy u', 'frames 8', 'joy', 'frames 30'] + fire + ['frames 250', f'snap {w("hof")}', 'mark hof'] + fire + ['frames 200']
    for i in (1, 2, 3, 4):
        L += [f'inject {stp:#x} {i}', 'frames 150', f'snap {w(f"pic{i}")}', f'mark pic{i}'] + fire + ['frames 60']
    L += [f'disk {bl:#x} none', f'inject {stp:#x} 3', 'frames 200', f'snap {w("nodisk")}', 'mark nodisk',
          f'disk {bl:#x} {w("other.adf")}', 'frames 150', f'snap {w("other")}', 'mark other',
          f'disk {bl:#x} {w("game.adf")}', 'frames 150', f'snap {w("back")}', 'mark back']
    script = '\n'.join(l if not l.startswith('mark ') else f'snap {w("m_" + l[5:])}' for l in L) + '\n'
    open(w('s.txt'), 'w').write(script)
    if not os.path.exists(bench.EMU):
        subprocess.run(['sh', os.path.join(bench.EMU_DIR, 'build.sh')], check=True)
    subprocess.run([bench.EMU, os.path.join(build, 'game.bin'), os.path.join(build, 'helper_c0.bin'),
                    os.path.join(bench.ORIG, 'bin', 'loadpic_78000.bin'), w('s.txt')], check=True, stdout=subprocess.DEVNULL)
    log = open(w('log.txt')).read()
    if 'crash:' in log:
        sys.exit('the game crashed:\n' + log[log.index('crash:'):][:400])
    reads = re.findall(r'disk read \$(\w+)\+\$(\w+) to \$(\w+): (\w+)', log)
    table = adf[0x400:0x490]
    import struct
    ent = {fid: struct.unpack_from('>LL', table, 16 + 8 * fid) for fid in FILES}
    picture = lambda name, fid: open(w(name + '.mem'), 'rb').read()[sym['DiskPicture']:sym['DiskPicture'] + ent[fid][1]] \
        == adf[ent[fid][0]:ent[fid][0] + ent[fid][1]]
    def loaded(fid):
        return any(int(o, 16) == ent[fid][0] and int(n, 16) == ent[fid][1] and r == 'ok' for o, n, d, r in reads)
    def asked(name):                         # the question printed: the drive's digit changed in the text
        m = open(w(name + '.mem'), 'rb').read()
        return m[sym['InsertGameDiscDrive']] == ord('0') and m[sym['DiskAsked']] != 0
    checks = [('the Hall of Fame: its picture loaded', loaded(3) and picture('hof', 3))]
    for i in (1, 2, 3, 4):
        checks.append((f'ShowTablePicture {i} ({FILES[TABLE[i]]}): loaded', loaded(TABLE[i]) and picture(f'pic{i}', TABLE[i])))
    n_fail = sum(1 for o, n, d, r in reads if r == 'failed')
    checks += [(f'no disk: the game asks for its disk and waits ({n_fail} reads failed)', n_fail >= 2 and asked('nodisk')),
               ('another disk: still waiting (its file table is not the game\'s)', asked('other') and not picture('other', 4)),
               ('its disk back: the wreck loaded', picture('back', 4))]
    ok = True
    for what, good in checks:
        print(f'  {"ok  " if good else "FAIL"} {what}'); ok &= good
    if '--png' in sys.argv:
        out = sys.argv[sys.argv.index('--png') + 1]
        os.makedirs(out, exist_ok=True)
        sys.path.insert(0, os.path.join(bench.ORIG, 'tools'))
        from screen import render
        for n in ('hof', 'pic1', 'pic2', 'pic3', 'pic4', 'nodisk', 'other', 'back'):
            mem, regs = open(w(n + '.mem'), 'rb').read(), open(w(n + '.regs'), 'rb').read()
            r = lambda o: regs[o] << 8 | regs[o + 1]
            cust = {o: r(o) for o in list(range(0x180, 0x1C0, 2)) + [0x100, 0x102, 0x108, 0x10A, 0x8E, 0x90, 0x92, 0x94]}
            render(mem, r(0x80) << 16 | r(0x82), cust).save(os.path.join(out, n + '.png'))
    print('all as expected' if ok else 'FAILED')
    return ok


if __name__ == '__main__':
    sys.exit(0 if main() else 1)
