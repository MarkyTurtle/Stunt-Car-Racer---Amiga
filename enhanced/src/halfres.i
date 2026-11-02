;-------------------------------------------------------------------------------
; halfres.i - (the enhanced game) the race's view drawn at half its height and doubled: F9.
;
; Most of the view's cost is a line at a time - the sky and ground (DrawHorizon), the track's
; surfaces (FillBetweenEdges), the lines along it (DrawEdgeLine), the mountains and the opponent's
; car (FillPolygon), the edges' stepping (ScanEdge). Drawn in 64 lines instead of 128 and each
; line shown twice, all of that halves; the projection (the points' places) stays as it was.
;
; How: ScanEdge, where every edge of the view begins (its two points' places on the screen,
; PointScreenX/Y), takes each y as 64 + y / 2: the view is drawn in its lower 64 lines (64-127).
; Everything after - the edge buffers, the fills, the lines - works on those lines as it did on
; 128, and the clipping is unchanged (an edge below the view still reaches line 128 and is cut
; there; one above it lands in lines 0-63, which are drawn over next). DrawHorizon fills only
; lines 64-127 (HalfHorizon1, HalfHorizon2). Then, before the sparks and the cockpit are drawn
; (they are drawn as before, at the full height), the blitter doubles the lines (HalfExpand):
; for each plane, line 64 + i copied to line 2i (top to bottom: a line is always written at or
; above the one being read, and above all those still to be read), then each even line copied to
; the odd line under it. 8 blits of 1,024 words, 2 memory cycles a word.
;
; The rest of the game sees the points as before (the physics borrows PointScreenY as a work area,
; and some of the view's own tests compare the points with the view's edges): only ScanEdge halves
; them. F9 (the helper block's flag, HelperHalfRes) is read once a view (HalfLatch), so that a
; view is drawn all one way.
;-------------------------------------------------------------------------------

HelperHalfRes	equ	$175			; F9: non-zero - the view at half its height (helper_c0.s)
HALF_TOP	equ	64			; the half-height view's first line

HalfRes:	dc.b	0			; this view's way (HalfLatch)
	even

;-------------------------------------------------------------------------------
; HalfLatch - RaceView's start: F9's flag taken for this view. All registers kept
;-------------------------------------------------------------------------------
HalfLatch:
	move.b	(HelperHalfRes).w,HalfRes
	rts

;-------------------------------------------------------------------------------
; HalfExpand - after the view's drawing: at half height, its lines 64-127 doubled into 0-127.
; All registers kept
;-------------------------------------------------------------------------------
HalfExpand:
	tst.b	HalfRes
	beq.s	.rts
	movem.l	d0-d1/a0-a1/a5,-(a7)
	lea	(CUSTOM).l,a5
	movea.l	(ScreenDrawTop).l,a0		; the view's line 0, plane 0
	moveq	#3,d1
	bsr.w	BlitWait
	move.w	#$8240,DMACON(a5)		; the blitter's DMA on
	move.l	#$09F00000,BLTCON0(a5)		; A to D
	move.l	#-1,BLTAFWM(a5)
.plane:	bsr.w	BlitWait
	lea	HALF_TOP*40(a0),a1		; line 64 + i to line 2i
	move.l	a1,BLTAPTH(a5)
	move.l	a0,BLTDPTH(a5)
	move.w	#40-32,BLTAMOD(a5)
	move.w	#80-32,BLTDMOD(a5)
	move.w	#(64<<6)|16,BLTSIZE(a5)
	bsr.w	BlitWait
	move.l	a0,BLTAPTH(a5)			; line 2i to line 2i + 1
	lea	40(a0),a1
	move.l	a1,BLTDPTH(a5)
	move.w	#80-32,BLTAMOD(a5)
	move.w	#(64<<6)|16,BLTSIZE(a5)
	lea	$1f40(a0),a0
	dbra	d1,.plane
	bsr.w	BlitWait			; done before the sparks and the cockpit
	movem.l	(a7)+,d0-d1/a0-a1/a5
.rts:	rts
