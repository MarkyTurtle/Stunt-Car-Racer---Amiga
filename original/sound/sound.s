;-----------------------------------------------------------------------------------------------
; The sound effects: 8 samples (8-bit, stored with the sign bit flipped: the start-up code
; flips it, $EE64), the engine buffer and the sound driver's table of them.
; (scr_game.s, $F4B8-$1B749: split out by tools/split_data.py)
;-----------------------------------------------------------------------------------------------

Sample0:
	incbin	"sound/sample0.bin"		; $0F4B8-$0FE3B, 2436 bytes
dat_0F4B8	equ	Sample0

Sample1:
	incbin	"sound/sample1.bin"		; $0FE3C-$12183, 9032 bytes

Sample2:
	incbin	"sound/sample2.bin"		; $12184-$140D1, 8014 bytes

Sample3:
	incbin	"sound/sample3.bin"		; $140D2-$14CF5, 3108 bytes
dat_14874	equ	Sample3+$7A2

Sample4:
	incbin	"sound/sample4.bin"		; $14CF6-$16127, 5170 bytes

Sample5:
	incbin	"sound/sample5.bin"		; $16128-$18215, 8430 bytes

Sample6:
	incbin	"sound/sample6.bin"		; $18216-$19DE5, 7120 bytes

Sample7_Engine:
	incbin	"sound/sample7_engine.bin"		; $19DE6-$1AA49, 3172 bytes
dat_19DE6	equ	Sample7_Engine


; the engine sample at 6 rates, made by the sound driver at start-up ($F402)
EngineBuffer:
	dcb.b	$C80,0

; the sound effects: pointer, length (bytes), period, volume, channel, (spare)
SampleTable:
	dc.l	Sample0,$984
	dc.w	$96,$1E,1,0
	dc.l	Sample1,$2348
	dc.w	$B4,$40,1,0
	dc.l	Sample2,$1F4E
	dc.w	$EE,$38,1,0
	dc.l	Sample3,$C24
	dc.w	$190,$32,1,0
	dc.l	Sample4,$1432
	dc.w	$EE,$40,2,0
	dc.l	Sample5,$20EE
	dc.w	$118,$40,3,0
	dc.l	Sample6,$1BD0
	dc.w	$1F4,$40,1,0
	dc.l	Sample7_Engine,$C64
	dc.w	$12C,$30,0,0
dat_1AA4A	equ	EngineBuffer
dat_1B6CA	equ	SampleTable
dat_1B6E2	equ	SampleTable+$18
dat_1B705	equ	SampleTable+$3B
dat_1B715	equ	SampleTable+$4B
dat_1B732	equ	SampleTable+$68
dat_1B73A	equ	SampleTable+$70
dat_1B73E	equ	SampleTable+$74
