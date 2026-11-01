"""scr_loader4000.s: the Turbo release's loader as unpacked to $4000 (bin/loader_4000.bin): shows
the loading picture and reads the game to $E700 with its sector loader. For study: on the disk it
is packed (scr_loader.s)."""
NAME = 'loader4000'
BINARY = 'bin/loader_4000.bin'
SEGMENTS = [(0, 0xA4CA, 0x4000)]
ENTRIES = [0x4000]
SWEEP = True

PROLOGUE = r'''
; Stunt Car Racer (MicroStyle 1989) - the "Turbo" release's loader, unpacked to $4000
; Assemble: vasmm68k_mot -Fbin -m68000 -no-opt -o loader_4000.bin scr_loader4000.s
;
; Shows the loading picture (4 bitplanes at $78000), reads the game (sectors $6E-$392) to $E700
; with its sector loader and enters it. See docs/BOOT.md.

	include	"scr_hw.i"

	section	loader4000,code
'''
SEGMENT_TEXT = ['\torg\t$4000']
NAMES = {0x4000: 'LoaderStart', 0x40C2: 'Level3Handler', 0x40EA: 'Copper', 0x418E: 'Palette32',
         0x442A: 'SetDisplay', 0x44AE: 'Retries', 0x44B0: 'SetColours', 0x44F8: 'SectorLoader',
         0x4D04: 'PicturePalette', 0x4D24: 'PictureData'}
HEADERS = {
    0x4000: 'LoaderStart - the picture, then the game (sectors $6E, $325 of them) to $E700.',
    0x442A: 'SetDisplay - 4 planes lores at $78000, the copper list.',
    0x44B0: 'SetColours - Palette32 (3-bit values) to the copper list: each nibble doubled, +1 if not 0.',
    0x44F8: 'SectorLoader - d0 = drive, d1 = first sector, d2 = sectors, d3 = 0 read / 1 write,\n'
            'a0 = buffer, a1 = MFM buffer; d0 = 0 if it worked.',
    0x4D24: 'The loading picture: 320x200, 4 planes interleaved by word.',
}
DATAFMT = {0x40EA: 'w', 0x418E: 'w', 0x4D04: 'w'}
