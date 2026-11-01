; Stunt Car Racer (MicroStyle 1989) - the "Turbo" release's bootblock (AGA fix and Turbo by Galahad)
; Assemble: vasmm68k_mot -Fbin -m68000 -no-opt -o boot.bin scr_boot.s
;
; Reads $9800 bytes from disk offset $2C00 to $40000 through trackdisk.device, copies the
; helper block (HelperBlock, $9E bytes) to $C0 and jumps to $40000. See docs/BOOT.md.

	include	"scr_hw.i"

AbsExecBase	equ	4
_LVOForbid	equ	-132
_LVOPermit	equ	-150
_LVOAllocMem	equ	-198
_LVODoIO	equ	-456
IO_COMMAND	equ	$1C
IO_ERROR	equ	$1F
IO_LENGTH	equ	$24
IO_DATA		equ	$28
IO_OFFSET	equ	$2C
CMD_READ	equ	2
TD_MOTOR	equ	9
HelperRun	equ	$C0		; where the helper block runs

	section	boot,code

	org	0
BootBlock:
	dc.b	$44,$4F,$53,$00
dat_00004:
	dc.b	$10,$A8,$DA,$71,$00,$00,$03,$70
BootEntry:
        movea.l a1,a2                           ; 0000C
        lea.l   $400(pc),a7                     ; 0000E
        movea.l (AbsExecBase).w,a6              ; 00012
        jsr     _LVOForbid(a6)                  ; 00016
        move.l  a1,-(a7)                        ; 0001A
        move.l  #$9800,d0                       ; 0001C
        move.l  #$10002,d1                      ; 00022
        movea.l (AbsExecBase).w,a6              ; 00028
        jsr     _LVOAllocMem(a6)                ; 0002C  the result is not used: the read goes to LoadAddress
        movea.l (a7)+,a1                        ; 00030
ReadRetry:
        move.l  LoadAddress(pc),IO_DATA(a1)     ; 00032
        move.l  BootEntry+$12(pc),IO_LENGTH(a1) ; 00038  the length: the $9800 in the move.l at $1C
        move.l  #$2C00,IO_OFFSET(a1)            ; 0003E  disk offset $2C00 (sector 22)
        move.w  #CMD_READ,IO_COMMAND(a1)        ; 00046
        movea.l (AbsExecBase).w,a6              ; 0004C
        jsr     _LVODoIO(a6)                    ; 00050
        movea.l a2,a1                           ; 00054
        move.b  IO_ERROR(a1),d0                 ; 00056
        bne.b   ReadRetry                       ; 0005A
        move.w  #TD_MOTOR,IO_COMMAND(a1)        ; 0005C
        clr.l   IO_LENGTH(a1)                   ; 00062
        movea.l (AbsExecBase).w,a6              ; 00066
        jsr     _LVODoIO(a6)                    ; 0006A
        movea.l (AbsExecBase).w,a6              ; 0006E
        jsr     _LVOPermit(a6)                  ; 00072
        bsr.w   InstallHelper                   ; 00076
        jmp     $40000.l                        ; 0007A  the packed loader
	dc.b	'N Protection (C)Copyright 1989 Rob Northen Computing. All Rights'
dat_000C0:
	dc.b	$20,$52
dat_000C2:
	dc.b	'eserved.'
	dcb.b	54,$00
	dcb.b	64,$2D
	dc.b	'           Stunt Car Racer Turbo AGA fix by Galahad             ----------------------------------------------------------------'
	dcb.b	128,$00

;-------------------------------------------------------------------------------
; InstallHelper - copies the helper block to $C0.
;-------------------------------------------------------------------------------
InstallHelper:
        movem.l d0/a0-a1,-(a7)                  ; 00240
        lea.l   HelperBlock(pc),a0              ; 00244
        lea.l   (HelperRun).w,a1                ; 00248
        move.l  #HelperBlockEnd-HelperBlock-1,d0; 0024C
l_00252:
        move.b  (a0)+,(a1)+                     ; 00252
        dbra    d0,l_00252                      ; 00254
        movem.l (a7)+,d0/a0-a1                  ; 00258
        rts                                     ; 0025C

;-------------------------------------------------------------------------------
; HelperBlock - runs at $C0 (each routine below: run address = $C0 + (address - $25E)).
; $C0: wait while (a2) is not zero; F3 patches its bne at $C2 to a NOP (the turbo).
;-------------------------------------------------------------------------------
HelperBlock:
        tst.b   (a2)                            ; 0025E
        bne.b   HelperBlock                     ; 00260
        rts                                     ; 00262
HelperText:
	dc.b	'<Galahad> NqNqNq'

;-------------------------------------------------------------------------------
; HelperAGA1 ($D6) and HelperAGA2 ($E8): a0 masked to 24 bits (the AGA fix).
;-------------------------------------------------------------------------------
HelperAGA1:
        move.l  d0,-(a7)                        ; 00274
        move.l  a0,d0                           ; 00276
        and.l   #$ffffff,d0                     ; 00278
        movea.l d0,a0                           ; 0027E
        move.l  (a7)+,d0                        ; 00280
        addq.l  #$2,a0                          ; 00282
        rts                                     ; 00284
HelperAGA2:
        move.w  #$ffff,d0                       ; 00286
        move.l  d0,-(a7)                        ; 0028A
        move.l  a0,d0                           ; 0028C
        and.l   #$ffffff,d0                     ; 0028E
        movea.l d0,a0                           ; 00294
        move.l  (a7)+,d0                        ; 00296
        rts                                     ; 00298

;-------------------------------------------------------------------------------
; HelperKeys ($FC): d0 = raw key code. F1 ($50): audio filter; F2 ($51): BEAMCON0
; PAL/NTSC; F3 ($52): the turbo (patches $C2). Its flags at $2FA (run $15C).
;-------------------------------------------------------------------------------
HelperKeys:
        move.l  a0,-(a7)                        ; 0029A
        lea.l   dat_002FA(pc),a0                ; 0029C
        ror.b   #$1,d0                          ; 002A0
        eori.b  #$ff,d0                         ; 002A2
        cmp.b   #$50,d0                         ; 002A6
        bne.b   l_002B6                         ; 002AA
        bchg    #$1,(CIAA_PRA).l                ; 002AC
        bra.b   l_002D4                         ; 002B4
l_002B6:
        cmp.b   #$51,d0                         ; 002B6
        bne.b   l_002D4                         ; 002BA
        tst.b   (a0)                            ; 002BC
        beq.b   l_002CC                         ; 002BE
        sf.b    (a0)                            ; 002C0
        move.w  #$20,$dff1dc.l                  ; 002C2
        bra.b   l_002D4                         ; 002CA
l_002CC:
        st.b    (a0)                            ; 002CC
        clr.w   $dff1dc.l                       ; 002CE
l_002D4:
        cmp.b   #$52,d0                         ; 002D4
        bne.b   l_002F6                         ; 002D8
        tst.b   $1(a0)                          ; 002DA
        beq.b   l_002EC                         ; 002DE
        sf.b    $1(a0)                          ; 002E0
        move.w  #$66fc,(dat_000C2).w            ; 002E4
        bra.b   l_002F6                         ; 002EA
l_002EC:
        st.b    $1(a0)                          ; 002EC
        move.w  #$4e71,(dat_000C2).w            ; 002F0
l_002F6:
        movea.l (a7)+,a0                        ; 002F6
        rts                                     ; 002F8
dat_002FA:
	dc.b	$00,$00
HelperBlockEnd:
	dc.b	$00,$00,$00,$00
LoadAddress:
	dc.b	$00,$04
	dcb.b	62,$00
	dc.b	'Hey Siriax, was your '
	dc.b	$27,$63,$72,$61,$63,$6B,$27
	dc.b	' of Player Manager 2 AGA "masturbated from YOUR brain"?  If you can'
	dc.b	$27
	dc.b	't spell my name correctly, dont bother removing my credit from the bootblock - Galahad!         '
