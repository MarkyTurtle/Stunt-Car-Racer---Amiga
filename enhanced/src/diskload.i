;-------------------------------------------------------------------------------
; diskload.i - the enhanced game's loading from its disk while it runs: the pictures shown between
; races and in the Hall of Fame are files on the disk (tools/build_disk.py: files 3-7), loaded into
; DiskPicture when they are shown, instead of 124,485 bytes kept in memory all the time.
;
; The disk is read with the 4489_byteloader (byteloader.i), as the bootblock reads it: any drive,
; any offset and length, checksums verified, no interrupt, CIA timer, blitter or copper use. Its
; MFM buffer is MFM_BUFFER, low memory the game leaves free (the save routine borrows the same).
;
; The drive is the one the game was booted from; the bootblock leaves it at $1C08, in the file
; table it read to $1C00 ('SCRF', version.w, count.w, the drive.l, 4 bytes free, then the files'
; offsets and lengths), and DiskInit keeps a copy of the table before anything else can use that
; memory. Before each load the table is read again from the disk and compared with the copy: if the
; disk in the drive is not the game's (a save disk put in, no disk), the player is asked for it.
;-------------------------------------------------------------------------------

BOOT_FILE_TABLE	equ	$1C00			; where the bootblock read the file table
FT_OFFSET	equ	$400			; the file table on the disk
FT_SIZE		equ	16+16*8			; its header and 16 files
FT_DRIVE	equ	8			; the drive booted from (the bootblock puts it there)
MFM_BUFFER	equ	$400			; the byteloader's MFM buffer: $1760 words, to $32C0
PICTURE_MAX	equ	32034			; the largest picture file (a full screen, not packed)

FID_HALLOFFAME	equ	3			; the files (tools/build_disk.py)
FID_WRECK	equ	4
FID_SEASONWIN	equ	5
FID_SEASONCROWD	equ	6
FID_CHAMPION	equ	7

;-------------------------------------------------------------------------------
; DiskInit - at start-up (Trap0Handler): the bootblock's file table kept (DiskFileTable)
;-------------------------------------------------------------------------------
DiskInit:
	movem.l	d0/a0-a1,-(a7)
	lea	(BOOT_FILE_TABLE).w,a0
	lea	DiskFileTable(pc),a1
	moveq	#FT_SIZE/4-1,d0
.copy:	move.l	(a0)+,(a1)+
	dbra	d0,.copy
	movem.l	(a7)+,d0/a0-a1
	rts

;-------------------------------------------------------------------------------
; LoadPicture - d0.w: a picture's file - loaded into DiskPicture; a6 = DiskPicture (a picture
; record as the game keeps them: a flag word, 16 colours, the picture). If the game's disk is not
; in its drive, asks for it and waits. Other registers kept.
;-------------------------------------------------------------------------------
LoadPicture:
	movem.l	d0-d7/a0-a5,-(a7)
	move.w	d0,d7
	sf	DiskAsked
.again:	bsr.s	CheckGameDisk
	beq.s	.ours
	bsr.w	AskForGameDisk
	bra.s	.again
.ours:	move.w	d7,d0
	lsl.w	#3,d0
	lea	DiskFileTable+16(pc),a0
	movem.l	(a0,d0.w),d0-d1			; the file's offset and length
	lea	(DiskPicture).l,a0
	bsr.s	DiskRead
	bne.s	.again				; a failed read: the disk looked at again
	movem.l	(a7)+,d0-d7/a0-a5
	lea	(DiskPicture).l,a6
	rts

;-------------------------------------------------------------------------------
; CheckGameDisk - Z set if the disk in the game's drive is the game's (its file table read into
; DiskPicture and compared with DiskFileTable - all but the drive); d0-d7, a0-a5 used
;-------------------------------------------------------------------------------
CheckGameDisk:
	move.l	#FT_OFFSET,d0
	move.l	#FT_SIZE,d1
	lea	(DiskPicture).l,a0
	bsr.s	DiskRead
	bne.s	.no
	lea	(DiskPicture).l,a0
	lea	DiskFileTable(pc),a1
	move.l	FT_DRIVE(a1),FT_DRIVE(a0)	; (the copy has the drive in it, the disk 0)
	moveq	#FT_SIZE/4-1,d0
.cmp:	cmpm.l	(a0)+,(a1)+
	dbne	d0,.cmp
.no:	rts

;-------------------------------------------------------------------------------
; DiskRead - d0.l: an offset on the disk, d1.l: a length, a0: where - read from the game's drive
; (the byteloader); d0 = 0 (Z set) if it worked. The drive's motor off after. Other registers kept
; (the byteloader uses them all).
;-------------------------------------------------------------------------------
DiskRead:
	movem.l	d1-d7/a0-a6,-(a7)
	move.l	DiskFileTable+FT_DRIVE(pc),d2
	lea	(MFM_BUFFER).w,a1
	lea	ByteLoaderState(pc),a2
	move.w	#$FFFF,(a2)			; the head's track not known: the save routine may have moved it
	bsr.w	ByteLoader
	move.l	DiskFileTable+FT_DRIVE(pc),d2
	lea	$BFD100,a0			; the motor off: MTR high, the drive selected and deselected
	or.b	#$F8,(a0)
	addq.b	#3,d2
	bclr	d2,(a0)
	bset	d2,(a0)
	movem.l	(a7)+,d1-d7/a0-a6
	tst.l	d0
	rts

;-------------------------------------------------------------------------------
; AskForGameDisk - "Insert the Stunt Car Racer disc into drive n" printed (once a load), then a
; second waited. Registers kept.
;-------------------------------------------------------------------------------
AskForGameDisk:
	movem.l	d0-d7/a0-a6,-(a7)		; (the game's printing and Wait use them)
	tst.b	DiskAsked
	bne.s	.wait
	st	DiskAsked
	move.l	DiskFileTable+FT_DRIVE(pc),d0
	addi.b	#'0',d0
	move.b	d0,(InsertGameDiscDrive).l
	move.b	(TextNoBackground).l,-(a7)		; printed on the screen on show (ScreenToShow), as
	move.w	(TextCursorX).l,-(a7)		; PrintOnBothScreens does
	move.l	(ScreenDraw).l,-(a7)
	move.l	(ScreenToShow).l,(ScreenDraw).l
	move.b	#$0,(TextNoBackground).l
	move.b	#$1,d0
	jsr	(SetTextColour).l
	move.b	#$3,d0
	jsr	(SetTextBackground).l
	move.w	#$FFF,(CopperColours+1*4).l	; colours 1 and 3 white on dark blue, so that it can be read
	move.w	#$005,(CopperColours+3*4).l	; on any screen (the picture's colours replace them)
	move.w	#InsertGameDiscText-MessageTexts,d1
	jsr	(PrintMessage).l
	move.l	(a7)+,(ScreenDraw).l
	move.w	(a7)+,(TextCursorX).l
	move.b	(a7)+,(TextNoBackground).l
.wait:	move.b	#50,d2
	jsr	(Wait).l
	movem.l	(a7)+,d0-d7/a0-a6
	rts

DiskFileTable:				; the file table, as the bootblock read it (DiskInit)
	dcb.b	FT_SIZE,0
DiskAsked:				; the player asked for the game's disk in this load
	dc.b	0
	even

;-------------------------------------------------------------------------------
; ByteLoader - the 4489_byteloader: d0 an offset on the disk, d1 a length, d2 a drive, a0 where,
; a1 the MFM buffer -> d0 = 0 if it worked; every register used. Its last word is its state.
;-------------------------------------------------------------------------------
	cnop	0,4
ByteLoader:
	include	"byteloader.i"
ByteLoaderState	equ	*-2
	even
