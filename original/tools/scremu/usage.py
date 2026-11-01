"""Summarise scremu's memory-use maps ("usage FILE"): which bytes of the 512K the game touched, by
region, and the untouched runs.

  python3 original/tools/scremu/usage.py USAGE.bin [USAGE2.bin ...]      (several: combined)

A map has a byte per address: bit 0 read by the CPU, 1 written by the CPU, 2 an instruction
started there, 3 DMA (blitter, bitplanes, copper, audio, sprites)."""
import sys

REGIONS = [  # start, end, name
    (0x00000, 0x00100, 'vectors, the helper block at $C0'),
    (0x00100, 0x00400, 'low memory'),
    (0x00400, 0x03D80, 'below the supervisor stack ($3D80)'),
    (0x03D80, 0x0E700, 'between the stack and the game'),
    (0x0E700, 0x0F4B8, 'game: start-up code, interrupts, sound driver'),
    (0x0F4B8, 0x1AA4A, 'game: the 8 samples'),
    (0x1AA4A, 0x1B6CA, 'game: the engine buffer'),
    (0x1B6CA, 0x1BAF8, 'game: the sample table, code'),
    (0x1BAF8, 0x20182, 'game: variables, tables, the tracks'),
    (0x20182, 0x23C10, 'game: picture cockpit'),
    (0x23C30, 0x2B952, 'game: picture title (and the font)'),
    (0x2B972, 0x30BAE, 'game: picture stadium'),
    (0x30BCE, 0x35A54, 'game: picture hall_of_fame'),
    (0x35A74, 0x3D796, 'game: picture divisions'),
    (0x3D7B6, 0x4475B, 'game: picture wreck'),
    (0x4477C, 0x4AF1D, 'game: picture season_win'),
    (0x4AF3E, 0x50E2B, 'game: picture season_crowd'),
    (0x50E4C, 0x56FD8, 'game: picture champion'),
    (0x56FD8, 0x6A166, 'game: the picture table, the main code'),
    (0x6A166, 0x6A594, 'game: tables, the screen pointers'),
    (0x6A594, 0x72294, 'screen 1'),
    (0x72294, 0x79F94, 'screen 2 (the image ends at $73100)'),
    (0x79F94, 0x80000, 'above the screens: work areas, the user stack'),
]


def main():
    maps = [open(f, 'rb').read() for f in sys.argv[1:]]
    if not maps:
        sys.exit(__doc__)
    u = bytes(a | b for a, b in zip(*maps)) if len(maps) > 1 else maps[0]
    if len(maps) > 2:
        for m in maps[2:]:
            u = bytes(a | b for a, b in zip(u, m))
    print(f'{"region":<52}{"bytes":>8}{"touched":>9}{"read":>8}{"written":>9}{"code":>7}{"DMA":>8}')
    tot = 0
    for s, e, name in REGIONS:
        r = u[s:e]
        t = sum(1 for x in r if x)
        tot += t
        print(f'${s:05X}-${e - 1:05X} {name:<38}{e - s:>8}{t:>9}{sum(1 for x in r if x & 1):>8}'
              f'{sum(1 for x in r if x & 2):>9}{sum(1 for x in r if x & 4):>7}{sum(1 for x in r if x & 8):>8}')
    print(f'touched: {sum(1 for x in u if x):,} of {len(u):,} bytes')
    print('\nuntouched runs of 1K or more:')
    a = 0
    while a < len(u):
        if not u[a]:
            b = a
            while b < len(u) and not u[b]:
                b += 1
            if b - a >= 1024:
                print(f'  ${a:05X}-${b - 1:05X}  {b - a:7,} bytes')
            a = b
        else:
            a += 1


if __name__ == '__main__':
    main()
