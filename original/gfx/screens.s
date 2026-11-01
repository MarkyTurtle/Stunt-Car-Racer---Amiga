;-----------------------------------------------------------------------------------------------
; The two screens (4 planes of 320x200 each, $7D00 bytes: the start-up code sets the pointers at
; $6A584/$6A588 to $6A594 and $72294). The bytes here are what was in that memory when the
; game was saved to the disk: the game draws over them (the second screen runs on past the
; end of the file).
; (scr_game.s, $6A594-$730FF: split out by tools/split_data.py)
;-----------------------------------------------------------------------------------------------

Screens:
	incbin	"gfx/screens_initial.bin"		; $6A594-$730FF, 35692 bytes
ScreenMemory	equ	Screens
PictureBuffer	equ	Screens+$22
