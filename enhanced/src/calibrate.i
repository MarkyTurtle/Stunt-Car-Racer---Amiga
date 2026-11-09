;-------------------------------------------------------------------------------
; calibrate.i - the telemetry build's calibration run: F7 in a race runs a fixed set of tests, each
; timed to the colour clock, so that the same work can be compared on a real Amiga and in the
; study emulator (original/tools/scremu), and the emulator's timing made to match.
;
; Each test starts when the beam reaches line CAL_LINE (below the display, the same moment on any
; machine), runs with the interrupts off (nothing else in its time) and is timed from the beam:
; VPOSR/VHPOSR, 227 colour clocks a line, 2 CPU cycles a colour clock. A test lasts less than a
; frame (less than 142,102 CPU cycles: each is well under). The tests are the CPU's kinds of work - registers only, multiplies, chip memory read,
; written, read and written - and three of the game's routines.
;
; The results, at $3780 (CAL, below the telemetry's $3800; tools/telemetry.py reads them):
;   $3780 'CALB'   $3784 version.w 1   $3786 tests.w   $3788 runs.w (F7 presses)
;   $3790 per test: CPU cycles.l (the last run)
;-------------------------------------------------------------------------------

CAL		equ	$3780
CAL_MAGIC	equ	CAL+$00
CAL_VERSION	equ	CAL+$04
CAL_TESTS	equ	CAL+$06
CAL_RUNS	equ	CAL+$08
CAL_RESULTS	equ	CAL+$10
CAL_LINE	equ	300			; each test starts here (the display ends at line $2C+200)
HelperCalibrate	equ	$183			; F7 sets it (helper_c0.s)

;-------------------------------------------------------------------------------
; Calibrate - the tests run, their times kept at CAL. All registers kept.
;-------------------------------------------------------------------------------
Calibrate:
	movem.l	d0-d7/a0-a6,-(a7)
	cmpi.l	#'CALB',(CAL_MAGIC).w		; the first run: the count from 0
	beq.s	.counted
	clr.w	(CAL_RUNS).w
.counted:
	move.l	#'CALB',(CAL_MAGIC).w
	move.w	#1,(CAL_VERSION).w
	move.w	#(CalTestsEnd-CalTests)/4,(CAL_TESTS).w
	addq.w	#1,(CAL_RUNS).w
	lea	CalTests(pc),a5
	lea	(CAL_RESULTS).w,a4
.next:	cmpa.l	#CalTestsEnd,a5
	bhs.s	.done
	movea.l	(a5)+,a3			; the test
	move.w	sr,-(a7)
	ori.w	#$0700,sr
	bsr.w	CalWaitLine
	bsr.w	CalBeam
	move.l	d0,d6				; the start, in colour clocks
	movem.l	d6/a4-a5,-(a7)			; (the tests use any register)
	jsr	(a3)
	movem.l	(a7)+,d6/a4-a5
	bsr.w	CalBeam
	sub.l	d6,d0
	bpl.s	.pos
	addi.l	#313*227,d0			; over the frame's end
.pos:	add.l	d0,d0				; CPU cycles
	move.l	d0,(a4)+
	move.w	(a7)+,sr
	bra.s	.next
.done:	movem.l	(a7)+,d0-d7/a0-a6
	rts

; CalBeam - d0.l = the beam's line * 227 + its colour clock
CalBeam:
	move.l	d1,-(a7)
	move.l	(CUSTOM+VPOSR).l,d1
	move.l	d1,d0
	lsr.l	#8,d0
	andi.l	#$1FF,d0			; the line
	mulu	#227,d0
	andi.l	#$FF,d1				; the colour clock (H8-H1)
	add.l	d1,d0
	move.l	(a7)+,d1
	rts

; CalWaitLine - waits for the beam to reach CAL_LINE (from another line)
CalWaitLine:
	move.l	d0,-(a7)
.away:	bsr.s	CalLine
	cmpi.w	#CAL_LINE,d0
	beq.s	.away
.wait:	bsr.s	CalLine
	cmpi.w	#CAL_LINE,d0
	bne.s	.wait
	move.l	(a7)+,d0
	rts
CalLine:
	move.l	(CUSTOM+VPOSR).l,d0
	lsr.l	#8,d0
	andi.w	#$1FF,d0
	rts

CalTests:
	dc.l	CalRegs, CalMul, CalRead, CalWrite, CalRMW, CalCutout, CalPlotPixel, CalFill
CalTestsEnd:

; the tests: each a fixed amount of work (the screen being drawn on is used: it is drawn again)
CalRegs:					; registers only: 2,000 times add, eor, dbra (26 cycles)
	move.w	#1999,d7
.l:	add.l	d1,d0
	eor.l	d0,d1
	dbra	d7,.l
	rts
CalMul:						; 400 mulu (38-70 cycles by the bits) and dbra
	move.w	#399,d7
	move.w	#$5555,d1
.l:	move.w	d1,d0
	mulu	d1,d0
	dbra	d7,.l
	rts
CalRead:					; chip memory read: 2,000 words (8 + 10 cycles)
	movea.l	(ScreenDraw).l,a0
	move.w	#1999,d7
.l:	move.w	(a0)+,d0
	dbra	d7,.l
	rts
CalWrite:					; chip memory written: 2,000 longs (12 + 10 cycles)
	movea.l	(ScreenDraw).l,a0
	moveq	#0,d0
	move.w	#1999,d7
.l:	move.l	d0,(a0)+
	dbra	d7,.l
	rts
CalRMW:						; chip memory read and written: 2,000 words (12 + 10 cycles)
	movea.l	(ScreenDraw).l,a0
	moveq	#-1,d1
	move.w	#1999,d7
.l:	and.w	d1,(a0)+
	dbra	d7,.l
	rts
CalCutout:					; the game's DrawCutout: the cockpit's widest part (10), twice (the
						; enhanced game: by the blitter - blitcutout.i - its time to the end of
						; the last blit, below the display: no bitplane DMA in its way)
	moveq	#10,d0
	jsr	(DrawCutout).l
	moveq	#10,d0
	jmp	(DrawCutout).l
CalPlotPixel:					; the game's PlotPixel: 500 pixels (colour 15)
	moveq	#15,d0
	jsr	(SetPolygonColour).l
	movea.l	(ScreenDrawTop).l,a0
	move.w	#499,d7
.l:	move.w	d7,d4
	jsr	(PlotPixel).l
	dbra	d7,.l
	rts
CalFill:					; the game's ClearWordPlanes / PlotWord: 500 words in colour 7
	move.b	#7*16+2,d6
	jsr	(SetColourWord).l
	movea.l	(ScreenDrawTop).l,a4
	move.w	#$0FF0,d4
	move.w	#499,d7
.l:	movea.l	(ScreenDrawTop).l,a4
	jsr	(ClearWordPlanes).l
	dbra	d7,.l
	rts
