;-------------------------------------------------------------------------------
; plotpixel.i - SetPolygonColour and PlotPixel without self-modifying code (the enhanced game).
; In the space of the unused CopylockRoutine (scr_game.s), so that the game does not grow: its
; screens follow the code, and the work areas follow the screens with little room between.
;-------------------------------------------------------------------------------

;-------------------------------------------------------------------------------
; SetPolygonColour - d0: a colour - PlotPixel set to draw in it: its two routines (PlotPixelTable)
; put in PlotPixelOddRoutine and PlotPixelEvenRoutine. (The original rewrote PlotPixel's 8 bset
; instructions into bclr and back: self-modifying code, which the 68020's and later processors'
; instruction caches do not see. d0 is left shifted right by 4, as the original left it.)
;-------------------------------------------------------------------------------
SetPolygonColour:
	movem.l	d1/a1,-(a7)
	moveq	#$f,d1
	and.b	d0,d1
	lsl.w	#3,d1
	move.w	d1,(PlotColour8).l		; (DrawEdgeLine: its runs through PlotWord<colour>)
	lea	(PlotPixelTable).l,a1
	move.l	(a1,d1.w),(PlotPixelOddRoutine).l
	move.l	4(a1,d1.w),(PlotPixelEvenRoutine).l
	movem.l	(a7)+,d1/a1
	lsr.b	#4,d0
	rts

PlotColour8:				; the colour * 8 (SetPolygonColour)
	dc.w	0
PlotPixelOddRoutine:			; PlotPixel's routine for a pixel in the word's second byte (SetPolygonColour)
	dc.l	PlotPixelOdd15
PlotPixelEvenRoutine:			; ... and in its first byte
	dc.l	PlotPixelEven15

;-------------------------------------------------------------------------------
; PlotPixel - a0, d4: a pixel set to the colour SetPolygonColour chose, in the 4 planes (through
; PlotPixelOddRoutine or PlotPixelEvenRoutine: d0 the bit). Uses d0 only.
;-------------------------------------------------------------------------------
PlotPixel:
	move.b	d4,d0
	andi.w	#$f,d0
	eori.w	#$f,d0
	cmpi.w	#$8,d0
	bge.s	.even
	move.l	(PlotPixelOddRoutine).l,-(a7)
	rts
.even:	andi.w	#$7,d0
	move.l	(PlotPixelEvenRoutine).l,-(a7)
	rts

; the 32 routines: a pixel (bit d0) set or cleared in each plane by the colour's bits
PlotPixelOdd0:
	bclr	d0,$1(a0)
	bclr	d0,$1f41(a0)
	bclr	d0,$3e81(a0)
	bclr	d0,$5dc1(a0)
	rts
PlotPixelOdd1:
	bset	d0,$1(a0)
	bclr	d0,$1f41(a0)
	bclr	d0,$3e81(a0)
	bclr	d0,$5dc1(a0)
	rts
PlotPixelOdd2:
	bclr	d0,$1(a0)
	bset	d0,$1f41(a0)
	bclr	d0,$3e81(a0)
	bclr	d0,$5dc1(a0)
	rts
PlotPixelOdd3:
	bset	d0,$1(a0)
	bset	d0,$1f41(a0)
	bclr	d0,$3e81(a0)
	bclr	d0,$5dc1(a0)
	rts
PlotPixelOdd4:
	bclr	d0,$1(a0)
	bclr	d0,$1f41(a0)
	bset	d0,$3e81(a0)
	bclr	d0,$5dc1(a0)
	rts
PlotPixelOdd5:
	bset	d0,$1(a0)
	bclr	d0,$1f41(a0)
	bset	d0,$3e81(a0)
	bclr	d0,$5dc1(a0)
	rts
PlotPixelOdd6:
	bclr	d0,$1(a0)
	bset	d0,$1f41(a0)
	bset	d0,$3e81(a0)
	bclr	d0,$5dc1(a0)
	rts
PlotPixelOdd7:
	bset	d0,$1(a0)
	bset	d0,$1f41(a0)
	bset	d0,$3e81(a0)
	bclr	d0,$5dc1(a0)
	rts
PlotPixelOdd8:
	bclr	d0,$1(a0)
	bclr	d0,$1f41(a0)
	bclr	d0,$3e81(a0)
	bset	d0,$5dc1(a0)
	rts
PlotPixelOdd9:
	bset	d0,$1(a0)
	bclr	d0,$1f41(a0)
	bclr	d0,$3e81(a0)
	bset	d0,$5dc1(a0)
	rts
PlotPixelOdd10:
	bclr	d0,$1(a0)
	bset	d0,$1f41(a0)
	bclr	d0,$3e81(a0)
	bset	d0,$5dc1(a0)
	rts
PlotPixelOdd11:
	bset	d0,$1(a0)
	bset	d0,$1f41(a0)
	bclr	d0,$3e81(a0)
	bset	d0,$5dc1(a0)
	rts
PlotPixelOdd12:
	bclr	d0,$1(a0)
	bclr	d0,$1f41(a0)
	bset	d0,$3e81(a0)
	bset	d0,$5dc1(a0)
	rts
PlotPixelOdd13:
	bset	d0,$1(a0)
	bclr	d0,$1f41(a0)
	bset	d0,$3e81(a0)
	bset	d0,$5dc1(a0)
	rts
PlotPixelOdd14:
	bclr	d0,$1(a0)
	bset	d0,$1f41(a0)
	bset	d0,$3e81(a0)
	bset	d0,$5dc1(a0)
	rts
PlotPixelOdd15:
	bset	d0,$1(a0)
	bset	d0,$1f41(a0)
	bset	d0,$3e81(a0)
	bset	d0,$5dc1(a0)
	rts
PlotPixelEven0:
	bclr	d0,(a0)
	bclr	d0,$1f40(a0)
	bclr	d0,$3e80(a0)
	bclr	d0,$5dc0(a0)
	rts
PlotPixelEven1:
	bset	d0,(a0)
	bclr	d0,$1f40(a0)
	bclr	d0,$3e80(a0)
	bclr	d0,$5dc0(a0)
	rts
PlotPixelEven2:
	bclr	d0,(a0)
	bset	d0,$1f40(a0)
	bclr	d0,$3e80(a0)
	bclr	d0,$5dc0(a0)
	rts
PlotPixelEven3:
	bset	d0,(a0)
	bset	d0,$1f40(a0)
	bclr	d0,$3e80(a0)
	bclr	d0,$5dc0(a0)
	rts
PlotPixelEven4:
	bclr	d0,(a0)
	bclr	d0,$1f40(a0)
	bset	d0,$3e80(a0)
	bclr	d0,$5dc0(a0)
	rts
PlotPixelEven5:
	bset	d0,(a0)
	bclr	d0,$1f40(a0)
	bset	d0,$3e80(a0)
	bclr	d0,$5dc0(a0)
	rts
PlotPixelEven6:
	bclr	d0,(a0)
	bset	d0,$1f40(a0)
	bset	d0,$3e80(a0)
	bclr	d0,$5dc0(a0)
	rts
PlotPixelEven7:
	bset	d0,(a0)
	bset	d0,$1f40(a0)
	bset	d0,$3e80(a0)
	bclr	d0,$5dc0(a0)
	rts
PlotPixelEven8:
	bclr	d0,(a0)
	bclr	d0,$1f40(a0)
	bclr	d0,$3e80(a0)
	bset	d0,$5dc0(a0)
	rts
PlotPixelEven9:
	bset	d0,(a0)
	bclr	d0,$1f40(a0)
	bclr	d0,$3e80(a0)
	bset	d0,$5dc0(a0)
	rts
PlotPixelEven10:
	bclr	d0,(a0)
	bset	d0,$1f40(a0)
	bclr	d0,$3e80(a0)
	bset	d0,$5dc0(a0)
	rts
PlotPixelEven11:
	bset	d0,(a0)
	bset	d0,$1f40(a0)
	bclr	d0,$3e80(a0)
	bset	d0,$5dc0(a0)
	rts
PlotPixelEven12:
	bclr	d0,(a0)
	bclr	d0,$1f40(a0)
	bset	d0,$3e80(a0)
	bset	d0,$5dc0(a0)
	rts
PlotPixelEven13:
	bset	d0,(a0)
	bclr	d0,$1f40(a0)
	bset	d0,$3e80(a0)
	bset	d0,$5dc0(a0)
	rts
PlotPixelEven14:
	bclr	d0,(a0)
	bset	d0,$1f40(a0)
	bset	d0,$3e80(a0)
	bset	d0,$5dc0(a0)
	rts
PlotPixelEven15:
	bset	d0,(a0)
	bset	d0,$1f40(a0)
	bset	d0,$3e80(a0)
	bset	d0,$5dc0(a0)
	rts

PlotPixelTable:				; for each colour: its PlotPixelOdd and PlotPixelEven routines
	dc.l	PlotPixelOdd0,PlotPixelEven0
	dc.l	PlotPixelOdd1,PlotPixelEven1
	dc.l	PlotPixelOdd2,PlotPixelEven2
	dc.l	PlotPixelOdd3,PlotPixelEven3
	dc.l	PlotPixelOdd4,PlotPixelEven4
	dc.l	PlotPixelOdd5,PlotPixelEven5
	dc.l	PlotPixelOdd6,PlotPixelEven6
	dc.l	PlotPixelOdd7,PlotPixelEven7
	dc.l	PlotPixelOdd8,PlotPixelEven8
	dc.l	PlotPixelOdd9,PlotPixelEven9
	dc.l	PlotPixelOdd10,PlotPixelEven10
	dc.l	PlotPixelOdd11,PlotPixelEven11
	dc.l	PlotPixelOdd12,PlotPixelEven12
	dc.l	PlotPixelOdd13,PlotPixelEven13
	dc.l	PlotPixelOdd14,PlotPixelEven14
	dc.l	PlotPixelOdd15,PlotPixelEven15
