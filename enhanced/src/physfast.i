;-------------------------------------------------------------------------------
; physfast.i - (the enhanced game) the physics' work made cheaper, exactly: the race goes as
; before to the byte (tools/test_physics.py: every race variable at every vertical blank of a
; driven race on each of the 8 tracks, against the game before this change). Measured in such a
; race at an A500's speed (cycles a step): CarPhysics 31,100 -> 27,350, MoveOpponent 6,100 ->
; 5,400, PlaceOpponentOnTrack 11,000 -> 10,100, LoadPiece 8,200 -> 4,900 (all its callers): the
; step's work about 1% less (862,600 -> 854,400).
;
; 1. LoadPiece from a table. LoadPiece makes a piece current: 20 of its numbers copied from the
; track's tables (its profiles, base heights, flags) and its shape's data (Data6502) into
; variables, about 930 cycles - and the race calls it about 9 times a step (the physics, the
; opponent, the view), mostly for the same two or three pieces. What it writes depends only on
; the piece and those tables, which BuildTrack writes once before the race (the draw bridge
; rewrites only the height data the profiles point to, which LoadPiece does not read; nothing
; else writes them but HallOfFame). So after BuildTrack each piece of the track is loaded once by
; the release's routine (LoadPieceRelease: BuildTrackTable) and what it left kept in a record
; (LoadPieceTable: the 20 variables and the registers it returns), and LoadPiece then copies the
; piece's record: about 550 cycles. The registers are left as the release leaves them - d0 (the
; shape's address, its low byte AcrossOtherWay), d1 (unchanged), d2 and d3 (their low bytes; the
; rest kept), a0 (the shape's data), a1 (TrackPieceFlags), a2 (Data6502) - and the flags (the same
; last addq). A piece beyond the table, or a call while it is not valid (from BuildTrack's start
; until the table is built, and after HallOfFame, which borrows the tables' memory, until the next
; BuildTrack), is loaded the release's way. Checked call by call too: assembled with PHYS_CHECK
; (tools/test_physfast.py), each call is loaded both ways from the same state and the 20 variables
; and the registers compared ($3770 counts the calls compared, $3774 those that differ).
;
; 2. The physics' variables through a6. The physics addresses its variables as absolute longs:
; 4 cycles more an access than a base register's 16-bit offset. CarPhysics, MoveOpponent and
; PlaceOpponentOnTrack keep a6 (movem: the flags left as they were) and set it to PHYS_BASE, and
; the code only they reach - 2,245 lines, worked out from the code's flow (from every entry
; outside them, calls followed, nothing outside reaches it: not Sin and Cos, which BuildViewMatrix
; also calls from outside; and none of it uses a6) - addresses the race's variables and the
; tables after them as offsets from a6: 663 operands, and 25 movea.l #address which became lea
; (the same address). PlaceOpponentOnTrack puts a6 back before it runs on into
; OpponentPieceDistance, which is called on its own too. The same values, the same flags: only
; the time differs.
;
; 3. MatrixTimes inlined at its 12 calls (ForceToWorld, TorqueToWorld, VelocityToCarAxes,
; GravityInCarAxes; 20 a step): its seven instructions in place of the jsr and rts.
;
; Looked at, not done: Sin and Cos (10 calls a step, about 280 cycles each): a table of their
; results would take 32K, and they leave d3, d4, d6 and the X flag depending on the angle, which
; a cheaper way would have to give too. ReadPiecePoints (31 calls a step, most of them the view's):
; its pointer worked out once with LoadPiece would be a copy of PieceDataPointer, which interp.i
; sets back with the race's variables - so it would not stay exact.
;-------------------------------------------------------------------------------
PHYS_BASE	equ	RaceSettings+$4000	; a6 in the physics (CarPhysics, MoveOpponent,
						; PlaceOpponentOnTrack): the race's variables and the
						; tables after them within its 16-bit reach
LP_SIZE		equ	32			; a record:
LP_BASES	equ	0			; .l PieceBaseA, PieceBaseB
LP_TDP		equ	4			; .w TrackDataPointer
LP_TDS		equ	6			; .w TrackDataStart
LP_PDP		equ	8			; .w PieceDataPointer
LP_A0		equ	10			; .l a0: the shape's data
LP_BYTES	equ	14			; 15 bytes: the byte variables (in LoadPieceBytes' order)
LP_D2		equ	29			; d2's low byte before the last addq
LP_D3		equ	30			; d3's low byte
LP_PIECES	equ	100			; the track's tables' size

LoadPieceCount:	dc.w	0			; the pieces in the table (0: not valid)

;-------------------------------------------------------------------------------
; LoadPiece - d1: a piece made current (as LoadPieceRelease): its record copied
;-------------------------------------------------------------------------------
LoadPiece:
	cmp.w	(LoadPieceCount).l,d1		; in the table? (d1's word, as the release
	bcs.s	.table				; indexes by it)
	jmp	(LoadPieceRelease).l
.table:
	ifd	PHYS_CHECK
	bra.w	LoadPieceCheck
LoadPieceNow:
	endc
	move.w	d1,d0
	lsl.w	#5,d0				; x LP_SIZE
	lea	(LoadPieceTable).l,a0
	adda.w	d0,a0
	move.l	(a0)+,(PieceBaseA).l		; PieceBaseA and PieceBaseB are next to each other
	move.w	(a0)+,(TrackDataPointer).l
	move.w	(a0)+,(TrackDataStart).l
	move.w	(a0)+,(PieceDataPointer).l
	move.l	(a0)+,d0			; the shape's data
	move.b	(a0)+,(PieceProfileA).l
	move.b	(a0)+,(SideSwap).l
	move.b	(a0)+,(PieceHeading).l
	move.b	(a0)+,(PieceReversed).l
	move.b	(a0)+,(PieceShape).l
	move.b	(a0)+,(PieceDirection).l
	move.b	(a0)+,(PiecePointCount).l
	move.b	(a0)+,(PiecePointBytes).l
	move.b	(a0)+,(PieceLastPair).l
	move.b	(a0)+,(PieceLastPairBytes).l
	move.b	(a0)+,(PieceSections).l
	move.b	(a0)+,(AcrossOtherWay).l
	move.b	(a0)+,(ShapeAcrossScale).l
	move.b	(a0)+,(ShapeAlongScale).l
	move.b	(a0)+,(ShapeSteer).l
	move.b	(a0)+,d2
	move.b	(a0)+,d3
	movea.l	d0,a0				; a0: the shape's data; d0: it, its low byte
	move.b	(AcrossOtherWay).l,d0		; AcrossOtherWay's (the release's last into d0)
	lea	(TrackPieceFlags).l,a1
	lea	(Data6502).l,a2
	addq.b	#1,d2				; the release's last instruction: its flags
	rts

;-------------------------------------------------------------------------------
; BuildTrackTable - (TrackPreview, in place of BuildTrack) BuildTrack, then BuildPieceTable. Not
; a jump at BuildTrack's own end: BuildTrack reads a table of 4 bytes just after its last rts
; through a label in its code (l_5B2B8 + d2), so its bytes there must not move
;-------------------------------------------------------------------------------
BuildTrackTable:
	jsr	(BuildTrack).l

;-------------------------------------------------------------------------------
; BuildPieceTable - after BuildTrack: each of the track's pieces loaded the release's way
; and kept (LoadPieceTable); the registers, the flags and LoadPiece's variables left as BuildTrack
; left them
;-------------------------------------------------------------------------------
BuildPieceTable:
	movem.l	d0-d7/a0-a6,-(a7)
	lea	(LoadPieceKept).l,a3		; LoadPiece's variables as BuildTrack left them
	bsr.w	KeepPieceVars
	moveq	#0,d1
	move.b	(TrackPieceCount).l,d1
	cmpi.w	#LP_PIECES,d1
	bls.s	.count
	move.w	#LP_PIECES,d1
.count:	move.w	d1,d7				; the pieces
	lea	(LoadPieceTable).l,a4
	moveq	#0,d6
.piece:	cmp.w	d7,d6
	bcc.s	.done
	move.w	d6,d1
	moveq	#0,d2				; d2, d3: their low bytes are what is kept
	moveq	#0,d3
	jsr	(LoadPieceRelease).l
	move.l	a0,LP_A0(a4)
	subq.b	#1,d2				; d2 before the last addq
	move.b	d2,LP_D2(a4)
	move.b	d3,LP_D3(a4)
	movea.l	a4,a3
	bsr.w	KeepPieceVars
	lea	LP_SIZE(a4),a4
	addq.w	#1,d6
	bra.s	.piece
.done:	lea	(LoadPieceKept).l,a3		; the variables put back
	bsr.w	PutPieceVars
	move.w	d7,(LoadPieceCount).l		; the table valid
	movem.l	(a7)+,d0-d7/a0-a6
	move.w	#$04,ccr			; BuildTrack's flags at its end: its last subq.b #1
	rts					; reached 0 (Z; X, N, V, C clear)

; KeepPieceVars - a3: a record - LoadPiece's variables kept in it (not a0, d2, d3)
; PutPieceVars - a3: a record - the variables set from it
KeepPieceVars:
	move.l	(PieceBaseA).l,LP_BASES(a3)
	move.w	(TrackDataPointer).l,LP_TDP(a3)
	move.w	(TrackDataStart).l,LP_TDS(a3)
	move.w	(PieceDataPointer).l,LP_PDP(a3)
	lea	(LoadPieceBytes).l,a5
	lea	LP_BYTES(a3),a6
	moveq	#15-1,d5
.b:	movea.l	(a5)+,a2
	move.b	(a2),(a6)+
	dbra	d5,.b
	rts
PutPieceVars:
	move.l	LP_BASES(a3),(PieceBaseA).l
	move.w	LP_TDP(a3),(TrackDataPointer).l
	move.w	LP_TDS(a3),(TrackDataStart).l
	move.w	LP_PDP(a3),(PieceDataPointer).l
	lea	(LoadPieceBytes).l,a5
	lea	LP_BYTES(a3),a6
	moveq	#15-1,d5
.b:	movea.l	(a5)+,a2
	move.b	(a6)+,(a2)
	dbra	d5,.b
	rts
LoadPieceBytes:					; the byte variables, in a record's order
	dc.l	PieceProfileA,SideSwap,PieceHeading,PieceReversed,PieceShape,PieceDirection
	dc.l	PiecePointCount,PiecePointBytes,PieceLastPair,PieceLastPairBytes,PieceSections
	dc.l	AcrossOtherWay,ShapeAcrossScale,ShapeAlongScale,ShapeSteer

	ifd	PHYS_CHECK
;-------------------------------------------------------------------------------
; LoadPieceCheck - (PHYS_CHECK) the piece loaded the release's way and the table's way from the
; same state, and the variables and the registers (d0-d7/a0-a6) compared; the table's results
; kept. The flags need no comparing: both ways end with the same addq.b #1,d2, so the same d2
; gives the same flags. $3770: the calls compared, $3774: those that differ
;-------------------------------------------------------------------------------
LoadPieceCheck:
	movem.l	d0-d7/a0-a6,LPCheckIn
	addq.l	#1,($3770).w
	lea	(LPCheckRec).l,a3		; the variables before
	bsr.w	KeepPieceVars
	movem.l	LPCheckIn,d0-d7/a0-a6
	jsr	(LoadPieceRelease).l		; the release's way
	movem.l	d0-d7/a0-a6,LPCheckOutA
	lea	(LPCheckRecA).l,a3
	bsr.w	KeepPieceVars
	lea	(LPCheckRec).l,a3		; the variables put back
	bsr.w	PutPieceVars
	movem.l	LPCheckIn,d0-d7/a0-a6
	jsr	(LoadPieceNow).l		; the table's way
	movem.l	d0-d7/a0-a6,LPCheckOutB
	lea	(LPCheckRecB).l,a3
	bsr.w	KeepPieceVars
	lea	(LPCheckRecA+LP_BASES).l,a0	; the variables (a record's, less a0 and d2/d3)
	lea	(LPCheckRecB+LP_BASES).l,a1
	moveq	#LP_A0-1,d0
.v1:	cmpm.b	(a0)+,(a1)+
	bne.s	.bad
	dbra	d0,.v1
	lea	(LPCheckRecA+LP_BYTES).l,a0
	lea	(LPCheckRecB+LP_BYTES).l,a1
	moveq	#15-1,d0
.v2:	cmpm.b	(a0)+,(a1)+
	bne.s	.bad
	dbra	d0,.v2
	lea	LPCheckOutA,a0			; the registers
	lea	LPCheckOutB,a1
	moveq	#15-1,d0
.r:	cmpm.l	(a0)+,(a1)+
	bne.s	.bad
	dbra	d0,.r
	bra.s	.done
.bad:	addq.l	#1,($3774).w
.done:	movem.l	LPCheckOutB,d0-d7/a0-a6		; the table's results
	subq.b	#1,d2				; and its flags: its last addq again
	addq.b	#1,d2
	rts

LPCheckIn:	dcb.l	15,0
LPCheckOutA:	dcb.l	15,0
LPCheckOutB:	dcb.l	15,0
LPCheckRec:	dcb.b	LP_SIZE,0
LPCheckRecA:	dcb.b	LP_SIZE,0
LPCheckRecB:	dcb.b	LP_SIZE,0
	endc

	even
LoadPieceKept:	dcb.b	LP_SIZE,0
LoadPieceTable:	dcb.b	LP_SIZE*LP_PIECES,0
