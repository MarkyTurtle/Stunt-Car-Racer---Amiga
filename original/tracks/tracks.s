;-----------------------------------------------------------------------------------------------
; The 8 tracks, as the track builder ($5AE46) reads them: its table at $1F0A2 gives each
; one's start (byte-swapped, - $B100, + $1EF82).
; (scr_game.s, $1F8E4-$1FDC3: split out by tools/split_data.py)
;-----------------------------------------------------------------------------------------------

Track_LittleRamp:
	incbin	"tracks/little_ramp.bin"		; $1F8E4-$1F95F, 124 bytes

Track_SteppingStones:
	incbin	"tracks/stepping_stones.bin"		; $1F960-$1F9F0, 145 bytes

Track_HumpBack:
	incbin	"tracks/hump_back.bin"		; $1F9F1-$1FA81, 145 bytes

Track_BigRamp:
	incbin	"tracks/big_ramp.bin"		; $1FA82-$1FB0F, 142 bytes

Track_SkiJump:
	incbin	"tracks/ski_jump.bin"		; $1FB10-$1FBA0, 145 bytes

Track_DrawBridge:
	incbin	"tracks/draw_bridge.bin"		; $1FBA1-$1FC75, 213 bytes

Track_HighJump:
	incbin	"tracks/high_jump.bin"		; $1FC76-$1FD03, 142 bytes

Track_RollerCoaster:
	incbin	"tracks/roller_coaster.bin"		; $1FD04-$1FDC3, 192 bytes
