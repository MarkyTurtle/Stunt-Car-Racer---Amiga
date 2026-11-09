;-------------------------------------------------------------------------------
; renderer_surf.i - (the enhanced game) renderer 1's track surfaces: RenderFillSurface, in place
; of FillBetweenEdges for FillRowSurface's polygon.
;
; A surface's edges are in edge buffers already (ScanEdge's, a word of x a line), a list of them
; the closed outline of the surface: left edges and right edges, no line in two of them. So each
; line has an even number of crossings, and the surface is what an exclusive-or of the crossings
; and an exclusive fill give, as renderer_blit.i's polygons - but the CPU puts each crossing in
; the mask with a bit change a line (the buffers' x, so the same pixels as FillBetweenEdges
; fills between: the left one in, the right one not), not a blitter line. Then the blitter
; fills the mask's lines (a 17th word: the view's right side, x 256) and puts the colour on the
; 4 planes (a cookie cut a plane).
; The mask: SurfMask, 128 lines of 17 words.
;-------------------------------------------------------------------------------

SURF_STRIDE	equ	34

SurfMask:	dcb.b	128*SURF_STRIDE,0

;-------------------------------------------------------------------------------
; RenderFillSurface - FillBetweenEdges' registers: a1 the end of the list of the surface's edge
; buffers, a2 its start; the colour in dat_69AEC. All registers kept; the blits are done on return
;-------------------------------------------------------------------------------
RenderFillSurface:
	tst.b	RendererSel
	bne.s	.blit
	jmp	(FillBetweenEdges).l
.blit:
	cmpa.l	a1,a2
	beq.w	.none
	movem.l	d0-d7/a0-a6,-(a7)
	lea	(CUSTOM).l,a5
	bsr.w	BlitWait			; (the last surface's blits done: its mask, the screen)
	moveq	#-1,d6				; the top line (greatest y) and the bottom
	move.w	#$7fff,d7
	movea.l a2,a3
.head:	movea.l (a3)+,a0			; each edge: its lines top-1 to bottom-1
	move.w	(a0),d0
	move.w	2(a0),d1
	cmp.w	d0,d1
	beq.s	.hnext				; level: no lines
	subq.w	#1,d0
	subq.w	#1,d1
	cmp.w	d6,d0
	ble.s	.h1
	move.w	d0,d6
.h1:	cmp.w	d7,d1
	bge.s	.hnext
	move.w	d1,d7
.hnext:	cmpa.l	a1,a3
	blt.s	.head
	tst.w	d7
	bpl.s	.y0
	moveq	#0,d7
.y0:	cmpi.w	#127,d6
	ble.s	.y1
	moveq	#127,d6
.y1:	cmp.w	d7,d6
	blt.w	.out				; no lines
	move.w	d7,d0				; the mask cleared on the lines d7-d6
	mulu.w	#SURF_STRIDE,d0
	lea	SurfMask(pc),a4
	adda.l	d0,a4
	move.w	d6,d4
	sub.w	d7,d4
	addq.w	#1,d4				; the lines
	lsl.w	#6,d4
	ori.w	#17,d4				; the blits' size
	move.w	#$0100,BLTCON0(a5)
	clr.w	BLTCON1(a5)
	clr.w	BLTDMOD(a5)
	move.l	a4,BLTDPTH(a5)
	move.w	d4,BLTSIZE(a5)
	bsr.w	BlitWait
	; the crossings: a bit changed a line of each edge
	movea.l	a2,a3
.edge:	movea.l	(a3)+,a0
	move.w	(a0),d0
	cmp.w	2(a0),d0
	beq.s	.enext				; level
	subq.w	#1,d0				; the first line
	mulu.w	#SURF_STRIDE,d0
	lea	SurfMask(pc),a6
	adda.l	d0,a6				; its line in the mask
	move.w	(a0),d5
	subq.w	#1,d5				; the line's y
	lea	8(a0),a0			; the x words
.px:	move.w	(a0)+,d0
	bmi.s	.enext				; the end
	tst.w	d5
	bmi.s	.enext				; (below the view: its lines are not filled)
	move.w	d0,d1
	lsr.w	#3,d1
	not.w	d0
	bchg	d0,(a6,d1.w)
	lea	-SURF_STRIDE(a6),a6
	subq.w	#1,d5
	bra.s	.px
.enext:	cmpa.l	a1,a3
	blt.s	.edge
	; the fill: exclusive, descending, from the last line's last word
	move.w	d6,d0
	mulu.w	#SURF_STRIDE,d0
	lea	SurfMask+SURF_STRIDE-2(pc),a4
	adda.l	d0,a4
	move.w	d6,d3				; (the lines, for the blits' size: again)
	sub.w	d7,d3
	addq.w	#1,d3
	lsl.w	#6,d3
	move.w	d3,d4
	ori.w	#17,d4
	move.w	#$09f0,BLTCON0(a5)
	move.w	#$0012,BLTCON1(a5)
	clr.w	BLTAMOD(a5)
	clr.w	BLTDMOD(a5)
	move.l	#-1,BLTAFWM(a5)
	move.l	a4,BLTAPTH(a5)
	move.l	a4,BLTDPTH(a5)
	move.w	d4,BLTSIZE(a5)
	; the colour on the planes
	move.w	d7,d0
	mulu.w	#SURF_STRIDE,d0
	lea	SurfMask(pc),a4
	adda.l	d0,a4
	move.w	d7,d1
	mulu.w	#40,d1
	movea.l	(ScreenDrawTop).l,a2
	adda.l	d1,a2
	move.b	(dat_69AEC).l,d4
	ori.w	#16,d3				; 16 words wide
	moveq	#3,d2
.plane:	bsr.w	BlitWait
	move.w	#$0dfc,d0			; A or B
	lsr.b	#1,d4
	bcs.s	.set
	move.w	#$0d0c,d0			; B and not A
.set:	move.w	d0,BLTCON0(a5)
	clr.w	BLTCON1(a5)
	move.w	#SURF_STRIDE-32,BLTAMOD(a5)
	move.w	#40-32,BLTBMOD(a5)
	move.w	#40-32,BLTDMOD(a5)
	move.l	a4,BLTAPTH(a5)
	move.l	a2,BLTBPTH(a5)
	move.l	a2,BLTDPTH(a5)
	move.w	d3,BLTSIZE(a5)
	adda.w	#8000,a2
	dbra	d2,.plane
	bsr.w	BlitWait
.out:	movem.l	(a7)+,d0-d7/a0-a6
.none:	rts
