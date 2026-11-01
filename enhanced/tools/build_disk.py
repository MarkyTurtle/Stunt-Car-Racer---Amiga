"""Build the AmigaDOS-format disk image of Stunt Car Racer: enhanced/build/scr.adf.

  python3 enhanced/tools/build_disk.py        (VASM=/path/to/vasmm68k_mot if it is not on the PATH)

An ordinary 880K disk (80 cylinders x 2 heads x 11 sectors of 512 bytes, standard AmigaDOS MFM
with the $4489 sync) with no filesystem, read only through the 4489_byteloader:

  $000  the bootblock (src/boot_4489.s): 'DOS',0, checksum (filled in here), root block 880, code
  $400  the file table: 'SCRF', version.w, count.w, 8 bytes zero, then per file id (index) its
        offset on the disk and its length, longs
  $600  the files, one after another in id order

The files (ids: FID_ in boot_4489.s), from original/ (original/tools/disk/extract_files.py):
  0  the game: original/disk/files/t010-083_game.bin, loaded to $E700 and entered there
  1  the loading picture: original/bin/loadpic_78000.bin (4 bitplanes), loaded to $78000
  2  the helper block the game calls: original/bin/lowmem_c0.bin, loaded to $C0
"""
import hashlib, os, struct, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
ENH = os.path.normpath(os.path.join(HERE, '..'))
ORIG = os.path.normpath(os.path.join(ENH, '..', 'original'))
SRC, OUT = os.path.join(ENH, 'src'), os.path.join(ENH, 'build')
ADF = os.path.join(OUT, 'scr.adf')
VASM = os.environ.get('VASM', 'vasmm68k_mot')
DISK = 901120
FT_OFFSET, FT_VERSION, FT_ENTRIES, DATA_START = 0x400, 1, 16, 0x600
FILES = [os.path.join(ORIG, 'disk', 'files', 't010-083_game.bin'),     # 0 FID_GAME
         os.path.join(ORIG, 'bin', 'loadpic_78000.bin'),               # 1 FID_LOADPIC
         os.path.join(ORIG, 'bin', 'lowmem_c0.bin')]                   # 2 FID_LOWMEM


def vasm(src, out, listing):
    cmd = [VASM, '-Fbin', '-m68000', '-no-opt', '-quiet', '-I', SRC, '-L', listing, '-o', out, src]
    try:
        r = subprocess.run(cmd, capture_output=True, text=True)
    except FileNotFoundError:
        sys.exit(f'{VASM} not found: put vasmm68k_mot on the PATH, or set VASM to its full path')
    if r.returncode: sys.exit(f'vasm {os.path.basename(src)}:\n{r.stdout}{r.stderr}')


def bootblock_checksum(boot):
    boot = bytearray(boot)
    struct.pack_into('>L', boot, 4, 0)
    s = 0
    for (v,) in struct.iter_unpack('>L', boot):
        s += v
        if s > 0xFFFFFFFF: s = (s & 0xFFFFFFFF) + 1
    struct.pack_into('>L', boot, 4, ~s & 0xFFFFFFFF)
    return bytes(boot)


def build():
    os.makedirs(OUT, exist_ok=True)
    bin_ = os.path.join(OUT, 'boot_4489.bin')
    vasm(os.path.join(SRC, 'boot_4489.s'), bin_, os.path.join(OUT, 'boot_4489.lst'))
    boot = open(bin_, 'rb').read()
    if len(boot) != 1024: sys.exit(f'the bootblock is {len(boot)} bytes, not 1024')
    adf = bytearray(DISK)
    table = bytearray(16 + FT_ENTRIES * 8)
    struct.pack_into('>4sHH', table, 0, b'SCRF', FT_VERSION, len(FILES))
    pos = DATA_START
    for i, path in enumerate(FILES):
        data = open(path, 'rb').read()
        if pos + len(data) > DISK: sys.exit(f'{path} does not fit on the disk')
        adf[pos:pos + len(data)] = data
        struct.pack_into('>LL', table, 16 + 8 * i, pos, len(data))
        print(f'  file {i}: {os.path.relpath(path, ORIG):34s} ${pos:05X} length ${len(data):05X}')
        pos = (pos + len(data) + 1) & ~1
    adf[FT_OFFSET:FT_OFFSET + len(table)] = table
    adf[0:1024] = bootblock_checksum(boot)
    open(ADF, 'wb').write(adf)
    print(f'{os.path.relpath(ADF, os.path.join(ENH, ".."))}: {pos:,} of {DISK:,} bytes used, '
          f'sha1 {hashlib.sha1(adf).hexdigest()}')
    return ADF


if __name__ == '__main__':
    build()
