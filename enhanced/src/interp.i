;-------------------------------------------------------------------------------
; interp.i - (the enhanced game) the race's physics at a constant rate, the view drawn between.
;
; The release runs the race a step at a time: the controls, CarPhysics, the opponent, then the
; view drawn, then FrameLimiter waits for the 6th vertical blank since the last step. The game
; is simulated a step a frame - so when a frame takes longer than 6 vertical blanks (on an A500,
; most of them), the whole game slows down; and a faster machine cannot show more than 8.33
; pictures a second.
;
; Here (F8 switches back to the release's way; a two-player link race always uses it - the two
; machines exchange their cars a frame at a time):
;
; * The steps are kept to the clock: a step every 6 vertical blanks (InterpVBlanks, counted by
;   VBlankTick), the game's speed as designed. When a picture took too long, the next steps are
;   run at once without pictures until the game has caught up (at most 2 behind; after a pause,
;   the clock is set again).
; * Between steps, pictures of the moments between them: the car's place and angles and the
;   opponent's place blended between the last two steps (InterpPrev, InterpCur), and the view
;   drawn from them. A picture begun t vertical blanks after a step shows the moment t of the
;   step before it (one step behind: the blend needs the step after the moment) - so the
;   pictures are spaced as the time between them, however unevenly they come, and a faster
;   machine shows 2, 3 or more pictures a step, each further along. When a picture takes as long
;   as a step (InterpR, the last picture's time to draw and show: 6 vertical blanks), each shows
;   the latest step instead (InterpLatest, until a picture takes 4 or less), as the release did:
;   on an A500 the pictures come as often as before and are no later.
;
; How a picture is drawn: the view (RaceView) is in two halves - the cars placed (the piece the
; car is on, the camera's place on it, the opponent moved and placed) and the drawing. The
; drawing writes nothing the physics reads (measured with scremu's phasetrack over a race), so
; it can be run any number of times. A step runs only the first half (InterpViewStart keeps a
; copy of the variables as they were before it: InterpPre); after the step its variables are kept
; (InterpPost). A picture: the variables set back to InterpPre, the blended place and angles
; written over them, the whole of RaceView run (the opponent not moved: InterpMoveOpponent),
; and the variables set back to InterpPost - so the physics goes on from exactly where the step
; left it. The variables: the block from dat_1BAF8 to dat_1C280 (1,928 bytes: all the cars-placing
; half writes, with three others), less those the interrupts change meanwhile (the wheels'
; animation, the engine's revs) and the screens' parity (FrameFlip changes it with each picture).
;
; The drawing half is not only drawing: it lowers the car on its chains at the start (DropCar),
; shakes and sways the cockpit, runs the messages' timers, calls Random and sets the text's colours
; the instruments are printed in. So the first picture after a step does that for the step, as the
; release's one drawing a frame did: the variables the drawing keeps (InterpKeepList, measured:
; interp_keep.i) are left as it leaves them, and the text's colours and the random numbers too.
; Any further picture before the next step is drawn from them and leaves nothing changed (all set
; back: InterpPost2) - so the game goes the same way however many pictures a machine draws.
;
; The blending: the car's place (dat_1BCD8, dat_1BCDC, dat_1BCE0: across, height, along: longs)
; and angles (dat_1BCE4, dat_1BCE6, dat_1BCE8: words, the shorter way round), the camera's bob
; (dat_1BD38) and the horizon's pitch (dat_1BC42), the view's rotation (ViewMatrix, each of its
; words - built by CarPhysics from the step before's angles, as in the release), the opponent's
; distance along its piece (OpponentPiecePos, onto the next piece when it has crossed: the piece's
; length kept from the step, InterpMoveOpponent) and its steering (dat_1BB1A).
;-------------------------------------------------------------------------------

HelperInterpOff	equ	$174			; F8: non-zero - the release's timing (helper_c0.s)
INTERP_STEP	equ	6			; vertical blanks a step (FrameLimiter's limit)

InterpVBlanks:	dc.l	0			; vertical blanks (VBlankTick)
InterpStepDue:	dc.l	0			; when the next step is due
InterpDrawStart: dc.l	0			; when this step's view began (InterpLatest: its time to draw)
InterpR:	dc.w	INTERP_STEP		; the last picture's time to draw and show, vertical blanks
InterpLastA6:	dc.w	-1			; the moment (0-6) of this step's last picture
InterpActive:	dc.b	0			; the steps are being run to the clock
InterpRendering: dc.b	0			; a picture is being drawn (RaceView: the opponent not moved)
InterpSkipDraw:	dc.b	0			; RaceView in a step: the cars placed, nothing drawn
InterpLatest:	dc.b	$FF			; the pictures as slow as a step: each the latest step's, drawn
						; by the step itself as in the release (no copies, no blend)
InterpStepDrew:	dc.b	0			; this step drew its view (InterpLatest)
InterpBlendReady: dc.b	0			; this step's variables kept for the blend (InterpPre, InterpPost)
StepParity:	dc.b	0			; $80 every other step (the race loop's end check)
InterpOppLen:	dc.b	0			; the length of the piece the opponent was on before its move
	even

; a step's state to blend (taken as its view starts: InterpViewStart; the opponent's after its
; move: InterpMoveOpponent): offsets
IS_X		equ	0			; dat_1BCD8.l
IS_Y		equ	4			; dat_1BCDC.l
IS_Z		equ	8			; dat_1BCE0.l
IS_A1		equ	12			; dat_1BCE4.w
IS_A2		equ	14			; dat_1BCE6.w
IS_A3		equ	16			; dat_1BCE8.w
IS_BOB		equ	18			; dat_1BD38.w
IS_PITCH	equ	20			; dat_1BC42.w
IS_OPOS		equ	22			; OpponentPiecePos.w
IS_OPIECE	equ	24			; OpponentPiece.b
IS_OSTEER	equ	25			; dat_1BB1A.b
IS_OLEN		equ	26			; InterpOppLen.b
IS_MATRIX	equ	28			; ViewMatrix: 36 words
IS_SIZE		equ	IS_MATRIX+72
InterpPrev:	dcb.b	IS_SIZE,0
InterpCur:	dcb.b	IS_SIZE,0

IB_SIZE		equ	dat_1C280-dat_1BAF8	; the variables' block
	ifne	IB_SIZE&3
	fail	"interp.i: the variables' block is not a number of longs"
	endc
InterpPre:	dcb.b	IB_SIZE+8,0		; before a step's view (and dat_5A54E, dat_63EDE, dat_65EC0.l)
InterpPost:	dcb.b	IB_SIZE+8,0		; after the step
InterpPost2:	dcb.b	IB_SIZE+8,0		; after its first picture
InterpOut:	dcb.b	14,0			; the text's colours, the random numbers: kept over a further picture
InterpKeepBuf:	dcb.b	INTERP_KEEP_BYTES+1,0	; the drawing's own variables (InterpBlockIn)
	even
InterpFirst:	dc.b	0			; the next picture is the step's first
	even

	include	"interp_keep.i"
	even

;-------------------------------------------------------------------------------
; FrameEnd - the race loop's end of a step, in place of its jsr FrameLimiter
;-------------------------------------------------------------------------------
FrameEnd:
	tst.b	(LinkMode).l
	bne.s	.release
	tst.b	(HelperInterpOff).w
	bne.s	.release
	tst.b	InterpActive
	bne.w	InterpFrameEnd
	; starting: this step's view was drawn as before - shown, and the clock started
	jsr	(FrameLimiter).l
	move.b	(dat_1BBC8).l,StepParity
	movem.l	d0-d1/a0-a1,-(a7)
	lea	InterpCur(pc),a1
	bsr.w	InterpTake
	lea	InterpCur(pc),a0
	lea	InterpPrev(pc),a1
	moveq	#IS_SIZE/2-1,d0
.copy:	move.w	(a0)+,(a1)+
	dbra	d0,.copy
	move.l	InterpVBlanks(pc),InterpStepDue
	move.w	#INTERP_STEP,InterpR
	st	InterpLatest
	st	InterpActive
	movem.l	(a7)+,d0-d1/a0-a1
	rts
.release:
	sf	InterpActive
	jsr	(FrameLimiter).l
	move.b	(dat_1BBC8).l,StepParity
	rts

;-------------------------------------------------------------------------------
; InterpFrameEnd - after a step: its state kept, then pictures until the next step is due
;-------------------------------------------------------------------------------
InterpFrameEnd:
	movem.l	d0-d7/a0-a6,-(a7)
	eori.b	#$80,StepParity
	move.w	#-1,InterpLastA6
	tst.b	InterpLatest
	beq.s	.blend
	move.w	#INTERP_STEP,InterpLastA6	; the step drew the latest: no picture until the next
	sf	InterpBlendReady		; (nor any blend this step, were the way to change)
	tst.b	InterpStepDrew
	beq.s	.clock
	sf	InterpStepDrew
	jsr	(FrameFlip).l			; shown
	move.l	InterpVBlanks(pc),d1		; its time: drawing, and until it is shown (+1)
	sub.l	InterpDrawStart(pc),d1
	addq.l	#1,d1
	bsr.w	InterpTime
	bra.s	.clock
.blend:	lea	InterpPost,a1
	bsr.w	InterpBlockOut
	st	InterpFirst
	st	InterpBlendReady
.clock:
	move.l	InterpStepDue(pc),d0		; the next step's time
	addq.l	#INTERP_STEP,d0
	move.l	InterpVBlanks(pc),d1
	sub.l	d0,d1
	cmpi.l	#2*INTERP_STEP,d1		; more than 2 steps behind (a pause, a load): the clock set again
	blt.s	.due
	move.l	InterpVBlanks(pc),d0
.due:	move.l	d0,InterpStepDue
.picture:
	move.l	InterpVBlanks(pc),d1
	move.l	InterpStepDue(pc),d0
	sub.l	d0,d1				; now - due
	bge.s	.done				; the next step is due
	addq.l	#INTERP_STEP,d1		; the time since the step (0-5): the moment of a step before
	tst.b	InterpLatest			; pictures as slow as a step: the step itself, as the release
	beq.s	.a6
	moveq	#INTERP_STEP,d1
.a6:	cmp.w	InterpLastA6(pc),d1		; this moment drawn already: wait for the clock
	beq.s	.picture
	tst.b	InterpLatest			; (just changed to the blend: from the next step)
	bne.s	.ready
	tst.b	InterpBlendReady
	beq.s	.picture
.ready:
	move.w	d1,InterpLastA6
	move.l	InterpVBlanks(pc),d2
	move.w	d1,d7
	bsr.w	InterpRender
	jsr	(FrameFlip).l
	move.l	InterpVBlanks(pc),d1		; its time: drawing, and until it is shown (+1)
	sub.l	d2,d1
	addq.l	#1,d1
	bsr.s	InterpTime
	tst.b	InterpLatest			; (now as slow as a step: no more pictures this step)
	beq.s	.picture
	move.w	#INTERP_STEP,InterpLastA6
	bra.s	.picture
.done:	movem.l	(a7)+,d0-d7/a0-a6
	rts

; InterpTime - d1.l: a picture's time to draw and show: InterpR, and the way to draw the next
; ones - the latest step's (as slow as a step), or the blend (2 or more pictures fit in a step;
; between the two, no change: no switching to and fro)
InterpTime:
	cmpi.l	#INTERP_STEP,d1
	ble.s	.r
	moveq	#INTERP_STEP,d1
.r:	move.w	d1,InterpR
	cmpi.w	#INTERP_STEP,d1
	blt.s	.fast
	st	InterpLatest
.fast:	cmpi.w	#INTERP_STEP-2,d1
	bgt.s	.rts
	sf	InterpLatest
.rts:	rts

;-------------------------------------------------------------------------------
; InterpRender - d7.w = the moment (0: the step before, 6: the last step): its picture drawn
;-------------------------------------------------------------------------------
InterpRender:
	movem.l	d0-d7/a0-a6,-(a7)
	tst.b	InterpFirst
	bne.s	.first
	lea	InterpOut(pc),a1		; a further picture: the text's colours, the random numbers kept
	bsr.w	InterpOutsideOut
.first:	lea	InterpPre,a0			; the variables as the step's view began (but the drawing's own)
	moveq	#1,d6
	bsr.w	InterpBlockIn
	bsr.w	InterpBlend			; the place and angles of the moment
	st	InterpRendering
	moveq	#0,d0				; (the release's view relies on clear upper bytes in its registers:
	moveq	#0,d1				; sub_5FE04 indexes the grid with d1.w, setting only its low byte)
	moveq	#0,d2
	moveq	#0,d3
	moveq	#0,d4
	moveq	#0,d5
	moveq	#0,d6
	moveq	#0,d7
	jsr	(RaceView).l
	sf	InterpRendering
	tst.b	InterpFirst
	beq.s	.further
	sf	InterpFirst			; the first: the step's end, with the drawing's own as it left them
	lea	InterpPost,a0
	moveq	#1,d6
	bsr.w	InterpBlockIn
	lea	InterpPost2,a1			; (for any further pictures)
	bsr.w	InterpBlockOut
	bra.s	.done
.further:
	lea	InterpPost2,a0			; a further one: all as after the first
	moveq	#0,d6
	bsr.w	InterpBlockIn
	lea	InterpOut(pc),a0
	bsr.w	InterpOutsideIn
.done:	movem.l	(a7)+,d0-d7/a0-a6
	rts

; InterpOutsideOut, InterpOutsideIn - a1 / a0: the text's colours and the random numbers
InterpOutsideOut:
	move.l	(TextColourMasks).l,(a1)+
	move.l	(dat_5983A).l,(a1)+
	move.w	(RandomSeed).l,(a1)+
	move.b	(dat_625A4).l,(a1)+
	move.b	(dat_625A5).l,(a1)+
	move.w	(dat_625A6).l,(a1)+
	rts
InterpOutsideIn:
	move.l	(a0)+,(TextColourMasks).l
	move.l	(a0)+,(dat_5983A).l
	move.w	(a0)+,(RandomSeed).l
	move.b	(a0)+,(dat_625A4).l
	move.b	(a0)+,(dat_625A5).l
	move.w	(a0)+,(dat_625A6).l
	rts

;-------------------------------------------------------------------------------
; InterpViewStart - RaceView's start: in a step (the steps run to the clock), its state to
; blend taken; then either the view drawn as in the release (InterpLatest: the latest step
; shown), or the variables kept (InterpPre) and the drawing left to the pictures
; (InterpSkipDraw). All registers kept.
;-------------------------------------------------------------------------------
InterpViewStart:
	sf	InterpSkipDraw
	tst.b	InterpActive
	beq.s	.rts
	tst.b	InterpRendering
	bne.s	.rts
	movem.l	d0/a0-a1,-(a7)
	lea	InterpCur(pc),a0		; the last step's state is now the one before
	lea	InterpPrev(pc),a1
	moveq	#IS_SIZE/2-1,d0
.copy:	move.w	(a0)+,(a1)+
	dbra	d0,.copy
	lea	InterpCur(pc),a1		; this step's: as the view takes it (the cars' placing
	bsr.w	InterpTake			; changes some of it; the opponent's after its move)
	tst.b	InterpLatest
	beq.s	.blend
	move.l	InterpVBlanks(pc),d0		; the latest: drawn by the step as in the release - unless
	sub.l	InterpStepDue(pc),d0		; the next step is already due (catching up: none drawn)
	cmpi.l	#INTERP_STEP,d0
	bge.s	.skip
	st	InterpStepDrew
	move.l	InterpVBlanks(pc),InterpDrawStart
	bra.s	.out
.blend:	lea	InterpPre,a1			; the blend: the variables kept for the pictures
	bsr.s	InterpBlockOut
.skip:	st	InterpSkipDraw
.out:	movem.l	(a7)+,d0/a0-a1
.rts:	rts

;-------------------------------------------------------------------------------
; InterpMoveOpponent - RaceView's MoveOpponent: not in a picture (the opponent's place is the
; blend); in a step, the length of the piece it was on kept (for the blend across pieces)
;-------------------------------------------------------------------------------
InterpNoDraw:					; (RaceView: a step's, nothing drawn)
	rts

;-------------------------------------------------------------------------------
; InterpWaitFlip - RaceView, before its first write to the screen (DrawHorizon): the last flip
; done, so that the screen drawn on is no longer the one shown. The release relied on its
; FrameLimiter's wait and on the geometry coming first; the pictures between steps come sooner.
; All registers kept
;-------------------------------------------------------------------------------
InterpWaitFlip:
	tst.b	(FlipPending).l
	bne.s	InterpWaitFlip
	rts

InterpMoveOpponent:
	tst.b	InterpRendering
	bne.s	.rts
	jsr	(MoveOpponent).l
	move.b	(dat_1BB6A).l,InterpOppLen	; (MoveOpponent loaded its piece: its length)
	tst.b	InterpSkipDraw
	beq.s	.rts
	move.l	a1,-(a7)			; a step's: the opponent where it has moved to
	lea	InterpCur(pc),a1
	move.w	(OpponentPiecePos).l,IS_OPOS(a1)
	move.b	(OpponentPiece).l,IS_OPIECE(a1)
	move.b	(dat_1BB1A).l,IS_OSTEER(a1)
	move.b	InterpOppLen(pc),IS_OLEN(a1)
	movea.l	(a7)+,a1
.rts:	rts

;-------------------------------------------------------------------------------
; InterpBlockOut - a1: the variables copied to it. d0, a0-a1 used
;-------------------------------------------------------------------------------
InterpBlockOut:
	lea	(dat_1BAF8).l,a0
	move.w	#IB_SIZE/4-1,d0
.copy:	move.l	(a0)+,(a1)+
	dbra	d0,.copy
	move.w	(dat_5A54E).l,(a1)+
	move.w	(dat_63EDE).l,(a1)+
	move.l	(dat_65EC0).l,(a1)+
	rts

;-------------------------------------------------------------------------------
; InterpBlockIn - a0: the variables copied back from it, but for those the interrupts and the
; screens' flips change (kept as they are) and, with d6.b non-zero, the drawing's own
; (InterpKeepList: kept as they are). The interrupts off meanwhile. d0-d4, a0-a3 used
;-------------------------------------------------------------------------------
InterpBlockIn:
	move.w	sr,-(a7)
	ori.w	#$0700,sr
	tst.b	d6
	beq.s	.nokeep
	lea	InterpKeepBuf,a2		; the drawing's own put aside
	lea	InterpKeepList(pc),a3
.k1:	move.w	(a3)+,d0
	bmi.s	.nokeep
	move.w	(a3)+,d1
	lea	(dat_1BAF8).l,a1
	adda.w	d0,a1
	subq.w	#1,d1
.k2:	move.b	(a1)+,(a2)+
	dbra	d1,.k2
	bra.s	.k1
.nokeep:
	move.b	(dat_1BBE3).l,d1		; the wheels' animation (VBlankTick: sub_651B8)
	move.b	(dat_1BBDB).l,d2
	move.w	(dat_1BC34).l,d3		; the engine's revs (VBlankTick)
	move.b	(dat_1BBC8).l,d4		; the screens' parity (FrameFlip)
	swap	d4
	move.b	(dat_1BCC8).l,d4
	lea	(dat_1BAF8).l,a1
	move.w	#IB_SIZE/4-1,d0
.copy:	move.l	(a0)+,(a1)+
	dbra	d0,.copy
	move.w	(a0)+,(dat_5A54E).l
	move.w	(a0)+,(dat_63EDE).l
	move.l	(a0)+,(dat_65EC0).l
	move.b	d1,(dat_1BBE3).l
	move.b	d2,(dat_1BBDB).l
	move.w	d3,(dat_1BC34).l
	move.b	d4,(dat_1BCC8).l
	swap	d4
	move.b	d4,(dat_1BBC8).l
	tst.b	d6
	beq.s	.done
	lea	InterpKeepBuf,a2		; and put back
	lea	InterpKeepList(pc),a3
.k3:	move.w	(a3)+,d0
	bmi.s	.done
	move.w	(a3)+,d1
	lea	(dat_1BAF8).l,a1
	adda.w	d0,a1
	subq.w	#1,d1
.k4:	move.b	(a2)+,(a1)+
	dbra	d1,.k4
	bra.s	.k3
.done:	move.w	(a7)+,sr
	rts

;-------------------------------------------------------------------------------
; InterpTake - a1: the step's state to blend, from the variables. d0, a0-a1 used
;-------------------------------------------------------------------------------
InterpTake:
	move.l	(dat_1BCD8).l,IS_X(a1)
	move.l	(dat_1BCDC).l,IS_Y(a1)
	move.l	(dat_1BCE0).l,IS_Z(a1)
	move.w	(dat_1BCE4).l,IS_A1(a1)
	move.w	(dat_1BCE6).l,IS_A2(a1)
	move.w	(dat_1BCE8).l,IS_A3(a1)
	move.w	(dat_1BD38).l,IS_BOB(a1)
	move.w	(dat_1BC42).l,IS_PITCH(a1)
	move.w	(OpponentPiecePos).l,IS_OPOS(a1)
	move.b	(OpponentPiece).l,IS_OPIECE(a1)
	move.b	(dat_1BB1A).l,IS_OSTEER(a1)
	move.b	InterpOppLen(pc),IS_OLEN(a1)
	lea	(ViewMatrix).l,a0
	lea	IS_MATRIX(a1),a1
	moveq	#36-1,d0
.m:	move.w	(a0)+,(a1)+
	dbra	d0,.m
	rts

;-------------------------------------------------------------------------------
; InterpBlend - d7.w = the moment (0-6): the variables set to the blend of InterpPrev and
; InterpCur. d0-d6, a0-a2 used
;-------------------------------------------------------------------------------
InterpBlend:
	lea	InterpPrev(pc),a0
	lea	InterpCur(pc),a1
	; the place: longs, p + (c - p) * a / 6
	move.l	IS_X(a0),d0
	move.l	IS_X(a1),d1
	bsr.w	InterpLong
	move.l	d0,(dat_1BCD8).l
	move.l	IS_Y(a0),d0
	move.l	IS_Y(a1),d1
	bsr.w	InterpLong
	move.l	d0,(dat_1BCDC).l
	move.l	IS_Z(a0),d0
	move.l	IS_Z(a1),d1
	bsr.w	InterpLong
	move.l	d0,(dat_1BCE0).l
	; the angles: the shorter way round
	move.w	IS_A1(a0),d0
	move.w	IS_A1(a1),d1
	bsr.w	InterpAngle
	move.w	d0,(dat_1BCE4).l
	move.w	IS_A2(a0),d0
	move.w	IS_A2(a1),d1
	bsr.w	InterpAngle
	move.w	d0,(dat_1BCE6).l
	move.w	IS_A3(a0),d0
	move.w	IS_A3(a1),d1
	bsr.w	InterpAngle
	move.w	d0,(dat_1BCE8).l
	move.w	IS_BOB(a0),d0
	move.w	IS_BOB(a1),d1
	bsr.w	InterpWord
	move.w	d0,(dat_1BD38).l
	move.w	IS_PITCH(a0),d0
	move.w	IS_PITCH(a1),d1
	bsr.w	InterpWord
	move.w	d0,(dat_1BC42).l
	; the view's rotation, word by word
	lea	IS_MATRIX(a0),a2
	movem.l	a0-a1,-(a7)
	lea	IS_MATRIX(a1),a1
	lea	(ViewMatrix).l,a0
	moveq	#36-1,d6
.m:	move.w	(a2)+,d0
	move.w	(a1)+,d1
	bsr.w	InterpWord
	move.w	d0,(a0)+
	dbra	d6,.m
	movem.l	(a7)+,a0-a1
	; the opponent's steering
	move.b	IS_OSTEER(a0),d0
	ext.w	d0
	move.b	IS_OSTEER(a1),d1
	ext.w	d1
	bsr.w	InterpWord
	move.b	d0,(dat_1BB1A).l
	; the opponent's place: along its piece, or onto the next
	moveq	#0,d0
	move.w	IS_OPOS(a0),d0			; before
	moveq	#0,d1
	move.w	IS_OPOS(a1),d1			; after
	move.b	IS_OPIECE(a1),d2
	cmp.b	IS_OPIECE(a0),d2
	beq.s	.same
	move.b	IS_OPIECE(a0),d3		; crossed onto the next piece (or round to the first)?
	addq.b	#1,d3
	cmp.b	d3,d2
	beq.s	.next
	tst.b	d2
	bne.s	.after				; (not one piece on: the step's)
.next:	moveq	#0,d3
	move.b	IS_OLEN(a1),d3			; the length of the piece it was on
	lsl.w	#8,d3
	add.l	d3,d1				; "after" as along the piece before
	bsr.s	InterpULong
	cmp.l	d3,d0
	blo.s	.before
	sub.l	d3,d0				; on the next piece
	move.w	d0,(OpponentPiecePos).l
	move.b	IS_OPIECE(a1),(OpponentPiece).l
	rts
.before:
	move.w	d0,(OpponentPiecePos).l
	move.b	IS_OPIECE(a0),(OpponentPiece).l
	rts
.same:	bsr.s	InterpULong
	move.w	d0,(OpponentPiecePos).l
	rts
.after:	move.w	d1,(OpponentPiecePos).l
	rts

; InterpULong - d0.l, d1.l (positive, less than $20000 apart): d0 + (d1 - d0) * d7 / 6. d1 kept
InterpULong:
	move.l	d1,d4
	sub.l	d0,d4				; (positive: the opponent goes forwards)
	bmi.s	.back
	cmpi.l	#$10000,d4			; (a jump: the step's)
	bcc.s	.back
	mulu	d7,d4
	divu	#INTERP_STEP,d4
	ext.l	d4
	add.l	d4,d0
	rts
.back:	move.l	d1,d0				; (backwards: the step's)
	rts

; InterpWord - d0.w, d1.w (signed): (d0 * (6 - d7) + d1 * d7) / 6 in d0.w
InterpWord:
	moveq	#INTERP_STEP,d5
	sub.w	d7,d5
	muls	d5,d0
	muls	d7,d1
	add.l	d1,d0
	divs	#INTERP_STEP,d0
	rts

; InterpAngle - d0.w, d1.w (angles: a turn is $10000): d0 + (d1 - d0) * d7 / 6, the shorter way
InterpAngle:
	sub.w	d0,d1				; (a signed word: the shorter way round)
	muls	d7,d1
	divs	#INTERP_STEP,d1
	add.w	d1,d0
	rts

; InterpLong - d0.l, d1.l: d0 + (d1 - d0) * d7 / 6 in d0.l (the difference less than 2^28).
; d1, d3-d6 used
InterpLong:
	sub.l	d0,d1				; the difference
	move.l	d1,d4
	bpl.s	.pos
	neg.l	d4
.pos:	move.l	d4,d5				; |difference| / 6, in two divu
	clr.w	d5
	swap	d5				; its high word
	divu	#INTERP_STEP,d5			; remainder:quotient
	move.w	d5,d3
	swap	d3				; the quotient's high word
	move.w	d4,d5				; the remainder above the low word
	divu	#INTERP_STEP,d5
	move.w	d5,d3				; d3 = |difference| / 6
	clr.w	d5
	swap	d5				; and its remainder (0-5)
	moveq	#0,d4				; quotient * moment
	move.w	d7,d6
	bra.s	.mul
.add:	add.l	d3,d4
.mul:	dbra	d6,.add
	mulu	d7,d5				; + remainder * moment / 6
	divu	#INTERP_STEP,d5
	and.l	#$FFFF,d5
	add.l	d5,d4
	tst.l	d1
	bpl.s	.sum
	neg.l	d4
.sum:	add.l	d4,d0
	rts
