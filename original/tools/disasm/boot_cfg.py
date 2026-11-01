"""scr_boot.s: the Turbo release's bootblock (disk $000-$3FF).

Kickstart reads the two boot sectors into a buffer and calls offset 12 with a1 = the trackdisk
IORequest and a6 = ExecBase. The code is position independent, so it is assembled at org 0. The
helper block at $25E-$2FB is copied to $C0 and runs there (the game calls $C0, $D6, $E8, $FC):
its routines are traced at their bootblock addresses ($C0 = $25E).
"""
NAME = 'boot'
BINARY = 'disk/files/t000_bootblock.bin'
SEGMENTS = [(0, 0x400, 0)]
ENTRIES = [0xC, 0x25E, 0x274, 0x286, 0x29A]

PROLOGUE = r'''
; Stunt Car Racer (MicroStyle 1989) - the "Turbo" release's bootblock (AGA fix and Turbo by Galahad)
; Assemble: vasmm68k_mot -Fbin -m68000 -no-opt -o boot.bin scr_boot.s
;
; Reads $9800 bytes from disk offset $2C00 to $40000 through trackdisk.device, copies the
; helper block (HelperBlock, $9E bytes) to $C0 and jumps to $40000. See docs/BOOT.md.

	include	"scr_hw.i"

AbsExecBase	equ	4
_LVOForbid	equ	-132
_LVOPermit	equ	-150
_LVOAllocMem	equ	-198
_LVODoIO	equ	-456
IO_COMMAND	equ	$1C
IO_ERROR	equ	$1F
IO_LENGTH	equ	$24
IO_DATA		equ	$28
IO_OFFSET	equ	$2C
CMD_READ	equ	2
TD_MOTOR	equ	9
HelperRun	equ	$C0		; where the helper block runs

	section	boot,code
'''
SEGMENT_TEXT = ['\torg\t0']

NAMES = {0x0: 'BootBlock', 0xC: 'BootEntry', 0x32: 'ReadRetry', 0x240: 'InstallHelper',
         0x25E: 'HelperBlock', 0x264: 'HelperText', 0x274: 'HelperAGA1', 0x286: 'HelperAGA2',
         0x29A: 'HelperKeys', 0x2FC: 'HelperBlockEnd', 0x300: 'LoadAddress'}
MEM = {0x4: 'AbsExecBase'}

OPERANDS = {
    0x248: '(HelperRun).w,a1',
    0x24C: '#HelperBlockEnd-HelperBlock-1,d0',
    0x16: '_LVOForbid(a6)',
    0x2C: '_LVOAllocMem(a6)',
    0x32: 'LoadAddress(pc),IO_DATA(a1)',
    0x38: 'BootEntry+$12(pc),IO_LENGTH(a1)',
    0x3E: '#$2C00,IO_OFFSET(a1)',
    0x46: '#CMD_READ,IO_COMMAND(a1)',
    0x50: '_LVODoIO(a6)',
    0x56: 'IO_ERROR(a1),d0',
    0x5C: '#TD_MOTOR,IO_COMMAND(a1)',
    0x62: 'IO_LENGTH(a1)',
    0x6A: '_LVODoIO(a6)',
    0x72: '_LVOPermit(a6)',
}

HEADERS = {
    0x240: 'InstallHelper - copies the helper block to $C0.',
    0x25E: 'HelperBlock - runs at $C0 (each routine below: run address = $C0 + (address - $25E)).\n'
           '$C0: wait while (a2) is not zero; F3 patches its bne at $C2 to a NOP (the turbo).',
    0x274: 'HelperAGA1 ($D6) and HelperAGA2 ($E8): a0 masked to 24 bits (the AGA fix).',
    0x29A: 'HelperKeys ($FC): d0 = raw key code. F1 ($50): audio filter; F2 ($51): BEAMCON0\n'
           'PAL/NTSC; F3 ($52): the turbo (patches $C2). Its flags at $2FA (run $15C).',
}
COMMENTS = {
    0x2C: 'the result is not used: the read goes to LoadAddress',
    0x38: 'the length: the $9800 in the move.l at $1C',
    0x3E: 'disk offset $2C00 (sector 22)',
    0x7A: 'the packed loader',
}
