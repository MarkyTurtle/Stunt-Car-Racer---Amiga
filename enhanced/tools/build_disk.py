"""Build the AmigaDOS-format disk image of Stunt Car Racer: enhanced/build/scr.adf.

  python3 enhanced/tools/build_disk.py        (VASM=/path/to/vasmm68k_mot if it is not on the PATH)

An ordinary 880K disk (80 cylinders x 2 heads x 11 sectors of 512 bytes, standard AmigaDOS MFM
with the $4489 sync) with no filesystem, read only through the 4489_byteloader:

  $000  the bootblock (src/boot_4489.s): 'DOS',0, checksum (filled in here), root block 880, code
  $400  the file table: 'SCRF', version.w, count.w, 8 bytes zero, then per file id (index) its
        offset on the disk and its length, longs
  $600  the files, one after another in id order

  python3 enhanced/tools/build_disk.py --check SHA1    (fails unless the disk's SHA-1 is SHA1)
  python3 enhanced/tools/build_disk.py --telemetry     (the telemetry build: the game assembled with
      TELEMETRY defined - src/telemetry.i times each race frame - to enhanced/build/scr_telemetry.adf)

The files (ids: FID_ in boot_4489.s):
  0  the game: src/scr_game.s (the hand-edited source forked from original/scr_game.s),
     assembled at $E700 (its data - sound/, gfx/, tracks/ - from original/: -I original);
     loaded to $E700 and entered there
  1  the loading picture: original/bin/loadpic_78000.bin (4 bitplanes), loaded to $78000
  2  the helper block the game calls: original/bin/lowmem_c0.bin, loaded to $C0
"""
import hashlib, os, struct, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
ENH = os.path.normpath(os.path.join(HERE, '..'))
ORIG = os.path.normpath(os.path.join(ENH, '..', 'original'))
SRC, OUT = os.path.join(ENH, 'src'), os.path.join(ENH, 'build')
TELEMETRY = '--telemetry' in sys.argv
ADF = os.path.join(OUT, 'scr_telemetry.adf' if TELEMETRY else 'scr.adf')
VASM = os.environ.get('VASM', 'vasmm68k_mot')
DISK = 901120
FT_OFFSET, FT_VERSION, FT_ENTRIES, DATA_START = 0x400, 1, 16, 0x600
GAME_BIN = os.path.join(OUT, 'game_telemetry.bin' if TELEMETRY else 'game.bin')
FILES = [GAME_BIN,                                                      # 0 FID_GAME (src/scr_game.s)
         os.path.join(ORIG, 'bin', 'loadpic_78000.bin'),               # 1 FID_LOADPIC
         os.path.join(ORIG, 'bin', 'lowmem_c0.bin')]                   # 2 FID_LOWMEM


def vasm(src, out, listing=None, defines=()):
    cmd = ([VASM, '-Fbin', '-m68000', '-no-opt', '-quiet', '-I', SRC, '-I', ORIG] + [f'-D{d}' for d in defines] +
           (['-L', listing] if listing else []) + ['-o', out, src])
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
    vasm(os.path.join(SRC, 'scr_game.s'), GAME_BIN, defines=['TELEMETRY=1'] if TELEMETRY else [])
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
        print(f'  file {i}: {os.path.relpath(path, os.path.join(ENH, "..")):34s} ${pos:05X} length ${len(data):05X}')
        pos = (pos + len(data) + 1) & ~1
    adf[FT_OFFSET:FT_OFFSET + len(table)] = table
    adf[0:1024] = bootblock_checksum(boot)
    open(ADF, 'wb').write(adf)
    sha = hashlib.sha1(adf).hexdigest()
    print(f'{os.path.relpath(ADF, os.path.join(ENH, ".."))}: {pos:,} of {DISK:,} bytes used, sha1 {sha}')
    return sha


if __name__ == '__main__':
    sha = build()
    if '--check' in sys.argv:
        want = sys.argv[sys.argv.index('--check') + 1]
        if sha != want:
            sys.exit(f'the disk SHA-1 is {sha}, not {want}: if the change is intended, update ADF_SHA1 in '
                     '.github/workflows/enhanced.yml')
        print('SHA-1 as expected')
