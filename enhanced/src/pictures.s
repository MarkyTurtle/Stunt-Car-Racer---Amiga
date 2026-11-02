;-----------------------------------------------------------------------------------------------
; pictures.s - the enhanced game's pictures: original/gfx/pictures.s without the five shown only
; between races and in the Hall of Fame (wreck, season_win, season_crowd, champion, hall_of_fame:
; 124,485 bytes), which are files on the disk now (tools/build_disk.py: files 3-7) loaded into
; DiskPicture when they are shown (diskload.i). The tables between the pictures are kept; the
; single $00 bytes after three of them are not: they made up for the odd lengths of wreck,
; season_win and season_crowd, and without those pictures they would leave everything after on
; odd addresses (PictureTable's longs: an address error on a 68000).
;-----------------------------------------------------------------------------------------------
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

; Pic_HallOfFame (hall_of_fame.bin): not in the game - a file on the disk, loaded when it is shown (diskload.i)

	dc.b	$00,$00,$00,$04,$00,$08,$00,$0C,$00,$03,$00,$07,$00,$0B,$00,$0F
	dc.b	$00,$01,$00,$01,$00,$01,$00,$01,$00,$80,$00,$54,$00,$2A,$00,$00

Pic_Divisions:
	incbin	"gfx/divisions.bin"		; $35A74-$3D795, 32034 bytes
dat_35A76	equ	Pic_Divisions+$2
dat_35A96	equ	Pic_Divisions+$22

	dc.b	$00,$00,$00,$04,$00,$08,$00,$0C,$00,$03,$00,$07,$00,$0B,$00,$0F
	dc.b	$00,$01,$00,$01,$00,$01,$00,$01,$00,$80,$00,$54,$00,$2A,$00,$00

; Pic_Wreck (wreck.bin): not in the game - a file on the disk, loaded when it is shown (diskload.i)

	dc.b	$00,$00,$00,$04,$00,$08,$00,$0C,$00,$03,$00,$07,$00,$0B,$00,$0F
	dc.b	$00,$01,$00,$01,$00,$01,$00,$01,$00,$80,$00,$54,$00,$2A,$00,$00

; Pic_SeasonWin (season_win.bin): not in the game - a file on the disk, loaded when it is shown (diskload.i)

	dc.b	$00,$00,$00,$04,$00,$08,$00,$0C,$00,$03,$00,$07,$00,$0B,$00,$0F
	dc.b	$00,$01,$00,$01,$00,$01,$00,$01,$00,$80,$00,$54,$00,$2A,$00,$00

; Pic_SeasonCrowd (season_crowd.bin): not in the game - a file on the disk, loaded when it is shown (diskload.i)

	dc.b	$00,$00,$00,$04,$00,$08,$00,$0C,$00,$03,$00,$07,$00,$0B,$00,$0F
	dc.b	$00,$01,$00,$01,$00,$01,$00,$01,$00,$80,$00,$54,$00,$2A,$00,$00

; Pic_Champion (champion.bin): not in the game - a file on the disk, loaded when it is shown (diskload.i)
	even					; (what follows reads words and longs)
