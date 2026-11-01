"""scr_loader.s: the Turbo release's loader as read to $40000 (disk $2C00-$C3FF): a decruncher,
then the packed code, which it unpacks to $4000 and runs (scr_loader4000.s is that code)."""
NAME = 'loader'
BINARY = 'disk/files/t002-008_loader_packed.bin'
SEGMENTS = [(0, 0x9800, 0x40000)]
ENTRIES = [0x40000]

PROLOGUE = r'''
; Stunt Car Racer (MicroStyle 1989) - the "Turbo" release's loader, read to $40000 by the bootblock
; Assemble: vasmm68k_mot -Fbin -m68000 -no-opt -o loader.bin scr_loader.s
;
; Supervisor mode, interrupts off, then the decruncher unpacks PackedData ($A4CA bytes from
; $31C6) backwards to $4000 and jumps there. The packed data is kept as it is: its unpacked
; form is bin/loader_4000.bin (scr_loader4000.s).

	include	"scr_hw.i"

	section	loader,code
'''
SEGMENT_TEXT = ['\torg\t$40000']
NAMES = {0x40000: 'LoaderEntry', 0x4000E: 'Supervisor', 0x40020: 'Decrunch', 0x400F2: 'GetBit',
         0x4010A: 'GetBits', 0x40122: 'BitMasks', 0x4013E: 'DecrunchDone', 0x40148: 'UnpackedLength',
         0x4014C: 'PackedLength', 0x40150: 'PackedData'}
HEADERS = {0x40020: 'Decrunch - unpacks PackedData backwards to $4000, then runs it.',
           0x40148: 'The packed loader: unpacked length, packed length, data.'}
DATAFMT = {0x40148: 'w'}
