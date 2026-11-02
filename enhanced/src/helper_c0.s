;-------------------------------------------------------------------------------
; helper_c0.s - the helper block the game calls, at $C0 ($9E bytes): the "Turbo" release's
; (original/scr_boot.s HelperBlock, original/bin/lowmem_c0.bin), loaded by the bootblock as file 2.
;
;   $C0  Helper_Wait  wait while (a2) is not zero (FrameLimiter: Countdown1) - unless the turbo is on
;   $D6  Helper_AGA1  a0 = its low 24 bits, + 2
;   $E8  Helper_AGA2  d0.w = $FFFF, a0 = its low 24 bits
;   $FC  Helper_Keys  the keyboard interrupt's hook, d0 the raw key byte: decoded; F1 the audio
;                     filter, F2 PAL / NTSC (BEAMCON0), F3 the turbo, F6 the cockpit (the enhanced
;                     game: CockpitOff, which the game tests), F7 a calibration run (the
;                     telemetry build: calibrate.i), F8 the race's steps to the clock with the
;                     view drawn between them, or the release's timing (interp.i), F9 the view
;                     at half its height (halfres.i)
;   $15C the flags (the release's; the enhanced game's at $170, its code having grown): F2's (NTSC
;        on), F3's (the turbo on), F6's (the cockpit off: $172), F7's ($173), F8's ($174: the
;        release's timing), F9's ($175: half height)
;
; The release's F3 rewrote the wait's bne at $C2 into a NOP and back: self-modifying code, which
; the instruction caches of the 68020 and later do not see (the change would not be noticed until
; the cache dropped the old instruction). Here the wait tests F3's flag instead. With ORIGINAL
; defined it assembles to the release's bytes (tools/build_disk.py checks it).
;-------------------------------------------------------------------------------

	org	$C0

Helper_Wait:
	ifd	ORIGINAL
.wait:	tst.b	(a2)
	bne.s	.wait				; F3 makes this a NOP ($4E71) and back ($66FC)
	rts
	dc.b	'<Galahad> '			; the cracker's mark
	nop
	nop
	nop
	else
	tst.b	(TurboOn).w			; the turbo: no wait
	bne.s	.done
.wait:	tst.b	(a2)
	bne.s	.wait
.done:	rts
	dc.b	'<Galahad> '			; the cracker's mark
	endc

Helper_AGA1:					; $D6
	move.l	d0,-(a7)
	move.l	a0,d0
	and.l	#$FFFFFF,d0
	movea.l	d0,a0
	move.l	(a7)+,d0
	addq.l	#2,a0
	rts

Helper_AGA2:					; $E8
	move.w	#$FFFF,d0
	move.l	d0,-(a7)
	move.l	a0,d0
	and.l	#$FFFFFF,d0
	movea.l	d0,a0
	move.l	(a7)+,d0
	rts

Helper_Keys:					; $FC
	move.l	a0,-(a7)
	lea	HelperFlags(pc),a0
	ror.b	#1,d0
	eori.b	#$FF,d0				; the raw key code (bit 7: released)
	cmp.b	#$50,d0				; F1: the audio filter (the power LED)
	bne.s	.notf1
	bchg	#1,$BFE001
	bra.s	.f3
.notf1:	cmp.b	#$51,d0				; F2: PAL / NTSC
	bne.s	.f3
	tst.b	(a0)
	beq.s	.ntsc
	sf	(a0)
	move.w	#$20,$DFF1DC			; BEAMCON0: PAL
	bra.s	.f3
.ntsc:	st	(a0)
	clr.w	$DFF1DC				; BEAMCON0: NTSC
.f3:	cmp.b	#$52,d0				; F3: the turbo
	ifd	ORIGINAL
	bne.s	.done
	else
	bne.s	.f6
	endc
	ifd	ORIGINAL
	tst.b	1(a0)
	beq.s	.on
	sf	1(a0)
	move.w	#$66FC,(Helper_Wait+2).w	; the bne back
	bra.s	.done
.on:	st	1(a0)
	move.w	#$4E71,(Helper_Wait+2).w	; a NOP: no wait
	else
	not.b	1(a0)				; (Helper_Wait tests it)
.f6:	cmp.b	#$55,d0				; F6: the cockpit drawn over the view or not (the game's
	bne.s	.f7				; DrawCockpitPart tests CockpitOff). Caught here, in the
	not.b	2(a0)				; keyboard interrupt, so that no press is missed
.f7:	cmp.b	#$56,d0				; F7: the telemetry build's calibration run, asked for
	bne.s	.f8				; (calibrate.i: run at the end of the race frame)
	st	3(a0)
.f8:	cmp.b	#$57,d0				; F8: the race's timing - to the clock, the view drawn
	bne.s	.f9				; between steps (interp.i), or the release's
	not.b	4(a0)
.f9:	cmp.b	#$58,d0				; F9: the race's view at full or half height
	bne.s	.done				; (halfres.i)
	not.b	5(a0)
	endc
.done:	movea.l	(a7)+,a0
	rts

	ifnd	ORIGINAL
	dcb.b	$170-*,0
	endc
HelperFlags:					; $15C ($170)
	dc.b	0				; F2: NTSC
TurboOn:
	dc.b	0				; F3: the turbo
	ifnd	ORIGINAL
CockpitOff:					; $172
	dc.b	0				; F6: the cockpit off
CalibrateAsked:					; $173
	dc.b	0				; F7: a calibration run asked for (the telemetry build)
InterpOff:					; $174
	dc.b	0				; F8: the release's timing
HalfHeight:					; $175
	dc.b	0				; F9: the view at half height
	endc
