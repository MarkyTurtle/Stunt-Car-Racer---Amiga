"""Boot the rebuilt disk (enhanced/build/scr.adf, build_disk.py) in the emulator, from Kickstart's call to
its bootblock to the game's entry at $E700, with the 4489_byteloader reading the disk through
tools/floppy.py (from the Ghosts'n Goblins repository). Exec's OpenDevice is a stub that knows the
drives connected.

Checks: at $E700 with the game, the loading picture and the helper block in memory as in original/;
the stacks (USP $7FFFC, SSP $3D80), a0 and d0 as the source disk's loader leaves them; the
loading picture's display (copper list, BPLCON0); the drive left off. Cases: booted from DF0,
from DF1, from DF3, and from a unit of some other device (DF0 then), each also with the DMA
starting at a random sector.

  python3 enhanced/tools/test_boot.py"""
import os, struct, sys
from unicorn import Uc, UC_ARCH_M68K, UC_MODE_BIG_ENDIAN, UC_HOOK_MEM_READ, UC_HOOK_CODE
from unicorn.m68k_const import (UC_CPU_M68K_M68000, UC_M68K_REG_A0, UC_M68K_REG_A1, UC_M68K_REG_A6, UC_M68K_REG_A7,
                                UC_M68K_REG_D0, UC_M68K_REG_SR, UC_M68K_REG_PC)
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import floppy

ENH = os.path.normpath(os.path.join(HERE, '..'))
ORIG = os.path.normpath(os.path.join(ENH, '..', 'original'))
EXEC, BOOTBUF = 0x676, 0x20000
OPENDEVICE = 0x900                      # exec's OpenDevice (EXEC - $1BC jumps here): a hook, then rts
DEVICE, NAME, BOOTREQ = 0x940, 0x980, 0x9C0
UNITS = [0xA00 + 0x40 * n for n in range(4)]
FOREIGN = 0xB00
GAME = 0xE700


class Machine:
    def __init__(self):
        u = self.u = Uc(UC_ARCH_M68K, UC_MODE_BIG_ENDIAN)
        u.ctl_set_cpu_model(UC_CPU_M68K_M68000)
        u.mem_map(0, 0x80000); u.mem_map(0xBFD000, 0x2000); u.mem_map(0xDFF000, 0x1000)
    def r8(self, a): return self.u.mem_read(a, 1)[0]
    def r16(self, a): return struct.unpack('>H', bytes(self.u.mem_read(a, 2)))[0]
    def r32(self, a): return struct.unpack('>L', bytes(self.u.mem_read(a, 4)))[0]
    def w8(self, a, v): self.u.mem_write(a, bytes([v & 0xFF]))
    def w16(self, a, v): self.u.mem_write(a, struct.pack('>H', v & 0xFFFF))
    def w32(self, a, v): self.u.mem_write(a, struct.pack('>L', v & 0xFFFFFFFF))


def files():
    f = lambda *p: open(os.path.join(*p), 'rb').read()
    build = os.path.join(ENH, 'build')
    return (f(build, 'game.bin'), f(ORIG, 'bin', 'loadpic_78000.bin'),       # the game and the helper block as
            f(build, 'helper_c0.bin'))                                      # tools/build_disk.py made them


def boot(adf, unit=0, drives=(0, 1), random_start=False, foreign=False):
    m = Machine(); u = m.u
    w = lambda a, f, *v: u.mem_write(a, struct.pack(f, *v))
    u.mem_write(BOOTBUF, adf[:1024])
    w(EXEC - 0x1BC, '>HL', 0x4EF9, OPENDEVICE)
    w(OPENDEVICE, '>H', 0x4E75)
    opened = []
    def opendevice(uc, addr, size, ud):
        n, req = u.reg_read(UC_M68K_REG_D0), u.reg_read(UC_M68K_REG_A1)
        name = bytes(u.mem_read(u.reg_read(UC_M68K_REG_A0), 17))
        good = name == b'trackdisk.device\0' and n in drives
        opened.append(n)
        if good: w(req + 0x14, '>LL', DEVICE, UNITS[n])
        w(req + 0x1F, '>B', 0 if good else 32)
        u.reg_write(UC_M68K_REG_D0, 0 if good else 32)
    u.hook_add(UC_HOOK_CODE, opendevice, begin=OPENDEVICE, end=OPENDEVICE)
    w(DEVICE + 10, '>L', NAME); u.mem_write(NAME, b'trackdisk.device\0')
    w(BOOTREQ + 0x14, '>LL', DEVICE, FOREIGN if foreign else UNITS[unit])
    u.reg_write(UC_M68K_REG_A1, BOOTREQ)
    m.w8(0xBFE001, 0xFF)
    fd = floppy.Floppy(m, adf, timing_ranges=[(0x1000, 0x1400)], random_start=random_start, unit=unit)
    u.reg_write(UC_M68K_REG_A6, EXEC)
    u.reg_write(UC_M68K_REG_SR, 0x2000)
    u.reg_write(UC_M68K_REG_A7, 0x7F000)
    u.emu_start(BOOTBUF + 0x0C, GAME, count=400_000_000)
    game, pic, low = files()
    pc = u.reg_read(UC_M68K_REG_PC)
    usp = u.reg_read(getattr(__import__('unicorn.m68k_const', fromlist=['x']), 'UC_M68K_REG_A7'))
    checks = [('at the game entry ($E700)', pc == GAME),
              ('the file table', adf[0x400:0x404] == b'SCRF'),
              ('the game at $E700', bytes(u.mem_read(GAME, len(game))) == game),
              ('the loading picture at $78000', bytes(u.mem_read(0x78000, len(pic))) == pic),
              ('the helper block at $C0', bytes(u.mem_read(0xC0, len(low))) == low),
              ('SSP = $3D80', usp == 0x3D80),
              ('a0 = $E700, d0 = 0', u.reg_read(UC_M68K_REG_A0) == GAME and u.reg_read(UC_M68K_REG_D0) == 0),
              ('supervisor mode', u.reg_read(UC_M68K_REG_SR) & 0x2000 != 0),
              ('the copper list in the loader', 0x1000 <= m.r32(0xDFF080) < 0x1400),
              ('BPLCON0 4 planes', m.r16(0xDFF100) == 0x4200),
              (f'units opened: {opened}', opened[0] == 3 and opened[-1] == (0 if foreign else unit)),
              (f'the motor off or DF{unit} deselected', not fd.motor or not fd.sel)]
    print(f'DF{unit} ({"booted from a unit of another device" if foreign else "booted from"}; drives {list(drives)}; '
          f'random start {random_start}): {fd.reads} track reads, head at cylinder {fd.cyl}')
    ok = True
    for what, good in checks:
        print(f'  {"ok  " if good else "FAIL"} {what}'); ok &= good
    return ok


def main():
    adf = open(os.path.join(ENH, 'build', 'scr.adf'), 'rb').read()
    ok = True
    for rs in (False, True):
        for unit, drives, foreign in ((0, (0, 1), False), (1, (0, 1), False), (3, (0, 1, 2, 3), False), (0, (0, 1), True)):
            ok &= boot(adf, unit, drives, rs, foreign)
    print('all as expected' if ok else 'FAILED')
    return ok


if __name__ == '__main__':
    sys.exit(0 if main() else 1)
