;-------------------------------------------------------------------------------
; blitcutout.i - (the enhanced game) the cockpit's cut-outs drawn by the blitter.
;
; DrawCutout drew each cut-out with the CPU: for every 16 pixels of every plane, a read of the
; screen, an and with the cut-out's mask, an or of its picture and a write - about 33 cycles a
; word. The blitter's cookie-cut does the same (D = C and A, or B: minterm $EC, with A the
; mask, B the picture, C and D the screen) in 4 of its memory cycles a word - 8 of the CPU's.
;
; The cut-outs are kept interleaved (MakeCutout: for each 16 pixels the mask, then the 4
; planes' words), which the blitter cannot step through. So at start-up, after MakeCutouts,
; MakeBlitCutouts copies each one into the blitter's form - a header (a plane's bytes, the width
; and height it was made at), then the mask's words, plane 0's, 1's, 2's, 3's, each W x H - in
; the free memory after DiskPicture (BlitCutouts; 32K at most:
; less than the cut-outs' own $6490-$E298). The chains' cut-outs ($25-$30) are sprites, which
; MoveChains rewrites in play: they are not copied, and DrawCutout draws them (if asked) with the
; CPU as before. Nothing else writes the cut-outs after start-up (checked with scremu's
; writecount over a race). Their rectangles do change: the springs (0-5) are drawn shorter as the
; car bounces (from 58 lines down) - so each plane's blit is pointed at its plane by the header,
; and a narrower width is stepped over with the A and B modulos; a larger one than the copy's
; (not expected) is left to the CPU.
;
; DrawCutout calls DrawCutoutBlit first: 4 blits (one a plane), the CPU waiting for each (so
; that nothing drawn after the cockpit - the instruments, the drawbridge - can meet a blit in
; progress). The result is the same picture as the CPU's.
;-------------------------------------------------------------------------------

CUTOUTS		equ	52
BLIT_CUTOUTS_MAX equ	$E298-$6490+CUTOUTS*8		; at most what MakeCutouts made, and the headers (BlitCutouts: after
						; DiskPicture, scr_game.s)

BlitCutoutPtrs:					; each cut-out's copy (0: none - drawn by the CPU)
	dcb.l	CUTOUTS,0

;-------------------------------------------------------------------------------
; MakeBlitCutouts - after MakeCutouts: the cut-outs copied into the blitter's form. All
; registers kept.
;-------------------------------------------------------------------------------
MakeBlitCutouts:
	movem.l	d0-d7/a0-a6,-(a7)
	lea	(BlitCutouts).l,a1		; the next copy
	lea	BlitCutoutPtrs(pc),a6
	moveq	#0,d7				; the cut-out
.next:	clr.l	(a6)
	cmpi.w	#$25,d7				; the chains: sprites, rewritten in play
	blo.s	.copy
	cmpi.w	#$30,d7
	bls.s	.skip
.copy:	move.l	a1,(a6)
	move.w	d7,d0
	lsl.w	#2,d0
	lea	(CutoutPointers).l,a0
	movea.l	(a0,d0.w),a0			; the cut-out (MakeCutout's form)
	lsl.w	#2,d0
	lea	(CutoutRects).l,a2
	move.w	4(a2,d0.w),d1			; width - 1 (words)
	addq.w	#1,d1
	move.w	6(a2,d0.w),d2			; height - 1
	addq.w	#1,d2
	move.w	d1,d3
	mulu	d2,d1				; the words a plane
	move.l	d1,d0
	add.l	d0,d0				; the bytes a plane
	move.l	d0,(a1)+			; the header: a plane's bytes,
	move.w	d3,(a1)+			; the width,
	move.w	d2,(a1)+			; the height
	lea	(a1,d0.l),a2			; plane 0's
	lea	(a2,d0.l),a3			; 1's
	lea	(a3,d0.l),a4			; 2's
	lea	(a4,d0.l),a5			; 3's
	subq.w	#1,d1
.word:	move.w	(a0)+,(a1)+			; the mask
	move.w	(a0)+,(a2)+
	move.w	(a0)+,(a3)+
	move.w	(a0)+,(a4)+
	move.w	(a0)+,(a5)+
	dbra	d1,.word
	movea.l	a5,a1				; the next after plane 3
.skip:	addq.l	#4,a6
	addq.w	#1,d7
	cmpi.w	#CUTOUTS,d7
	bne.s	.next
	movem.l	(a7)+,d0-d7/a0-a6
	rts

;-------------------------------------------------------------------------------
; DrawCutoutBlit - from DrawCutout: d0.w = a cut-out (0-$33) drawn on ScreenDraw at its place
; (CutoutRects) by the blitter, if it has a copy. Z set: drawn; Z clear: not (DrawCutout draws
; it with the CPU; d0 kept). d1, d3-d5, a0-a2, a4-a5 used (DrawCutout keeps d1, d5, a4-a6).
;-------------------------------------------------------------------------------
DrawCutoutBlit:
	move.w	d0,d5
	add.w	d5,d5
	add.w	d5,d5
	lea	BlitCutoutPtrs(pc),a1
	move.l	(a1,d5.w),d4
	bne.s	.blit
	moveq	#-1,d5				; Z clear: the CPU's
	rts
.blit:	movea.l	d4,a1
	add.w	d5,d5
	add.w	d5,d5
	lea	(CutoutRects+4).l,a2
	adda.w	d5,a2
	moveq	#0,d4				; its bottom line at the opponent's distance's cells or
	move.b	7(a2),d4			; below: they may be drawn over (readout.i). The
	add.w	2(a2),d4			; cockpit's parts end above them
	cmpi.w	#READOUT_Y0,d4
	blo.s	.above
	jsr	(ReadoutCutoutCheck).l
.above:
	move.w	(a2),d1				; width - 1 (words)
	addq.w	#1,d1
	move.w	2(a2),d4			; height - 1
	addq.w	#1,d4
	cmp.w	4(a1),d1			; no wider and no taller than the copy
	bhi.s	.cpu
	cmp.w	6(a1),d4
	bls.s	.fits
.cpu:	moveq	#-1,d5
	rts
.fits:	movea.l	(ScreenDraw).l,a0		; where: as DrawCutout works it out
	moveq	#0,d3
	move.b	5(a2),d3			; x (words: its low byte)
	add.w	d3,d3
	adda.l	d3,a0
	moveq	#0,d3
	move.b	7(a2),d3			; y (its low byte)
	mulu	#40,d3
	adda.l	d3,a0
	move.w	d4,d3
	lsl.w	#6,d3
	or.w	d1,d3				; BLTSIZE: height, width
	move.w	4(a1),d5
	sub.w	d1,d5
	add.w	d5,d5				; A's and B's modulo: the copy's width less this
	moveq	#40,d0
	sub.w	d1,d0
	sub.w	d1,d0				; the screen's modulo
	move.l	(a1),d4				; a plane's bytes
	addq.l	#8,a1				; the mask
	lea	(CUSTOM).l,a5
	bsr.s	BlitWait
	move.w	#$8240,DMACON(a5)		; the blitter's DMA on (GameLoop turns it off)
	move.l	#$0FEC0000,BLTCON0(a5)		; A, B, C, D; D = A and C, or B. BLTCON1 0
	move.l	#-1,BLTAFWM(a5)			; no first or last word mask
	move.w	d0,BLTCMOD(a5)
	move.w	d5,BLTBMOD(a5)
	move.w	d5,BLTAMOD(a5)
	move.w	d0,BLTDMOD(a5)
	movea.l	a1,a4				; B: each plane's picture
	moveq	#3,d1				; the 4 planes
.plane:	adda.l	d4,a4
	bsr.s	BlitWait
	move.l	a1,BLTAPTH(a5)
	move.l	a4,BLTBPTH(a5)
	move.l	a0,BLTCPTH(a5)
	move.l	a0,BLTDPTH(a5)
	move.w	d3,BLTSIZE(a5)
	lea	$1f40(a0),a0
	dbra	d1,.plane
	bsr.s	BlitWait			; done before anything else draws
	moveq	#0,d5				; Z set: drawn
	rts

; BlitWait - until the blitter is not busy (a5 = CUSTOM)
BlitWait:
	tst.b	DMACONR(a5)			; (the first read after a blit starts can be early: older Agnus)
.wait:	btst	#6,DMACONR(a5)			; BBUSY (DMACONR bit 14)
	bne.s	.wait
	rts
