"""Extract the files from the Stunt Car Racer "Turbo" ADF (MicroStyle 1989; AGA fix and Turbo by
Galahad) into original/disk/files/ and original/bin/, then check them against
original/disk/SHA1SUMS.

  python3 original/tools/disk/extract_files.py <Stunt Car Racer Turbo.adf>

The disk (original/disk/FILES.md, original/docs/BOOT.md):
  $00000-$003FF   bootblock: reads $9800 bytes from $2C00 to $40000 through trackdisk.device,
                  copies its helper block ($9E bytes at bootblock $25E) to $C0, jumps to $40000
  $00400-$02BFF   formatter fill (unused)
  $02C00-$0C3FF   the loader: a decruncher at $40000 that unpacks $A4CA bytes to $4000 and runs it
  $0C400-$0DBFF   formatter fill (unused)
  $0DC00-$725FF   the game: sectors $6E-$392 ($325 sectors) loaded to $E700, entered at $E700
  $72600-         empty

disk/files/ (named by track, as read from the disk):
  t000_bootblock.bin            the bootblock (1024 bytes)
  t002-008_loader_packed.bin    the loader as read to $40000 ($9800 bytes)
  t010-083_game.bin             the game, all $325 sectors as loaded to $E700 ($64A00 bytes)
bin/ (made from them):
  loader_4000.bin               the loader unpacked to $4000 ($A4CA bytes), by its own decruncher
                                run under Unicorn (unpack_loader.py)
  lowmem_c0.bin                 the helper block the bootblock copies to $C0 ($9E bytes)
  loadpic_78000.bin             the loading picture as the loader shows it: 4 bitplanes of
                                320x200 one after another at $78000 ($1F40 bytes each), from the
                                word-interleaved copy in the loader (its $4D24)
"""
import hashlib, os, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
ORIG = os.path.normpath(os.path.join(HERE, '..', '..'))
FILES, BIN = os.path.join(ORIG, 'disk', 'files'), os.path.join(ORIG, 'bin')

GAME_SECTOR, GAME_SECTORS = 0x6E, 0x325          # the loader at $4000: d1, d2 of its $44F8 call
LOADER_OFFSET, LOADER_LENGTH = 0x2C00, 0x9800     # the bootblock's trackdisk read
LOWMEM_OFFSET, LOWMEM_LENGTH = 0x25E, 0x9E        # the bootblock's copy to $C0
PIC_SRC, PIC_PLANE, PIC_PLANES = 0x4D24 - 0x4000, 0x1F40, 4


def check_sums():
    ok = True
    for line in open(os.path.join(ORIG, 'disk', 'SHA1SUMS')):
        want, name = line.split()
        got = hashlib.sha1(open(os.path.join(ORIG, 'disk', name), 'rb').read()).hexdigest()
        print(f'  {"ok  " if got == want else "FAIL"} {name}')
        ok &= got == want
    return ok


def main():
    if len(sys.argv) != 2: sys.exit(__doc__)
    adf = open(sys.argv[1], 'rb').read()
    if len(adf) != 901120: sys.exit('not an 880K ADF')
    if adf[:4] != b'DOS\0' or adf[0x7A:0x80] != bytes.fromhex('4ef900040000'):
        sys.exit('not the Turbo disk this script knows (its bootblock should end with jmp $40000)')
    os.makedirs(FILES, exist_ok=True); os.makedirs(BIN, exist_ok=True)
    w = lambda d, n, b: open(os.path.join(d, n), 'wb').write(b)
    w(FILES, 't000_bootblock.bin', adf[:1024])
    packed = os.path.join(FILES, 't002-008_loader_packed.bin')
    w(FILES, 't002-008_loader_packed.bin', adf[LOADER_OFFSET:LOADER_OFFSET + LOADER_LENGTH])
    w(FILES, 't010-083_game.bin', adf[GAME_SECTOR * 512:(GAME_SECTOR + GAME_SECTORS) * 512])
    w(BIN, 'lowmem_c0.bin', adf[LOWMEM_OFFSET:LOWMEM_OFFSET + LOWMEM_LENGTH])
    unpacked = os.path.join(BIN, 'loader_4000.bin')
    subprocess.run([sys.executable, os.path.join(HERE, 'unpack_loader.py'), packed, unpacked], check=True,
                   stdout=subprocess.DEVNULL)
    l4000 = open(unpacked, 'rb').read()
    # the picture: the loader's copy loop ($401E) moves word i of plane p from src + (i*4 + p)*2
    src = l4000[PIC_SRC:PIC_SRC + PIC_PLANE * PIC_PLANES]
    planes = bytearray(PIC_PLANE * PIC_PLANES)
    for i in range(PIC_PLANE // 2):
        for p in range(PIC_PLANES):
            planes[p * PIC_PLANE + i * 2:p * PIC_PLANE + i * 2 + 2] = src[(i * 4 + p) * 2:(i * 4 + p) * 2 + 2]
    w(BIN, 'loadpic_78000.bin', bytes(planes))
    print('extracted; checking against disk/SHA1SUMS:')
    sys.exit(0 if check_sums() else 1)


if __name__ == '__main__':
    main()
