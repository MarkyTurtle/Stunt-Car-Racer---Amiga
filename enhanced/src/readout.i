;-------------------------------------------------------------------------------
; readout.i - (the enhanced game) the opponent's distance on the instruments, only the
; characters that changed printed again.
;
; Every 4th step PrintOpponentDistance prints the distance: a sign (space or '-') and 4 digits, at the
; text cursor (6, $17) a pixel further right each (TextPixelX 2-6) and 4 lines down (TextLineOffset):
; the cells at x 44-83, lines 188-195, in both screens. PrintCharNow draws a character a row at a
; time into both screens - about 11,400 cycles each, 57,000 on those steps (2% of the race's
; work on average, and a hitch every 4th step). Most of the time only the last digit or two have
; changed.
;
; So the 5 characters last printed there are kept (ReadoutChars); one that is the same again is
; not drawn - the cursor and PrintCharNow's own work bytes (dat_59840, dat_59841) are moved on as
; printing it would have, so the game's state is the same - while the cells still hold it
; (ReadoutValid). They do unless something else has drawn there or the way of drawing changed:
; * ReadoutStart compares the text's colours, its background's, TextNoBackground (a background or
;   not), dat_5D724 and ScreenFront with those of the last print: any change, all 5 printed;
; * text printed to one screen only (TextOneScreen set) or to the other buffer (dat_5924A): not kept;
; * UnpackCockpit (the race's start: ReadoutUnpackCockpit), any other text whose rows meet
;   lines 188-195 (PrintCharNow, any column) and any cut-out whose rectangle meets the cells
;   (DrawCutoutBlit, DrawCutout's CPU path): ReadoutValid cleared.
;
; Checked by tools/test_readout.py: assembled with READOUT_CHECK, each character left as it is is
; printed anyway in races, and must change no byte of the screens.
;-------------------------------------------------------------------------------

READOUT_X0	equ	44			; the readout's cells (pixels of the screen)
READOUT_X1	equ	83
READOUT_Y0	equ	188
READOUT_Y1	equ	195

ReadoutSlot:	dc.l	0			; the next character's place in ReadoutChars
ReadoutContext:	dcb.b	16+2+4,0		; the text's colours (16 bytes), TextNoBackground, dat_5D724, ScreenFront
ReadoutChars:	dcb.b	5,0			; the characters last printed (sign, 4 digits)
ReadoutValid:	dc.b	0			; non-zero: the cells hold ReadoutChars
ReadoutOk:	dc.b	0			; this print: the same characters may be left as they are
ReadoutKeep:	dc.b	0			; this print: what it prints may be kept
ReadoutPrinting: dc.b	0			; non-zero: PrintOpponentDistance printing (PrintCharNow: not another text)
	even

;-------------------------------------------------------------------------------
; ReadoutStart - PrintOpponentDistance, before the readout's characters. All registers kept
;-------------------------------------------------------------------------------
ReadoutStart:
	movem.l	d0-d3/a0-a1,-(a7)
	st	ReadoutPrinting
	move.l	#ReadoutChars,ReadoutSlot
	sf	ReadoutOk
	moveq	#0,d1				; any change of the way of drawing
	lea	(TextBackgroundMasks).l,a0	; the background's and the text's planes (16 bytes)
	lea	ReadoutContext(pc),a1
	moveq	#3,d2
.mask:	move.l	(a0)+,d0
	cmp.l	(a1),d0
	sne	d3
	or.b	d3,d1
	move.l	d0,(a1)+
	dbra	d2,.mask
	move.b	(TextNoBackground).l,d0
	cmp.b	(a1),d0
	sne	d3
	or.b	d3,d1
	move.b	d0,(a1)+
	move.b	(dat_5D724).l,d0
	cmp.b	(a1),d0
	sne	d3
	or.b	d3,d1
	move.b	d0,(a1)+
	move.l	(ScreenFront).l,d0
	cmp.l	(a1),d0
	sne	d3
	or.b	d3,d1
	move.l	d0,(a1)
	sf	ReadoutKeep
	tst.b	(TextOneScreen).l			; one screen only, or not the screen: not kept
	bmi.s	.done
	tst.b	(dat_5924A).l
	bne.s	.done
	st	ReadoutKeep
	tst.b	d1
	bne.s	.done
	move.b	ReadoutValid(pc),ReadoutOk
.done:	movem.l	(a7)+,d0-d3/a0-a1
	rts

;-------------------------------------------------------------------------------
; ReadoutEnd - PrintOpponentDistance, after them. All registers kept
;-------------------------------------------------------------------------------
ReadoutEnd:
	sf	ReadoutPrinting
	move.b	ReadoutKeep(pc),ReadoutValid
	rts

;-------------------------------------------------------------------------------
; ReadoutDigit - PrintOpponentDistance, for PrintDigitNext: d0 a digit (or $F0, $FD: space, '-') printed -
; or, if the cell already shows it, the cursor moved on as printing it would. d0 = the character
; on return (as PrintDigitNext); the rest kept
;-------------------------------------------------------------------------------
ReadoutDigit:
	addq.b	#1,(TextPixelX).l		; PrintDigitNext
	addi.b	#$30,d0				; PrintDigit
	move.l	a0,-(a7)
	movea.l	ReadoutSlot(pc),a0
	addq.l	#1,ReadoutSlot
	tst.b	ReadoutOk
	beq.s	.print
	cmp.b	(a0),d0
	beq.s	.same
.print:	move.b	d0,(a0)
	movea.l	(a7)+,a0
	jmp	(PrintChar).l
.same:	movea.l	(a7)+,a0
	ifd	READOUT_CHECK
	bra.w	ReadoutCheckSame		; (tools/test_readout.py: printed anyway, and compared)
	endc
ReadoutSkip:
	movem.l	d3-d4,-(a7)			; what PrintCharNow leaves (59568-595A0, 597EA-597FE)
	moveq	#0,d3
	move.b	(TextCursorX).l,d3
	move.w	d3,d4
	asl.w	#3,d3
	sub.w	d4,d3				; the column x 7 (dat_5924A clear: kept only then)
	moveq	#0,d4
	move.b	(TextPixelX).l,d4
	add.w	d4,d3
	move.w	d3,d4
	lsr.w	#4,d4
	move.b	d4,(dat_59840).l
	andi.b	#$f,d3
	move.b	d3,(dat_59841).l
	move.b	(TextCursorX).l,d3
	addq.b	#1,d3
	cmpi.b	#$2d,d3
	bcs.s	.col
	moveq	#0,d3
.col:	move.b	d3,(TextCursorX).l
	movem.l	(a7)+,d3-d4
	rts

;-------------------------------------------------------------------------------
; ReadoutTextCheck - PrintCharNow, d0.l = the character's first line (0-255): text other than
; the readout's whose rows meet its cells - they are no longer kept. All registers kept (not
; the flags)
;-------------------------------------------------------------------------------
ReadoutTextCheck:
	tst.b	ReadoutPrinting
	bne.s	.rts
	cmpi.w	#READOUT_Y0-7,d0
	blo.s	.rts
	cmpi.w	#READOUT_Y1,d0
	bhi.s	.rts
	sf	ReadoutValid
.rts:	rts

;-------------------------------------------------------------------------------
; ReadoutCutoutCheck - DrawCutout, d0.w a cut-out: if its rectangle meets the readout's cells,
; they are no longer kept. All registers kept
;-------------------------------------------------------------------------------
ReadoutCutoutCheck:
	move.l	a0,-(a7)
	move.w	d1,-(a7)
	moveq	#0,d1
	move.b	d0,d1
	lsl.w	#4,d1
	lea	(CutoutRects).l,a0
	adda.w	d1,a0				; +4 width - 1 (words), +6 height - 1, +9 x (words), +11 y
	moveq	#0,d1
	move.b	11(a0),d1			; top line
	add.w	6(a0),d1			; bottom line: above the cells (the cockpit's parts) - done
	cmpi.w	#READOUT_Y0,d1
	blo.s	.rts
	cmpi.b	#READOUT_Y1,11(a0)		; top below them
	bhi.s	.rts
	moveq	#0,d1
	move.b	9(a0),d1			; left word: right of the cells (16 x it > 83) - done
	cmpi.w	#READOUT_X1/16,d1
	bhi.s	.rts
	add.w	4(a0),d1			; right word: left of them (16 x it + 15 < 44) - done
	cmpi.w	#READOUT_X0/16,d1
	blo.s	.rts
	sf	ReadoutValid
.rts:	move.w	(a7)+,d1
	movea.l	(a7)+,a0
	rts

;-------------------------------------------------------------------------------
; ReadoutUnpackCockpit - the race's start (5D35E): UnpackCockpit, which draws over the cells
;-------------------------------------------------------------------------------
ReadoutUnpackCockpit:
	sf	ReadoutValid
	jmp	(UnpackCockpit).l

	ifd	READOUT_CHECK
;-------------------------------------------------------------------------------
; ReadoutCheckSame - (tools/test_readout.py) a character ReadoutDigit would leave as it is,
; printed anyway: the cells' bytes (lines 188-195, bytes 4-11 of both screens' 4 planes) before
; and after compared - $3720 counts the longs printing changed, which must be 0; the cursor and
; work bytes the skip leaves against printing's - $3728 counts the differences; $3724 the skips
;-------------------------------------------------------------------------------
ReadoutCheckSame:
	movem.l	d0-d7/a0-a3,-(a7)
	addq.l	#1,($3724).w
	move.b	(TextCursorX).l,d6		; the skip's result, from the state before
	move.b	(dat_59840).l,d7
	move.b	(dat_59841).l,d5
	bsr.w	ReadoutSkip
	move.b	(TextCursorX).l,CheckSkip
	move.b	(dat_59840).l,CheckSkip+1
	move.b	(dat_59841).l,CheckSkip+2
	move.b	d6,(TextCursorX).l		; the state put back
	move.b	d7,(dat_59840).l
	move.b	d5,(dat_59841).l
	lea	CheckCells,a1			; the cells before
	bsr.w	CheckCopyCells
	movem.l	(a7),d0-d7/a0-a3
	jsr	(PrintChar).l			; printed
	lea	CheckSkip,a1			; the state: as the skip's?
	move.b	(TextCursorX).l,d0
	cmp.b	(a1)+,d0
	bne.s	.bad
	move.b	(dat_59840).l,d0
	cmp.b	(a1)+,d0
	bne.s	.bad
	move.b	(dat_59841).l,d0
	cmp.b	(a1),d0
	beq.s	.cmp
.bad:	addq.l	#1,($3728).w
.cmp:	lea	CheckCells,a1			; the cells: as before?
	bsr.w	CheckCompareCells
	movem.l	(a7)+,d0-d7/a0-a3
	rts

; CheckCopyCells, CheckCompareCells - a1: the cells' bytes (lines 188-195, bytes 4-11; 8 planes:
; the first screen's 4, then the second's) copied there, or compared with what is there
CheckCopyCells:
	movea.l	(ScreenFront).l,a0
	lea	READOUT_Y0*40+4(a0),a0
	moveq	#7,d2
.plane:	movea.l	a0,a2
	moveq	#7,d1
.line:	move.l	(a2),(a1)+
	move.l	4(a2),(a1)+
	lea	40(a2),a2
	dbra	d1,.line
	lea	$1f40(a0),a0
	dbra	d2,.plane
	rts
CheckCompareCells:
	movea.l	(ScreenFront).l,a0
	lea	READOUT_Y0*40+4(a0),a0
	moveq	#7,d2
.plane:	movea.l	a0,a2
	moveq	#7,d1
.line:	move.l	(a2),d0
	cmp.l	(a1)+,d0
	beq.s	.ok1
	addq.l	#1,($3720).w
.ok1:	move.l	4(a2),d0
	cmp.l	(a1)+,d0
	beq.s	.ok2
	addq.l	#1,($3720).w
.ok2:	lea	40(a2),a2
	dbra	d1,.line
	lea	$1f40(a0),a0
	dbra	d2,.plane
	rts
CheckSkip:	dc.b	0,0,0,0
CheckCells:	dcb.b	8*8*8,0
	even
	endc
