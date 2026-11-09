;-------------------------------------------------------------------------------
; renderer_blit.i - (the enhanced game) renderer 1's mountains: BlitMountains, DrawMountains'
; polygons drawn by the blitter (renderer.i, F5).
;
; DrawMountains steps each polygon's edges a line at a time with ScanEdge (clipped to the view,
; into edge buffers) and fills them with FillPolygon: about 79,000 cycles a frame of the CPU's.
; BlitMountains takes the same polygons - the same groups by the car's heading, the same points
; moved by the heading and pitch and turned by the roll, the same edges and colours - and draws each
; one the way the blitter draws a polygon:
;
;   1. the polygon's lines in the mask (a plane of the view's size, BlitMask): each edge clipped
;      to the view (BlitEdge) and drawn in the blitter's line mode, one pixel a row (ONEDOT) and
;      exclusive-or'd, so that the rows hold the edges' crossings and nothing else. The part of an
;      edge beyond a side of the view is put on that side's column (the polygon closes there, as
;      with ScanEdge's EdgeOffSide), the part above or below it is left out;
;   2. the mask's lines area-filled (exclusive fill, descending: between each pair of crossings);
;   3. the mask put on the screen in the polygon's colour, a blit a plane: the polygon's pixels set
;      to that plane's bit of the colour, the rest left as they were (a cookie cut: D = A or B, or
;      B and not A, from the mask A and the screen B).
;
; The edges are not stepped by the CPU and the rows not filled by it: the CPU's part is the points,
; each edge's clipping and the set-up of the blits - about a third of DrawMountains' cycles - and
; the blitter's the rest. The picture is the release's to within a pixel at the edges (the blitter's
; Bresenham line is not ScanEdge's; the fill's end pixels may differ by one).
;
; At half height (F9) the points' y is 64 + y / 2 as ScanEdge does, and only lines 64-127 drawn.
;-------------------------------------------------------------------------------

BM_STRIDE	equ	32			; the mask's bytes a line: the view's 256 pixels
BM_POINTS	equ	64			; the most points in a group (word arrays)
BM_EDGES	equ	64			; the most edges in a group (a long each)

BlitMask:	dcb.b	128*BM_STRIDE,0		; the polygon's mask: the view's 128 lines
BmX:		dcb.w	BM_POINTS,0		; the group's points, turned and centred: x, y (a word each; the
BmY:		dcb.w	BM_POINTS,0		; edges and polygons reach them by the byte offset, 2 a point)
BmEdge:		dcb.l	BM_EDGES,0		; the group's edges: the points' offsets, p1 << 16 | p2
BmPoly:		dcb.l	4,0			; the polygon being drawn: its edges (copied from BmEdge)
BmPolyN:	dc.w	0			; how many
BmColour:	dc.b	0			; its colour
	even
BmY0:		dc.w	0			; the polygon's first and last line
BmY1:		dc.w	0
BmEX1:		dc.w	0			; BlitEdge's edge: x1, y1 (the upper end), x2, y2
BmEY1:		dc.w	0
BmEX2:		dc.w	0
BmEY2:		dc.w	0
	even
	ifne	(BmY0|BmY1|BmEX1|BmEY1|BmEX2|BmEY2)&1		; a word at an odd address is the 68000's address error
	fail	"renderer_blit.i: a variable's word is at an odd address"
	endc

;-------------------------------------------------------------------------------
; BlitMountains - the mountains drawn the blitter's way. As DrawMountains: the groups in view by
; the heading, their points moved and turned, their edges and polygons - F10 leaves them out.
; Registers: none kept
;-------------------------------------------------------------------------------
BlitMountains:
	tst.b	(HelperMountainsOff).w
	beq.s	.on
	rts
.on:	lea	(CUSTOM).l,a5
	clr.w	BmTopW
	tst.b	HalfRes
	beq.s	.full
	move.w	#HALF_TOP,BmTopW
.full:	move.w	(ViewPitch).l,d0
	asr.w	#3,d0
	neg.w	d0
	move.w	d0,(dat_6979C).l
	movea.l	#dat_69736,a0
	move.b	(CarHeading).l,d6
	subi.b	#$1c,d6
	move.b	#$2c,d7
	move.b	(dat_69799).l,d1
	subq.b	#1,d1
.group:	move.b	(a0,d1.w),d0
	sub.b	d6,d0
	cmp.b	d7,d0
	bcc.w	.next
	movem.l	d1/d6-d7/a0,-(a7)
	subi.b	#$1c,d0
	asl.w	#8,d0
	clr.w	d3
	move.b	(CarHeadingLow).l,d3
	andi.b	#$fe,d3
	sub.w	d3,d0
	asr.w	#3,d0
	move.w	d0,(dat_6979A).l
	clr.w	d0
	movea.l	#dat_69766,a0
	move.b	(a0,d1.w),d0
	asl.w	#3,d0
	movea.l	#dat_699B8,a0
	movea.l	(a0,d0.w),a6
	movea.l	4(a0,d0.w),a2
	move.w	(a6)+,d6
	subq.w	#1,d6
	move.b	d6,d1
	asl.b	#1,d1
	lea	BmX(pc),a4
	lea	BmY(pc),a5
	move.w	(dat_6979A).l,d4
	move.w	(dat_6979C).l,d5
.pts:	move.w	(a6)+,d0
	bpl.s	.px
	move.w	(a2)+,d0
.px:	add.w	d4,d0
	move.w	d0,(a4)+
	move.w	(a6)+,d0
	bpl.s	.py
	move.w	(a2)+,d0
.py:	sub.w	d5,d0
	neg.w	d0
	move.w	d0,(a5)+
	dbra	d6,.pts
	move.l	a6,-(a7)
	movea.l	#ViewMatrix,a3
	lea	BmX(pc),a5
	lea	BmY(pc),a4
	tst.w	$20(a3)				; the car level: RollPointXY's level case, as in DrawMountains
	bne.s	.roll
	cmpi.w	#$7fff,$22(a3)
	bne.s	.roll
	moveq	#0,d3
.level:	move.w	(a5,d1.w),d5
	move.w	(a4,d1.w),d4
	move.w	d5,d0
	ble.s	.lx
	subq.w	#1,d0
.lx:	asr.w	#2,d0
	addi.w	#$80,d0
	move.w	d0,(a5,d1.w)
	move.w	d4,d0
	neg.w	d0
	add.w	d0,d0
	swap	d0
	move.w	d4,d0
	ble.s	.ly
	subq.w	#1,d0
.ly:	asr.w	#2,d0
	addi.w	#$40,d0
	move.w	d0,(a4,d1.w)
	subq.b	#2,d1
	bpl.s	.level
	bra.s	.rolled
.roll:	jsr	(RollPointXY).l
	subq.b	#2,d1
	bpl.s	.roll
.rolled:
	movea.l	(a7)+,a6
	tst.b	HalfRes				; half height: y as 64 + y / 2 (ScanEdge's)
	beq.s	.edges
	lea	BmY(pc),a4
	move.w	#BM_POINTS-1,d1
.half:	move.w	(a4),d0
	asr.w	#1,d0
	addi.w	#HALF_TOP,d0
	move.w	d0,(a4)+
	dbra	d1,.half
.edges:	moveq	#0,d1				; the edges: their points' offsets
	move.b	(a6)+,d1			; (dat_69797: how many)
	subq.w	#1,d1
	lea	BmEdge(pc),a0
.edge:	moveq	#0,d0
	move.b	(a6)+,d0			; p1
	swap	d0
	move.b	(a6)+,d0			; p2: the long's low word
	move.l	d0,(a0)+
	dbra	d1,.edge
	moveq	#0,d7
	move.b	(a6)+,d7			; (dat_69798: the polygons)
	subq.w	#1,d7
.poly:	move.b	(a6)+,d0			; the colour
	move.b	d0,BmColour
	moveq	#0,d2
	move.b	(a6)+,d2			; 3 or 4 edges
	subq.w	#1,d2
	lea	BmPoly(pc),a1
	lea	BmEdge(pc),a0
	move.w	d2,d3
	addq.w	#1,d3
	move.w	d3,BmPolyN
.pe:	moveq	#0,d0
	move.b	(a6)+,d0			; an edge: its offset (4 a long)
	move.l	(a0,d0.w),(a1)+
	dbra	d2,.pe
	movem.l	d7/a6,-(a7)
	bsr.w	BlitPoly
	movem.l	(a7)+,d7/a6
	dbra	d7,.poly
	movem.l	(a7)+,d1/d6-d7/a0
.next:	subq.b	#1,d1
	bpl.w	.group
	lea	(CUSTOM).l,a5
	bra.w	BlitWait				; (the last blit done before the rows are drawn on the screen)

;-------------------------------------------------------------------------------
; BlitPoly - the polygon of BmPoly's BmPolyN edges drawn in BmColour: its lines in the mask, the
; fill, the colour on the screen. Skipped when all its points are off one side of the view (the
; release's test of its edges' flags). Registers: none kept
;-------------------------------------------------------------------------------
BlitPoly:
	lea	(CUSTOM).l,a5
	lea	BmPoly(pc),a0
	lea	BmX(pc),a3
	lea	BmY(pc),a4
	moveq	#$f,d5				; the sides all the points are off: left 1, right 2, above 4,
	move.w	#$7fff,d6			; below 8 (a bit is cleared by a point not off that side);
	move.w	#$8000,d7			; the lowest and highest y
	movea.w	#255,a1				; the points' x range (clamped to the view): a1 least, a2 greatest
	suba.l	a2,a2
	move.w	BmPolyN,d3
	subq.w	#1,d3
.edge:	move.l	(a0)+,d0			; p1 << 16 | p2
	moveq	#1,d2
.pt:	move.w	d0,d1
	andi.w	#$ff,d1
	move.w	(a4,d1.w),d4			; y
	move.w	(a3,d1.w),d1			; x
	tst.w	d1
	bmi.s	.a
	bclr	#0,d5				; x >= 0: not off the left
.a:	cmpi.w	#255,d1
	bgt.s	.b
	bclr	#1,d5
.b:	tst.w	d1				; (the x range, d1 kept in the view)
	bpl.s	.xl
	moveq	#0,d1
.xl:	cmpi.w	#255,d1
	ble.s	.xh
	move.w	#255,d1
.xh:	cmpa.w	d1,a1
	ble.s	.xm
	movea.w	d1,a1
.xm:	cmpa.w	d1,a2
	bge.s	.xn
	movea.w	d1,a2
.xn:	cmp.w	BmTopW(pc),d4
	blt.s	.c
	bclr	#2,d5
.c:	cmpi.w	#127,d4
	bgt.s	.d
	bclr	#3,d5
.d:	cmp.w	d4,d6
	ble.s	.e
	move.w	d4,d6
.e:	cmp.w	d4,d7
	bge.s	.f
	move.w	d4,d7
.f:	swap	d0
	dbra	d2,.pt
	dbra	d3,.edge
	tst.b	d5
	bne.w	.skip				; wholly off a side
	cmp.w	BmTopW(pc),d6
	bge.s	.y0
	move.w	BmTopW(pc),d6
.y0:	cmpi.w	#127,d7
	ble.s	.y1
	move.w	#127,d7
.y1:	cmp.w	d6,d7
	blt.w	.skip
	move.w	d6,BmY0
	move.w	d7,BmY1
	sub.w	d6,d7
	addq.w	#1,d7				; the lines
	lsl.w	#6,d7
	move.w	a1,d0				; the words the polygon spans: BmW0 to the last
	lsr.w	#4,d0
	move.w	d0,BmW0
	move.w	a2,d1
	lsr.w	#4,d1
	sub.w	d0,d1
	addq.w	#1,d1				; how many
	or.w	d1,d7				; the blits' size: the lines, and the words wide
	move.w	d7,BmSize
	add.w	d1,d1				; bytes
	moveq	#BM_STRIDE,d0
	sub.w	d1,d0
	move.w	d0,BmMMod			; the mask's modulo
	moveq	#40,d0
	sub.w	d1,d0
	move.w	d0,BmSMod			; the screen's

	; 1. the mask cleared on those lines
	move.w	d6,d0
	lsl.w	#5,d0				; * BM_STRIDE
	add.w	BmW0,d0
	add.w	BmW0,d0				; (and the first word)
	lea	BlitMask(pc),a1
	adda.w	d0,a1
	bsr.w	BlitWait
	move.w	#$0100,BLTCON0(a5)		; D only: zeros
	clr.w	BLTCON1(a5)
	move.w	BmMMod,BLTDMOD(a5)
	move.l	a1,BLTDPTH(a5)
	move.w	BmSize,BLTSIZE(a5)

	; 2. the lines: each edge clipped to the view and drawn one pixel a row, exclusive-or'd
	bsr.w	BlitWait
	move.w	#BM_STRIDE,BLTCMOD(a5)
	move.w	#BM_STRIDE,BLTDMOD(a5)
	move.w	#$8000,BLTADAT(a5)
	move.w	#$ffff,BLTBDAT(a5)
	move.l	#-1,BLTAFWM(a5)
	lea	BmPoly(pc),a0
	move.w	BmPolyN,d3
	subq.w	#1,d3
.draw:	move.l	(a0)+,d0
	movem.l	d3/a0,-(a7)
	bsr.w	BlitEdge
	movem.l	(a7)+,d3/a0
	dbra	d3,.draw

	; 3. the fill: exclusive, descending, from the last line's last word
	move.w	BmY1,d0
	lsl.w	#5,d0
	move.w	BmSize,d1
	andi.w	#$3f,d1				; the words wide: the last word is BmW0 + that - 1
	add.w	BmW0,d1
	add.w	d1,d1
	add.w	d1,d0
	lea	BlitMask-2(pc),a1
	adda.w	d0,a1
	bsr.w	BlitWait
	move.w	#$09f0,BLTCON0(a5)		; A to D
	move.w	#$0012,BLTCON1(a5)		; descending, exclusive fill
	move.w	BmMMod,BLTAMOD(a5)
	move.w	BmMMod,BLTDMOD(a5)
	move.l	a1,BLTAPTH(a5)
	move.l	a1,BLTDPTH(a5)
	move.w	BmSize,BLTSIZE(a5)

	; 4. the colour: for each plane, the mask's pixels set (the colour's bit 1) or cleared (0)
	move.w	BmY0,d0
	move.w	d0,d1
	lsl.w	#5,d0
	add.w	BmW0,d0
	add.w	BmW0,d0
	lea	BlitMask(pc),a1
	adda.w	d0,a1				; the mask's first line, first word
	mulu.w	#40,d1
	add.w	BmW0,d1
	add.w	BmW0,d1
	movea.l	(ScreenDrawTop).l,a2
	adda.w	d1,a2				; the screen's, plane 0
	move.b	BmColour,d4
	moveq	#3,d3
.plane:	bsr.w	BlitWait
	move.w	#$0dfc,d0			; A or B
	lsr.b	#1,d4
	bcs.s	.set
	move.w	#$0d0c,d0			; B and not A
.set:	move.w	d0,BLTCON0(a5)
	clr.w	BLTCON1(a5)
	move.w	BmMMod,BLTAMOD(a5)
	move.w	BmSMod,BLTBMOD(a5)
	move.w	BmSMod,BLTDMOD(a5)
	move.l	a1,BLTAPTH(a5)
	move.l	a2,BLTBPTH(a5)
	move.l	a2,BLTDPTH(a5)
	move.w	BmSize,BLTSIZE(a5)
	adda.w	#8000,a2
	dbra	d3,.plane
.skip:	rts

;-------------------------------------------------------------------------------
; BlitEdge - d0 an edge's points (p1 << 16 | p2: offsets into BmX and BmY): clipped to the lines
; BmY0-BmY1 and to the view's width, drawn in the mask by BlitLine, top to bottom. The part of
; the edge left of the view is put on column 0, the part right of it on column 255 (the polygon
; closes at the side), in pieces that do not share a row (a row's pixel would be exclusive-or'd
; away). A level edge puts nothing in a row. a3, a4 = BmX, BmY; a5 = CUSTOM
;-------------------------------------------------------------------------------
BlitEdge:
	move.w	d0,d1
	andi.w	#$ff,d1
	move.w	(a3,d1.w),BmEX2
	move.w	(a4,d1.w),BmEY2
	swap	d0
	andi.w	#$ff,d0
	move.w	(a3,d0.w),BmEX1
	move.w	(a4,d0.w),BmEY1
	move.w	BmEY1,d4
	move.w	BmEY2,d5
	cmp.w	d4,d5
	beq.w	.done				; level
	bgt.s	.ordered
	move.w	BmEX1,d0			; the upper end first
	move.w	BmEX2,BmEX1
	move.w	d0,BmEX2
	move.w	d4,BmEY2
	move.w	d5,BmEY1
	exg	d4,d5
.ordered:					; d4 = y1 < d5 = y2
	subq.w	#1,d5				; the edge's rows are y1 to y2 - 1: the lower end's row is left to
					; the edge that goes on from it (both would put a pixel there: the
					; exclusive-or would cancel them)
	cmp.w	BmY1,d4
	bgt.w	.done				; below the lines
	cmp.w	BmY0,d5
	blt.w	.done				; above them
	move.w	BmY0,d6				; d6 = the first row: y1 or the first line
	cmp.w	d4,d6
	bge.s	.ra
	move.w	d4,d6
.ra:	move.w	BmY1,d7				; d7 = the last row
	cmp.w	d5,d7
	ble.s	.rb
	move.w	d5,d7
.rb:	move.w	d6,d1
	bsr.w	BmLerp
	move.w	d0,d4				; d4 = x at the first row, d5 = at the last
	move.w	d7,d1
	bsr.w	BmLerp
	move.w	d0,d5
	cmpi.w	#256,d4				; both in the view: the line as it is
	bcc.s	.clip
	cmpi.w	#256,d5
	bcc.s	.clip
	move.w	d4,d0
	move.w	d6,d1
	move.w	d5,d2
	move.w	d7,d3
	bra.w	BlitLine
.clip:	move.w	d6,BmPA				; the rows to draw, and their x at the ends
	move.w	d7,BmPB
	move.w	d4,BmXA
	move.w	d5,BmXB
	; the rows where the edge crosses column 0 and column 255 (if it does), sorted: BmC1, BmC2
	move.w	d7,BmC1				; (none: the last row, and the x there)
	move.w	d7,BmC2
	move.w	d5,BmK1
	move.w	d5,BmK2
	moveq	#0,d3				; d3: how many crossings
	tst.w	d4
	bpl.s	.l1
	tst.w	d5
	bmi.s	.l2				; both left of it
	moveq	#0,d0
	moveq	#0,d5				; (d5 the column: its x)
	bsr.w	BmCross				; d0 the row
	bsr.w	BmAddCross
	bra.s	.l2
.l1:	tst.w	d5
	bpl.s	.l2
	moveq	#0,d0
	moveq	#0,d5
	bsr.w	BmCross
	bsr.w	BmAddCross
.l2:	cmpi.w	#255,BmXA
	ble.s	.r1
	cmpi.w	#255,BmXB
	bgt.s	.pieces				; both right of it
	move.w	#255,d0
	move.w	#255,d5
	bsr.w	BmCross
	bsr.w	BmAddCross
	bra.s	.pieces
.r1:	cmpi.w	#255,BmXB
	ble.s	.pieces
	move.w	#255,d0
	move.w	#255,d5
	bsr.w	BmCross
	bsr.w	BmAddCross
.pieces:				; the pieces' ends' x: the edge's ends and the columns it crosses
	move.w	BmPA,d6				; the first piece's first row
	move.w	BmC1,d7
	move.w	BmXA,d4
	move.w	BmK1,d5
	bsr.w	BmPiece
	move.w	BmC1,d6
	addq.w	#1,d6
	move.w	BmC2,d7
	move.w	BmK1,d4
	move.w	BmK2,d5
	bsr.w	BmPiece
	move.w	BmC2,d6
	addq.w	#1,d6
	move.w	BmPB,d7
	move.w	BmK2,d4
	move.w	BmXB,d5
	bsr.w	BmPiece
.done:	rts

;-------------------------------------------------------------------------------
; BmCross - d0 a column (0 or 255): the row where the edge (BmE*) crosses it -> d0 (BmPA-BmPB)
;-------------------------------------------------------------------------------
BmCross:
	move.w	BmEX2,d1
	sub.w	BmEX1,d1			; dx (not 0: the ends are on two sides of the column)
	sub.w	BmEX1,d0			; column - x1
	move.w	BmEY2,d2
	sub.w	BmEY1,d2			; dy
	muls.w	d2,d0				; (column - x1) * dy
	divs.w	d1,d0				; / dx
	add.w	BmEY1,d0
	cmp.w	BmPA(pc),d0
	bge.s	.lo
	move.w	BmPA(pc),d0
.lo:	cmp.w	BmPB(pc),d0
	ble.s	.hi
	move.w	BmPB(pc),d0
.hi:	rts

;-------------------------------------------------------------------------------
; BmAddCross - d0 a crossing row, d5 its column: kept in BmC1, BmC2 (and BmK1, BmK2) in order of
; the rows (d3 how many so far)
;-------------------------------------------------------------------------------
BmAddCross:
	tst.w	d3
	bne.s	.second
	move.w	d0,BmC1
	move.w	d5,BmK1
	moveq	#1,d3
	rts
.second:
	cmp.w	BmC1(pc),d0
	bge.s	.in
	move.w	BmC1(pc),BmC2
	move.w	BmK1(pc),BmK2
	move.w	d0,BmC1
	move.w	d5,BmK1
	rts
.in:	move.w	d0,BmC2
	move.w	d5,BmK2
	rts

;-------------------------------------------------------------------------------
; BmPiece - rows d6-d7 of the edge (BmE*), its x d4 at the first and d5 at the last: on column 0 if left of the view, on 255 if right of it,
; else its line, its ends kept in the view. Nothing if there are no rows
;-------------------------------------------------------------------------------
BmPiece:
	cmp.w	d6,d7
	blt.s	.none
	move.w	d4,d0
	add.w	d5,d0
	asr.w	#1,d0				; the middle
	bpl.s	.notleft
	moveq	#0,d4				; left of the view: column 0
	moveq	#0,d5
	bra.s	.line
.notleft:
	cmpi.w	#255,d0
	ble.s	.in
	move.w	#255,d4				; right of it: column 255
	move.w	#255,d5
	bra.s	.line
.in:	tst.w	d4				; in the view: the ends kept in it
	bpl.s	.a
	moveq	#0,d4
.a:	cmpi.w	#255,d4
	ble.s	.b
	move.w	#255,d4
.b:	tst.w	d5
	bpl.s	.c
	moveq	#0,d5
.c:	cmpi.w	#255,d5
	ble.s	.line
	move.w	#255,d5
.line:	move.w	d4,d0
	move.w	d6,d1
	move.w	d5,d2
	move.w	d7,d3
	bra.w	BlitLine
.none:	rts

;-------------------------------------------------------------------------------
; BmLerp - d1 a row of the edge (BmE*: y1 < y2): d0 its x there, rounded. Clobbers d1, d2
;-------------------------------------------------------------------------------
BmLerp:
	move.w	BmEY2(pc),d2
	sub.w	BmEY1(pc),d2			; dy > 0
	sub.w	BmEY1(pc),d1			; row - y1
	move.w	BmEX2(pc),d0
	sub.w	BmEX1(pc),d0			; dx
	muls.w	d0,d1				; dx * (row - y1)
	moveq	#0,d0
	move.w	d2,d0
	lsr.w	#1,d0				; dy / 2: the rounding
	tst.l	d1
	bpl.s	.pos
	neg.l	d0
.pos:	add.l	d0,d1
	divs.w	d2,d1
	move.w	d1,d0
	add.w	BmEX1(pc),d0
	rts

;-------------------------------------------------------------------------------
; BlitLine - d0, d1 and d2, d3 two points of the mask (x 0-255, y 0-127; y1 <= y2): the line between
; them in the blitter's line mode, one pixel a row, exclusive-or'd into the mask. a5 = CUSTOM
; The line's octant: the major axis (the longer: x or y) is stepped every pixel, the other
; sometimes (the error term, BLTAPT = 4 minor - 2 major, BLTAMOD = 4 (minor - major), BLTBMOD =
; 4 minor); the major axis' direction and the minor's are bits of BLTCON1: SUD set when y moves only sometimes
; (x is the major axis), AUL when the axis that always moves goes up or left, SUL when the other does
;-------------------------------------------------------------------------------
BlitLine:
	move.w	d2,d4
	sub.w	d0,d4				; dx
	sub.w	d1,d3				; dy >= 0
	moveq	#0,d5				; BLTCON1's octant bits
	tst.w	d4
	bge.s	.right
	neg.w	d4				; |dx|
	moveq	#4,d5				; left: AUL (x always)
.right:	cmp.w	d3,d4
	bcs.s	.vert
	move.w	d3,d6				; the major axis x: the minor is dy
	move.w	d4,d7
	ori.w	#$10,d5				; SUD: y only sometimes
	bra.s	.go
.vert:	move.w	d4,d6				; the major axis y: the minor is |dx|
	move.w	d3,d7
	andi.w	#4,d5
	beq.s	.down
	moveq	#8,d5				; left: SUL (x sometimes)
.down:
.go:	move.w	d6,d4
	add.w	d4,d4
	add.w	d4,d4				; 4 minor
	move.w	d7,d3
	add.w	d3,d3				; 2 major
	sub.w	d3,d4				; 4 minor - 2 major
	bpl.s	.sign
	ori.w	#$40,d5				; SIGN
.sign:	ori.w	#3,d5				; ONEDOT, LINE
	moveq	#15,d3
	and.w	d0,d3
	ror.w	#4,d3				; the start bit in BLTCON0's top nibble
	ori.w	#$0b4a,d3			; A, C and D, exclusive-or
	lsr.w	#4,d0				; the first word
	add.w	d0,d0
	lsl.w	#5,d1				; * BM_STRIDE
	add.w	d1,d0
	lea	BlitMask(pc),a1
	adda.w	d0,a1
	move.w	d6,d0
	sub.w	d7,d0
	add.w	d0,d0
	add.w	d0,d0				; 4 (minor - major)
	add.w	d6,d6
	add.w	d6,d6				; 4 minor
	bsr.w	BlitWait
	move.w	d3,BLTCON0(a5)
	move.w	d5,BLTCON1(a5)
	move.l	a1,BLTCPTH(a5)
	move.l	a1,BLTDPTH(a5)
	ext.l	d4
	move.l	d4,BLTAPTH(a5)
	move.w	d0,BLTAMOD(a5)
	move.w	d6,BLTBMOD(a5)
	addq.w	#1,d7
	lsl.w	#6,d7
	addq.w	#2,d7
	move.w	d7,BLTSIZE(a5)
	rts

BmW0:		dc.w	0			; the polygon's first word, its modulos in the mask and the screen
BmMMod:		dc.w	0
BmSMod:		dc.w	0
BmSize:		dc.w	0			; the polygon's blits' size: its lines, its words wide
BmTopW:		dc.w	0			; the view's first line to draw: 0, or 64 at half height
BmPA:		dc.w	0			; BlitEdge: the rows drawn, the x at the ends, the crossings
BmPB:		dc.w	0
BmXA:		dc.w	0
BmXB:		dc.w	0
BmC1:		dc.w	0
BmC2:		dc.w	0
BmK1:		dc.w	0			; the x (column) at the crossings BmC1, BmC2
BmK2:		dc.w	0
