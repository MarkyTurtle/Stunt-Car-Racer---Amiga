;-------------------------------------------------------------------------------
; blitqueue.i - (the enhanced game) the sky and ground filled by the blitter while the CPU works
; out the view's geometry.
;
; DrawHorizon fills the view's sky (colour 7, above the horizon band's top line) and ground
; (colour $D, from that line down) before anything is drawn on them: 8 blits (4 planes, 2 areas),
; 8,192 words - about 4.6 ms of the blitter's time, which the CPU spent waiting (HorizonFill: one
; blit a plane, the next set up when the last is done). But the fills need only the band's top
; line, which comes from the car's angles (ViewPitch, dat_1BB68, the roll in ViewMatrix) - known
; before the geometry (ProjectNearPiece ... EdgesFarPieces: about a third of the frame, the CPU
; only, the screen not touched).
;
; So at the geometry's start (l_64F80) HorizonEarly works the line out as DrawHorizon does (the two
; points turned by the roll, ScanEdge's clipping - into a buffer of its own, and everything it
; changed put back: the points, the row table's entry, EdgeBufferNext, ScanEdge's variables) and
; queues the fills; the blitter's interrupt (BLIT, level 3: Level3Handler) starts each when the one
; before is done. DrawHorizon then waits for the queue (by then long done), works the line out
; as before and skips the fills if they were made for the same line, screen and height (else
; it fills as before). Nothing else uses the blitter meanwhile.
;
; The screen to draw on may still be the one shown: the flip asked for at the end of the last
; frame is made by the copper's interrupt at line $FA (FlipPending: InterpWaitFlip's test), often
; after the geometry has begun. Then the queue waits (BlitQWaiting) and CopperInterrupt starts it
; as soon as it has flipped the screens (HorizonFlipped).
;-------------------------------------------------------------------------------

BLITQ_MAX	equ	8			; the most blits queued (DrawHorizon's: 2 areas, 4 planes)
HORIZON_SCRATCH	equ	8+2*130+2+16		; the horizon's edge buffer: its header, a word a line, the end

BlitQLeft:	dc.w	0			; the blits still to start (BlitInterrupt)
BlitQCount:	dc.w	0			; the blits queued (HorizonQueue)
BlitQWaiting:	dc.b	0			; non-zero: queued, to be started after the flip (HorizonFlipped)
	even
BlitQNext:	dc.l	0			; the next: its D pointer, A's data word, BLTSIZE (8 bytes)
BlitQ:		dcb.b	BLITQ_MAX*8,0
HorizonEarlyTop:	dc.w	-1		; the band's top line the queued fills are for (-1: none)
HorizonEarlyNow:	dc.w	-1		; (DrawHorizon's copy)
HorizonEarlyScreen:	dc.l	0		; on which screen (ScreenDrawTop)
HorizonEarlyHalf:	dc.b	0		; at which height (HalfRes)
HorizonSkipFills:	dc.b	0		; DrawHorizon: non-zero - its fills already made
HorizonSave:	dcb.b	28,0			; what HorizonEarly changes, put back
HorizonScratch:	dcb.b	HORIZON_SCRATCH,0
	even

;-------------------------------------------------------------------------------
; HorizonEarly - RaceView, before the geometry: the band's top line worked out and the sky's and
; ground's fills queued - started now, or by the copper's interrupt once the screen to draw on is
; no longer shown. All registers and memory kept but for the queue
;-------------------------------------------------------------------------------
HorizonEarly:
	move.w	#-1,HorizonEarlyTop
	movem.l	d0-d7/a0-a6,-(a7)
	lea	HorizonSave(pc),a6		; put aside what DrawHorizon's first part changes
	move.l	(dat_1BFB4).l,(a6)+		; the points' x (4, 6)
	move.l	(dat_1C0F4).l,(a6)+		; and y
	move.l	(EdgeBufferNext).l,(a6)+
	move.l	($7b08a).l,(a6)+		; the row table's first entry (ScanEdge's, with RowOffset 0)
	move.l	(dat_668A0).l,(a6)+		; ScanEdge's variables
	move.l	(dat_668A0+4).l,(a6)+
	move.w	(RowOffset).l,(a6)+
	move.b	(ScanEdgeHorizon).l,(a6)+
	move.l	#HorizonScratch,(EdgeBufferNext).l
	move.w	#$500,d0			; DrawHorizon's first part (67888-678EE), as it is
	move.w	d0,(dat_1BFB6).l
	neg.w	d0
	move.w	d0,(dat_1BFB4).l
	move.w	(ViewPitch).l,d0
	asr.w	#$3,d0
	neg.w	d0
	tst.b	(dat_1BB68).l
	bmi.s	.pitch
	subq.w	#$8,d0
.pitch:	move.w	d0,(dat_1C0F4).l
	move.w	d0,(dat_1C0F6).l
	move.w	#$4,d1
	jsr	(RollPointNow).l
	move.w	#$6,d1
	jsr	(RollPointNow).l
	move.w	#$0,(RowOffset).l
	move.w	#$4,d1
	move.w	#$6,d2
	move.b	#$80,(ScanEdgeHorizon).l
	jsr	(ScanEdge).l
	move.l	(a1),d0				; DrawHorizon's tests (678FE-6792C): nothing filled unless
	andi.l	#$ffffff,d0			; the edge is in the view
	beq.s	.back
	movea.l	d0,a2
	cmpi.w	#$81,(a2)+
	bcc.s	.back
	move.w	(a2),d3				; the band's top line
	cmpi.w	#$81,d3
	bcc.s	.back
	move.w	d3,HorizonEarlyTop
	move.l	(ScreenDrawTop).l,HorizonEarlyScreen
	move.b	HalfRes,HorizonEarlyHalf
	bsr.s	HorizonQueue
.back:	lea	HorizonSave(pc),a6		; all put back
	move.l	(a6)+,(dat_1BFB4).l
	move.l	(a6)+,(dat_1C0F4).l
	move.l	(a6)+,(EdgeBufferNext).l
	move.l	(a6)+,($7b08a).l
	move.l	(a6)+,(dat_668A0).l
	move.l	(a6)+,(dat_668A0+4).l
	move.w	(a6)+,(RowOffset).l
	move.b	(a6)+,(ScanEdgeHorizon).l
	movem.l	(a7)+,d0-d7/a0-a6
	rts

;-------------------------------------------------------------------------------
; HorizonQueue - d3.w the band's top line: DrawHorizon's two fills (6798C-67A6A, with F9's half
; height) queued and started. d0-d2, d4, d7, a0, a4-a5 used
;-------------------------------------------------------------------------------
HorizonQueue:
	lea	BlitQ(pc),a0
	moveq	#0,d7				; the blits queued
	movea.l	(ScreenDrawTop).l,a4		; the ground: from the top line down, colour $D
	move.w	d3,d0
	mulu	#40,d0
	adda.l	d0,a4
	move.w	#$7f,d4
	sub.w	d3,d4
	bmi.s	.sky
	tst.b	HalfRes
	beq.s	.g
	cmpi.w	#HALF_TOP,d3
	bge.s	.g
	movea.l	(ScreenDrawTop).l,a4
	lea	HALF_TOP*40(a4),a4
	moveq	#127-HALF_TOP,d4
.g:	moveq	#$d,d1
	bsr.s	.fill
.sky:	move.w	d3,d4				; the sky: the lines above it, colour 7
	subq.b	#1,d4
	bmi.s	.go
	movea.l	(ScreenDrawTop).l,a4
	tst.b	HalfRes
	beq.s	.s
	subi.w	#HALF_TOP,d4
	bmi.s	.go
	lea	HALF_TOP*40(a4),a4
.s:	moveq	#7,d1
	bsr.s	.fill
.go:	move.w	d7,BlitQCount
	beq.s	.rts
	move.w	sr,-(a7)			; (no flip between the test and the flag)
	ori.w	#$0700,sr
	tst.b	(FlipPending).l
	bne.s	.later
	move.w	(a7)+,sr
	bra.w	BlitQStart
.later:	st	BlitQWaiting			; the screen still shown: started by HorizonFlipped
	move.w	(a7)+,sr
	rts
.fill:	addq.w	#1,d4				; a4 the first line, d4 the lines - 1, d1 the colour: a
	lsl.w	#6,d4				; blit a plane
	ori.w	#16,d4
	moveq	#3,d2
.plane:	move.l	a4,(a0)+
	moveq	#0,d0
	lsr.b	#1,d1
	bcc.s	.set
	moveq	#-1,d0
.set:	move.w	d0,(a0)+
	move.w	d4,(a0)+
	addq.w	#1,d7
	lea	$1f40(a4),a4
	dbra	d2,.plane
.rts:	rts

;-------------------------------------------------------------------------------
; HorizonFlipped - CopperInterrupt, the screens just flipped (all registers saved): the queue
; started if it was waiting for the flip
;-------------------------------------------------------------------------------
HorizonFlipped:
	tst.b	BlitQWaiting
	beq.s	.rts
	sf	BlitQWaiting
	bra.s	BlitQStart
.rts:	rts

;-------------------------------------------------------------------------------
; BlitQStart - BlitQ's BlitQCount fills (D only, 16 words wide, D's modulo 8) started: the first
; now, the rest by BlitInterrupt. d7, a0, a5 used
;-------------------------------------------------------------------------------
BlitQStart:
	move.w	BlitQCount(pc),d7
	lea	(CUSTOM).l,a5
	bsr.w	BlitWait
	move.w	#$8240,DMACON(a5)		; the blitter's DMA on
	move.l	#$01F00000,BLTCON0(a5)		; D only: D = A (its data register)
	move.l	#-1,BLTAFWM(a5)
	move.w	#40-32,BLTDMOD(a5)
	lea	BlitQ(pc),a0
	subq.w	#1,d7
	move.w	d7,BlitQLeft
	move.w	#$0040,INTREQ(a5)		; no BLIT left over from an earlier blit
	move.l	(a0)+,BLTDPTH(a5)
	move.w	(a0)+,BLTADAT(a5)
	move.w	(a0)+,BLTSIZE(a5)
	move.l	a0,BlitQNext
	move.w	#$8040,INTENA(a5)		; BLIT on: each blit's end starts the next
	rts

;-------------------------------------------------------------------------------
; BlitInterrupt - Level3Handler, BLIT (INTREQ bit 6, cleared): the queue's next blit started; the
; queue done - BLIT off. All registers kept
;-------------------------------------------------------------------------------
BlitInterrupt:
	tst.w	BlitQLeft
	beq.s	.off
	movem.l	a0/a5,-(a7)
	lea	(CUSTOM).l,a5
	movea.l	BlitQNext(pc),a0
	move.l	(a0)+,BLTDPTH(a5)
	move.w	(a0)+,BLTADAT(a5)
	move.w	(a0)+,BLTSIZE(a5)
	move.l	a0,BlitQNext
	subq.w	#1,BlitQLeft
	movem.l	(a7)+,a0/a5
	rts
.off:	move.w	#$0040,(CUSTOM+INTENA).l
	rts

;-------------------------------------------------------------------------------
; HorizonWait - the queue's blits and any other blit done. All registers kept
;-------------------------------------------------------------------------------
HorizonWait:
	tst.b	BlitQWaiting			; (not started: the flip not made - InterpWaitFlip waits for it first)
	bne.s	HorizonWait
	tst.w	BlitQLeft
	bne.s	HorizonWait
	move.l	a5,-(a7)
	lea	(CUSTOM).l,a5
	bsr.w	BlitWait
	movea.l	(a7)+,a5
	rts

;-------------------------------------------------------------------------------
; HorizonStart - DrawHorizon's start: the queued fills done; whether they were for this frame's
; band (HorizonEarlyNow: HorizonEarlyMatch). All registers kept
;-------------------------------------------------------------------------------
HorizonStart:
	bsr.s	HorizonWait
	move.w	HorizonEarlyTop(pc),HorizonEarlyNow
	move.w	#-1,HorizonEarlyTop		; (used once)
	rts

;-------------------------------------------------------------------------------
; HorizonEarlyMatch - DrawHorizon, the band's top line known (dat_1BC58): HorizonSkipFills set if
; the queued fills were for it, on this screen at this height. All registers kept
;-------------------------------------------------------------------------------
HorizonEarlyMatch:
	sf	HorizonSkipFills
	move.l	d0,-(a7)
	move.w	HorizonEarlyNow(pc),d0
	cmp.w	(dat_1BC58).l,d0
	bne.s	.no
	move.l	HorizonEarlyScreen(pc),d0
	cmp.l	(ScreenDrawTop).l,d0
	bne.s	.no
	move.b	HorizonEarlyHalf(pc),d0
	cmp.b	HalfRes,d0
	bne.s	.no
	st	HorizonSkipFills
.no:	move.l	(a7)+,d0
	rts

; HorizonFillLate - DrawHorizon's fills: HorizonFill, unless already made (HorizonSkipFills)
HorizonFillLate:
	tst.b	HorizonSkipFills
	beq.w	HorizonFill
	rts
