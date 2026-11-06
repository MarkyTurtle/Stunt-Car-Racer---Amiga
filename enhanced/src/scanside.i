;-------------------------------------------------------------------------------
; scanside.i - (the enhanced game) ScanEdge's edges clipped only at the view's sides, the
; outcodes and the y tests skipped.
;
; ScanEdge's clipping (from .clip) works out each end's outcode (x left of 0 or right of 255, y
; above 0 or below 127) bit by bit, then tests the four y cases one by one before it gets to the
; sides. About 20 edges a frame have both ends' y in the view and only x outside it - the
; mountains' ends (6 small mountains, often across a side) and the track's edges that run off the
; view's left or right: wholly off one side (EdgeOffSide, the side's x on each line) or crossing
; it (the x clipping at l_66BEE). Those need only the two x outcodes. ScanSides works them out
; and goes on where the release would, with the registers and the variables as the release would
; have them there:
; * wholly off one side: at the jsr EdgeOffSide (l_669B0), d0 = $00c1 : (the caller's d0 bits
;   8-15, c1 & c2), d1.b = c1, d2.b = c2;
; * crossing: at l_66BEE, d0 = (the caller's d0 bits 24-31, then 0) : $00c1, d1.b = c1, d2.b = c2;
; with dat_668A6 = 0 and dat_668A2 = $FFFF written first, as .clip does (c1, c2: the ends'
; outcodes - bit 3 x < 0, bit 2 x > 255). Any other edge (a y outside the view): .clip as before
; (ScanEdgeClip). About 450 cycles less an edge.
;
; Checked by tools/test_scanside.py: assembled with SCAN_CHECK, each such edge is clipped both
; ways - the release's from the same state - and the edge buffer, the row table's entry, the
; variables and all the registers compared.
;-------------------------------------------------------------------------------

ScanSides:
	move.w	d5,d0				; both ends' y in the view (0-127, as unsigned)?
	or.w	d7,d0
	cmpi.w	#$80,d0
	bcc.w	ScanEdgeClip			; no: the release's way
	ifd	SCAN_CHECK
	bra.w	ScanSidesCheck
ScanSidesNow:
	endc
	move.w	#$0,(dat_668A6).l		; as .clip
	move.w	#$ffff,(dat_668A2).l
	clr.w	d3				; c2: the top end's outcode (bits 3, 2: x < 0, x > 255) -
	cmpi.w	#$100,d6			; d3's word only (its high word left as the release
	bcs.s	.c1				; leaves it)
	move.w	#4,d3
	tst.w	d6
	bpl.s	.c1
	move.w	#8,d3
.c1:	move.b	d3,d2
	clr.w	d3				; c1: the bottom end's
	cmpi.w	#$100,d4
	bcs.s	.both
	move.w	#4,d3
	tst.w	d4
	bpl.s	.both
	move.w	#8,d3
.both:	move.b	d3,d1
	and.b	d2,d3				; both off the same side?
	bne.s	.off
	swap	d0				; crossing: d0 = (d0 bits 24-31 kept) : $00c1
	clr.b	d0
	swap	d0
	clr.w	d0
	move.b	d1,d0
	bra.w	l_66BEE
.off:	swap	d0				; off one side: d0 = $00c1 : (d0 bits 8-15 kept, c1 & c2)
	move.b	d3,d0
	swap	d0
	clr.w	d0
	move.b	d1,d0
	swap	d0
	bra.w	l_669B0

	ifd	SCAN_CHECK
;-------------------------------------------------------------------------------
; ScanSidesCheck - (tools/test_scanside.py) the edge clipped the release's way (ScanEdgeClip)
; and ScanSides' way from the same state, and the results compared: the edge buffer (320 bytes
; from its header), the row table's entry, EdgeBufferNext, dat_668A0-dat_668A7 and the registers
; d0-d7/a0-a6. $3760 counts the edges compared, $3764 those whose memory differs, $3768 those
; whose registers differ. ScanSides' results are kept
;-------------------------------------------------------------------------------
SCAN_BUF	equ	320

ScanSidesCheck:
	movem.l	d0-d7/a0-a6,CheckIn
	addq.l	#1,($3760).w
	lea	CheckSaved,a3			; the state before
	bsr.w	CheckState
	movem.l	CheckIn,d0-d7/a0-a6
	jsr	ScanEdgeClip			; the release's way
	movem.l	d0-d7/a0-a6,CheckOutA
	lea	CheckStateA,a3
	bsr.w	CheckState
	lea	CheckSaved,a3			; the state put back
	bsr.w	CheckRestore
	movem.l	CheckIn,d0-d7/a0-a6
	jsr	ScanSidesNow			; ScanSides' way
	movem.l	d0-d7/a0-a6,CheckOutB
	lea	CheckStateB,a3
	bsr.w	CheckState
	lea	CheckStateA,a0			; the memory: the same?
	lea	CheckStateB,a1
	move.w	#(SCAN_BUF+16)/2-1,d0
.mem:	cmpm.w	(a0)+,(a1)+
	bne.s	.memx
	dbra	d0,.mem
	bra.s	.regs
.memx:	addq.l	#1,($3764).w
.regs:	lea	CheckOutA,a0			; the registers
	lea	CheckOutB,a1
	moveq	#15-1,d0
.reg:	cmpm.l	(a0)+,(a1)+
	bne.s	.regx
	dbra	d0,.reg
	bra.s	.done
.regx:	addq.l	#1,($3768).w
.done:	movem.l	CheckOutB,d0-d7/a0-a6
	rts

; CheckState - a3: the state saved there (the edge's header and buffer from CheckIn's a2, the row
; table's entry, EdgeBufferNext, dat_668A0-dat_668A7). CheckRestore - put back from a3
CheckState:
	movea.l	CheckIn+4*10,a0			; a2: the header
	move.w	#SCAN_BUF/2-1,d0
.buf:	move.w	(a0)+,(a3)+
	dbra	d0,.buf
	move.w	(RowOffset).l,d0
	movea.l	CheckIn+4*9,a0			; a1: the row table
	move.l	(a0,d0.w),(a3)+
	move.l	(EdgeBufferNext).l,(a3)+
	move.l	(dat_668A0).l,(a3)+
	move.l	(dat_668A0+4).l,(a3)+
	rts
CheckRestore:
	movea.l	CheckIn+4*10,a0
	move.w	#SCAN_BUF/2-1,d0
.buf:	move.w	(a3)+,(a0)+
	dbra	d0,.buf
	move.w	(RowOffset).l,d0
	movea.l	CheckIn+4*9,a0
	move.l	(a3)+,(a0,d0.w)
	move.l	(a3)+,(EdgeBufferNext).l
	move.l	(a3)+,(dat_668A0).l
	move.l	(a3)+,(dat_668A0+4).l
	rts

CheckIn:	dcb.l	15,0
CheckOutA:	dcb.l	15,0
CheckOutB:	dcb.l	15,0
CheckSaved:	dcb.b	SCAN_BUF+16,0
CheckStateA:	dcb.b	SCAN_BUF+16,0
CheckStateB:	dcb.b	SCAN_BUF+16,0
	endc
