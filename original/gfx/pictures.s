;-----------------------------------------------------------------------------------------------
; The pictures: each a record of a flag word (bit 15: packed, ByteRun1 by line and plane,
; unpacked by $593F8; else 4 planes interleaved by word), 16 colours and 320x200 in 4 planes.
; The 32 bytes before each record are the header left from its picture file (not used).
; (scr_game.s, $20182-$56FD7: split out by tools/split_data.py)
;-----------------------------------------------------------------------------------------------

Pic_Cockpit:
	incbin	"gfx/cockpit.bin"		; $20182-$23C0F, 14990 bytes
dat_20184	equ	Pic_Cockpit+$2
dat_201A4	equ	Pic_Cockpit+$22

	dc.b	$00,$00,$00,$04,$00,$08,$00,$0C,$00,$03,$00,$07,$00,$0B,$00,$0F
	dc.b	$00,$01,$00,$01,$00,$01,$00,$01,$00,$80,$00,$54,$00,$2A,$00,$00

Pic_Title:
	incbin	"gfx/title.bin"		; $23C30-$2B951, 32034 bytes
dat_23C32	equ	Pic_Title+$2
dat_23C52	equ	Pic_Title+$22
dat_272C2	equ	Pic_Title+$3692

	dc.b	$00,$00,$00,$04,$00,$08,$00,$0C,$00,$03,$00,$07,$00,$0B,$00,$0F
	dc.b	$00,$01,$00,$01,$00,$01,$00,$01,$00,$80,$00,$54,$00,$2A,$00,$00

Pic_Stadium:
	incbin	"gfx/stadium.bin"		; $2B972-$30BAD, 21052 bytes
dat_2B974	equ	Pic_Stadium+$2
dat_2B994	equ	Pic_Stadium+$22

	dc.b	$00,$00,$00,$04,$00,$08,$00,$0C,$00,$03,$00,$07,$00,$0B,$00,$0F
	dc.b	$00,$01,$00,$01,$00,$01,$00,$01,$00,$80,$00,$54,$00,$2A,$00,$00

Pic_HallOfFame:
	incbin	"gfx/hall_of_fame.bin"		; $30BCE-$35A53, 20102 bytes
dat_30BD0	equ	Pic_HallOfFame+$2
dat_30BF0	equ	Pic_HallOfFame+$22

	dc.b	$00,$00,$00,$04,$00,$08,$00,$0C,$00,$03,$00,$07,$00,$0B,$00,$0F
	dc.b	$00,$01,$00,$01,$00,$01,$00,$01,$00,$80,$00,$54,$00,$2A,$00,$00

Pic_Divisions:
	incbin	"gfx/divisions.bin"		; $35A74-$3D795, 32034 bytes
dat_35A76	equ	Pic_Divisions+$2
dat_35A96	equ	Pic_Divisions+$22

	dc.b	$00,$00,$00,$04,$00,$08,$00,$0C,$00,$03,$00,$07,$00,$0B,$00,$0F
	dc.b	$00,$01,$00,$01,$00,$01,$00,$01,$00,$80,$00,$54,$00,$2A,$00,$00

Pic_Wreck:
	incbin	"gfx/wreck.bin"		; $3D7B6-$4475A, 28581 bytes

	dc.b	$00,$00,$00,$04,$00,$08,$00,$0C,$00,$03,$00,$07,$00,$0B,$00,$0F
	dc.b	$00,$01,$00,$01,$00,$01,$00,$01,$00,$80,$00,$54,$00,$2A,$00,$00
	dc.b	$00

Pic_SeasonWin:
	incbin	"gfx/season_win.bin"		; $4477C-$4AF1C, 26529 bytes

	dc.b	$00,$00,$00,$04,$00,$08,$00,$0C,$00,$03,$00,$07,$00,$0B,$00,$0F
	dc.b	$00,$01,$00,$01,$00,$01,$00,$01,$00,$80,$00,$54,$00,$2A,$00,$00
	dc.b	$00

Pic_SeasonCrowd:
	incbin	"gfx/season_crowd.bin"		; $4AF3E-$50E2A, 24301 bytes

	dc.b	$00,$00,$00,$04,$00,$08,$00,$0C,$00,$03,$00,$07,$00,$0B,$00,$0F
	dc.b	$00,$01,$00,$01,$00,$01,$00,$01,$00,$80,$00,$54,$00,$2A,$00,$00
	dc.b	$00

Pic_Champion:
	incbin	"gfx/champion.bin"		; $50E4C-$56FD7, 24972 bytes
