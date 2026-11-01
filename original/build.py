"""Assemble the original game's programs, check them against the originals' SHA-1, and rebuild the
source disk (the "Turbo" release's ADF) from them: original/build/scr_original.adf.

  python3 original/build.py        (python or py on Windows; run from anywhere)

The assembler is vasmm68k_mot on the PATH, or the program the VASM environment variable names
(for example VASM=C:\\Tools\\vasmm68k_mot.exe).

The disk (disk/FILES.md): the bootblock at $0, the packed loader at $2C00 (sector 22), the game at
$DC00 (sector $6E), zeros elsewhere except the formatter's fill at $400-$2BFF and $C400-$DBFF:
longs 'DO', $53 + 4 * ((offset >> 12) mod 11), (offset >> 2) & $FF. scr_loader4000.s (the loader
unpacked) is assembled and checked too, but is not on the disk: it is in the packed loader."""
import hashlib, os, struct, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, 'build')
VASM = os.environ.get('VASM', 'vasmm68k_mot')
PROGRAMS = [  # output, source, SHA-1 of the original
    ('game.bin', 'scr_game.s', 'e1808f34a83fa6dec856a7b6c6f380613ec0226f'),
    ('boot.bin', 'scr_boot.s', '1b0a2f4ed7a602573f922b598f609278d3e3eebe'),
    ('loader.bin', 'scr_loader.s', 'b1a11ee483062e21611c734030a5a3f609ecf382'),
    ('loader_4000.bin', 'scr_loader4000.s', 'f2d2e307a35e901abc6ba787fbfd9bb5212ae72d'),
]
ADF = 'scr_original.adf'
ADF_SHA1 = '603162f17d913aea67ac84674733b78df5a2cbaa'      # the Turbo release's ADF
DISK = 901120
FILL = [(0x400, 0x2C00), (0xC400, 0xDC00)]
PLACE = {'boot.bin': 0, 'loader.bin': 0x2C00, 'game.bin': 0x6E * 512}


def fill(adf, start, end):
    for o in range(start, end, 4):
        adf[o:o + 4] = bytes([0x44, 0x4F, 0x53 + 4 * ((o >> 12) % 11), (o >> 2) & 0xFF])


def main():
    os.makedirs(OUT, exist_ok=True)
    ok = True
    bins = {}
    for out, src, sha in PROGRAMS:
        path = os.path.join(OUT, out)
        cmd = [VASM, '-Fbin', '-m68000', '-no-opt', '-quiet', '-o', path, src]
        try:
            r = subprocess.run(cmd, cwd=HERE, capture_output=True, text=True)
        except FileNotFoundError:
            sys.exit(f'{VASM} not found: put vasmm68k_mot on the PATH, or set VASM to its full path')
        if r.returncode:
            sys.exit(f'{out}: vasm failed\n{r.stdout}{r.stderr}')
        bins[out] = open(path, 'rb').read()
        got = hashlib.sha1(bins[out]).hexdigest()
        print(f'{out}: OK' if got == sha else f'{out}: MISMATCH ({got})')
        ok &= got == sha
    adf = bytearray(DISK)
    for s, e in FILL:
        fill(adf, s, e)
    for name, off in PLACE.items():
        adf[off:off + len(bins[name])] = bins[name]
    open(os.path.join(OUT, ADF), 'wb').write(adf)
    got = hashlib.sha1(adf).hexdigest()
    print(f'build/{ADF}: OK (the Turbo release disk)' if got == ADF_SHA1 else f'build/{ADF}: MISMATCH ({got})')
    ok &= got == ADF_SHA1
    return 0 if ok else 1


if __name__ == '__main__':
    sys.exit(main())
