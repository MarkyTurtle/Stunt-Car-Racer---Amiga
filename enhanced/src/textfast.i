
;-------------------------------------------------------------------------------
; textfast.i - (the enhanced game) a character's 8 rows drawn faster by PrintCharNow, the same
; bytes written.
;
; PrintCharNow draws a glyph a row at a time: for each row the glyph's byte and its cell's mask
; (7 columns, $1FC00; 6 for the proportional font, $1F800) shifted to the column, then for each
; of the row's 2 words and each pair of planes the screen read, the background's colour put in
; the cell (unless the text is drawn without one: dat_1BBD3 set), the text's colour in the glyph's
; pixels, and the word written - to the second screen, and to the first (unless dat_1BBBC is
; set: then to ScreenDraw only). About 11,400 cycles a character: the colours reloaded from
; memory, the masks turned and swapped for each step.
;
; The same result, per plane and word of a row: (old AND NOT U) OR V, where U is the cell and the
; glyph (or the glyph only, without a background), and V the plane's part of the colours: U
; itself (the text's and background's colours both have the plane), the glyph (the text's only),
; the cell less the glyph (the background's only), or nothing. So TextRows works out the 8 rows'
; U and the 3 kinds of V once (the mask is the same for every row: shifted once), then each plane
; with its own V: a read, an and, an or and the writes for each of its 16 words.
;
; The registers PrintChar does not keep are left as the release leaves them: d7 the last row's
; glyph, shifted; d6 the inverse of its low word, in both halves (and d2 0, a0 and a1 past the
; rows). tools/test_text.py checks it against the release's loop (TEXT_CHECK).
;-------------------------------------------------------------------------------

TextNotU:	dcb.w	16,0			; per row, its 2 words: NOT U
TextVTable:	dc.l	TextVNone,TextVBack,TextVText,TextVBoth	; by colour: neither, background only, text only, both
TextVNone:	dcb.w	16,0			; V: nothing
TextVBack:	dcb.w	16,0			; the cell less the glyph
TextVText:	dcb.w	16,0			; the glyph
TextVBoth:	dcb.w	16,0			; U
TextPlaneMasks:	dc.l	0,0			; (TextRows: the 4 planes' text colour, background colour)

;-------------------------------------------------------------------------------
; TextRows - PrintCharNow (59640): a0 the glyph (or GlyphRow's place: dat_5924A), a1 the second
; screen's word (or ScreenDraw's, or dat_5924C's), dat_59841 the column in the word: the 8 rows
; drawn. d0-d5 changed (PrintChar keeps them); d6, d7, d2, a0, a1 as the release's loop leaves
; them; the rest kept
;-------------------------------------------------------------------------------
TextRows:
	movem.l	a2-a4,-(a7)
	moveq	#0,d3
	move.b	(dat_59841).l,d3
	eori.b	#$f,d3				; the shift: 15 - the column
	move.l	#$1FC00,d4			; the cell: 7 columns,
	tst.b	(dat_5924A).l
	beq.s	.mask
	move.l	#$1F800,d4			; or 6 (the proportional font)
.mask:	lsl.l	d3,d4				; M (the same for every row)
	moveq	#9,d1
	add.w	d3,d1				; the glyph's shift: 9 + 15 - the column
	lea	TextNotU(pc),a2
	lea	TextVBack(pc),a3
	lea	TextVText(pc),a4
	moveq	#7,d2
	tst.b	(dat_5924A).l
	bne.s	.prop
	tst.b	(dat_1BBD3).l
	bmi.s	.clear
.back:	moveq	#0,d7				; the glyph's rows, with a background: U = M or G,
	move.b	(a0)+,d7			; V back = M and not G
	lsl.l	d1,d7				; G: (byte << 9) << the shift, as the release
	move.l	d7,(a4)+			; V text: G
	move.l	d4,d0
	or.l	d7,d0
	move.l	d0,TextVBoth-TextVText-4(a4)	; V both: U
	not.l	d0
	move.l	d0,(a2)+			; NOT U
	move.l	d7,d0				; V back: M and not G
	not.l	d0
	and.l	d4,d0
	move.l	d0,(a3)+
	dbra	d2,.back
	bra.s	.rows
.clear:	moveq	#0,d7				; without a background: U = G, V back = nothing
	move.b	(a0)+,d7
	lsl.l	d1,d7
	move.l	d7,(a4)+
	move.l	d7,TextVBoth-TextVText-4(a4)
	clr.l	(a3)+
	move.l	d7,d0
	not.l	d0
	move.l	d0,(a2)+
	dbra	d2,.clear
	bra.s	.rows
.prop:	movem.l	d1-d4,-(a7)			; the proportional font: each row from GlyphRow (d0, d4,
	jsr	(GlyphRow).l			; d5 used)
	movem.l	(a7)+,d1-d4
	lsl.l	d1,d7
	move.l	d7,(a4)+
	move.l	d4,d5
	tst.b	(dat_1BBD3).l
	bmi.s	.pclr
	or.l	d7,d5
	move.l	d7,d0
	not.l	d0
	and.l	d4,d0
	move.l	d0,(a3)+
	bra.s	.pu
.pclr:	move.l	d7,d5
	clr.l	(a3)+
.pu:	move.l	d5,TextVBoth-TextVText-4(a4)
	not.l	d5
	move.l	d5,(a2)+
	dbra	d2,.prop
.rows:	move.l	d7,d6				; d6: as the release leaves it - the inverse of the last
	swap	d6				; row's low word, in both halves
	move.w	d7,d6
	not.l	d6
	move.l	(TextColourMasks).l,d0		; the planes: text colour 0, 1 | 2, 3 (high, low words)
	move.l	(dat_5983A).l,d1
	move.l	(TextBackgroundMasks).l,d2
	move.l	(dat_59832).l,d3
	tst.b	(dat_1BBBC).l			; to both screens, or (dat_1BBBC set) to this one only
	bmi.s	.one
	swap	d0				; plane 0
	swap	d2
	bsr.w	TextPlane2
	swap	d0				; plane 1
	swap	d2
	bsr.w	TextPlane2
	move.l	d1,d0				; plane 2
	move.l	d3,d2
	swap	d0
	swap	d2
	bsr.w	TextPlane2
	swap	d0				; plane 3
	swap	d2
	bsr.w	TextPlane2
	bra.s	.done
.one:	swap	d0
	swap	d2
	bsr.w	TextPlane1
	swap	d0
	swap	d2
	bsr.w	TextPlane1
	move.l	d1,d0
	move.l	d3,d2
	swap	d0
	swap	d2
	bsr.w	TextPlane1
	swap	d0
	swap	d2
	bsr.w	TextPlane1
.done:	lea	8*40-4*$1f40(a1),a1		; past the rows, as the release
	moveq	#0,d2
	movem.l	(a7)+,a2-a4
	rts

; TextPlane2, TextPlane1 - TextRows: a plane's 8 rows (both words of each as a long), d0.w its
; text colour, d2.w its background's ($0000 or $FFFF): (old and not U) or V, written to both
; screens (a1 and a1 - $7D00) or to a1's only. a1 then the next plane's; a2-a3, d5 used
TextPlaneV:
	moveq	#0,d5				; which V: 4 the background's colour, 8 the text's
	tst.w	d2
	beq.s	.b
	moveq	#4,d5
.b:	tst.w	d0
	beq.s	.t
	addq.w	#8,d5
.t:	lea	TextVTable(pc),a3
	movea.l	(a3,d5.w),a3
	lea	TextNotU(pc),a2
	rts
TextPlane2:
	bsr.w	TextPlaneV
ROW	set	0
	rept	8
	move.l	ROW(a1),d5
	and.l	(a2)+,d5
	or.l	(a3)+,d5
	move.l	d5,ROW(a1)
	move.l	d5,ROW-$7d00(a1)
ROW	set	ROW+40
	endr
	lea	$1f40(a1),a1
	rts
TextPlane1:
	bsr.w	TextPlaneV
ROW	set	0
	rept	8
	move.l	ROW(a1),d5
	and.l	(a2)+,d5
	or.l	(a3)+,d5
	move.l	d5,ROW(a1)
ROW	set	ROW+40
	endr
	lea	$1f40(a1),a1
	rts

	ifd	TEXT_CHECK
;-------------------------------------------------------------------------------
; TextRowsRelease - (tools/test_text.py) the release's loop (59640-597E6), as it was
;-------------------------------------------------------------------------------
TextRowsRelease:
        move.b  #$8,d2                          ; 59640
.r59644:
        tst.b   (dat_5924A).l                   ; 59644
        beq.w   .r5965E                         ; 5964A
        jsr     (GlyphRow).l                    ; 5964E
        move.l  #$1F800,d5                      ; 59654 the glyph's mask (a number, not dat_1F800)
        bra.w   .r5966C                         ; 5965A
.r5965E:
        move.b  (a0)+,d7                        ; 5965E
        andi.l  #$ff,d7                         ; 59660
        move.l  #$1FC00,d5                      ; 59666 the glyph's mask: 7 columns (a number)
.r5966C:
        asl.l   #$8,d7                          ; 5966C
        asl.l   #$1,d7                          ; 5966E
        move.b  (dat_59841).l,d3                ; 59670
        eori.b  #$f,d3                          ; 59676
        andi.l  #$f,d3                          ; 5967A
        asl.l   d3,d7                           ; 59680
        asl.l   d3,d5                           ; 59682
        move.l  d7,d6                           ; 59684
        swap    d7                              ; 59686
        move.w  d7,d6                           ; 59688
        move.l  d5,d4                           ; 5968A
        swap    d5                              ; 5968C
        move.w  d5,d4                           ; 5968E
        move.l  (TextBackgroundMasks).l,d3      ; 59690
        and.l   d4,d3                           ; 59696
        not.l   d4                              ; 59698
        move.w  (a1),d0                         ; 5969A
        swap    d0                              ; 5969C
        move.w  $1f40(a1),d0                    ; 5969E
        tst.b   (dat_1BBD3).l                   ; 596A2
        bmi.w   .r596B0                         ; 596A8
        and.l   d4,d0                           ; 596AC
        or.l    d3,d0                           ; 596AE
.r596B0:
        move.l  (TextColourMasks).l,d3          ; 596B0
        and.l   d6,d3                           ; 596B6
        not.l   d6                              ; 596B8
        and.l   d6,d0                           ; 596BA
        or.l    d3,d0                           ; 596BC
        move.w  d0,$1f40(a1)                    ; 596BE
        swap    d0                              ; 596C2
        move.w  d0,(a1)                         ; 596C4
        tst.b   (dat_1BBBC).l                   ; 596C6
        bmi.w   .r596DA                         ; 596CC
        move.w  d0,-$7d00(a1)                   ; 596D0
        swap    d0                              ; 596D4
        move.w  d0,-$5dc0(a1)                   ; 596D6
.r596DA:
        adda.l  #$3e80,a1                       ; 596DA
        not.l   d4                              ; 596E0
        not.l   d6                              ; 596E2
        move.l  (dat_59832).l,d3                ; 596E4
        and.l   d4,d3                           ; 596EA
        not.l   d4                              ; 596EC
        move.w  (a1),d0                         ; 596EE
        swap    d0                              ; 596F0
        move.w  $1f40(a1),d0                    ; 596F2
        tst.b   (dat_1BBD3).l                   ; 596F6
        bmi.w   .r59704                         ; 596FC
        and.l   d4,d0                           ; 59700
        or.l    d3,d0                           ; 59702
.r59704:
        move.l  (dat_5983A).l,d3                ; 59704
        and.l   d6,d3                           ; 5970A
        not.l   d6                              ; 5970C
        and.l   d6,d0                           ; 5970E
        or.l    d3,d0                           ; 59710
        move.w  d0,$1f40(a1)                    ; 59712
        swap    d0                              ; 59716
        move.w  d0,(a1)                         ; 59718
        tst.b   (dat_1BBBC).l                   ; 5971A
        bmi.w   .r5972E                         ; 59720
        move.w  d0,-$7d00(a1)                   ; 59724
        swap    d0                              ; 59728
        move.w  d0,-$5dc0(a1)                   ; 5972A
.r5972E:
        adda.l  #$ffffc182,a1                   ; 5972E
        move.l  d7,d6                           ; 59734
        swap    d7                              ; 59736
        move.w  d7,d6                           ; 59738
        move.l  d5,d4                           ; 5973A
        swap    d5                              ; 5973C
        move.w  d5,d4                           ; 5973E
        move.l  (TextBackgroundMasks).l,d3      ; 59740
        and.l   d4,d3                           ; 59746
        not.l   d4                              ; 59748
        move.w  (a1),d0                         ; 5974A
        swap    d0                              ; 5974C
        move.w  $1f40(a1),d0                    ; 5974E
        tst.b   (dat_1BBD3).l                   ; 59752
        bmi.w   .r59760                         ; 59758
        and.l   d4,d0                           ; 5975C
        or.l    d3,d0                           ; 5975E
.r59760:
        move.l  (TextColourMasks).l,d3          ; 59760
        and.l   d6,d3                           ; 59766
        not.l   d6                              ; 59768
        and.l   d6,d0                           ; 5976A
        or.l    d3,d0                           ; 5976C
        move.w  d0,$1f40(a1)                    ; 5976E
        swap    d0                              ; 59772
        move.w  d0,(a1)                         ; 59774
        tst.b   (dat_1BBBC).l                   ; 59776
        bmi.w   .r5978A                         ; 5977C
        move.w  d0,-$7d00(a1)                   ; 59780
        swap    d0                              ; 59784
        move.w  d0,-$5dc0(a1)                   ; 59786
.r5978A:
        adda.l  #$3e80,a1                       ; 5978A
        not.l   d4                              ; 59790
        not.l   d6                              ; 59792
        move.l  (dat_59832).l,d3                ; 59794
        and.l   d4,d3                           ; 5979A
        not.l   d4                              ; 5979C
        move.w  (a1),d0                         ; 5979E
        swap    d0                              ; 597A0
        move.w  $1f40(a1),d0                    ; 597A2
        tst.b   (dat_1BBD3).l                   ; 597A6
        bmi.w   .r597B4                         ; 597AC
        and.l   d4,d0                           ; 597B0
        or.l    d3,d0                           ; 597B2
.r597B4:
        move.l  (dat_5983A).l,d3                ; 597B4
        and.l   d6,d3                           ; 597BA
        not.l   d6                              ; 597BC
        and.l   d6,d0                           ; 597BE
        or.l    d3,d0                           ; 597C0
        move.w  d0,$1f40(a1)                    ; 597C2
        swap    d0                              ; 597C6
        move.w  d0,(a1)                         ; 597C8
        tst.b   (dat_1BBBC).l                   ; 597CA
        bmi.w   .r597DE                         ; 597D0
        move.w  d0,-$7d00(a1)                   ; 597D4
        swap    d0                              ; 597D8
        move.w  d0,-$5dc0(a1)                   ; 597DA
.r597DE:
        adda.l  #$ffffc1a6,a1                   ; 597DE
        subq.b  #$1,d2                          ; 597E4
        bne.w   .r59644                         ; 597E6
	rts

;-------------------------------------------------------------------------------
; TextCheckRows - (tools/test_text.py) PrintCharNow's rows drawn by the release's loop, then
; again by TextRows from the same start: the bytes they write (8 rows x 2 words x 4 planes, at a1
; and a1 - $7D00) and the registers they leave (d2, d6, d7, a0-a6) compared. $3740: bytes that
; differ, $3744: characters, $3748: registers that differ. TextRows' result kept
;-------------------------------------------------------------------------------
TextCheckRows:
	movem.l	d0-d7/a0-a6,-(a7)		; the start (a1 at 36)
	addq.l	#1,($3744).w
	tst.b	(dat_5924A).l			; how many in each way: $374C the proportional font,
	beq.s	.c1				; $3750 one screen only, $3754 without a background
	addq.l	#1,($374C).w
.c1:	tst.b	(dat_1BBBC).l
	bpl.s	.c2
	addq.l	#1,($3750).w
.c2:	tst.b	(dat_1BBD3).l
	bpl.s	.c3
	addq.l	#1,($3754).w
.c3:	lea	TCBefore,a2
	bsr.w	TCCopyOut
	movem.l	(a7),d0-d7/a0-a6
	bsr.w	TextRowsRelease
	movem.l	d0-d7/a0-a6,TCRelRegs
	lea	TCRelease,a2
	bsr.w	TCCopyOut
	lea	TCBefore,a2			; the start put back
	bsr.w	TCCopyIn
	movem.l	(a7),d0-d7/a0-a6
	jsr	(TextRows).l
	movem.l	d0-d7/a0-a6,TCNewRegs
	lea	TCNew,a2
	bsr.w	TCCopyOut
	lea	TCRelease,a2			; the bytes (one screen's, or both)
	lea	TCNew,a3
	move.w	#TC_BYTES-1,d0
	tst.b	(dat_1BBBC).l
	bpl.s	.cmp
	move.w	#TC_BYTES/2-1,d0
.cmp:	cmpm.b	(a2)+,(a3)+
	beq.s	.same
	addq.l	#1,($3740).w
.same:	dbra	d0,.cmp
	lea	TCRelRegs,a2			; the registers: d2, d6, d7, a0-a6
	lea	TCNewRegs,a3
	moveq	#14,d0
.reg:	move.l	(a2)+,d1
	move.l	(a3)+,d2
	cmpi.w	#14-2,d0			; (d0, d1 skipped: PrintChar keeps them; d3-d5 too)
	beq.s	.cmpr
	cmpi.w	#14-6,d0			; (d6 on: compared)
	bhi.s	.skip
.cmpr:	cmp.l	d1,d2
	beq.s	.skip
	addq.l	#1,($3748).w
.skip:	dbra	d0,.reg
	lea	15*4(a7),a7
	movem.l	TCNewRegs,d0-d7/a0-a6
	rts
; TCCopyOut, TCCopyIn - a2: the rows' bytes (from the start's a1) to it, or back from it
TCCopyOut:
	movea.l	36+4(a7),a0			; (the start's a1: past the return address)
	moveq	#1,d3				; both screens - or, text to one screen only (dat_1BBBC
	tst.b	(dat_1BBBC).l			; set), that one only: the other's place is not the rows'
	bpl.s	.scr
	moveq	#0,d3				; the screen, and the first (- $7D00)
.scr:	moveq	#3,d2				; the planes
	movea.l	a0,a1
.pl:	moveq	#7,d1
	movea.l	a1,a3
.row:	move.l	(a3),(a2)+
	lea	40(a3),a3
	dbra	d1,.row
	lea	$1f40(a1),a1
	dbra	d2,.pl
	lea	-$7d00(a0),a0
	dbra	d3,.scr
	rts
TCCopyIn:
	movea.l	36+4(a7),a0
	moveq	#1,d3				; both screens - or, text to one screen only (dat_1BBBC
	tst.b	(dat_1BBBC).l			; set), that one only: the other's place is not the rows'
	bpl.s	.scr
	moveq	#0,d3
.scr:	moveq	#3,d2
	movea.l	a0,a1
.pl:	moveq	#7,d1
	movea.l	a1,a3
.row:	move.l	(a2)+,(a3)
	lea	40(a3),a3
	dbra	d1,.row
	lea	$1f40(a1),a1
	dbra	d2,.pl
	lea	-$7d00(a0),a0
	dbra	d3,.scr
	rts
TC_BYTES	equ	2*4*8*4
TCBefore:	dcb.b	TC_BYTES,0
TCRelease:	dcb.b	TC_BYTES,0
TCNew:		dcb.b	TC_BYTES,0
TCRelRegs:	dcb.l	15,0
TCNewRegs:	dcb.l	15,0
	endc
