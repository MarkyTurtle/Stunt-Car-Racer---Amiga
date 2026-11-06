;-------------------------------------------------------------------------------
; telemetry.i - the telemetry build's timing of the race (assembled with -DTELEMETRY=1:
; tools/build_disk.py --telemetry).
;
; Each race frame is timed in raster lines (64 us each; 313 a frame, so 15,650 a second) and
; split into 7 phases by the moments the main race loop reaches:
;
;   0 input   the loop's top, the controls, CarPhysics, UpdateEngineRevs     (to TelView)
;   1 cars    the view's start: the cars placed on their pieces, the opponent  (to TelGeometry)
;   2 geometry  the track's pieces in view: points rotated and projected, edges clipped and
;             stepped into the edge buffers                                   (to TelDrawing)
;   3 drawing the sky and ground, the mountains, the track's surfaces filled, the cars
;                                                                             (to TelCockpit)
;   4 cockpit the cockpit's parts drawn over the view (DrawCutout), the chains (to the view's end)
;   5 rest    the drawbridge, the instruments, the lap and time digits        (to TelFrameEnd)
;   6 wait    FrameLimiter: waiting for the 6th vertical blank, the screens flipped (with the
;             steps to the clock, interp.i: the pictures between steps, and the wait for the next)
;
; The marks are calls that replace calls of the same size in the game (the game's addresses do
; not change: this code fills the space of the unused CopylockRoutine). The vertical blank's
; count comes from the game's level 3 handler (TelVBlank in place of its jsr VBlankInterrupt).
;
; The results are kept in memory nothing else uses ($3800-$3C7F: below the supervisor stack, above
; the save routine's MFM buffer), and survive from race to race until the machine is reset:
;
;   $3800 'TELM'            $3818 8 words: this frame's phases so far
;   $3804 version.w 1       $3828 8 longs: each phase's lines over all frames, then the frames'
;   $3806 record size.w 16        total lines
;   $3808 frames.l          $3848 16 words: frames by length in vertical blanks (0 .. 15 or more)
;   $380C next record.w     $3868 shortest frame.w, $386A longest frame.w (lines)
;   $380E records.w 64      $3880 64 records, oldest first from the next record's slot: the frame's
;   $3810 line clock.l            lines, then its 7 phases' lines (8 words)
;   $3814 last mark.l
;
; tools/telemetry.py reads them: from a scremu snapshot, or from memory saved in WinUAE's debugger
; ("S telemetry.bin 3780 500": with the calibration run's results before them, calibrate.i).
;-------------------------------------------------------------------------------

TEL		equ	$3800
TEL_MAGIC	equ	TEL+$00
TEL_VERSION	equ	TEL+$04
TEL_RECSIZE	equ	TEL+$06
TEL_FRAMES	equ	TEL+$08
TEL_INDEX	equ	TEL+$0C
TEL_RINGLEN	equ	TEL+$0E
TEL_LINES	equ	TEL+$10
TEL_LAST	equ	TEL+$14
TEL_ACC		equ	TEL+$18
TEL_SUM		equ	TEL+$28
TEL_HIST	equ	TEL+$48
TEL_MIN		equ	TEL+$68
TEL_MAX		equ	TEL+$6A
TEL_RING	equ	TEL+$80
TEL_RECORDS	equ	64
TEL_END		equ	TEL_RING+TEL_RECORDS*16
TEL_FRAMELINES	equ	313

TelemetryCode:

;-------------------------------------------------------------------------------
; TelVBlank - in the level 3 handler, for each vertical blank: the line clock on a frame
;-------------------------------------------------------------------------------
TelVBlank:
	addi.l	#TEL_FRAMELINES,(TEL_LINES).w
	jmp	(VBlankInterrupt).l

;-------------------------------------------------------------------------------
; TelNow - d0.l = the time in lines (the line clock plus the beam's line). Other registers kept.
;-------------------------------------------------------------------------------
TelNow:
	move.w	sr,-(a7)
	ori.w	#$0700,sr			; no interrupt between the beam and the clock
	move.l	d1,-(a7)
	move.l	(CUSTOM+VPOSR).l,d0		; VPOSR (V8 in bit 0), VHPOSR (V7-V0, H)
	lsr.l	#8,d0
	andi.l	#$1FF,d0			; the beam's line
	move.l	(TEL_LINES).w,d1
	btst	#5,(CUSTOM+INTREQR+1).l		; a vertical blank not yet counted: the clock is a frame behind -
	beq.s	.counted
	cmpi.w	#TEL_FRAMELINES/2,d0		; if the beam was read after it (the beam in the frame's top
	bhs.s	.counted			; half); read on the last line before it, the beam is still the old frame's
	addi.l	#TEL_FRAMELINES,d1
.counted:
	add.l	d1,d0
	move.l	(a7)+,d1
	move.w	(a7)+,sr
	rts

;-------------------------------------------------------------------------------
; TelMark - d1.w = a phase * 2: the time since the last mark added to that phase. d0, d1, a0 used.
;-------------------------------------------------------------------------------
TelMark:
	tst.b	InterpRendering			; a picture between steps (interp.i): its time left in the wait
	bne.s	.rts
	lea	(TEL_ACC).w,a0
	adda.w	d1,a0
	bsr	TelNow
	move.l	d0,d1
	sub.l	(TEL_LAST).w,d1
	move.l	d0,(TEL_LAST).w
	add.w	d1,(a0)
.rts:	rts

;-------------------------------------------------------------------------------
; TelRaceStart - in place of the jsr StartEngineSound before the race loop: the results set up
; (the first time), this frame's phases cleared, the clock started
;-------------------------------------------------------------------------------
TelRaceStart:
	movem.l	d0-d1/a0,-(a7)
	cmpi.l	#'TELM',(TEL_MAGIC).w
	beq.s	.ready
	lea	(TEL_FRAMES).w,a0
.clear:	clr.w	(a0)+
	cmpa.w	#TEL_END,a0
	blo.s	.clear
	move.w	#1,(TEL_VERSION).w
	move.w	#16,(TEL_RECSIZE).w
	move.w	#TEL_RECORDS,(TEL_RINGLEN).w
	move.w	#$FFFF,(TEL_MIN).w
	move.l	#'TELM',(TEL_MAGIC).w
.ready:	lea	(TEL_ACC).w,a0
	clr.l	(a0)+
	clr.l	(a0)+
	clr.l	(a0)+
	clr.l	(a0)+
	bsr	TelNow
	move.l	d0,(TEL_LAST).w
	movem.l	(a7)+,d0-d1/a0
	jmp	(StartEngineSound).l

;-------------------------------------------------------------------------------
; TelView - in place of the race loop's jsr RaceView (the view): marks 0 before it, 4 after it
;-------------------------------------------------------------------------------
TelView:
	movem.l	d0-d1/a0,-(a7)
	moveq	#0*2,d1
	bsr	TelMark
	movem.l	(a7)+,d0-d1/a0
	jsr	(RaceView).l
	movem.l	d0-d1/a0,-(a7)
	moveq	#4*2,d1
	bsr	TelMark
	movem.l	(a7)+,d0-d1/a0
	rts

;-------------------------------------------------------------------------------
; TelGeometry, TelDrawing, TelCockpit - in the view (RaceView), in place of its jsr ProjectNearPiece
; (the first track piece), jsr DrawHorizon and jsr StartKnockSparks: marks 1, 2 and 3
;-------------------------------------------------------------------------------
TelGeometry:
	movem.l	d0-d1/a0,-(a7)
	moveq	#1*2,d1
	bsr	TelMark
	movem.l	(a7)+,d0-d1/a0
	jmp	(ProjectNearPiece).l

TelDrawing:
	movem.l	d0-d1/a0,-(a7)
	moveq	#2*2,d1
	bsr	TelMark
	movem.l	(a7)+,d0-d1/a0
	jmp	(DrawHorizon).l

TelCockpit:
	movem.l	d0-d1/a0,-(a7)
	moveq	#3*2,d1
	bsr	TelMark
	movem.l	(a7)+,d0-d1/a0
	jmp	(StartKnockSparks).l

;-------------------------------------------------------------------------------
; TelPauseKey - in place of the race loop's jsr CheckPauseKey: the time it took (a pause) left out
;-------------------------------------------------------------------------------
TelPauseKey:
	jsr	(CheckPauseKey).l
	move.l	d0,-(a7)
	bsr	TelNow
	move.l	d0,(TEL_LAST).w
	move.l	(a7)+,d0
	rts

;-------------------------------------------------------------------------------
; TelFrameEnd - in place of the race loop's jsr FrameLimiter: marks 5 before it and 6 after it,
; then the frame's record written and added to the totals
;-------------------------------------------------------------------------------
TelFrameEnd:
	movem.l	d0-d1/a0,-(a7)
	moveq	#5*2,d1
	bsr	TelMark
	movem.l	(a7)+,d0-d1/a0
	jsr	(FrameEnd).l			; (FrameLimiter, or the pictures until the next step: interp.i)
	movem.l	d0-d3/a0-a2,-(a7)
	moveq	#6*2,d1
	bsr	TelMark
	; the frame's length: its phases added up
	lea	(TEL_ACC).w,a0
	moveq	#0,d0
	moveq	#6,d3
.total:	add.w	(a0)+,d0
	dbra	d3,.total
	; its record, in the next slot
	move.w	(TEL_INDEX).w,d1
	lsl.w	#4,d1
	lea	(TEL_RING).w,a1
	adda.w	d1,a1
	move.w	d0,(a1)+
	lea	(TEL_ACC).w,a0
	lea	(TEL_SUM).w,a2
	moveq	#6,d3
.phase:	moveq	#0,d2
	move.w	(a0),d2
	clr.w	(a0)+
	move.w	d2,(a1)+
	add.l	d2,(a2)+
	dbra	d3,.phase
	moveq	#0,d2
	move.w	d0,d2
	add.l	d2,(a2)				; the frames' total
	move.w	(TEL_INDEX).w,d1
	addq.w	#1,d1
	andi.w	#TEL_RECORDS-1,d1
	move.w	d1,(TEL_INDEX).w
	addq.l	#1,(TEL_FRAMES).w
	cmp.w	(TEL_MIN).w,d0
	bhs.s	.notmin
	move.w	d0,(TEL_MIN).w
.notmin:
	cmp.w	(TEL_MAX).w,d0
	bls.s	.notmax
	move.w	d0,(TEL_MAX).w
.notmax:
	; the histogram: the frame's length in vertical blanks (rounded), 15 or more together
	move.l	d2,d1
	addi.l	#TEL_FRAMELINES/2,d1
	divu	#TEL_FRAMELINES,d1
	cmpi.w	#15,d1
	bls.s	.hist
	moveq	#15,d1
.hist:	add.w	d1,d1
	lea	(TEL_HIST).w,a0
	addq.w	#1,(a0,d1.w)
	tst.b	(HelperCalibrate).w		; F7: the calibration run (calibrate.i), its time left out
	beq.s	.nocal
	sf	(HelperCalibrate).w
	jsr	(Calibrate).l
	bsr	TelNow
	move.l	d0,(TEL_LAST).w
.nocal:	movem.l	(a7)+,d0-d3/a0-a2
	rts

TelemetryCodeEnd:
