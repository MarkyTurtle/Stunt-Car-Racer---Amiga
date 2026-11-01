;==============================================================================
; boot_4489.s - the bootblock of the rebuilt Stunt Car Racer disk (enhanced/tools/build_disk.py). The disk
; is an ordinary 880K AmigaDOS-format disk (11 sectors a track, $4489 sync) with no filesystem:
;
;   $000-$3FF   this bootblock
;   $400-$5FF   the file table (FT_OFFSET): 'SCRF', version.w, count.w, 8 bytes free (in memory
;               the bootblock puts the drive booted from in the first 4, for the game), then
;               per file (file id = index) its offset on the disk and its length, longs
;   $600-       the files, one after another
;
; Every load goes through the 4489_byteloader (byteloader.i). Based on the Ghosts'n Goblins
; boot_4489.s; what it does is the source disk's boot (the "Turbo" release, original/docs/BOOT.md):
;   1. find the drive booted from (trackdisk.device's units opened until one is the boot
;      IORequest's; DF0 if none is), while Kickstart is intact
;   2. take over: interrupts and DMA off, supervisor mode, stack at $80000
;   3. copy the loader to LOADER and run it there
;   4. read the file table, load the loading picture (file 1) to $78000 and show it as the
;      source disk's loader at $4000 did (4 planes lores, its copper list and colours)
;   5. load the helper block (file 2) to $C0 - the source bootblock copied it there; the game
;      calls it ($C0, $D6, $E8, $FC)
;   6. load the game (file 0) to $E700 and enter it as the loader at $4000 did: drives
;      deselected, DMACON $0450 off, USP = $7FFFC, SSP = $3D80, a0 = $E700, d0 = 0
; A load that fails is tried again; after 8 failures COLOR00 flashes red while it goes on trying.
;==============================================================================

LOADER          equ     $1000                   ; the loader runs here (the game's area starts at $E700)
FILE_TABLE      equ     $1C00                   ; the file table read from the disk
MFM_BUF         equ     $2000                   ; $1760 words, to $4EC0
PICTURE         equ     $78000                  ; 4 planes of $1F40 bytes, to $7FD00
GAME            equ     $E700
LOWMEM          equ     $C0
FID_GAME        equ     0                       ; (build_disk.py's file ids)
FID_LOADPIC     equ     1
FID_LOWMEM      equ     2
FT_OFFSET       equ     $400
FT_ENTRIES      equ     16

	org	0
	dc.b	'DOS',0
	dc.l	0                               ; checksum (build_disk.py)
	dc.l	880                             ; root block (no filesystem)

;------------------------------------------------------------------------------
; Kickstart calls here with a6 = ExecBase and a1 = the boot IORequest (trackdisk.device, the
; unit booted from).
BootEntry:
        movem.l $14(a1),a4-a5                   ; IO_DEVICE, IO_UNIT: the boot drive's unit
        movea.l $a(a4),a4                       ; the device's name (ln_Name)
        lea     -$30(a7),a7
        movea.l a7,a3
        moveq   #3,d7
.unit:          movea.l a4,a0
        movea.l a3,a1
        move.l  d7,d0
        moveq   #0,d1
        jsr     -$1bc(a6)                       ; OpenDevice
        tst.b   d0
        bne.b   .next
        cmpa.l  $18(a3),a5                      ; IO_UNIT: the one booted from?
        beq.b   .found
.next:          dbra    d7,.unit
        moveq   #0,d7
.found:         lea     $dff000,a0
        move.w  #$7fff,$9a(a0)                  ; INTENA: all off
        move.w  #$7fff,$96(a0)                  ; DMACON: all off
        lea     .super(pc),a1                   ; privilege violation -> the next instruction
        move.l  a1,$20.w
.super:         move.w  #$2700,sr               ; supervisor (or a trap that lands here), IPL 7
        lea     $80000,a7
        lea     Loader(pc),a1                   ; the loader, out of the way
        lea     LOADER,a2
        movea.l a2,a3
        move.w  #(LoaderEnd-Loader)/4,d0
.copy:          move.l  (a1)+,(a2)+
        dbra    d0,.copy
        move.l  d7,Drive-Loader(a3)             ; the drive booted from
        jmp     (a3)

;------------------------------------------------------------------------------
; The loader, run at LOADER. a0 = $DFF000.
	cnop	0,4
Loader:
        move.l  #FT_OFFSET,d0                   ; the file table
        move.l  #FT_ENTRIES*8+16,d1
        lea     FILE_TABLE,a0
        bsr.w   LoadIt
        move.l  Drive(pc),FILE_TABLE+8          ; the drive booted from, for the game (diskload.i)
        moveq   #FID_LOADPIC,d0                 ; the loading picture
        lea     PICTURE,a0
        bsr.w   LoadFile
        lea     $dff000,a0                      ; show it, as the loader at $4000 did ($442A)
        move.w  #$4200,$100(a0)                 ; BPLCON0: 4 planes, colour
        move.w  #$3c81,$8e(a0)                  ; DIWSTRT
        move.w  #$04c1,$90(a0)                  ; DIWSTOP
        move.w  #$0038,$92(a0)                  ; DDFSTRT
        move.w  #$00d0,$94(a0)                  ; DDFSTOP
        clr.w   $108(a0)                        ; BPL1MOD
        clr.w   $10a(a0)                        ; BPL2MOD
        clr.w   $102(a0)                        ; BPLCON1
        lea     Copper(pc),a1
        move.l  a1,$80(a0)                      ; COP1LC
        move.w  $88(a0),d0                      ; COPJMP1
        move.w  #$8380,$96(a0)                  ; bitplanes and copper on
        moveq   #FID_LOWMEM,d0                  ; the helper block at $C0
        lea     LOWMEM,a0
        bsr.w   LoadFile
        moveq   #FID_GAME,d0                    ; the game
        lea     GAME,a0
        bsr.w   LoadFile
.blit:          btst    #6,$dff002              ; as the loader at $4000 did ($4074-$40C0)
        bne.b   .blit
        ori.b   #$08,$bfd100                    ; DF0 deselected
        move.w  #$0450,$dff096                  ; DMACON: disk, blitter, blitter priority off
        lea     $7fffc,a1
        move.l  a1,usp
        lea     $3d80,a7
        lea     GAME,a0
        moveq   #0,d0
        jmp     (a0)

; LoadFile - d0 = file id, a0 = destination
LoadFile:       lea     FILE_TABLE+16,a1
        lsl.w   #3,d0
        movem.l (a1,d0.w),d0-d1
; LoadIt - d0 = offset, d1 = length, a0 = destination: the byteloader, tried until it works
LoadIt:         moveq   #0,d6                   ; failures
.try:           movem.l d0-d1/d6/a0,-(a7)
        move.l  Drive(pc),d2                    ; the drive booted from
        lea     MFM_BUF,a1
        bsr.w   ByteLoader
        move.l  d0,d7
        movem.l (a7)+,d0-d1/d6/a0
        tst.l   d7
        beq.b   .ok
        addq.w  #1,d6                           ; after 8 failures: flash red while trying
        cmp.w   #8,d6
        bcs.b   .try
        move.w  #$f00,$dff180
        bra.b   .try
.ok:            rts

Drive:          dc.l    0                       ; the drive booted from (BootEntry)

; the loading picture's copper list: the source loader's ($40EA), with the colours its $44B0
; made from the picture's palette (3-bit values doubled and rounded up; colours 16-31 red)
Copper:         dc.w    $00E0,$0007,$00E2,$8000,$00E4,$0007,$00E6,$9F40
        dc.w    $00E8,$0007,$00EA,$BE80,$00EC,$0007,$00EE,$DDC0
        dc.w    $0180,$0033,$0182,$0000,$0184,$0555,$0186,$0777
        dc.w    $0188,$0999,$018A,$0BBB,$018C,$0DDD,$018E,$0FFF
        dc.w    $0190,$0300,$0192,$0500,$0194,$0700,$0196,$0900
        dc.w    $0198,$0B00,$019A,$0D00,$019C,$0F00,$019E,$09B9
        dc.w    $FFFF,$FFFE

; the 4489_byteloader (byteloader.i): d0 = offset on the disk, d1 = length, d2 = drive,
; a0 = destination, a1 = MFM buffer -> d0 = 0 if it worked; uses every register
	cnop	0,4
ByteLoader:
	include "byteloader.i"
	cnop	0,4
LoaderEnd:

	ifgt	*-1024
	fail	the bootblock is over 1024 bytes
	endc
	ifgt	LOADER+LoaderEnd-Loader-FILE_TABLE
	fail	the loader runs into the file table
	endc
	dcb.b	1024-*,0
