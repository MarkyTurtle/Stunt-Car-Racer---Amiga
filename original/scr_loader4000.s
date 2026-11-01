; Stunt Car Racer (MicroStyle 1989) - the "Turbo" release's loader, unpacked to $4000
; Assemble: vasmm68k_mot -Fbin -m68000 -no-opt -o loader_4000.bin scr_loader4000.s
;
; Shows the loading picture (4 bitplanes at $78000), reads the game (sectors $6E-$392) to $E700
; with its sector loader and enters it. See docs/BOOT.md.

	include	"scr_hw.i"

	section	loader4000,code

	org	$4000

;-------------------------------------------------------------------------------
; LoaderStart - the picture, then the game (sectors $6E, $325 of them) to $E700.
;-------------------------------------------------------------------------------
LoaderStart:
        lea.l   dat_04426(pc),a7                ; 04000
        lea.l   Palette32(pc),a0                ; 04004
        move.w  #$1f,d0                         ; 04008
        move.w  #$700,d3                        ; 0400C
l_04010:
        move.w  d3,(a0)+                        ; 04010
        dbra    d0,l_04010                      ; 04012
        jsr     SetColours(pc)                  ; 04016
        jsr     SetDisplay(pc)                  ; 0401A
        movea.l #$78000,a1                      ; 0401E
        lea.l   PictureData(pc),a0              ; 04024
        move.w  #$f9f,d0                        ; 04028
l_0402C:
        move.w  (a0)+,(a1)+                     ; 0402C
        move.w  (a0)+,$1f3e(a1)                 ; 0402E
        move.w  (a0)+,$3e7e(a1)                 ; 04032
        move.w  (a0)+,$5dbe(a1)                 ; 04036
        dbra    d0,l_0402C                      ; 0403A
        lea.l   PicturePalette(pc),a0           ; 0403E
        lea.l   Palette32(pc),a1                ; 04042
        move.w  #$f,d3                          ; 04046
l_0404A:
        move.w  (a0)+,(a1)+                     ; 0404A
        dbra    d3,l_0404A                      ; 0404C
        jsr     SetColours(pc)                  ; 04050
l_04054:
        move.w  #$0,d0                          ; 04054
        move.w  #$6e,d1                         ; 04058
        move.w  #$325,d2                        ; 0405C
        move.w  #$0,d3                          ; 04060
        movea.l #$e700,a0                       ; 04064
        movea.l #$400,a1                        ; 0406A
        jsr     SectorLoader(pc)                ; 04070
l_04074:
        btst    #$6,(CUSTOM+DMACONR).l          ; 04074
        bne.w   l_04074                         ; 0407C
        ori.b   #$8,(CIAB_PRB).l                ; 04080
        move.w  #$450,(CUSTOM+DMACON).l         ; 04088
        tst.l   d0                              ; 04090
        beq.w   l_040AC                         ; 04092
        lea.l   Retries(pc),a0                  ; 04096
        subq.w  #$1,(a0)                        ; 0409A
        bpl.w   l_04054                         ; 0409C
        lea.l   dat_0410C(pc),a0                ; 040A0
        move.w  #$f0f,(a0)                      ; 040A4
l_040A8:
        bra.w   l_040A8                         ; 040A8
l_040AC:
        movea.l #$e700,a0                       ; 040AC
        movea.l #$7fffc,a1                      ; 040B2
        move    a1,usp                          ; 040B8
        movea.l #$3d80,a7                       ; 040BA
        jmp     (a0)                            ; 040C0
Level3Handler:		; (no references found: found by the code sweep)
        btst    #$5,$dff01f.l                   ; 040C2
        beq.w   l_040E0                         ; 040CA
        move.w  #$20,(CUSTOM+DMACON).l          ; 040CE
        move.w  #$20,(CUSTOM+INTREQ).l          ; 040D6
        rte                                     ; 040DE
l_040E0:
        move.w  #$50,(CUSTOM+INTREQ).l          ; 040E0
        rte                                     ; 040E8
Copper:
	dc.w	$00E0,$0007,$00E2,$8000,$00E4,$0007,$00E6,$9F40
	dc.w	$00E8,$0007,$00EA,$BE80,$00EC,$0007,$00EE,$DDC0
	dc.w	$0180
dat_0410C:
	dc.b	$00,$33,$01,$82,$00,$00,$01,$84,$05,$55,$01,$86,$07,$77,$01,$88
	dc.b	$09,$99,$01,$8A,$0B,$BB,$01,$8C,$0D,$DD,$01,$8E,$0F,$FF,$01,$90
	dc.b	$03,$00,$01,$92,$05,$00,$01,$94,$07,$00,$01,$96,$09,$00,$01,$98
	dc.b	$0B,$00,$01,$9A,$0D,$00,$01,$9C,$0F,$00,$01,$9E,$09,$B9,$01,$A0
	dc.b	$0F,$00,$01,$A2,$0F,$00,$01,$A4,$0F,$00,$01,$A6,$0F,$00,$01,$A8
	dc.b	$0F,$00,$01,$AA,$0F,$00,$01,$AC,$0F,$00,$01,$AE,$0F,$00,$01,$B0
	dc.b	$0F,$00,$01,$B2,$0F,$00,$01,$B4,$0F,$00,$01,$B6,$0F,$00,$01,$B8
	dc.b	$0F,$00,$01,$BA,$0F,$00,$01,$BC,$0F,$00,$01,$BE,$0F,$00,$FF,$FF
	dc.b	$FF,$FE
Palette32:
	dc.w	$0011,$0000,$0222,$0333,$0444,$0555,$0666,$0777
	dc.w	$0100,$0200,$0300,$0400,$0500,$0600,$0700,$0454
	dc.w	$0700,$0700,$0700,$0700,$0700,$0700,$0700,$0700
	dc.b	$07,$00,$07,$00,$07,$00,$07,$00,$07,$00,$07,$00,$07,$00,$07
	dcb.b	491,$00
	dc.w	$2700,$0000,$4CC6,$0000,$4BC2,$0000,$455E,$0000
	dc.w	$006E,$0325,$0000,$0000,$E700,$0000,$0400,$0001
	dc.w	$000A,$0000,$0000,$0000,$0000,$0000,$0000,$0000
	dc.w	$0000,$00C0,$0276,$8000,$006E,$0000,$0325,$DDC0
	dc.w	$0000,$0000,$FFFF,$BD7F,$00B1,$FFFF,$FFFF,$0000
	dc.w	$0008,$0000,$E700,$0000,$0400,$0000,$E4A4,$0000
	dc.w	$59E8,$0000,$1558,$00C0,$14BA,$0000,$4074
dat_04426:
	dc.b	$00,$00,$00,$00

;-------------------------------------------------------------------------------
; SetDisplay - 4 planes lores at $78000, the copper list.
;-------------------------------------------------------------------------------
SetDisplay:
        move.l  #$78000,d0                      ; 0442A
        lea.l   Copper(pc),a0                   ; 04430
        move.w  #$3,d4                          ; 04434
l_04438:
        move.l  d0,d3                           ; 04438
        swap    d3                              ; 0443A
        move.w  d3,$2(a0)                       ; 0443C
        move.w  d0,$6(a0)                       ; 04440
        adda.l  #$8,a0                          ; 04444
        addi.l  #$1f40,d0                       ; 0444A
        dbra    d4,l_04438                      ; 04450
        move.w  #$4200,(CUSTOM+BPLCON0).l       ; 04454
        move.w  #$3c81,(CUSTOM+DIWSTRT).l       ; 0445C
        move.w  #$4c1,(CUSTOM+DIWSTOP).l        ; 04464
        move.w  #$38,(CUSTOM+DDFSTRT).l         ; 0446C
        move.w  #$d0,(CUSTOM+DDFSTOP).l         ; 04474
        move.w  #$0,(CUSTOM+BPL1MOD).l          ; 0447C
        move.w  #$0,(CUSTOM+BPL2MOD).l          ; 04484
        move.w  #$0,(CUSTOM+BPLCON1).l          ; 0448C
        lea.l   Copper(pc),a0                   ; 04494
        move.l  a0,(CUSTOM+COP1LCH).l           ; 04498
        move.w  (CUSTOM+COPJMP1).l,d0           ; 0449E
        move.w  #$8380,(CUSTOM+DMACON).l        ; 044A4
        rts                                     ; 044AC
Retries:
	dc.b	$00,$01

;-------------------------------------------------------------------------------
; SetColours - Palette32 (3-bit values) to the copper list: each nibble doubled, +1 if not 0.
;-------------------------------------------------------------------------------
SetColours:
        lea.l   Palette32(pc),a1                ; 044B0
        lea.l   dat_0410C(pc),a0                ; 044B4
        move.w  #$1f,d4                         ; 044B8
l_044BC:
        move.w  (a1)+,d3                        ; 044BC
        asl.w   #$1,d3                          ; 044BE
        move.b  d3,d0                           ; 044C0
        andi.b  #$f,d0                          ; 044C2
        beq.w   l_044CE                         ; 044C6
        ori.b   #$1,d3                          ; 044CA
l_044CE:
        move.b  d3,d0                           ; 044CE
        andi.b  #$f0,d0                         ; 044D0
        beq.w   l_044DC                         ; 044D4
        ori.b   #$10,d3                         ; 044D8
l_044DC:
        move.w  d3,d0                           ; 044DC
        andi.w  #$f00,d0                        ; 044DE
        beq.w   l_044EA                         ; 044E2
        ori.w   #$100,d3                        ; 044E6
l_044EA:
        move.w  d3,(a0)+                        ; 044EA
        adda.l  #$2,a0                          ; 044EC
        dbra    d4,l_044BC                      ; 044F2
        rts                                     ; 044F6

;-------------------------------------------------------------------------------
; SectorLoader - d0 = drive, d1 = first sector, d2 = sectors, d3 = 0 read / 1 write,
; a0 = buffer, a1 = MFM buffer; d0 = 0 if it worked.
;-------------------------------------------------------------------------------
SectorLoader:
        movem.l d1-d7/a0-a5,-(a7)               ; 044F8
        link.w  a6,#$ffdc                       ; 044FC
        move.w  d0,d4                           ; 04500
        andi.w  #$3,d4                          ; 04502
        move.w  d4,-$24(a6)                     ; 04506
        move.w  d1,-$22(a6)                     ; 0450A
        move.w  d2,-$20(a6)                     ; 0450E
        move.w  d3,-$1e(a6)                     ; 04512
        move.l  a0,-$1c(a6)                     ; 04516
        move.l  a1,-$18(a6)                     ; 0451A
        rol.w   #$1,d0                          ; 0451E
        andi.w  #$1,d0                          ; 04520
        addq.w  #$1,d0                          ; 04524
        move.w  d0,-$14(a6)                     ; 04526
        moveq   #$1e,d0                         ; 0452A
        move.w  d2,d3                           ; 0452C
        beq.w   l_045E2                         ; 0452E
        add.w   d1,d3                           ; 04532
        cmp.w   #$6e0,d3                        ; 04534
        bgt.w   l_045E2                         ; 04538
        andi.l  #$ffff,d1                       ; 0453C
        divu.w  #$b,d1                          ; 04542
        cmpi.w  #$1,-$14(a6)                    ; 04546
        beq.b   l_04550                         ; 0454C
        add.w   d1,d1                           ; 0454E
l_04550:
        move.w  d1,-$12(a6)                     ; 04550
        swap    d1                              ; 04554
        move.w  d1,-$10(a6)                     ; 04556
        bsr.w   sub_04BAA                       ; 0455A
l_0455E:
        move.w  -$10(a6),d0                     ; 0455E
        moveq   #$b,d1                          ; 04562
        sub.w   d0,d1                           ; 04564
        cmp.w   -$20(a6),d1                     ; 04566
        ble.b   l_04570                         ; 0456A
        move.w  -$20(a6),d1                     ; 0456C
l_04570:
        move.w  d1,-$e(a6)                      ; 04570
        bsr.w   sub_045EC                       ; 04574
        bne.b   l_045B4                         ; 04578
        cmpi.w  #$1,-$1e(a6)                    ; 0457A
        bne.b   l_0458C                         ; 04580
        bsr.w   sub_0496C                       ; 04582
        bsr.w   sub_046CE                       ; 04586
        bne.b   l_045B4                         ; 0458A
l_0458C:
        move.w  -$20(a6),d0                     ; 0458C
        sub.w   -$e(a6),d0                      ; 04590
        beq.b   l_045B4                         ; 04594
        move.w  d0,-$20(a6)                     ; 04596
        move.w  -$e(a6),d0                      ; 0459A
        lsl.l   #$8,d0                          ; 0459E
        add.l   d0,d0                           ; 045A0
        add.l   d0,-$1c(a6)                     ; 045A2
        clr.w   -$10(a6)                        ; 045A6
        move.w  -$14(a6),d0                     ; 045AA
        add.w   d0,-$12(a6)                     ; 045AE
        bra.b   l_0455E                         ; 045B2
l_045B4:
        move.l  d0,-(a7)                        ; 045B4
        bsr.w   sub_04B82                       ; 045B6
        bsr.w   sub_04A7C                       ; 045BA
        move.l  (a7)+,d0                        ; 045BE
        beq.b   l_045E2                         ; 045C0
        moveq   #$0,d1                          ; 045C2
        move.w  -$12(a6),d1                     ; 045C4
        cmpi.w  #$1,-$14(a6)                    ; 045C8
        beq.b   l_045D2                         ; 045CE
        lsr.w   #$1,d1                          ; 045D0
l_045D2:
        mulu.w  #$b,d1                          ; 045D2
        add.w   -$10(a6),d1                     ; 045D6
        add.w   -$6(a6),d1                      ; 045DA
        move.l  d1,$28(a7)                      ; 045DE
l_045E2:
        unlk    a6                              ; 045E2
        tst.l   d0                              ; 045E4
        movem.l (a7)+,d1-d7/a0-a5               ; 045E6
        rts                                     ; 045EA
sub_045EC:
        moveq   #$4,d4                          ; 045EC
l_045EE:
        clr.w   -$4(a6)                         ; 045EE
        clr.w   -$6(a6)                         ; 045F2
        clr.w   -$8(a6)                         ; 045F6
        move.w  -$12(a6),d2                     ; 045FA
        bsr.w   sub_04BC4                       ; 045FE
        bne.w   l_046B6                         ; 04602
        moveq   #$1d,d0                         ; 04606
        btst    #$2,(CIAA_PRA).l                ; 04608
        beq.w   l_046B6                         ; 04610
        movea.l -$18(a6),a5                     ; 04614
        lea.l   $400(a5),a5                     ; 04618
        move.l  #$aaaaaaaa,(a5)                 ; 0461C
        move.w  #$4489,$4(a5)                   ; 04622
        bsr.w   sub_048F0                       ; 04628
        bsr.w   sub_04A7C                       ; 0462C
        bsr.w   sub_0474C                       ; 04630
        bne.w   l_046B6                         ; 04634
        move.w  -$c(a6),d0                      ; 04638
        beq.b   l_0468C                         ; 0463C
        mulu.w  #$440,d0                        ; 0463E
        lea.l   $6(a5),a0                       ; 04642
        bsr.w   sub_04B0C                       ; 04646
        lea.l   (CUSTOM+INTREQR).l,a4           ; 0464A
        bsr.w   sub_047A4                       ; 04650
        bne.b   l_046C4                         ; 04654
        cmpi.w  #$1,-$1e(a6)                    ; 04656
        beq.b   l_04668                         ; 0465C
        move.w  -$6(a6),d0                      ; 0465E
        sub.w   -$e(a6),d0                      ; 04662
        beq.b   l_046C8                         ; 04666
l_04668:
        movea.l -$18(a6),a5                     ; 04668
        lea.l   $400(a5),a5                     ; 0466C
        move.w  -$c(a6),d0                      ; 04670
        mulu.w  #$440,d0                        ; 04674
        adda.l  d0,a5                           ; 04678
        move.l  #$aaaaaaaa,(a5)                 ; 0467A
        move.w  #$4489,$4(a5)                   ; 04680
        movea.l a5,a0                           ; 04686
        bsr.w   sub_04AC2                       ; 04688
l_0468C:
        move.w  -$a(a6),d0                      ; 0468C
        beq.b   l_046AA                         ; 04690
        mulu.w  #$440,d0                        ; 04692
        lea.l   $6(a5),a0                       ; 04696
        bsr.w   sub_04B0C                       ; 0469A
        lea.l   -$2(a6),a4                      ; 0469E
        clr.w   (a4)                            ; 046A2
        bsr.w   sub_047A4                       ; 046A4
        bne.b   l_046C4                         ; 046A8
l_046AA:
        move.w  -$6(a6),d0                      ; 046AA
        sub.w   -$e(a6),d0                      ; 046AE
        beq.b   l_046C8                         ; 046B2
        moveq   #$1a,d0                         ; 046B4
l_046B6:
        move.l  d0,-(a7)                        ; 046B6
        moveq   #$2,d2                          ; 046B8
        bsr.w   sub_04BC4                       ; 046BA
        bsr.w   sub_04C1A                       ; 046BE
        move.l  (a7)+,d0                        ; 046C2
l_046C4:
        dbra    d4,l_045EE                      ; 046C4
l_046C8:
        bsr.w   sub_04B6E                       ; 046C8
        rts                                     ; 046CC
sub_046CE:
        moveq   #$4,d2                          ; 046CE
        clr.w   -$6(a6)                         ; 046D0
l_046D4:
        bsr.w   sub_04C7A                       ; 046D4
        move.l  #$c8,d0                         ; 046D8
        bsr.w   sub_04CBA                       ; 046DE
        moveq   #$1c,d0                         ; 046E2
        btst    #$3,(CIAA_PRA).l                ; 046E4
        beq.b   l_0473C                         ; 046EC
        lea.l   CUSTOM,a0                       ; 046EE
        move.w  #$4000,DSKLEN(a0)               ; 046F4
        move.l  -$18(a6),DSKPTH(a0)             ; 046FA
        move.w  #$6600,ADKCON(a0)               ; 04700
        move.w  #$9100,ADKCON(a0)               ; 04706
        cmpi.w  #$50,-$12(a6)                   ; 0470C
        bcs.b   l_0471A                         ; 04712
        move.w  #$a000,ADKCON(a0)               ; 04714
l_0471A:
        move.w  #$8010,$96(a0)                  ; 0471A
        move.w  #$2,$9c(a0)                     ; 04720
        move.w  #$d961,$24(a0)                  ; 04726
        move.w  #$d961,$24(a0)                  ; 0472C
        bsr.w   sub_04B4A                       ; 04732
        beq.b   l_0473C                         ; 04736
        dbra    d2,l_046D4                      ; 04738
l_0473C:
        move.l  d0,-(a7)                        ; 0473C
        move.l  #$2,d0                          ; 0473E
        bsr.w   sub_04CBA                       ; 04744
        move.l  (a7)+,d0                        ; 04748
        rts                                     ; 0474A
sub_0474C:
        moveq   #$a,d2                          ; 0474C
l_0474E:
        lea.l   $6(a5),a0                       ; 0474E
        move.w  #$40,d0                         ; 04752
        bsr.w   sub_04B0C                       ; 04756
        bsr.w   sub_04B4A                       ; 0475A
        bne.b   l_04796                         ; 0475E
        bsr.w   sub_0493A                       ; 04760
        beq.b   l_0476C                         ; 04764
        dbra    d2,l_0474E                      ; 04766
        bra.b   l_04798                         ; 0476A
l_0476C:
        bsr.w   sub_04902                       ; 0476C
        bne.b   l_0479C                         ; 04770
        cmp.w   -$12(a6),d1                     ; 04772
        bne.b   l_0479C                         ; 04776
        cmp.b   #$b,d2                          ; 04778
        bge.b   l_0479C                         ; 0477C
        cmp.b   #$b,d3                          ; 0477E
        bgt.b   l_0479C                         ; 04782
        subq.b  #$1,d3                          ; 04784
        move.w  d3,-$c(a6)                      ; 04786
        move.w  #$b,-$a(a6)                     ; 0478A
        sub.w   d3,-$a(a6)                      ; 04790
        moveq   #$0,d0                          ; 04794
l_04796:
        rts                                     ; 04796
l_04798:
        moveq   #$18,d0                         ; 04798
        rts                                     ; 0479A
l_0479C:
        moveq   #$1b,d0                         ; 0479C
        rts                                     ; 0479E
l_047A0:
        moveq   #$19,d0                         ; 047A0
        rts                                     ; 047A2
sub_047A4:
        movea.l -$18(a6),a5                     ; 047A4
        lea.l   $400(a5),a5                     ; 047A8
        move.w  -$8(a6),d0                      ; 047AC
        mulu.w  #$440,d0                        ; 047B0
        adda.l  d0,a5                           ; 047B4
        move.l  #$1770,d0                       ; 047B6
        bsr.w   sub_04CDC                       ; 047BC
l_047C0:
        btst    #$1,$1(a4)                      ; 047C0
        bne.w   l_048C8                         ; 047C6
        bsr.w   sub_04CCE                       ; 047CA
        beq.w   l_048CC                         ; 047CE
        tst.l   $440(a5)                        ; 047D2
        beq.b   l_047C0                         ; 047D6
        bsr.w   sub_0493A                       ; 047D8
        bne.b   l_04798                         ; 047DC
        bsr.w   sub_04902                       ; 047DE
        bne.b   l_0479C                         ; 047E2
        cmp.w   -$12(a6),d1                     ; 047E4
        bne.b   l_0479C                         ; 047E8
        move.w  d2,d3                           ; 047EA
        lea.l   $8(a5),a0                       ; 047EC
        bsr.w   sub_04924                       ; 047F0
        move.b  #$b,d0                          ; 047F4
        sub.b   -$7(a6),d0                      ; 047F8
        lea.l   $8(a5),a0                       ; 047FC
        bsr.w   sub_04AB4                       ; 04800
        bsr.w   sub_0494C                       ; 04804
        lea.l   $30(a5),a0                      ; 04808
        bsr.w   sub_04AB4                       ; 0480C
        cmp.w   -$10(a6),d3                     ; 04810
        blt.w   l_048BA                         ; 04814
        move.w  -$e(a6),d0                      ; 04818
        add.w   -$10(a6),d0                     ; 0481C
        cmp.w   d0,d3                           ; 04820
        bge.w   l_048BA                         ; 04822
        btst    #$1,$1(a4)                      ; 04826
        bne.w   l_048C8                         ; 0482C
        move.w  -$4(a6),d0                      ; 04830
        btst    d3,d0                           ; 04834
        bne.w   l_048BA                         ; 04836
        cmpi.w  #$1,-$1e(a6)                    ; 0483A
        bne.b   l_04878                         ; 04840
        bsr.w   sub_048D0                       ; 04842
        movea.l -$1c(a6),a0                     ; 04846
        adda.l  d1,a0                           ; 0484A
        lea.l   $40(a5),a1                      ; 0484C
        bsr.w   sub_049C8                       ; 04850
        btst    #$1,$1(a4)                      ; 04854
        bne.w   l_048C8                         ; 0485A
        lea.l   $40(a5),a0                      ; 0485E
        move.w  #$400,d1                        ; 04862
        bsr.w   sub_04952                       ; 04866
        lea.l   $38(a5),a0                      ; 0486A
        bsr.w   sub_04AB4                       ; 0486E
        bsr.w   sub_048E0                       ; 04872
        bra.b   l_048BA                         ; 04876
l_04878:
        lea.l   $40(a5),a0                      ; 04878
        move.w  #$400,d1                        ; 0487C
        bsr.w   sub_04952                       ; 04880
        move.l  d0,-(a7)                        ; 04884
        lea.l   $38(a5),a0                      ; 04886
        bsr.w   sub_04924                       ; 0488A
        cmp.l   (a7)+,d0                        ; 0488E
        bne.w   l_047A0                         ; 04890
        btst    #$1,$1(a4)                      ; 04894
        bne.b   l_048C8                         ; 0489A
        bsr.b   sub_048D0                       ; 0489C
        lea.l   $40(a5),a0                      ; 0489E
        movea.l -$1c(a6),a1                     ; 048A2
        adda.l  d1,a1                           ; 048A6
        bsr.w   sub_04992                       ; 048A8
        bsr.w   sub_048E0                       ; 048AC
        move.w  -$6(a6),d0                      ; 048B0
        cmp.w   -$e(a6),d0                      ; 048B4
        beq.b   l_048C8                         ; 048B8
l_048BA:
        addq.w  #$1,-$8(a6)                     ; 048BA
        cmpi.w  #$b,-$8(a6)                     ; 048BE
        bne.w   sub_047A4                       ; 048C4
l_048C8:
        moveq   #$0,d0                          ; 048C8
        rts                                     ; 048CA
l_048CC:
        moveq   #-1,d0                          ; 048CC
        rts                                     ; 048CE
sub_048D0:
        move.l  d3,d1                           ; 048D0
        sub.w   -$10(a6),d1                     ; 048D2
        move.l  #$200,d0                        ; 048D6
        mulu.w  d0,d1                           ; 048DC
        rts                                     ; 048DE
sub_048E0:
        move.w  -$4(a6),d0                      ; 048E0
        bset    d3,d0                           ; 048E4
        move.w  d0,-$4(a6)                      ; 048E6
        addq.w  #$1,-$6(a6)                     ; 048EA
        rts                                     ; 048EE
sub_048F0:
        movea.l a5,a0                           ; 048F0
        moveq   #$a,d1                          ; 048F2
        moveq   #$0,d0                          ; 048F4
l_048F6:
        lea.l   $440(a0),a0                     ; 048F6
        move.l  d0,(a0)                         ; 048FA
        dbra    d1,l_048F6                      ; 048FC
        rts                                     ; 04900
sub_04902:
        lea.l   $8(a5),a0                       ; 04902
        bsr.w   sub_04924                       ; 04906
        move.w  d0,d3                           ; 0490A
        andi.w  #$ff,d3                         ; 0490C
        move.w  d0,d2                           ; 04910
        lsr.w   #$8,d2                          ; 04912
        swap    d0                              ; 04914
        move.w  d0,d1                           ; 04916
        andi.w  #$ff,d1                         ; 04918
        lsr.w   #$8,d0                          ; 0491C
        cmp.b   #$ff,d0                         ; 0491E
        rts                                     ; 04922
sub_04924:
        move.l  (a0)+,d0                        ; 04924
        move.l  (a0)+,d1                        ; 04926
        andi.l  #$55555555,d0                   ; 04928
        andi.l  #$55555555,d1                   ; 0492E
        add.l   d0,d0                           ; 04934
        or.l    d1,d0                           ; 04936
        rts                                     ; 04938
sub_0493A:
        bsr.w   sub_0494C                       ; 0493A
        move.l  d0,-(a7)                        ; 0493E
        lea.l   $30(a5),a0                      ; 04940
        bsr.w   sub_04924                       ; 04944
        cmp.l   (a7)+,d0                        ; 04948
        rts                                     ; 0494A
sub_0494C:
        lea.l   $8(a5),a0                       ; 0494C
        moveq   #$28,d1                         ; 04950
sub_04952:
        move.l  d2,-(a7)                        ; 04952
        lsr.w   #$2,d1                          ; 04954
        subq.w  #$1,d1                          ; 04956
        moveq   #$0,d0                          ; 04958
l_0495A:
        move.l  (a0)+,d2                        ; 0495A
        eor.l   d2,d0                           ; 0495C
        dbra    d1,l_0495A                      ; 0495E
        move.l  (a7)+,d2                        ; 04962
        andi.l  #$55555555,d0                   ; 04964
        rts                                     ; 0496A
sub_0496C:
        movea.l -$18(a6),a0                     ; 0496C
        lea.l   $400(a0),a1                     ; 04970
        move.l  #$aaaaaaaa,d0                   ; 04974
        move.l  d0,d1                           ; 0497A
        move.l  d0,d2                           ; 0497C
        move.l  d0,d3                           ; 0497E
        move.l  d0,d4                           ; 04980
        move.l  d0,d5                           ; 04982
        move.l  d0,d6                           ; 04984
        move.l  d0,d7                           ; 04986
l_04988:
        movem.l d0-d7,-(a1)                     ; 04988
        cmpa.l  a1,a0                           ; 0498C
        bne.b   l_04988                         ; 0498E
        rts                                     ; 04990
sub_04992:
        move.l  a2,-(a7)                        ; 04992
        bsr.w   sub_04A88                       ; 04994
        adda.l  d0,a0                           ; 04998
        subq.l  #$1,a0                          ; 0499A
        move.l  a0,$50(a2)                      ; 0499C
        adda.l  d0,a0                           ; 049A0
        move.l  a0,$4c(a2)                      ; 049A2
        adda.l  d0,a1                           ; 049A6
        subq.l  #$1,a1                          ; 049A8
        move.l  a1,$54(a2)                      ; 049AA
        move.w  #$1dd8,$40(a2)                  ; 049AE
        move.w  #$2,$42(a2)                     ; 049B4
        lsl.w   #$2,d0                          ; 049BA
        ori.w   #$8,d0                          ; 049BC
        move.w  d0,$58(a2)                      ; 049C0
        movea.l (a7)+,a2                        ; 049C4
        rts                                     ; 049C6
sub_049C8:
        movem.l d1-d3/a2,-(a7)                  ; 049C8
        bsr.w   sub_04A88                       ; 049CC
        move.w  d0,d1                           ; 049D0
        lsl.w   #$2,d1                          ; 049D2
        ori.w   #$8,d1                          ; 049D4
        move.l  a0,$50(a2)                      ; 049D8
        move.l  a0,$4c(a2)                      ; 049DC
        move.l  a1,$54(a2)                      ; 049E0
        move.w  #$1db1,$40(a2)                  ; 049E4
        move.w  #$0,$42(a2)                     ; 049EA
        move.w  d1,$58(a2)                      ; 049F0
        bsr.w   sub_04A7C                       ; 049F4
        move.l  a0,$50(a2)                      ; 049F8
        move.l  a1,$4c(a2)                      ; 049FC
        move.l  a1,$54(a2)                      ; 04A00
        move.w  #$2d8c,$40(a2)                  ; 04A04
        move.w  d1,$58(a2)                      ; 04A0A
        bsr.w   sub_04A7C                       ; 04A0E
        move.l  a0,d2                           ; 04A12
        add.l   d0,d2                           ; 04A14
        subq.l  #$2,d2                          ; 04A16
        move.l  a1,d3                           ; 04A18
        add.l   d0,d3                           ; 04A1A
        add.l   d0,d3                           ; 04A1C
        subq.l  #$2,d3                          ; 04A1E
        move.l  d2,$50(a2)                      ; 04A20
        move.l  d2,$4c(a2)                      ; 04A24
        move.l  d3,$54(a2)                      ; 04A28
        move.w  #$db1,$40(a2)                   ; 04A2C
        move.w  #$1002,$42(a2)                  ; 04A32
        move.w  d1,$58(a2)                      ; 04A38
        bsr.w   sub_04A7C                       ; 04A3C
        move.l  a1,d3                           ; 04A40
        add.l   d0,d3                           ; 04A42
        move.l  a0,$50(a2)                      ; 04A44
        move.l  d3,$4c(a2)                      ; 04A48
        move.l  d3,$54(a2)                      ; 04A4C
        move.w  #$1d8c,$40(a2)                  ; 04A50
        move.w  #$0,$42(a2)                     ; 04A56
        move.w  d1,$58(a2)                      ; 04A5C
        bsr.w   sub_04A7C                       ; 04A60
        move.l  d0,d1                           ; 04A64
        movea.l a1,a0                           ; 04A66
        bsr.w   sub_04AC2                       ; 04A68
        adda.l  d1,a0                           ; 04A6C
        bsr.w   sub_04AC2                       ; 04A6E
        adda.l  d1,a0                           ; 04A72
        bsr.b   sub_04AC2                       ; 04A74
        movem.l (a7)+,d1-d3/a2                  ; 04A76
        rts                                     ; 04A7A
sub_04A7C:
        btst    #$6,(CUSTOM+DMACONR).l          ; 04A7C
        bne.b   sub_04A7C                       ; 04A84
        rts                                     ; 04A86
sub_04A88:
        lea.l   CUSTOM,a2                       ; 04A88
        bsr.w   sub_04A7C                       ; 04A8E
        move.w  #$8040,DMACON(a2)               ; 04A92
        move.l  #$ffffffff,BLTAFWM(a2)          ; 04A98
        move.w  #$5555,BLTCDAT(a2)              ; 04AA0
        clr.w   BLTAMOD(a2)                     ; 04AA6
        clr.w   BLTBMOD(a2)                     ; 04AAA
        clr.w   BLTDMOD(a2)                     ; 04AAE
        rts                                     ; 04AB2
sub_04AB4:
        move.l  d0,-(a7)                        ; 04AB4
        lsr.l   #$1,d0                          ; 04AB6
        bsr.w   sub_04AE0                       ; 04AB8
        move.l  (a7)+,d0                        ; 04ABC
        bsr.w   sub_04AE0                       ; 04ABE
sub_04AC2:
        move.b  (a0),d0                         ; 04AC2
        btst    #$0,-$1(a0)                     ; 04AC4
        bne.b   l_04AD8                         ; 04ACA
        btst    #$6,d0                          ; 04ACC
        bne.b   l_04ADE                         ; 04AD0
        bset    #$7,d0                          ; 04AD2
        bra.b   l_04ADC                         ; 04AD6
l_04AD8:
        bclr    #$7,d0                          ; 04AD8
l_04ADC:
        move.b  d0,(a0)                         ; 04ADC
l_04ADE:
        rts                                     ; 04ADE
sub_04AE0:
        andi.l  #$55555555,d0                   ; 04AE0
        move.l  d0,d2                           ; 04AE6
        eori.l  #$55555555,d2                   ; 04AE8
        move.l  d2,d1                           ; 04AEE
        add.l   d2,d2                           ; 04AF0
        lsr.l   #$1,d1                          ; 04AF2
        bset    #$1f,d1                         ; 04AF4
        and.l   d2,d1                           ; 04AF8
        or.l    d1,d0                           ; 04AFA
        btst    #$0,-$1(a0)                     ; 04AFC
        beq.b   l_04B08                         ; 04B02
        bclr    #$1f,d0                         ; 04B04
l_04B08:
        move.l  d0,(a0)+                        ; 04B08
        rts                                     ; 04B0A
sub_04B0C:
        lea.l   CUSTOM,a1                       ; 04B0C
        move.w  #$4000,DSKLEN(a1)               ; 04B12
        move.w  #$8010,DMACON(a1)               ; 04B18
        move.w  #$6600,ADKCON(a1)               ; 04B1E
        move.w  #$9500,ADKCON(a1)               ; 04B24
        move.w  #$4489,DSKSYNC(a1)              ; 04B2A
        move.l  a0,DSKPTH(a1)                   ; 04B30
        move.w  #$2,INTREQ(a1)                  ; 04B34
        lsr.w   #$1,d0                          ; 04B3A
        ori.w   #$8000,d0                       ; 04B3C
        move.w  d0,DSKLEN(a1)                   ; 04B40
        move.w  d0,DSKLEN(a1)                   ; 04B44
        rts                                     ; 04B48
sub_04B4A:
        lea.l   CUSTOM,a1                       ; 04B4A
        move.l  #$1770,d0                       ; 04B50
        bsr.w   sub_04CDC                       ; 04B56
l_04B5A:
        btst    #$1,$1f(a1)                     ; 04B5A
        bne.b   l_04B6C                         ; 04B60
        bsr.w   sub_04CCE                       ; 04B62
        bne.b   l_04B5A                         ; 04B66
        moveq   #-1,d0                          ; 04B68
        bra.b   sub_04B6E                       ; 04B6A
l_04B6C:
        moveq   #$0,d0                          ; 04B6C
sub_04B6E:
        move.w  #$2,(CUSTOM+INTREQ).l           ; 04B6E
        move.w  #$4000,(CUSTOM+DSKLEN).l        ; 04B76
        tst.l   d0                              ; 04B7E
        rts                                     ; 04B80
sub_04B82:
        move.w  #$400,(CUSTOM+ADKCON).l         ; 04B82
        moveq   #-1,d1                          ; 04B8A
sub_04B8C:
        move.b  d1,(CIAB_PRB).l                 ; 04B8C
        move.w  -$24(a6),d0                     ; 04B92
        addq.l  #$3,d0                          ; 04B96
        bclr    d0,d1                           ; 04B98
        move.b  d1,(CIAB_PRB).l                 ; 04B9A
        bset    d0,d1                           ; 04BA0
        move.b  d1,(CIAB_PRB).l                 ; 04BA2
        rts                                     ; 04BA8
sub_04BAA:
        moveq   #-1,d1                          ; 04BAA
        move.b  d1,(CIAB_PRB).l                 ; 04BAC
        bclr    #$7,d1                          ; 04BB2
        bsr.b   sub_04B8C                       ; 04BB6
        move.l  #$c8,d0                         ; 04BB8
        bsr.w   sub_04CBA                       ; 04BBE
        rts                                     ; 04BC2
sub_04BC4:
        movem.l d2-d3,-(a7)                     ; 04BC4
        move.l  d2,d3                           ; 04BC8
        bsr.w   sub_04C7A                       ; 04BCA
        move.w  -$24(a6),d0                     ; 04BCE
        add.w   d0,d0                           ; 04BD2
        lea.l   dat_04CF6(pc),a0                ; 04BD4
        move.w  (a0,d0.w),d0                    ; 04BD8
        bpl.b   l_04BE4                         ; 04BDC
        bsr.w   sub_04C1A                       ; 04BDE
        bne.b   l_04C14                         ; 04BE2
l_04BE4:
        lsr.w   #$1,d0                          ; 04BE4
        lsr.w   #$1,d2                          ; 04BE6
        moveq   #$1,d1                          ; 04BE8
        sub.w   d0,d2                           ; 04BEA
        beq.b   l_04C00                         ; 04BEC
        bpl.b   l_04BF4                         ; 04BEE
        moveq   #-1,d1                          ; 04BF0
        neg.w   d2                              ; 04BF2
l_04BF4:
        moveq   #$6,d0                          ; 04BF4
l_04BF6:
        bsr.w   sub_04C50                       ; 04BF6
        moveq   #$6,d0                          ; 04BFA
        subq.w  #$1,d2                          ; 04BFC
        bne.b   l_04BF6                         ; 04BFE
l_04C00:
        move.w  -$24(a6),d0                     ; 04C00
        add.w   d0,d0                           ; 04C04
        lea.l   dat_04CF6(pc),a0                ; 04C06
        move.w  d3,(a0,d0.w)                    ; 04C0A
        bsr.w   sub_04C7A                       ; 04C0E
        moveq   #$0,d0                          ; 04C12
l_04C14:
        movem.l (a7)+,d2-d3                     ; 04C14
        rts                                     ; 04C18
sub_04C1A:
        movem.l d2,-(a7)                        ; 04C1A
        moveq   #$55,d2                         ; 04C1E
l_04C20:
        btst    #$4,(CIAA_PRA).l                ; 04C20
        beq.b   l_04C3A                         ; 04C28
        moveq   #$6,d0                          ; 04C2A
        moveq   #-1,d1                          ; 04C2C
        bsr.w   sub_04C50                       ; 04C2E
        dbra    d2,l_04C20                      ; 04C32
        moveq   #$1e,d0                         ; 04C36
        bra.b   l_04C4A                         ; 04C38
l_04C3A:
        move.w  -$24(a6),d0                     ; 04C3A
        add.w   d0,d0                           ; 04C3E
        lea.l   dat_04CF6(pc),a0                ; 04C40
        clr.w   (a0,d0.w)                       ; 04C44
        moveq   #$0,d0                          ; 04C48
l_04C4A:
        movem.l (a7)+,d2                        ; 04C4A
        rts                                     ; 04C4E
sub_04C50:
        move.l  d0,-(a7)                        ; 04C50
        bsr.w   sub_04C86                       ; 04C52
        tst.b   d1                              ; 04C56
        bmi.b   l_04C5E                         ; 04C58
        bclr    #$1,d0                          ; 04C5A
l_04C5E:
        bclr    #$0,d0                          ; 04C5E
        move.b  d0,(CIAB_PRB).l                 ; 04C62
        bset    #$0,d0                          ; 04C68
        move.b  d0,(CIAB_PRB).l                 ; 04C6C
        move.l  (a7)+,d0                        ; 04C72
        bsr.w   sub_04CBA                       ; 04C74
        rts                                     ; 04C78
sub_04C7A:
        bsr.w   sub_04C86                       ; 04C7A
        move.b  d0,(CIAB_PRB).l                 ; 04C7E
        rts                                     ; 04C84
sub_04C86:
        movem.w d1-d2,-(a7)                     ; 04C86
        move.w  -$24(a6),d0                     ; 04C8A
        move.b  (CIAB_PRB).l,d2                 ; 04C8E
        ori.b   #$7f,d2                         ; 04C94
        addi.b  #$3,d0                          ; 04C98
        bclr    d0,d2                           ; 04C9C
        subi.b  #$3,d0                          ; 04C9E
        add.w   d0,d0                           ; 04CA2
        move.w  dat_04CF6(pc,d0.w),d1           ; 04CA4
        btst    #$0,d1                          ; 04CA8
        beq.b   l_04CB2                         ; 04CAC
        bclr    #$2,d2                          ; 04CAE
l_04CB2:
        move.b  d2,d0                           ; 04CB2
        movem.w (a7)+,d1-d2                     ; 04CB4
        rts                                     ; 04CB8
sub_04CBA:
        bsr.w   sub_04CDC                       ; 04CBA
l_04CBE:
        btst    #$0,(CIAA_CRA).l                ; 04CBE
        bne.b   l_04CBE                         ; 04CC6
        subq.l  #$1,d0                          ; 04CC8
        bne.b   sub_04CBA                       ; 04CCA
        rts                                     ; 04CCC
sub_04CCE:
        btst    #$0,(CIAA_CRA).l                ; 04CCE
        bne.b   l_04CF4                         ; 04CD6
        subq.l  #$1,d0                          ; 04CD8
        beq.b   l_04CF4                         ; 04CDA
sub_04CDC:
        move.b  #$8,(CIAA_CRA).l                ; 04CDC
        move.b  #$cc,(CIAA_TALO).l              ; 04CE4
        move.b  #$2,(CIAA_TAHI).l               ; 04CEC
l_04CF4:
        rts                                     ; 04CF4
dat_04CF6:
	dc.b	$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$60,$00,$7D,$44,$00,$00
PicturePalette:
	dc.w	$0011,$0000,$0222,$0333,$0444,$0555,$0666,$0777
	dc.w	$0100,$0200,$0300,$0400,$0500,$0600,$0700,$0454

;-------------------------------------------------------------------------------
; The loading picture: 320x200, 4 planes interleaved by word.
;-------------------------------------------------------------------------------
PictureData:
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$3F,$00,$3F,$00,$3F,$00,$3F
	dc.b	$80,$00,$80,$00,$80,$00,$80
	dcb.b	34,$00
	dc.b	$3F,$00,$3F,$00,$3F,$00,$3F,$80,$00,$80,$00,$80,$00,$80,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$1F
	dc.b	$80,$1F,$80,$1F,$80,$1F,$80
	dcb.b	72,$00
	dc.b	$03,$FF,$03,$FF,$03,$FF,$03,$FF,$E0,$00,$E0,$00,$E0,$00,$E0
	dcb.b	33,$00
	dc.b	$03,$FF,$03,$FF,$03,$FF,$03,$FF,$E0,$00,$E0,$00,$E0,$00,$E0,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$FF,$E0,$FF,$E0,$FF,$E0,$FF,$E0
	dcb.b	72,$00
	dc.b	$1F,$FF,$1F,$FF,$1F,$FF,$1F,$C0,$F0,$00,$F0,$00,$F0,$00,$70
	dcb.b	33,$00
	dc.b	$1F,$FF,$1F,$FF,$1F,$FF,$1F,$C0,$F0,$00,$F0,$00,$F0,$00,$70,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$03,$00,$03,$00,$03,$00,$03
	dc.b	$FF,$F0,$FF,$F0,$FF,$F0,$E0,$70
	dcb.b	72,$00
	dc.b	$7F,$FF,$7F,$FF,$7F,$FF,$7C,$00,$F8,$00,$F8,$00,$F8,$00,$18
	dcb.b	33,$00
	dc.b	$7F,$FF,$7F,$FF,$7F,$FF,$7C,$00,$F8,$00,$F8,$00,$F8,$00,$18,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$0F,$00,$0F,$00,$0F,$00,$0F
	dc.b	$FF,$F8,$FF,$F8,$FF,$F8,$00,$18,$7F,$00,$7F,$00,$7F,$00,$7F,$00
	dc.b	$3F,$E1,$3F,$E1,$3F,$E1,$3F,$E1,$FF,$FB,$FF,$FB,$FF,$FB,$FF,$FB
	dc.b	$FF,$C0,$FF,$C0,$FF,$C0,$FF,$C0
	dcb.b	33,$00
	dc.b	$01,$00,$01,$00,$01,$00,$01,$E0,$3F,$FF,$FF,$FF,$FF,$E0,$00,$CF
	dc.b	$EF,$FF,$EF,$FF,$EF,$0F,$EF,$C7,$EF,$C7,$EF,$C7,$EF,$C7,$EF,$C3
	dc.b	$F7,$C3,$F7,$C3,$F7,$C3,$F7,$FF,$FC,$FF,$FC,$FF,$FC,$FF,$FC,$00
	dc.b	$03,$00,$03,$00,$03,$00,$03,$E0,$3F,$FF,$FF,$FF,$FF,$E0,$00,$CC
	dc.b	$FF,$FC,$FF,$FC,$FF,$0C,$FF,$F0,$00,$F0,$00,$F0,$00,$F0,$00,$00
	dc.b	$3C,$00,$3F,$00,$3F,$00,$3C,$3F,$CD,$FF,$FD,$FF,$FD,$00,$0D,$FF
	dc.b	$C0,$FF,$C0,$FF,$C0,$FF,$C0,$FF,$FB,$FF,$FB,$FF,$FB,$FF,$FB,$FF
	dc.b	$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$F0,$FF,$F0,$FF,$F0,$FF,$F0
	dcb.b	33,$00
	dc.b	$03,$00,$03,$00,$03,$00,$03,$83,$FF,$FF,$E0,$FF,$E0,$80,$00,$B7
	dc.b	$FF,$CF,$FF,$CF,$FF,$07,$FF,$EF,$FF,$EF,$FF,$EF,$FF,$EF,$FF,$E7
	dc.b	$FF,$E7,$FF,$E7,$FF,$E7,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$00
	dc.b	$0F,$00,$0F,$00,$0F,$00,$0F,$83,$FF,$FF,$F0,$FF,$F0,$80,$00,$E7
	dc.b	$FF,$9F,$FF,$9F,$FF,$07,$FF,$FC,$00,$FC,$00,$FC,$00,$FC,$00,$00
	dc.b	$70,$00,$7F,$00,$7F,$00,$70,$FF,$E7,$E1,$FF,$E1,$FF,$00,$07,$00
	dc.b	$61,$FF,$E1,$FF,$E1,$00,$61,$C0,$1E,$FF,$FF,$FF,$FF,$C0,$1E,$00
	dc.b	$04,$FF,$FF,$FF,$FF,$00,$04,$00,$38,$FF,$F8,$FF,$F8,$00,$38
	dcb.b	33,$00
	dc.b	$07,$00,$07,$00,$07,$00,$07,$FF,$FF,$1F,$80,$FF,$80,$00,$00,$FF
	dc.b	$FF,$00,$10,$1F,$FF,$00,$10,$FF,$FF,$38,$10,$FF,$FF,$38,$10,$FF
	dc.b	$FF,$3C,$08,$FF,$FF,$3C,$08,$FF,$FF,$00,$01,$FF,$FF,$00,$01,$80
	dc.b	$1F,$80,$1C,$80,$1F,$80,$1C,$FF,$FF,$1F,$80,$FF,$80,$00,$00,$FF
	dc.b	$FF,$07,$00,$1F,$FF,$07,$00,$FE,$00,$0E,$00,$FE,$00,$0E,$00,$01
	dc.b	$FF,$01,$C3,$01,$FF,$01,$C0,$FF,$FF,$80,$F2,$80,$FF,$00,$02,$FF
	dc.b	$F3,$00,$33,$FF,$F3,$00,$33,$FF,$FF,$00,$04,$FF,$FF,$00,$04,$FF
	dc.b	$FF,$00,$00,$FF,$FF,$00,$00,$FF,$FC,$00,$0C,$FF,$FC,$00,$0C
	dcb.b	33,$00
	dc.b	$0F,$00,$0E,$00,$0F,$00,$0E,$FF,$FF,$7E,$00,$FE,$00,$00,$00,$FF
	dc.b	$FF,$00,$00,$3F,$FF,$00,$00,$FF,$FF,$10,$00,$FF,$FF,$10,$00,$FF
	dc.b	$FF,$18,$00,$FF,$FF,$18,$00,$FF,$FF,$00,$00,$FF,$FF,$00,$00,$C0
	dc.b	$7F,$C0,$70,$C0,$7F,$C0,$70,$FF,$FF,$7E,$00,$FE,$00,$00,$00,$FF
	dc.b	$FF,$06,$00,$1F,$FF,$06,$00,$FF,$00,$03,$00,$FF,$00,$03,$00,$03
	dc.b	$FF,$03,$8F,$03,$FF,$03,$80,$FF,$FF,$00,$F0,$00,$F7,$00,$00,$FF
	dc.b	$FF,$FF,$9E,$FF,$FF,$00,$1E,$FF,$FF,$3F,$E1,$FF,$FF,$00,$00,$FF
	dc.b	$FF,$FF,$FB,$FF,$FF,$00,$00,$FF,$FE,$FF,$C6,$FF,$FE,$00,$06
	dcb.b	33,$00
	dc.b	$1C,$00,$1C,$00,$1F,$00,$1C,$07,$80,$F8,$7F,$F8,$7F,$00,$00,$00
	dc.b	$00,$FF,$EF,$FF,$FF,$00,$00,$00,$00,$C7,$EF,$FF,$FF,$00,$00,$00
	dc.b	$00,$C3,$F7,$FF,$FF,$00,$00,$00,$00,$FF,$FE,$FF,$FF,$00,$00,$60
	dc.b	$E0,$60,$E3,$E0,$FF,$60,$E0,$07,$80,$F8,$7F,$F8,$7F,$00,$00,$0C
	dc.b	$00,$CC,$FF,$FF,$FF,$0C,$00,$01,$80,$F1,$80,$FF,$80,$01,$80,$06
	dc.b	$01,$06,$3E,$07,$FE,$06,$00,$F0,$00,$01,$F8,$0F,$FF,$00,$00,$00
	dc.b	$4C,$FF,$8C,$FF,$BF,$00,$0C,$00,$00,$FF,$F9,$FF,$FF,$00,$00,$00
	dc.b	$04,$FF,$FB,$FF,$FB,$00,$00,$00,$03,$FF,$F3,$FF,$FF,$00,$03
	dcb.b	33,$00
	dc.b	$38,$00,$39,$00,$3F,$00,$38,$0F,$80,$F0,$7F,$F0,$7F,$00,$00,$00
	dc.b	$10,$FF,$EF,$FF,$EF,$00,$00,$20,$10,$C7,$EF,$DF,$EF,$00,$00,$00
	dc.b	$08,$E3,$F7,$FF,$F7,$00,$00,$00,$01,$FF,$FE,$FF,$FE,$00,$00,$21
	dc.b	$80,$21,$8F,$E1,$FF,$21,$80,$1F,$80,$E0,$7F,$E0,$7F,$00,$00,$24
	dc.b	$00,$C4,$FF,$DF,$FF,$04,$00,$00,$C0,$FC,$C0,$FF,$C0,$00,$C0,$0C
	dc.b	$03,$0C,$7C,$0F,$FC,$0C,$00,$C0,$04,$01,$F9,$3F,$FB,$00,$00,$00
	dc.b	$0C,$FF,$CC,$FF,$FF,$00,$0C,$00,$04,$FF,$F9,$FF,$FB,$00,$00,$00
	dc.b	$04,$FF,$FB,$FF,$FB,$00,$00,$00,$09,$FF,$F1,$FF,$F7,$00,$01
	dcb.b	33,$00
	dc.b	$3F,$00,$3C,$00,$33,$00,$30,$FF,$FF,$00,$80,$E0,$7F,$00,$00,$FF
	dc.b	$FF,$00,$00,$FF,$EF,$00,$00,$FF,$FF,$18,$00,$C7,$EF,$00,$00,$FF
	dc.b	$FF,$0C,$00,$F3,$F7,$00,$00,$FF,$FF,$00,$00,$FF,$FE,$00,$00,$F3
	dc.b	$FF,$F3,$E0,$33,$1F,$33,$00,$FF,$FF,$00,$00,$C0,$FF,$00,$00,$FF
	dc.b	$FF,$1F,$00,$E4,$FF,$04,$00,$FF,$E0,$01,$E0,$FC,$60,$00,$60,$1F
	dc.b	$FF,$1E,$00,$19,$FC,$18,$00,$FF,$FF,$7C,$02,$03,$F1,$00,$00,$FF
	dc.b	$FF,$00,$1E,$FF,$C1,$00,$00,$FF,$FF,$00,$02,$FF,$FD,$00,$00,$FF
	dc.b	$FF,$00,$00,$FF,$FB,$00,$00,$FF,$FF,$00,$07,$FF,$F9,$00,$01,$80
	dc.b	$00,$80,$00,$80,$00,$80,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$7F,$00,$78,$00,$67,$00,$60,$FF,$FF,$03,$80,$C0,$7F,$00,$00,$FF
	dc.b	$FF,$00,$00,$FF,$EF,$00,$00,$FF,$FF,$18,$00,$C7,$EF,$00,$00,$FF
	dc.b	$FF,$04,$00,$FB,$F7,$00,$00,$FF,$FF,$00,$00,$FF,$FE,$00,$00,$F7
	dc.b	$FF,$F7,$80,$36,$7F,$36,$00,$FF,$FF,$03,$00,$00,$FF,$00,$00,$FF
	dc.b	$FF,$0F,$00,$E0,$FF,$00,$00,$FF,$E0,$01,$E0,$FE,$60,$00,$60,$3F
	dc.b	$FF,$3C,$00,$33,$F8,$30,$00,$FF,$FF,$F8,$02,$27,$F1,$20,$00,$FF
	dc.b	$FF,$00,$1E,$FF,$C1,$00,$00,$FF,$FF,$00,$00,$FC,$FD,$00,$00,$FF
	dc.b	$FF,$00,$00,$F8,$03,$00,$00,$FF,$FF,$00,$03,$F1,$F8,$00,$00,$80
	dc.b	$00,$80,$00,$80,$00,$80,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$C0,$00,$F0,$00,$CF,$00,$C0,$38,$00,$07,$80,$C0,$7F,$00,$00,$00
	dc.b	$10,$00,$00,$FF,$EF,$00,$00,$20,$10,$18,$00,$C7,$EF,$00,$00,$00
	dc.b	$08,$00,$00,$FF,$F7,$00,$00,$00,$01,$00,$00,$FF,$FE,$00,$00,$3C
	dc.b	$01,$FF,$00,$3C,$FE,$3C,$00,$F0,$00,$0F,$00,$00,$FF,$00,$00,$10
	dc.b	$03,$0F,$00,$E0,$FC,$00,$00,$81,$30,$00,$F0,$7E,$30,$00,$30,$60
	dc.b	$0E,$78,$01,$67,$F0,$60,$00,$00,$1C,$F0,$00,$0F,$E3,$00,$00,$00
	dc.b	$00,$00,$1E,$FF,$E1,$00,$00,$07,$82,$00,$00,$F8,$7D,$00,$00,$07
	dc.b	$FC,$00,$00,$F8,$03,$00,$00,$0F,$04,$00,$03,$F0,$F8,$00,$00,$80
	dc.b	$00,$80,$00,$80,$00,$80,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$C0,$00,$F0,$00,$CF,$00,$C0,$33,$3E,$0F,$C0,$C3,$01,$03,$00,$07
	dc.b	$F0,$00,$00,$F8,$0F,$00,$00,$20,$10,$18,$00,$C7,$EF,$00,$00,$00
	dc.b	$0B,$00,$04,$FF,$F0,$00,$00,$E0,$7F,$00,$00,$1F,$80,$00,$00,$38
	dc.b	$03,$FE,$00,$39,$FC,$38,$00,$E0,$00,$1E,$00,$01,$FF,$00,$00,$00
	dc.b	$03,$0F,$00,$F0,$FC,$00,$00,$C1,$30,$00,$F0,$3E,$30,$00,$30,$C0
	dc.b	$1E,$F0,$01,$CF,$E0,$C0,$00,$00,$38,$E0,$04,$1F,$C3,$00,$00,$08
	dc.b	$10,$00,$0E,$F7,$E1,$00,$00,$07,$FE,$00,$00,$F8,$01,$00,$00,$07
	dc.b	$FC,$00,$00,$F8,$03,$00,$00,$0F,$04,$00,$03,$F0,$F8,$00,$00,$C0
	dc.b	$00,$C0,$00,$C0,$00,$C0,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$01
	dc.b	$FF,$01,$9F,$01,$80,$01,$80,$FF,$FF,$E1,$01,$01,$00,$01,$00,$FF
	dc.b	$FF,$F8,$0F,$00,$00,$00,$00,$FF,$FF,$C7,$EF,$00,$00,$00,$00,$FF
	dc.b	$FF,$FF,$F0,$00,$00,$00,$00,$FF,$FF,$1F,$80,$00,$00,$00,$00,$FF
	dc.b	$FF,$33,$F8,$30,$00,$30,$00,$FF,$FF,$09,$FB,$08,$00,$08,$00,$FF
	dc.b	$FF,$F0,$FC,$00,$00,$00,$00,$FF,$F1,$3E,$31,$00,$31,$00,$31,$FF
	dc.b	$FF,$9F,$E0,$80,$00,$80,$00,$FF,$FF,$7F,$03,$00,$00,$00,$00,$FF
	dc.b	$FF,$F7,$E1,$00,$00,$00,$00,$FF,$FF,$F8,$01,$00,$00,$00,$00,$FF
	dc.b	$FF,$FF,$FB,$00,$00,$00,$00,$FF,$FF,$F1,$F8,$00,$00,$00,$00,$C0
	dc.b	$00,$C0,$00,$C0,$00,$C0,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$01
	dc.b	$FF,$01,$9F,$01,$80,$01,$80,$FF,$FF,$F0,$01,$00,$00,$00,$00,$FF
	dc.b	$FF,$F8,$0F,$00,$00,$00,$00,$FF,$FF,$C7,$EF,$00,$00,$00,$00,$FF
	dc.b	$FF,$DF,$F0,$00,$00,$00,$00,$FF,$FF,$1F,$80,$00,$00,$00,$00,$FF
	dc.b	$FF,$27,$F8,$20,$00,$20,$00,$FF,$FF,$19,$FB,$18,$00,$18,$00,$FF
	dc.b	$FF,$F0,$FC,$00,$00,$00,$00,$FF,$F3,$7E,$33,$00,$33,$00,$33,$FF
	dc.b	$FF,$3F,$C1,$00,$00,$00,$00,$FF,$FF,$FC,$07,$00,$00,$00,$00,$FF
	dc.b	$FF,$F7,$F1,$00,$00,$00,$00,$FF,$FF,$F8,$01,$00,$00,$00,$00,$FF
	dc.b	$FF,$FF,$FB,$00,$00,$00,$00,$FF,$FF,$FF,$F0,$00,$00,$00,$00,$C0
	dc.b	$00,$C0,$00,$C0,$00,$C0,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$03
	dc.b	$00,$03,$3F,$03,$00,$03,$C0,$00,$00,$FC,$01,$00,$00,$03,$FE,$04
	dc.b	$00,$F8,$0F,$00,$00,$03,$F0,$20,$10,$C7,$EF,$00,$00,$18,$00,$30
	dc.b	$08,$CF,$F0,$00,$00,$00,$07,$00,$40,$1F,$80,$00,$00,$E0,$3F,$40
	dc.b	$0E,$4F,$F0,$40,$00,$F0,$01,$70,$04,$73,$FB,$70,$00,$FC,$00,$00
	dc.b	$00,$F8,$FF,$00,$00,$07,$00,$03,$33,$FC,$33,$00,$33,$00,$F3,$00
	dc.b	$70,$3F,$8F,$00,$00,$C0,$00,$0F,$E0,$F0,$07,$00,$00,$00,$18,$18
	dc.b	$08,$E3,$F1,$00,$00,$04,$06,$04,$80,$F8,$81,$00,$80,$03,$FE,$00
	dc.b	$04,$FF,$FB,$00,$00,$00,$00,$00,$0C,$FF,$F0,$00,$00,$00,$03,$C0
	dc.b	$00,$C0,$00,$C0,$00,$C0,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$03
	dc.b	$00,$03,$3F,$03,$00,$03,$C0,$00,$00,$FF,$01,$00,$00,$00,$FE,$04
	dc.b	$00,$F8,$0F,$00,$00,$03,$F0,$20,$10,$C7,$EF,$00,$00,$18,$00,$38
	dc.b	$08,$C7,$F0,$00,$00,$00,$07,$00,$40,$1F,$80,$00,$00,$E0,$3F,$C0
	dc.b	$1C,$CF,$E0,$C0,$00,$F0,$03,$F0,$0C,$F3,$F1,$F0,$00,$FC,$02,$04
	dc.b	$00,$F8,$FF,$00,$00,$03,$00,$03,$36,$FC,$36,$00,$36,$00,$F7,$00
	dc.b	$00,$7F,$FF,$00,$00,$80,$00,$7F,$80,$80,$07,$00,$00,$00,$78,$18
	dc.b	$08,$E3,$F1,$00,$00,$04,$06,$04,$80,$F8,$81,$00,$80,$03,$FE,$00
	dc.b	$04,$FF,$FB,$00,$00,$00,$00,$00,$3C,$FF,$C0,$00,$00,$00,$03,$C0
	dc.b	$00,$C0,$00,$C0,$00,$C0,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$03
	dc.b	$FF,$03,$00,$03,$00,$03,$C0,$FF,$FF,$00,$18,$00,$18,$00,$7E,$FF
	dc.b	$FF,$00,$C0,$00,$C0,$03,$F0,$FF,$FF,$00,$00,$00,$00,$18,$00,$FF
	dc.b	$FF,$00,$01,$00,$01,$10,$07,$FF,$FF,$80,$0F,$80,$0F,$E0,$3F,$FF
	dc.b	$FF,$80,$00,$80,$00,$E0,$03,$FF,$FF,$F0,$00,$F0,$00,$FC,$02,$FF
	dc.b	$FF,$00,$00,$00,$00,$03,$00,$FF,$F7,$00,$36,$00,$36,$00,$F7,$FF
	dc.b	$FF,$00,$00,$00,$00,$80,$00,$FF,$FF,$00,$00,$00,$00,$01,$F0,$FF
	dc.b	$FF,$00,$00,$00,$00,$00,$06,$FF,$FF,$00,$00,$00,$00,$03,$FE,$FF
	dc.b	$FF,$00,$00,$00,$00,$00,$00,$FF,$FF,$00,$01,$00,$01,$00,$07,$80
	dc.b	$00,$80,$00,$80,$00,$80,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$01
	dc.b	$FF,$01,$80,$01,$80,$01,$E0,$FF,$FF,$00,$08,$00,$08,$00,$3E,$FF
	dc.b	$FF,$00,$C0,$00,$C0,$03,$F0,$FF,$FF,$00,$00,$00,$00,$18,$00,$FF
	dc.b	$FF,$00,$01,$00,$01,$18,$07,$FF,$FF,$80,$0F,$80,$0F,$E0,$3F,$FF
	dc.b	$FF,$80,$01,$80,$01,$E0,$07,$FF,$FF,$E0,$00,$E0,$00,$F8,$00,$FF
	dc.b	$FF,$00,$00,$00,$00,$03,$00,$FF,$EF,$00,$6C,$00,$6C,$01,$EF,$FF
	dc.b	$FF,$00,$00,$00,$00,$00,$00,$FF,$FF,$00,$40,$00,$40,$07,$F0,$FF
	dc.b	$FF,$00,$00,$00,$00,$00,$02,$FF,$FF,$00,$00,$00,$00,$03,$82,$FF
	dc.b	$FF,$00,$00,$00,$00,$00,$00,$FF,$FF,$00,$01,$00,$01,$00,$07,$80
	dc.b	$00,$80,$00,$80,$00,$80,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$01
	dc.b	$80,$01,$E0,$01,$80,$01,$FF,$00,$08,$00,$3E,$00,$08,$FF,$FF,$04
	dc.b	$C0,$03,$F0,$00,$C0,$FB,$FF,$20,$10,$18,$00,$00,$00,$DF,$EF,$20
	dc.b	$09,$1C,$07,$00,$01,$DF,$F7,$80,$4F,$E0,$3F,$80,$0F,$FF,$BF,$00
	dc.b	$73,$C0,$0F,$00,$03,$FF,$8F,$60,$00,$78,$00,$60,$00,$7F,$FF,$02
	dc.b	$00,$01,$00,$00,$00,$FD,$FF,$0E,$6C,$01,$EF,$00,$6C,$F1,$EF,$01
	dc.b	$CF,$00,$00,$00,$00,$FE,$30,$C1,$C0,$3F,$F0,$01,$C0,$3F,$FF,$00
	dc.b	$04,$00,$02,$00,$00,$FF,$FB,$00,$02,$03,$00,$00,$00,$FF,$FD,$07
	dc.b	$FC,$00,$00,$00,$00,$F8,$03,$08,$03,$00,$1F,$00,$03,$F7,$FF
	dcb.b	32,$00
	dc.b	$01,$98,$01,$E0,$01,$80,$01,$E7,$00,$20,$00,$1E,$00,$00,$FF,$DF
	dc.b	$04,$C0,$03,$F0,$00,$C0,$FB,$FF,$00,$10,$00,$00,$00,$00,$FF,$EF
	dc.b	$20,$09,$1C,$07,$00,$01,$DF,$F7,$80,$4F,$E0,$3F,$80,$0F,$FF,$BF
	dc.b	$00,$66,$C0,$1E,$00,$06,$FF,$9E,$60,$00,$78,$00,$60,$00,$7F,$FF
	dc.b	$02,$02,$01,$00,$00,$00,$FD,$FD,$00,$D8,$07,$DE,$00,$D8,$FF,$DF
	dc.b	$03,$E0,$00,$07,$00,$00,$FC,$1F,$07,$80,$FF,$E0,$07,$80,$FF,$FF
	dc.b	$3E,$00,$00,$02,$00,$00,$C1,$FF,$00,$02,$00,$00,$00,$00,$FF,$FD
	dc.b	$00,$00,$00,$04,$00,$00,$FF,$FF,$0C,$03,$00,$0F,$00,$03,$F3,$FF
	dcb.b	33,$00
	dc.b	$FF,$00,$F0,$00,$C0,$00,$F0,$FF,$FF,$00,$1E,$00,$00,$FF,$DF,$FF
	dc.b	$FF,$03,$F0,$00,$C0,$FB,$FF,$FF,$FF,$00,$00,$00,$00,$FF,$EF,$FF
	dc.b	$FF,$1C,$07,$00,$01,$DF,$F7,$FF,$FF,$E0,$3F,$80,$0E,$FF,$BF,$FF
	dc.b	$FE,$80,$1E,$00,$06,$FF,$1E,$FF,$FF,$F0,$00,$C0,$00,$FF,$E0,$FF
	dc.b	$FF,$01,$00,$00,$00,$FF,$FC,$FF,$DF,$03,$DE,$00,$D8,$FF,$DF,$FF
	dc.b	$FF,$00,$C3,$00,$00,$FC,$CF,$FF,$FF,$FF,$E0,$3F,$80,$FF,$FF,$FF
	dc.b	$FF,$00,$01,$00,$00,$80,$FD,$FF,$FF,$00,$00,$00,$00,$FF,$F9,$FF
	dc.b	$FF,$00,$00,$00,$00,$FF,$FB,$FF,$FF,$00,$07,$00,$01,$F1,$FF,$80
	dc.b	$00,$80,$00,$80,$00,$80,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$FF,$00,$F0,$00,$C0,$00,$F0,$FF,$FF,$00,$1E,$00,$00,$3F,$DF,$FF
	dc.b	$FF,$03,$F8,$00,$E0,$FB,$FF,$FF,$FF,$00,$00,$00,$00,$FF,$CF,$FF
	dc.b	$FF,$1C,$07,$00,$01,$DF,$F7,$FF,$FF,$E0,$3F,$80,$0E,$FF,$BF,$FF
	dc.b	$FC,$80,$3C,$00,$0C,$FF,$3C,$FF,$FF,$F0,$00,$C0,$00,$FF,$C0,$FF
	dc.b	$FF,$00,$00,$00,$00,$7E,$FC,$FF,$FF,$01,$FC,$00,$70,$7F,$FF,$FF
	dc.b	$FF,$00,$E1,$00,$00,$F8,$E7,$F9,$FF,$F9,$E0,$79,$80,$F9,$FF,$FF
	dc.b	$FF,$00,$01,$00,$00,$80,$FD,$FF,$FF,$00,$00,$00,$00,$FF,$F9,$FF
	dc.b	$FF,$00,$00,$00,$00,$FF,$FB,$FF,$FF,$04,$03,$00,$00,$F4,$FF,$C0
	dc.b	$00,$C0,$00,$C0,$00,$C0,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$63,$00,$60,$00,$7C,$00,$7C,$E0,$20,$1F,$C1,$00,$1E,$1F,$DF,$04
	dc.b	$E0,$F8,$E7,$03,$F8,$FB,$FF,$00,$30,$FF,$CF,$00,$00,$FF,$CF,$20
	dc.b	$09,$C3,$F1,$1C,$07,$DF,$F7,$80,$4E,$9F,$8E,$E0,$3F,$FF,$BF,$00
	dc.b	$CC,$7F,$0C,$80,$3C,$FF,$3C,$C0,$3F,$CF,$C0,$F0,$00,$FF,$C0,$81
	dc.b	$02,$7E,$FC,$00,$01,$7E,$FD,$C0,$30,$3F,$33,$00,$FC,$3F,$FF,$0E
	dc.b	$4C,$F0,$43,$01,$F0,$F1,$F3,$39,$80,$39,$9F,$F9,$E0,$F9,$FF,$60
	dc.b	$02,$80,$FC,$1F,$01,$9F,$FD,$C0,$1E,$3F,$E1,$00,$00,$3F,$E1,$00
	dc.b	$04,$FF,$FB,$00,$00,$FF,$FB,$09,$82,$F0,$7C,$06,$01,$F6,$7D,$40
	dc.b	$00,$40,$00,$C0,$00,$C0,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	'p0p0p?p?p '
	dc.b	$0F,$C1,$80,$1E,$8F,$DF,$04,$E6,$F8,$E1,$03,$F8,$FB,$F9,$00,$F0
	dc.b	$FF,$0F,$00,$00,$FF,$0F,$20,$09,$C3,$F1,$1C,$07,$DF,$F7,$80,$4C
	dc.b	$9F,$8C,$E0,$3F,$FF,$BF,$01,$98,$FE,$18,$00,$78,$FE,$78,$C0,$30
	dc.b	$CF,$C0,$F0,$0F,$FF,$CF,$01,$02,$7E,$FC,$80,$01,$FE,$FD,$60,$80
	dc.b	$1F,$07,$80,$78,$9F,$7F,$0E,$64,$F0,$63,$01,$F8,$F1,$FB,$1C,$CF
	dc.b	$9C,$C0,$7C,$F0,$FC,$F0,$C0,$7E,$00,$00,$3F,$81,$3F,$81,$7F,$FC
	dc.b	$00,$00,$80,$03,$80,$03,$FF,$FD,$00,$00,$00,$02,$00,$02,$F8,$FE
	dc.b	$00,$00,$07,$01,$07,$01,$60,$00,$60,$00,$E0,$00,$E0,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$01
	dc.b	$00,$01,$00,$01,$00,$01,$FC,$1F,$FC,$1C,$FC,$1F,$FC,$1F,$FF,$FF
	dc.b	$07,$84,$E0,$1F,$E7,$9F,$FF,$FF,$00,$F0,$03,$FC,$03,$FC,$FF,$FF
	dc.b	$00,$00,$00,$18,$00,$18,$FF,$FF,$00,$01,$1E,$07,$1E,$07,$FF,$FF
	dc.b	$C0,$0C,$F0,$3F,$F0,$3F,$FF,$F8,$FE,$18,$00,$78,$FE,$78,$7F,$FF
	dc.b	$60,$00,$78,$1F,$78,$1F,$FF,$FF,$00,$00,$C0,$81,$C0,$81,$FF,$FF
	dc.b	$00,$07,$C0,$78,$C0,$7F,$FF,$FF,$E0,$F1,$03,$FC,$E3,$FD,$FF,$FF
	dc.b	$C7,$C0,$3F,$F0,$FF,$F0,$FF,$FF,$0E,$00,$3F,$81,$3F,$81,$FF,$FF
	dc.b	$00,$00,$80,$03,$80,$03,$FF,$FF,$00,$00,$00,$02,$00,$02,$FF,$FF
	dc.b	$00,$00,$07,$81,$07,$81,$E0,$00,$60,$00,$E0,$00,$E0,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$03
	dc.b	$00,$03,$00,$03,$00,$03,$FF,$0F,$0F,$0F,$FF,$0F,$FF,$0F,$FF,$FF
	dc.b	$87,$84,$F0,$1F,$F7,$9F,$FF,$FF,$00,$F0,$03,$FC,$03,$FC,$FF,$FF
	dc.b	$00,$00,$00,$18,$00,$18,$FF,$FF,$00,$01,$1E,$07,$1E,$07,$FF,$FF
	dc.b	$C0,$0C,$F0,$3F,$F0,$3F,$FF,$F8,$FE,$18,$00,$78,$FE,$78,$7F,$FF
	dc.b	$60,$07,$78,$1F,$78,$1F,$FF,$FF,$00,$00,$C0,$81,$C0,$81,$FF,$FF
	dc.b	$00,$0F,$E0,$70,$E0,$7F,$FF,$9F,$C1,$98,$07,$9E,$C7,$9E,$FF,$FF
	dc.b	$E3,$C0,$1F,$F0,$FF,$F0,$FF,$FF,$0E,$00,$3F,$81,$3F,$81,$FF,$FF
	dc.b	$00,$00,$E0,$0F,$E0,$0F,$FF,$FF,$00,$00,$00,$02,$00,$02,$FF,$FF
	dc.b	$01,$00,$07,$C1,$07,$C1,$C0,$00,$40,$00,$C0,$00,$C0,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$06
	dc.b	$00,$07,$00,$07,$00,$07,$03,$C3,$FF,$C3,$FF,$C3,$FF,$C3,$E0,$E4
	dc.b	$F8,$1F,$FF,$1F,$FF,$1F,$FC,$D8,$03,$DF,$03,$DF,$03,$DF,$FF,$87
	dc.b	$00,$78,$00,$78,$00,$78,$E1,$F9,$1E,$07,$1E,$07,$1E,$07,$CF,$CC
	dc.b	$F0,$3F,$F0,$3F,$F0,$3F,$00,$BF,$00,$7F,$FF,$7F,$FF,$7F,$E0,$E7
	dc.b	$F8,$1F,$FF,$1F,$FF,$1F,$3F,$7E,$C0,$81,$C0,$81,$C0,$81,$4F,$80
	dc.b	$F0,$60,$F0,$7F,$F0,$7F,$79,$99,$07,$9E,$87,$9E,$87,$9E,$80,$E0
	dc.b	$07,$FF,$7F,$FF,$7F,$FF,$1F,$00,$FF,$FF,$FF,$FF,$FF,$FF,$80,$02
	dc.b	$FF,$FF,$FF,$FF,$FF,$FF,$00,$00,$FF,$FF,$FF,$FF,$FF,$FF,$03,$80
	dc.b	$FF,$FF,$FF,$FF,$FF,$FF,$C0,$00,$C0,$00,$C0,$00,$C0,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$04
	dc.b	$00,$07,$00,$07,$00,$07,$00,$FF,$0F,$FF,$FF,$FF,$FF,$FF,$C1,$CE
	dc.b	$F8,$3F,$FE,$3F,$FE,$3F,$01,$8C,$FF,$8F,$FF,$8F,$FF,$8F,$00,$10
	dc.b	$FF,$FF,$FF,$FF,$FF,$FF,$0C,$03,$FF,$FF,$FF,$FF,$FF,$FF,$60,$1C
	dc.b	$7F,$FF,$7F,$FF,$7F,$FF,$00,$9F,$00,$7F,$FF,$7F,$FF,$7F,$81,$8D
	dc.b	$F8,$7D,$FE,$7D,$FE,$7D,$80,$00,$FF,$FF,$FF,$FF,$FF,$FF,$E0,$00
	dc.b	$FF,$E0,$FF,$FF,$FF,$FF,$F3,$0C,$0F,$0F,$0F,$0F,$0F,$0F,$C0,$10
	dc.b	$03,$FF,$3F,$FF,$3F,$FF,$07,$81,$FF,$FF,$FF,$FF,$FF,$FF,$E0,$0F
	dc.b	$FF,$FF,$FF,$FF,$FF,$FF,$00,$02,$FF,$FF,$FF,$FF,$FF,$FF,$06,$C1
	dc.b	$FE,$FF,$FE,$FF,$FE,$FF,$80,$00,$80,$00,$80,$00,$80,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$06
	dc.b	$00,$07,$00,$07,$00,$07,$7C,$3F,$83,$FF,$FF,$FF,$FF,$FF,$0F,$CF
	dc.b	$F0,$3F,$FC,$3F,$FC,$3F,$03,$07,$FF,$07,$FF,$07,$FF,$07,$00,$78
	dc.b	$FF,$FF,$FF,$FF,$FF,$FF,$1E,$06,$FF,$FE,$FF,$FE,$FF,$FE,$30,$36
	dc.b	$3F,$F7,$3F,$F7,$3F,$F7,$7F,$80,$80,$7F,$FF,$FF,$FF,$FF,$0F,$98
	dc.b	$F0,$78,$FC,$78,$FC,$78,$C0,$81,$FF,$FF,$FF,$FF,$FF,$FF,$B0,$3F
	dc.b	$BF,$C0,$BF,$FE,$BF,$FE,$E6,$06,$1E,$07,$1E,$07,$1E,$07,$7F,$00
	dc.b	$80,$FF,$8F,$FF,$8F,$FF,$03,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$7F,$FD
	dc.b	$7F,$FD,$7F,$FD,$7F,$FD,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FC,$7F
	dc.b	$FC,$7F,$FC,$7F,$FC,$7F,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$06
	dc.b	$00,$07,$00,$07,$00,$07,$7F,$00,$80,$FF,$FF,$FF,$FF,$FF,$3F,$99
	dc.b	$C0,$79,$F8,$79,$F8,$79,$FE,$03,$FE,$03,$FE,$03,$FE,$03,$FF,$EF
	dc.b	$FF,$EF,$FF,$EF,$FF,$EF,$F3,$FC,$F3,$FC,$F3,$FC,$F3,$FC,$1F,$E6
	dc.b	$1F,$E7,$1F,$E7,$1F,$E7,$7F,$E0,$80,$1F,$FF,$FF,$FF,$FF,$7F,$98
	dc.b	$80,$78,$F8,$78,$F8,$78,$7F,$FF,$7F,$FF,$7F,$FF,$7F,$FF,$1C,$7F
	dc.b	$1F,$80,$1F,$FC,$1F,$FC,$CC,$03,$3C,$03,$3C,$03,$3C,$03,$3F,$E0
	dc.b	$C0,$1F,$C7,$FF,$C7,$FF,$39,$FE,$C7,$FE,$FF,$FE,$FF,$FE,$1F,$F0
	dc.b	$1F,$F0,$1F,$F0,$1F,$F0,$7F,$FD,$7F,$FD,$7F,$FD,$7F,$FD,$F0,$1C
	dc.b	$F0,$1C,$F0,$1C,$F0,$1C,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$06
	dc.b	$00,$07,$00,$07,$00,$07,$40,$00,$BF,$FF,$BF,$FF,$BF,$FF,$0F,$30
	dc.b	$F0,$F0,$F0,$F0,$F0,$F0,$7C,$00,$7C,$00,$7C,$00,$7C,$00,$FF,$87
	dc.b	$FF,$87,$FF,$87,$FF,$87,$C0,$F0,$C0,$F0,$C0,$F0,$C0,$F0,$07,$86
	dc.b	$07,$87,$07,$87,$07,$87,$40,$00,$BF,$FF,$BF,$FF,$BF,$FF,$0F,$30
	dc.b	$F0,$F0,$F0,$F0,$F0,$F0,$1F,$7C,$1F,$7C,$1F,$7C,$1F,$7C,$30,$0F
	dc.b	$3F,$F0,$3F,$F0,$3F,$F0,$98,$01,$78,$01,$78,$01,$78,$01,$9C,$00
	dc.b	$E3,$FF,$E3,$FF,$E3,$FF,$1C,$C0,$E3,$C0,$E3,$C0,$E3,$C0
	dcb.b	49,$00
	dc.b	$03,$00,$03,$00,$03,$00,$03,$20,$00,$DF,$FF,$DF,$FF,$DF,$FF,$3E
	dc.b	$60,$C1,$E0,$C1,$E0,$C1,$E0,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$03,$00,$03,$00,$03,$00,$03,$20,$00,$DF,$FF,$DF,$FF,$DF,$FF,$3E
	dc.b	$60,$C1,$E0,$C1,$E0,$C1,$E0,$00,$00,$00,$00,$00,$00,$00,$00,$60
	dc.b	$3F,$7F,$C0,$7F,$C0,$7F,$C0,$30,$00,$F0,$00,$F0,$00,$F0,$00,$C6
	dc.b	$00,$F9,$FF,$F9,$FF,$F9,$FF,$3C,$C0,$C3,$C0,$C3,$C0,$C3,$C0
	dcb.b	49,$00
	dc.b	$03,$00,$03,$00,$03,$00,$03,$38,$00,$C7,$FF,$C7,$FF,$C7,$FF,$FC
	dc.b	$C0,$03,$C0,$03,$C0,$03,$C0,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$03,$00,$03,$00,$03,$00,$03,$38,$00,$C7,$FF,$C7,$FF,$C7,$FF,$FC
	dc.b	$C0,$03,$C0,$03,$C0,$03,$C0,$00,$00,$00,$00,$00,$00,$00,$00,$C0
	dc.b	$FE,$FF,$01,$FF,$01,$FF,$01,$60,$00,$E0,$00,$E0,$00,$E0,$00,$63
	dc.b	$C0
	dc.b	'|?|?|?'
	dc.b	$FC,$80,$03,$80,$03,$80,$03,$80
	dcb.b	49,$00
	dc.b	$01,$00,$01,$00,$01,$00,$01,$9F,$FF,$E0,$00,$E0,$00,$E0,$00,$F9
	dc.b	$80,$07,$80,$07,$80,$07,$80,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$01,$00,$01,$00,$01,$00,$01,$9F,$FF,$E0,$00,$E0,$00,$E0,$00,$F9
	dc.b	$80,$07,$80,$07,$80,$07,$80,$00,$00,$00,$00,$00,$00,$00,$00,$67
	dc.b	$F8,$78,$07,$78,$07,$78,$07,$C0,$00,$C0,$00,$C0,$00,$C0,$00,$31
	dc.b	$FF,$3E,$00,$3E,$00,$3E,$00,$F1,$80,$0F,$80,$0F,$80,$0F,$80
	dcb.b	56,$00
	dc.b	$CF,$FF,$F0,$00,$F0,$00,$F0,$00,$E3,$00,$1F,$00,$1F,$00,$1F
	dcb.b	33,$00
	dc.b	$CF,$FF,$F0,$00,$F0,$00,$F0,$00,$E3,$00,$1F,$00,$1F,$00,$1F,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$67,$E1,$78,$1F,$78,$1F,$78,$1F
	dc.b	$80,$00,$80,$00,$80,$00,$80,$00,$18,$FF,$1F,$00,$1F,$00,$1F,$00
	dc.b	$E3,$00,$1F,$00,$1F,$00,$1F
	dcb.b	57,$00
	dc.b	$63,$FF,$7C,$00,$7C,$00,$7C,$00,$86,$00,$7E,$00,$7E,$00,$7E
	dcb.b	33,$00
	dc.b	$63,$FF,$7C,$00,$7C,$00,$7C,$00,$86,$00,$7E,$00,$7E,$00,$7E,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$67,$87,$78,$7F,$78,$7F,$78,$7F
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$0C,$1F,$0F,$E0,$0F,$E0,$0F,$E0
	dc.b	$8E,$00,$7E,$00,$7E,$00,$7E
	dcb.b	57,$00
	dc.b	$30,$00,$3F,$FF,$3F,$FF,$3F,$FF,$1C,$00,$FC,$00,$FC,$00,$FC
	dcb.b	33,$00
	dc.b	$30,$00,$3F,$FF,$3F,$FF,$3F,$FF,$1C,$00,$FC,$00,$FC,$00,$FC,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$30,$1E,$3F,$FE,$3F,$FE,$3F,$FE
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$07,$00,$07,$FF,$07,$FF,$07,$FF
	dc.b	$1C,$00,$FC,$00,$FC,$00,$FC
	dcb.b	57,$00
	dc.b	$1C,$00,$1F,$FF,$1F,$FF,$1F,$FF,$78,$00,$F8,$00,$F8,$00,$F8
	dcb.b	33,$00
	dc.b	$1C,$00,$1F,$FF,$1F,$FF,$1F,$FF,$78,$00,$F8,$00,$F8,$00,$F8,$00
	dc.b	$1F,$C0,$00,$00,$00,$00,$00,$00,$18,$78,$1F,$F8,$1F,$F8,$1F,$F8
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$01,$E0,$01,$FF,$01,$FF,$01,$FF
	dc.b	$78,$00,$F8,$00,$F8,$00,$F8
	dcb.b	57,$00
	dc.b	$07,$FF,$07,$FF,$07,$FF,$07,$FF,$E0,$00,$E0,$00,$E0,$00,$E0
	dcb.b	33,$00
	dc.b	$0F,$FF,$0F,$FF,$0F,$FF,$0F,$FF,$E0,$00,$E0,$00,$E0,$00,$E0,$00
	dc.b	$20,$3F,$07,$C0,$1F,$C0,$1F,$C0,$CF,$E0,$0F,$E0,$0F,$E0,$0F,$E0
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$7F,$00,$7F,$00,$7F,$00,$7F
	dc.b	$E0,$00,$E0,$00,$E0,$00,$E0
	dcb.b	57,$00
	dc.b	$01,$FF,$01,$FF,$01,$FF,$01,$FF
	dcb.b	40,$00
	dc.b	$03,$FF,$03,$FF,$03,$FF,$03,$FF,$87,$F0,$80,$00,$80,$00,$80,$00
	dc.b	$40,$3F,$07,$C0,$3F,$FE,$3F,$FF,$FB,$80,$03,$80,$03,$80,$C3,$80
	dc.b	$7F,$FE,$00,$00,$00,$00,$00,$00,$00,$0F,$00,$0F,$00,$0F,$00,$0F
	dc.b	$80,$00,$80,$00,$80,$00,$80
	dcb.b	113,$00
	dc.b	$18,$0F,$00,$00,$07,$F0,$07,$F0,$FF,$FC,$00,$00,$00,$FF,$1F,$FF
	dc.b	$04,$1F,$00,$00,$F8,$00,$F8,$00,$80,$01,$00,$F0,$7F,$0E,$7F,$FE
	dcb.b	128,$00
	dc.b	$20,$07,$01,$F8,$1F,$FF,$1F,$FF,$FF,$83,$00,$03,$F0,$00,$FF,$FF
	dc.b	$FC,$20,$F8,$00,$00,$1F,$F8,$1F,$00,$01,$00,$00,$FF,$80,$FF,$FE
	dcb.b	120,$00
	dc.b	$7F,$C0,$00,$00,$00,$00,$00,$00,$1C,$03,$00,$1C,$03,$FF,$0F,$FF
	dc.b	$FF,$83,$00,$03,$C7,$00,$FF,$FF,$FF,$FF,$F8,$00,$00,$00,$F8,$1F
	dc.b	$C0,$02,$00,$00,$00,$00,$FF,$FC
	dcb.b	113,$00
	dc.b	$01,$00,$00,$00,$00,$00,$00,$80,$3F,$00,$00,$7F,$C0,$7F,$C0,$EF
	dc.b	$80,$00,$00,$00,$00,$07,$FF,$FF,$C1,$FF,$01,$00,$00,$FF,$FF,$FE
	dc.b	$00,$C0,$07,$3F,$F8,$FF,$FF,$80,$04,$00,$00,$70,$00,$FF,$F8
	dcb.b	113,$00
	dc.b	$02,$00,$00,$00,$01,$00,$01,$00,$1F,$0F,$E0,$FF,$FF,$FF,$FF,$FF
	dc.b	$C0,$00,$00,$E0,$00,$E3,$FF,$FF,$C0,$FF,$00,$00,$03,$FF,$FF,$00
	dc.b	$00,$00,$00,$FF,$F8,$FF,$FF,$00,$08,$00,$00,$00,$00,$FF,$F0
	dcb.b	113,$00
	dc.b	$01,$00,$00,$00,$00,$00,$00,$C0,$1F,$1F,$E0,$3F,$FF,$FF,$FF,$FF
	dc.b	$E0,$00,$00,$8F,$00,$FF,$FF,$FF,$83,$FE,$7C,$00,$00,$FF,$FF,$F8
	dc.b	$00,$00,$00,$00,$00,$FF,$FF,$00,$10,$00,$00,$00,$00,$FF,$E0
	dcb.b	105,$00
	dc.b	$7F,$00,$00,$00,$00,$00,$00,$FF,$FC,$00,$00,$00,$00,$00,$00,$FF
	dc.b	$FC,$00,$00,$07,$FF,$7F,$FF,$00,$E0,$01,$00,$FE,$00,$FF,$FF,$F8
	dc.b	$00,$F8,$00,$07,$FF,$FF,$FF,$00,$00,$00,$00,$FC,$00,$FF,$FF,$3F
	dc.b	$F0,$3C,$00,$03,$E0,$FF,$E0
	dcb.b	104,$00
	dc.b	$03,$80,$00,$07,$00,$7F,$00,$7F,$00,$03,$F0,$00,$FF,$FC,$FF,$FC
	dc.b	$7C,$07,$00,$07,$00,$00,$3F,$FF,$FF,$F0,$FE,$00,$00,$03,$FE,$FF
	dc.b	$7E,$00,$00,$03,$FF,$FC,$FF,$FF,$00,$00,$80,$00,$7C,$00,$FF,$FF
	dc.b	$7F,$F0,$7C,$00,$03,$E0,$FF,$E0
	dcb.b	104,$00
	dc.b	$04,$00,$00,$0F,$03,$FF,$03,$FF,$07,$FF,$F8,$00,$FF,$FF,$FF,$FF
	dc.b	$FE,$07,$00,$07,$00,$00,$3F,$FF,$FD,$E0,$FE,$18,$00,$07,$FE,$FF
	dc.b	$00,$00,$00,$00,$FF,$F8,$FF,$FF,$00,$00,$00,$00,$00,$00,$FF,$FF
	dc.b	$FF,$F0,$FC,$00,$03,$E0,$FF,$E0
	dcb.b	104,$00
	dc.b	$02,$00,$00,$1F,$01,$FF,$01,$FF,$07,$FF,$F8,$00,$FF,$E1,$FF,$FF
	dc.b	$FE,$07,$00,$07,$E0,$00,$FF,$FF,$FF,$E7,$FC,$18,$00,$00,$FC,$FF
	dc.b	$E0,$00,$00,$00,$00,$00,$FF,$FF,$0F,$FF,$0F,$C0,$00,$3F,$FF,$FF
	dc.b	$FF,$F0,$FC,$00,$03,$E0,$FF,$E0
	dcb.b	104,$00
	dc.b	$01,$FC,$00,$03,$00,$1F,$00,$FF,$03,$F1,$FC,$00,$FF,$EF,$FF,$FF
	dc.b	$DF,$03,$20,$03,$C0,$00,$EF,$FF,$FB,$F3,$FC,$0C,$00,$00,$FC,$FF
	dc.b	$E0,$00,$00,$00,$00,$00,$FF,$FF,$1F,$FF,$1F,$C0,$00,$3F,$FF,$FF
	dc.b	$FF,$F0,$7C,$00,$03,$E0,$FF,$E0
	dcb.b	105,$00
	dc.b	$F0,$00,$00,$00,$00,$00,$7F,$07,$FF,$07,$FF,$00,$00,$FF,$FF,$BF
	dc.b	$80,$C0,$00,$00,$07,$CF,$FF,$00,$00,$00,$1E,$FF,$E1,$FF,$FF,$00
	dc.b	$00,$00,$00,$E0,$00,$FF,$FF,$3F,$FF,$1F,$C0,$00,$3F,$FF,$FF,$FF
	dc.b	$F0,$7C,$00,$03,$E0,$FF,$E0
	dcb.b	105,$00
	dc.b	$F8,$00,$00,$00,$00,$00,$7F,$07,$FF,$07,$FF,$00,$00,$FF,$FF,$BF
	dc.b	$0F,$C0,$00,$00,$FF,$CF,$FF,$E0,$00,$00,$18,$FF,$E7,$FF,$FF,$20
	dc.b	$00,$00,$00,$C0,$00,$FF,$FF,$7F,$FF,$1F,$C0,$00,$3F,$FF,$FF,$FF
	dc.b	$F0,$7C,$00,$03,$E0,$FF,$E0
	dcb.b	105,$00
	dc.b	$7C,$00,$00,$00,$00,$00,$3F,$03,$FF,$03,$FF,$00,$00,$FF,$FF,$38
	dc.b	$00,$C0,$00,$07,$FF,$CF,$FF,$00,$00,$00,$00,$FF,$C0,$FF,$FF,$60
	dc.b	$00,$00,$00,$00,$01,$FF,$FF,$7F,$FF,$0F,$C0,$80,$3F,$FF,$FF,$FF
	dc.b	$F0,$7C,$00,$03,$E0,$FF,$E0
	dcb.b	105,$00
	dc.b	$3C,$00,$00,$00,$00,$00,$1F,$03,$FF,$03,$FF,$00,$00,$FF,$FF,$5F
	dc.b	$F0,$80,$00,$00,$00,$8F,$FF,$00,$00,$00,$00,$00,$00,$FF,$FF,$7F
	dc.b	$FF,$1F,$C0,$00,$3F,$FF,$FF,$7F,$FF,$0F,$C0,$80,$3F,$FF,$FF,$FF
	dc.b	$F0,$7C,$00,$03,$E0,$FF,$E0
	dcb.b	105,$00
	dc.b	$1E,$00,$00,$00,$00,$00,$0F,$03,$FE,$03,$FF,$00,$00,$FF,$FF,$7F
	dc.b	$F0,$80,$00,$00,$00,$8F,$FF,$00,$00,$00,$00,$00,$00,$FF,$FF,$FF
	dc.b	$FF,$3F,$C0,$00,$3F,$FF,$FF,$7F,$FF,$0F,$C0,$80,$3F,$FF,$FF,$FF
	dc.b	$E0,$7C,$00,$03,$C0,$FF,$C0
	dcb.b	105,$00
	dc.b	$1F,$00,$00,$00,$00,$00,$0F,$01,$FF,$01,$FF,$00,$00,$FF,$FF,$8F
	dc.b	$F0,$80,$00,$70,$00,$FF,$FF,$00,$01,$00,$00,$00,$00,$FF,$FF,$FF
	dc.b	$FF,$3F,$C0,$00,$3F,$FF,$FF,$7F,$FF,$0F,$C0,$80,$3F,$FF,$FF,$FF
	dc.b	$E7,$7C,$00,$03,$C0,$FF,$C0,$80
	dcb.b	104,$00
	dc.b	$1E,$00,$01,$00,$00,$00,$0F,$00,$01,$FE,$01,$01,$FE,$FF,$FF,$8F
	dc.b	$F8,$80,$00,$70,$00,$FF,$FF,$00,$01,$00,$02,$00,$00,$FF,$FF,$FF
	dc.b	$FF,$3F,$C0,$00,$3F,$FF,$FF,$7F,$FF,$0F,$C0,$80,$3F,$FF,$FF,$FF
	dc.b	$F8,$7C,$07,$03,$C7,$FF,$C7,$60,$00,$80,$00,$80,$00,$80
	dcb.b	98,$00
	dc.b	$FE,$00,$01,$00,$00,$00,$0F,$00,$01,$FE,$01,$01,$FE,$FF,$FF,$8F
	dc.b	$F8,$80,$00,$70,$00,$FF,$FF,$00,$01,$00,$02,$00,$0C,$FF,$FF,$FF
	dc.b	$FF,$3F,$C0,$00,$3F,$FF,$FF,$7F,$FF,$0F,$C0,$80,$3F,$FF,$FF,$FF
	dc.b	$E0,$7C,$1F,$03,$DF,$FF,$DF,$10,$00,$E0,$00,$E0,$00,$E0
	dcb.b	97,$00
	dc.b	$01,$FE,$00,$01,$00,$00,$00,$EF,$00,$01,$FE,$01,$01,$FE,$FF,$FF
	dc.b	$BF,$F8,$80,$00,$70,$00,$FF,$FF,$03,$F9,$00,$02,$03,$FC,$FF,$FF
	dc.b	$FF,$FF,$3F,$C0,$00,$3F,$FF,$FF,$7F,$FF,$0F,$C0,$80,$3E,$FF,$FF
	dc.b	$FF,$80,$7C,$7F,$03,$FF,$FF,$FF,$08,$00,$F0,$00,$F0,$00,$F0
	dcb.b	97,$00
	dc.b	$01,$CE,$00,$01,$00,$30,$00,$FF,$00,$01,$FE,$01,$01,$FE,$FF,$FF
	dc.b	$BF,$FF,$80,$07,$70,$00,$FF,$FF,$FF,$F9,$F0,$02,$0F,$FC,$FF,$FF
	dc.b	$FF,$FF,$0F,$C0,$00,$3F,$FF,$FF,$7F,$FF,$07,$C0,$80,$3E,$FF,$FF
	dc.b	$FE,$00,$7D,$FF,$03,$FF,$FF,$FF,$06,$00,$F8,$00,$F8,$00,$F8,$00
	dc.b	$00,$01,$00,$00,$00,$00,$00,$00,$FE
	dcb.b	87,$00
	dc.b	$01,$CE,$00,$01,$00,$30,$00,$FF,$00,$01,$FE,$01,$01,$FE,$FF,$FF
	dc.b	$BF,$FF,$80,$0F,$70,$00,$FF,$FF,$FF,$F9,$F0,$02,$0F,$FC,$FF,$FF
	dc.b	$FF,$FF,$0F,$C0,$00,$3F,$FF,$FF,$7F,$FF,$07,$C0,$80,$3E,$FF,$FF
	dc.b	$FC,$00,$7F,$FF,$03,$FF,$FF,$FF,$01,$00,$FE,$00,$FE,$00,$FE,$00
	dc.b	$00,$07,$00,$00,$00,$00,$00,$01,$F1,$C0,$00,$00,$0E,$00,$FE
	dcb.b	81,$00
	dc.b	$03,$8E,$00,$01,$00,$70,$01,$FF,$00,$01,$FE,$01,$01,$FE,$FF,$FF
	dc.b	$BF,$FF,$80,$0F,$70,$00,$FF,$FF,$FF,$F9,$F0,$02,$0F,$FC,$FF,$FF
	dc.b	$FF,$FF,$0F,$C0,$00,$3F,$FF,$FF,$7F,$FF,$07,$C0,$80,$3E,$FF,$FF
	dc.b	$C1,$00,$7E,$FF,$3E,$FF,$FF,$FF,$00,$C0,$FF,$00,$03,$00,$FF,$00
	dc.b	$00,$0F,$00,$00,$00,$00,$00,$07,$F8,$38,$00,$00,$07,$C0,$FF,$C0
	dcb.b	72,$00
	dc.b	$38,$00,$00,$00,$00,$00,$00,$00,$03,$8F,$00,$00,$00,$70,$01,$FF
	dc.b	$00,$01,$FE,$01,$01,$FE,$FF,$FF,$FF,$FF,$80,$0F,$70,$00,$FF,$FF
	dc.b	$FF,$F9,$F0,$02,$0F,$FC,$FF,$FF,$FF,$FF,$0F,$C0,$00,$3F,$FF,$FF
	dc.b	$7F,$FE,$07,$C1,$80,$3F,$FF,$FF,$00,$40,$FF,$BF,$FF,$BF,$FF,$FF
	dc.b	$0E,$20,$F1,$C0,$81,$C0,$FF,$C0,$00,$0F,$00,$00,$00,$00,$00,$07
	dc.b	$E0,$7C,$00,$00,$1F,$F8,$FF,$F8
	dcb.b	72,$00
	dc.b	$7F,$E0,$00,$00,$00,$00,$38,$00,$03,$8F,$00,$00,$00,$70,$01,$FF
	dc.b	$00,$01,$FE,$01,$01,$FE,$FF,$FF,$FF,$FF,$80,$0F,$70,$00,$FF,$FF
	dc.b	$FF,$F9,$F0,$02,$0F,$FC,$FF,$FF,$FF,$FF,$0F,$C0,$00,$3F,$FF,$FF
	dc.b	$7F,$F8,$07,$C7,$80,$3F,$FF,$FF,$00,$20,$FF,$DF,$FF,$DF,$FF,$FF
	dc.b	$0F,$90,$F0,$60,$00,$60,$FF,$E0,$00,$0F,$00,$00,$00,$00,$00,$07
	dc.b	$F0,$7C,$00,$00,$0F,$F8,$FF,$F8
	dcb.b	72,$00
	dc.b	$70,$1F,$00,$00,$0F,$E0,$3F,$E0,$03,$8F,$00,$00,$00,$70,$01,$FF
	dc.b	$00,$01,$FE,$01,$01,$FE,$FF,$FF,$EF,$FF,$90,$0F,$70,$00,$FF,$FF
	dc.b	$FF,$F8,$F0,$03,$0F,$FC,$FF,$FF,$FF,$FF,$0F,$C0,$00,$3F,$FF,$FF
	dc.b	$FF,$E0,$07,$DF,$80,$3F,$FF,$FF,$00,$00,$FF,$FF,$FF,$FF,$FF,$FF
	dc.b	$01,$EC,$FE,$10,$FE,$10,$FF,$F0,$00,$FF,$00,$00,$00,$00,$00,$0F
	dc.b	$F0,$FC,$00,$00,$0F,$F8,$FF,$F8
	dcb.b	72,$00
	dc.b	$70,$1F,$00,$00,$0F,$FF,$3F,$FF,$C3,$8F,$00,$00,$00,$70,$01,$FF
	dc.b	$00,$01,$FE,$01,$01,$FE,$FF,$FF,$8F,$FF,$F0,$0F,$70,$00,$FF,$FF
	dc.b	$FF,$F8,$F0,$03,$0F,$FC,$FF,$FF,$FF,$FF,$0F,$C0,$00,$3F,$FF,$FF
	dc.b	$FF,$80,$07,$FF,$80,$7F,$FF,$FF,$00,$04,$FF,$FB,$FF,$FB,$FF,$FF
	dc.b	$18,$32,$E7,$CC,$E7,$0C,$FF,$FC,$03,$FF,$00,$00,$00,$00,$00,$FF
	dc.b	$F0,$F8,$00,$00,$0F,$F0,$FF,$F0
	dcb.b	72,$00
	dc.b	$E0,$1F,$00,$00,$1F,$FF,$7F,$FF,$E7,$0F,$C0,$00,$00,$F0,$C3,$FF
	dc.b	$00,$01,$FE,$01,$01,$FE,$FF,$FF,$8F,$FF,$F0,$03,$70,$00,$FF,$FF
	dc.b	$FF,$F8,$F8,$03,$07,$FC,$FF,$FF,$FF,$FF,$0F,$C0,$00,$3F,$FF,$FF
	dc.b	$FC,$00,$07,$FF,$83,$FF,$FF,$FF,$00,$00,$FF,$FF,$F8,$0F,$FF,$FF
	dc.b	$1C,$3D,$E3,$C2,$E3,$C2,$FF,$FE,$07,$F8,$00,$00,$00,$07,$03,$FF
	dc.b	$00,$F8,$00,$00,$FF,$F0,$FF,$F0
	dcb.b	72,$00
	dc.b	$E0,$7F,$00,$00,$1F,$FF,$7F,$FF,$E7,$07,$C0,$00,$00,$F8,$C3,$FF
	dc.b	$00,$01,$FE,$01,$01,$FE,$FF,$FF,$0F,$FF,$F0,$03,$F0,$00,$FF,$FF
	dc.b	$FF,$F8,$F8,$03,$07,$FF,$FF,$FF,$FF,$FF,$0F,$C0,$00,$3F,$FF,$FF
	dc.b	$F0,$08,$0F,$F7,$8F,$F7,$FF,$FF,$00,$38,$FF,$C7,$FC,$07,$FF,$FF
	dc.b	$9C,$1C,$63,$E3,$63,$E3,$FF,$FF,$C7,$FC,$00,$00,$00,$03,$03,$FF
	dc.b	$0F,$F8,$00,$00,$FF,$F0,$FF,$F0
	dcb.b	72,$00
	dc.b	$E0,$7F,$00,$03,$1F,$FC,$7F,$FF,$E7,$07,$C0,$00,$00,$F8,$C3,$FF
	dc.b	$80,$01,$7E,$01,$01,$FE,$FF,$FF,$07,$FF,$F8,$03,$F8,$00,$FF,$FF
	dc.b	$FF,$F8,$F8,$03,$07,$FF,$FF,$FF,$FF,$FF,$0F,$C0,$00,$3F,$FF,$FF
	dc.b	$80,$00,$7F,$FF,$FF,$FF,$FF,$FF,$00,$3E,$FF,$C1,$FC,$01,$FF,$FF
	dc.b	$0E,$0E,$F1,$F1,$F1,$F1,$FF,$FF,$27,$F0,$C0,$00,$C0,$0F,$C3,$FF
	dc.b	$0F,$F8,$00,$00,$FF,$F0,$FF,$F0
	dcb.b	72,$00
	dc.b	$E0,$7F,$00,$03,$1F,$FC,$7F,$FF,$C7,$07,$80,$00,$00,$F8,$83,$FF
	dc.b	$80,$01,$7E,$01,$01,$FE,$FF,$FF,$03,$FF,$FC,$03,$FC,$00,$FF,$FF
	dc.b	$FF,$F8,$F8,$03,$07,$FF,$FF,$FF,$FF,$FE,$0F,$C1,$00,$3F,$FF,$FF
	dc.b	$00,$00,$FF,$FF,$FF,$FF,$FF,$FF,$00,$03,$FF,$FC,$FF,$FC,$FF,$FF
	dc.b	$90,$0F,$6F,$F0,$68,$00,$FF,$FF,$1F,$F8,$E0,$00,$E0,$07,$E7,$FF
	dc.b	$1F,$F8,$00,$00,$FF,$F0,$FF,$F0
	dcb.b	72,$00
	dc.b	$C0,$7F,$00,$03,$3F,$FC,$7F,$FF,$C7,$07,$80,$08,$00,$F8,$83,$FF
	dc.b	$80,$01,$7E,$01,$01,$FE,$FF,$FF,$03,$FF,$FC,$03,$FC,$00,$FF,$FF
	dc.b	$FF,$F8,$F8,$01,$07,$FF,$FF,$FF,$FF,$F8,$0F,$C7,$00,$3F,$FF,$FF
	dc.b	$00,$00,$FF,$FF,$FF,$FF,$FF,$FF,$80,$40,$7F,$BF,$7F,$BE,$FF,$FF
	dc.b	$09,$07,$F6,$F8,$16,$18,$FF,$FF,$07,$F8,$F8,$00,$F8,$07,$FF,$FF
	dc.b	$1F,$F0,$00,$00,$FF,$E0,$FF,$E0
	dcb.b	72,$00
	dc.b	$C0,$FF,$00,$01,$3F,$FE,$7F,$FF,$CF,$07,$80,$78,$00,$F8,$87,$FF
	dc.b	$80,$01,$7E,$01,$01,$FE,$FF,$FF,$00,$FF,$FF,$03,$FF,$00,$FF,$FF
	dc.b	$FF,$FD,$F8,$00,$07,$FF,$FF,$FF,$FF,$E0,$07,$DF,$00,$3F,$FF,$FF
	dc.b	$00,$00,$FF,$FF,$FF,$FF,$FF,$FF,$00,$00,$FF,$FF,$FF,$FF,$FF,$FF
	dc.b	$70,$03,$8F,$FC,$8F,$9C,$FF,$FF,$07,$F8,$F8,$00,$F8,$07,$FF,$FF
	dc.b	$1F,$F0,$00,$00,$FF,$E0,$FF,$E0
	dcb.b	65,$00
	dc.b	$01,$00,$00,$00,$00,$00,$00,$C0,$FF,$00,$01,$3F,$FE,$FF,$FF,$D8
	dc.b	$07,$87,$F8,$07,$F8,$87,$FF,$80,$01,$7E,$01,$01,$FE,$FF,$FF,$00
	dc.b	$3F,$FF,$C3,$FF,$C0,$FF,$FF,$FF,$FD,$F8,$00,$07,$FF,$FF,$FF,$FF
	dc.b	$80,$07,$FF,$00,$7F,$FF,$FF,$00,$00,$FF,$FF,$FF,$FF,$FF,$FF,$10
	dc.b	$E0,$EF,$1F,$EF,$1F,$FF,$FF,$39,$03,$C6,$FC,$C6,$FC,$FF,$FF,$FF
	dc.b	$F8,$00,$00,$00,$07,$FF,$FF,$1F,$F0,$00,$00,$FF,$E0,$FF,$E0
	dcb.b	65,$00
	dc.b	$01,$00,$00,$00,$00,$00,$00,$C0,$FF,$00,$01,$3F,$FE,$FF,$FF,$FC
	dc.b	$07,$83,$F8,$03,$F8,$FF,$FF,$80,$01,$7E,$01,$01,$FE,$FF,$FF,$00
	dc.b	$3F,$FF,$C3,$FF,$C0,$FF,$FF,$FF,$FD,$F8,$00,$07,$FF,$FF,$FF,$F8
	dc.b	$28,$07,$D7,$07,$D7,$FF,$FF,$1F,$80,$E0,$7F,$E0,$00,$FF,$FF,$08
	dc.b	$F0,$F7,$0F,$F7,$0F,$FF,$FF,$3C,$07,$C3,$F8,$C3,$F8,$FF,$FF,$F1
	dc.b	$F8,$00,$00,$0E,$07,$FF,$FF,$1F,$F0,$00,$00,$FF,$E0,$FF,$E0
	dcb.b	65,$00
	dc.b	$01,$00,$00,$00,$00,$00,$00,$C0,$FF,$00,$07,$3F,$F8,$FF,$FF,$FE
	dc.b	$07,$7D,$F8,$7D,$F8,$83,$FF,$80,$01,$7E,$01,$01,$FE,$FF,$FF,$00
	dc.b	$3F,$FF,$C3,$FF,$C0,$FF,$FF,$FF,$FD,$F8,$00,$07,$FF,$FF,$FF,$E0
	dc.b	$1C,$1F,$EB,$1F,$EB,$FF,$F7,$3F,$E3,$DF,$9C,$DF,$80,$E0,$7F,$80
	dc.b	$78,$7F,$97,$7F,$97,$FF,$EF,$1E,$27,$E1,$D8,$E1,$D8,$FF,$FF,$F8
	dc.b	$00,$00,$00,$07,$FF,$FF,$FF,$3F,$F0,$00,$00,$FF,$E0,$FF,$E0
	dcb.b	65,$00
	dc.b	$01,$00,$00,$00,$00,$00,$00,$80,$FF,$00,$07,$7F,$F8,$FF,$FF,$FF
	dc.b	$07,$22,$F8,$22,$F8,$DD,$FF,$80,$01,$7E,$01,$01,$FE,$FF,$FF,$00
	dc.b	$3F,$FF,$C3,$FF,$C0,$FF,$FF,$FF,$FD,$F8,$00,$07,$FF,$FF,$FF,$80
	dc.b	$3C,$7F,$DB,$7F,$DB,$FF,$E7,$1F,$F3,$E8,$6C,$E8,$60,$F7,$9F,$E1
	dc.b	$38,$1E,$C7,$1E,$C7,$FF,$F7,$1F,$07,$E0,$F8,$E0,$F8,$FF,$FF,$E0
	dc.b	$1F,$00,$00,$1F,$FF,$FF,$FF,$3F,$F0,$00,$00,$FF,$E0,$FF,$E0
	dcb.b	65,$00
	dc.b	$01,$00,$00,$00,$00,$00,$00,$81,$FF,$00,$06,$7F,$F8,$FF,$FF,$FF
	dc.b	$53,$22,$AC,$22,$AC,$D5,$FF,$C1,$F3,$3E,$01,$00,$0C,$FF,$FF,$9C
	dc.b	$7F,$63,$83,$63,$80,$FF,$FF,$FF,$FC,$38,$03,$07,$C7,$FF,$FF,$D8
	dc.b	$7E,$27,$89,$27,$89,$FF,$F5,$1F,$F3,$E8,$2C,$E8,$2C,$F4,$5F,$FF
	dc.b	$9C,$00,$63,$00,$60,$FF,$F3,$FF,$6F,$00,$90,$00,$90,$FF,$FF,$F0
	dc.b	$1F,$00,$00,$0F,$FF,$FF,$FF,$3F,$E0,$00,$00,$FF,$C0,$FF,$C0
	dcb.b	65,$00
	dc.b	$03,$00,$00,$00,$00,$00,$01,$81,$FF,$00,$04,$7F,$F8,$FF,$FF,$FF
	dc.b	$FB,$22,$55,$22,$55,$DD,$AE,$E3,$FF,$DD,$F2,$C1,$F2,$3E,$0D,$FE
	dc.b	$FF,$9D,$6C,$9D,$6C,$63,$93,$FF,$FD,$D8,$3A,$C7,$BA,$3F,$C7,$FC
	dc.b	$FE,$DB,$69,$DB,$69,$27,$95,$1F,$FF,$E8,$13,$E8,$13,$F4,$2C,$EF
	dc.b	$FD,$D7,$92,$C7,$90,$38,$6F,$FF,$FF,$FB,$60,$FB,$60,$04,$9F,$F0
	dc.b	$3F,$00,$00,$0F,$FF,$FF,$FF,$3F,$E0,$00,$00,$FF,$C0,$FF,$C0
	dcb.b	65,$00
	dc.b	$03,$00,$00,$00,$00,$00,$01,$81,$FF,$00,$00,$7F,$F0,$FF,$FF,$FF
	dc.b	$FF,$3C,$F2,$3C,$F2,$C3,$0D,$F7,$FF,$2A,$27,$22,$27,$DD,$D8,$FF
	dc.b	$7F,$A2,$B3,$A2,$B3,$5D,$CC,$FF,$FE,$28,$45,$27,$45,$DF,$BB,$FF
	dc.b	$FE,$64,$99,$64,$99,$9B,$65,$5E,$3F,$A9,$D4,$A9,$D4,$F5,$EB,$FF
	dc.b	$FB,$28,$B5,$28,$B5,$D7,$4E,$FF,$FF,$11,$90,$11,$90,$EA,$6F,$F0
	dc.b	$3E,$00,$00,$0F,$FF,$FF,$FF,$3D,$E0,$00,$00,$FF,$C0,$FF,$C0
	dcb.b	65,$00
	dc.b	$03,$00,$00,$00,$00,$00,$01,$81,$FF,$00,$00,$7F,$E0,$FF,$FF,$FF
	dc.b	$FF,$20,$44,$20,$44,$DC,$BA,$FF,$FF,$12,$22,$12,$22,$2D,$55,$FF
	dc.b	$7F,$06,$A2,$06,$A2,$B9,$D5,$FF,$7E,$28,$8D,$27,$8D,$5F,$F3,$FF
	dc.b	$FE,$45,$09,$45,$09,$AA,$95,$3E,$3F,$C9,$D4,$C9,$D4,$F5,$EB,$FF
	dc.b	$FF,$2C,$11,$2C,$11,$D3,$AA,$FF,$FF,$11,$10,$11,$10,$AA,$AF,$F0
	dc.b	$3E,$00,$00,$0F,$FF,$FF,$FF,$7D,$E0,$00,$00,$FF,$C0,$FF,$C0
	dcb.b	65,$00
	dc.b	$03,$00,$00,$00,$00,$00,$01,$01,$FF,$00,$00,$FF,$C0,$FF,$FF,$FF
	dc.b	$FF,$20,$44,$20,$44,$D0,$AA,$FF,$FF,$12,$22,$12,$22,$2D,$D5,$FF
	dc.b	$FF,$1A,$22,$1A,$22,$25,$55,$FC,$7F,$27,$B4,$23,$B4,$57,$CA,$FF
	dc.b	$FE,$45,$09,$45,$09,$AA,$95,$1E,$3F,$E9,$D7,$E9,$D7,$F5,$E8,$FF
	dc.b	$FF,$E7,$11,$E7,$11,$18,$AA,$FF,$FF,$11,$10,$11,$10,$EA,$AB,$F0
	dc.b	$3E,$00,$00,$0F,$FF,$FF,$FF,$7F,$E0,$00,$00,$FF,$C0,$FF,$C0
	dcb.b	65,$00
	dc.b	$03,$00,$00,$00,$00,$00,$01,$03,$FF,$00,$00,$FF,$00,$FF,$FF,$FF
	dc.b	$FF,$20,$44,$20,$44,$D1,$AA,$3F,$FF,$D1,$C2,$D1,$C2,$EA,$25,$FF
	dc.b	$FF
	dc.b	'""""]U'
	dc.b	$F8,$FF,$27,$44,$27,$44,$57,$BA,$FF,$DE,$45,$29,$45,$29,$AA,$B5
	dc.b	$1E,$7F,$E9,$A4,$E9,$A4,$F5,$DB,$FF,$FD,$01,$92,$01,$92,$EE,$6B
	dc.b	$FF,$FF,$E1,$10,$E1,$10,$12,$AB,$E0,$3E,$00,$00,$1F,$FF,$FF,$FF
	dc.b	$7F,$C0,$00,$00,$FF,$80,$FF,$80
	dcb.b	65,$00
	dc.b	$03,$00,$00,$00,$00,$00,$01,$03,$FF,$00,$00,$FE,$00,$FF,$FF,$FF
	dc.b	$F7,$20,$4A,$20,$4A,$D7,$AD,$FF,$FF,$22,$02,$22,$02,$D5,$E5,$FF
	dc.b	$FF
	dc.b	'""""]U'
	dc.b	$FC,$FF,$23,$44,$23,$44,$57,$BA,$FF,$FE,$44,$9D,$44,$9C,$AB,$63
	dc.b	$1F,$FF,$E8,$64,$E8,$64,$F7,$9B,$FF,$FF,$28,$91,$28,$91,$D7,$6A
	dc.b	$FF,$FC,$01,$10,$01,$13,$F2,$AB,$00,$3E,$00,$00,$FF,$FF,$FF,$FF
	dc.b	$7F,$C0,$00,$00,$FF,$80,$FF,$80
	dcb.b	65,$00
	dc.b	$07,$00,$00,$00,$00,$00,$03,$03,$FF,$00,$00,$FC,$00,$FF,$FF,$FF
	dc.b	$FF,$70,$E1,$70,$E1,$8F,$1A,$FF,$FF,$C3,$E7,$C3,$E7,$24,$18,$FF
	dc.b	$FF,$1D,$77,$5D,$77,$E2,$88,$FE,$7F,$71,$BA,$71,$BA,$8F,$C5,$FF
	dc.b	$FF,$EE,$68,$EE,$68,$11,$95,$FF,$FF,$1F,$83,$1F,$83,$E0,$64,$FF
	dc.b	$FF,$CF,$39,$CF,$39,$30,$C6,$FF,$FC,$F3,$B8,$F3,$BB,$0C,$47,$38
	dc.b	$7E,$00,$00,$FF,$FF,$FF,$FF,$F8,$40,$00,$00,$FF,$80,$FF,$80
	dcb.b	65,$00
	dc.b	$06,$00,$00,$00,$01,$00,$03,$07,$FF,$00,$00,$F8,$00,$FF,$FF,$FF
	dc.b	$FF,$00,$00,$00,$00,$F7,$ED,$FF,$FF,$04,$10,$04,$10,$CB,$EF,$FF
	dc.b	$FF,$00,$00,$40,$00,$5D,$77,$FF,$FF,$00,$00,$00,$00,$77,$BA,$FF
	dc.b	$FF,$00,$00,$00,$00,$EE,$68,$FF,$FF,$00,$00,$00,$00,$FF,$83,$FF
	dc.b	$FF,$00,$02,$00,$02,$CF,$3D,$FF,$FC,$08,$00,$08,$03,$F7,$BB,$3F
	dc.b	$7C,$00,$00,$FF,$FF,$FF,$FF,$F8,$80,$00,$00,$FF,$00,$FF
	dcb.b	66,$00
	dc.b	$06,$00,$00,$00,$01,$00,$03,$1F,$FF,$00,$00,$E0,$00,$FF,$FF,$FF
	dc.b	$FF,$00,$00,$00,$00,$83,$06,$FF,$FF,$04,$10,$04,$10,$0B,$E8,$FF
	dc.b	$FF,$00,$00,$20,$00,$20,$00,$FF,$FF,$00,$00,$00,$00,$03,$C0,$FF
	dc.b	$FF,$00,$00,$00,$00,$00,$01,$FF,$F3,$00,$0C,$00,$0C,$E0,$0C,$FF
	dc.b	$FF,$00,$02,$00,$02,$00,$05,$FF,$FE,$08,$00,$08,$01,$F4,$01,$7F
	dc.b	$7C,$00,$00,$FF,$FF,$FF,$FF,$F8,$80,$00,$00,$FF,$00,$FF
	dcb.b	66,$00
	dc.b	$07,$00,$00,$00,$00,$00,$03,$3F,$FF,$00,$00,$C0,$00,$FF,$FF,$FF
	dc.b	$FF,$00,$00,$00,$00,$C7,$8F,$E7,$FF,$1B,$E0,$1B,$E0,$1C,$10,$FF
	dc.b	$FF,$01,$44,$70,$00,$71,$44,$FF,$FD,$40,$02,$00,$02,$47,$E2,$77
	dc.b	$34,$88,$CB,$88,$CB,$88,$CB,$0F,$C1,$F0,$3E,$80,$3E,$F0,$3E,$E7
	dc.b	$9F,$18,$61,$00,$61,$18,$62,$FF,$DC,$F0,$00,$F0,$23,$08,$23,$7F
	dc.b	$7C,$00,$00,$FF,$FF,$FF,$FF,$79,$00,$00,$00,$FE,$00,$FE
	dcb.b	66,$00
	dc.b	$07,$00,$00,$00,$01,$00,$03,$FF,$FF,$00,$00,$80,$00,$FF,$FF,$FF
	dc.b	$FF,$00,$00,$00,$00,$FF,$FF,$FF,$FF,$00,$00,$18,$03,$FB,$E3,$FF
	dc.b	$FF,$0F,$E0,$F0,$00,$FF,$FF,$F7,$F0,$08,$0F,$08,$0F,$FF,$FF,$00
	dc.b	$00,$FF,$FF,$FF,$FF,$FF,$FF,$01,$C0,$FE,$3F,$C0,$3F,$FF,$FF,$00
	dc.b	$03,$FF,$FC,$FF,$FC,$FF,$FD,$FF,$C0,$00,$00,$00,$3F,$F1,$FF,$7E
	dc.b	$7C,$00,$00,$FF,$FF,$FF,$FF,$79,$00,$00,$00,$FE,$00,$FE
	dcb.b	66,$00
	dc.b	$07,$00,$00,$00,$00,$00,$03,$FF,$FF,$00,$00,$00,$00,$FF,$FF,$FF
	dc.b	$FF,$00,$00,$00,$00,$FF,$FF,$FF,$FF,$00,$00,$1C,$01,$FC,$07,$FF
	dc.b	$FF,$08,$00,$C0,$00,$FF,$FF,$FB,$FC,$04,$03,$04,$03,$FF,$FF,$00
	dc.b	$00,$FF,$FF,$FF,$FF,$FF,$FF,$01,$C2,$FE,$3D,$F8,$3D,$FF,$FF,$00
	dc.b	$11,$FF,$EE,$FF,$EE,$FF,$FE,$FF,$80,$00,$00,$00,$7F,$03,$FF,$7E
	dc.b	$FD,$00,$00,$FF,$FF,$FF,$FF,$FA,$00,$00,$00,$FC,$00,$FC
	dcb.b	66,$00
	dc.b	$07,$00,$00,$00,$00,$00,$03,$7F,$E0,$00,$06,$00,$06,$FF,$FF,$FF
	dc.b	$FF,$07,$40,$07,$40,$FF,$FF,$FF,$FF,$00,$06,$1E,$06,$FE,$0F,$FF
	dc.b	$FF,$30,$07,$30,$07,$FF,$FF,$FE,$FE,$41,$01,$41,$01,$FF,$FF,$00
	dc.b	$00,$FF,$FF,$FF,$FF,$FF,$FF,$01,$E0,$FE,$1F,$FE,$1F,$FF,$FF,$00
	dc.b	$38,$FF,$D7,$FF,$D7,$FF,$FF,$FF,$80,$00,$00,$00,$7F,$07,$FF,$7E
	dc.b	$F8,$00,$00,$FF,$FF,$FF,$FF,$F2,$00,$00,$00,$FC,$00,$FC
	dcb.b	66,$00
	dc.b	$0F,$00,$00,$00,$00,$00,$07,$FF,$80,$00,$1F,$00,$1F,$FF,$FF,$7F
	dc.b	$FF,$18,$C0,$18,$C0,$FF,$FF,$FF,$FF,$00,$0B,$1F,$EB,$FF,$FF,$FF
	dc.b	$FF,$58,$18,$58,$18,$FF,$FF,$FF,$7F,$C0,$80,$C0,$80,$FF,$FF,$00
	dc.b	$30,$FF,$CF,$FF,$CF,$FF,$FF,$01,$F0,$FE,$0F,$FE,$0F,$FF,$FF,$00
	dc.b	$78,$FF,$B7,$FF,$B7,$FF,$FF,$FF,$80,$00,$00,$00,$7F,$FF,$FF,$7E
	dc.b	$F8,$00,$00,$FF,$FF,$FF,$FF,$F4,$00,$00,$00,$F8,$00,$F8
	dcb.b	66,$00
	dc.b	$0F,$00,$00,$00,$00,$00,$07,$FE,$00,$00,$7F,$00,$7F,$FF,$FF,$3F
	dc.b	$FF,$90,$40,$90,$40,$F8,$EF,$FF,$FF,$00,$08,$08,$E8,$FF,$FF,$FF
	dc.b	$FF,$40,$10,$40,$10,$FB,$F8,$FF,$FF,$40,$00,$40,$00,$EF,$FF,$B3
	dc.b	$7B,$4C,$84,$4C,$84,$FF,$FF,$30,$F9,$CF,$06,$CF,$06,$FF,$FF,$B0
	dc.b	$FC,$4F,$13,$4F,$13,$FF,$FB,$FF,$80,$00,$00,$00,$7F,$FF,$FF,$FE
	dc.b	$F8,$00,$00,$FF,$FF,$FF,$FF,$08,$00,$00,$00,$F0,$00,$F0
	dcb.b	66,$00
	dc.b	$0F,$00,$00,$00,$00,$00,$07,$FD,$00,$00,$7F,$00,$7F,$FF,$FF,$7F
	dc.b	$FF,$A0,$07,$A0,$07,$F0,$4F,$FF,$FF,$87,$1C,$87,$5C,$FF,$FF,$FF
	dc.b	$FF,$E0,$20,$E0,$20,$F1,$F0,$FF,$FF,$0A,$71,$0A,$71,$5F,$FF,$FF
	dc.b	$FF,$B3,$1B,$B3,$1B,$FF,$FF,$F8,$FB,$37,$75,$37,$75,$FF,$FF,$F9
	dc.b	$FC,$B6,$D3,$B6,$D3,$FF,$FB,$FF,$80,$00,$00,$00,$7F,$FF,$FF,$FC
	dc.b	$F8,$00,$00,$FF,$FF,$FF,$FF,$08,$00,$00,$00,$F0,$00,$F0
	dcb.b	66,$00
	dc.b	$07,$00,$00,$00,$00,$00,$03,$F3,$80,$00,$3F,$00,$3F,$FF,$FF,$7F
	dc.b	$FF,$A0,$08,$A0,$08,$F3,$FF,$FF,$FF,$48,$88,$48,$A8,$FF,$FC,$FF
	dc.b	$FF,$40,$20,$40,$20,$E3,$F3,$FF,$FF,$1E,$88,$1E,$88,$BF,$FF,$FF
	dc.b	$FF,$CC,$8C,$CC,$8C,$FF,$FF,$FD,$FD,$CA,$8A,$CA,$8A,$FF,$FF,$FF
	dc.b	$FC,$C9,$33,$C9,$33,$FF,$FB,$FF,$00,$00,$00,$00,$FF,$FF,$FF,$FD
	dc.b	$F8,$00,$00,$FF,$FF,$FF,$FF,$10,$00,$00,$00,$E0,$00,$E0
	dcb.b	66,$00
	dc.b	$07,$00,$00,$00,$00,$00,$03,$EF,$C0,$00,$0F,$00,$0F,$FF,$FF,$7F
	dc.b	$FF,$A1,$E8,$A1,$E8,$F7,$FF,$FF,$FF,$50,$48,$50,$48,$F8,$FC,$FF
	dc.b	$FF,$40,$20,$40,$20,$E7,$F7,$FF,$FF,$08,$18,$08,$18,$DE,$FF,$FF
	dc.b	$FF,$88,$88,$88,$88,$DD,$FD,$FF,$FF,$89,$04,$89,$04,$DF,$8F,$FF
	dc.b	$FD,$8A,$12,$8A,$12,$DF,$3B,$FF,$00,$00,$00,$00,$FF,$FF,$FF,$FD
	dc.b	$F0,$00,$00,$FF,$FF,$FF,$FF,$10,$00,$00,$00,$E0,$00,$E0
	dcb.b	66,$00
	dc.b	$07,$00,$00,$00,$00,$00,$03,$DF,$F0,$00,$07,$00,$07,$FF,$FF,$7B
	dc.b	$FF,$A0,$4F,$A0,$4F,$F7,$FF,$FF,$FF,$D0,$48,$D0,$49,$F8,$FD,$FF
	dc.b	$FF,$40,$20,$40,$20,$EF,$F7,$FF,$FF,$08,$68,$08,$68,$FC,$FD,$FF
	dc.b	$FF,$88,$88,$88,$88,$DD,$DD,$FF,$FF,$89,$04,$89,$04,$DF,$8F,$FF
	dc.b	$FD,$8A,$12,$8A,$10,$DF,$3B,$FF,$00,$00,$00,$00,$FF,$FF,$FF,$FD
	dc.b	$F0,$00,$00,$FF,$FF,$FF,$FF,$20,$00,$00,$00,$C0,$00,$C0
	dcb.b	66,$00
	dc.b	$07,$00,$00,$00,$00,$00,$03,$DF,$F8,$00,$03,$00,$03,$FF,$FF,$3B
	dc.b	$FF,$10,$48,$10,$48,$FE,$FF,$FF,$FF,$10,$48,$13,$48,$FB,$FD,$FF
	dc.b	$FF,$40,$10,$40,$10,$EF,$FF,$FF,$FF,$48,$88,$48,$88,$FD,$FD,$FF
	dc.b	$FF,$88,$88,$88,$88,$DD,$DD,$FF,$CF,$89,$34,$89,$34,$DF,$BF,$FF
	dc.b	$BD,$8A,$52,$8A,$50,$DF,$7B,$FF,$01,$00,$00,$00,$FF,$FF,$FF,$FD
	dc.b	$F0,$00,$00,$FF,$FF,$FF,$FF,$40,$00,$00,$00,$80,$00,$80
	dcb.b	66,$00
	dc.b	$07,$00,$00,$00,$00,$00,$03,$5F,$FC,$00,$00,$00,$00,$FF,$FF,$FF
	dc.b	$FF,$18,$C8,$D8,$C8,$FF,$FF,$FF,$FF,$48,$88,$48,$88,$FF,$DD,$FF
	dc.b	$FF,$40,$18,$40,$18,$EF,$FF,$FF,$FF,$88,$88,$88,$88,$DD,$FD,$FF
	dc.b	$FF,$88,$88,$88,$88,$DD,$DD,$FF,$FF,$88,$88,$88,$88,$DD,$FD,$FF
	dc.b	$FD,$89,$3A,$89,$38,$DF,$FF,$FE,$01,$00,$00,$01,$FF,$FF,$FF,$F8
	dc.b	$F0,$00,$00,$FF,$FF,$FF,$FF,$80
	dcb.b	72,$00
	dc.b	$07,$00,$00,$00,$00,$00,$03,$5F,$FD,$00,$00,$00,$01,$FF,$FF,$FF
	dc.b	$FF,$07,$07,$E7,$07,$FF,$CF,$FF,$FF,$87,$1C,$87,$1C,$CF,$BF,$FF
	dc.b	$FF,$E0,$07,$E0,$07,$FF,$FF,$FF,$FF,$1C,$75,$1C,$75,$BF,$FF,$FF
	dc.b	$FF,$DD,$DD,$DD,$DD,$FF,$FF,$FF,$FF,$DC,$71,$DC,$71,$FE,$FB,$FF
	dc.b	$FF,$DC,$D0,$DC,$D0,$FF,$FB,$FE,$01,$00,$00,$01,$FF,$FF,$FF,$F8
	dc.b	$F0,$00,$00,$FF,$FF,$FF,$FF,$80
	dcb.b	72,$00
	dc.b	$03,$00,$00,$00,$00,$00,$01,$AF,$FD,$00,$00,$00,$01,$FF,$FF,$FF
	dc.b	$FF,$00,$00,$E0,$00,$E7,$07,$FF,$FF,$00,$00,$00,$00,$87,$1D,$FF
	dc.b	$FF,$00,$00,$00,$00,$EF,$E7,$FF,$FF,$00,$00,$00,$00,$1D,$75,$FF
	dc.b	$FF,$00,$00,$00,$00,$DD,$DD,$FE,$FF,$01,$00,$01,$00,$DD,$71,$FF
	dc.b	$FF,$00,$00,$00,$00,$DC,$D1,$FE,$01,$00,$00,$01,$FF,$FF,$FF,$FB
	dc.b	$F1,$00,$00,$FF,$FE,$FF,$FE
	dcb.b	73,$00
	dc.b	$01,$00,$00,$00,$00,$00,$00,$2F,$FD,$00,$00,$00,$01,$FF,$FF,$FF
	dc.b	$FF,$00,$00,$F0,$00,$F0,$18,$FF,$FF,$00,$00,$00,$20,$18,$20,$FF
	dc.b	$FF,$00,$00,$00,$00,$07,$F0,$FF,$FF,$00,$00,$00,$00,$20,$80,$FF
	dc.b	$FF,$00,$00,$00,$00,$00,$00,$FF,$7D,$00,$82,$00,$82,$00,$82,$FF
	dc.b	$FF,$00,$00,$00,$00,$00,$03,$FE,$01,$00,$00,$01,$FF,$FF,$FF,$F9
	dc.b	$E2,$00,$00,$FF,$FC,$FF,$FC
	dcb.b	80,$00
	dc.b	$8F,$FD,$00,$00,$00,$01,$7F,$FF,$FF,$FF,$00,$00,$FC,$00,$FC,$7C
	dc.b	$FF,$FF,$00,$00,$04,$70,$3C,$71,$FF,$FF,$00,$00,$00,$00,$8F,$FC
	dc.b	$FF,$FF,$00,$00,$00,$00,$71,$C5,$FF,$FE,$00,$01,$00,$01,$11,$11
	dc.b	$EE,$38,$11,$C7,$11,$C7,$11,$C7,$EE,$6B,$11,$94,$10,$00,$11,$97
	dc.b	$FC,$03,$00,$00,$03,$FF,$FF,$FF,$F9,$E2,$00,$00,$FF,$FC,$FF,$FC
	dcb.b	80,$00
	dc.b	$4F,$FE,$00,$00,$00,$00,$3F,$FF,$FD,$FF,$00,$00,$FC,$00,$FF,$FF
	dc.b	$FF,$FF,$00,$00,$07,$FE,$FF,$FF,$FF,$FF,$00,$00,$00,$00,$FF,$FF
	dc.b	$FF,$E7,$00,$00,$00,$00,$FF,$FF,$FE,$FE,$01,$01,$01,$01,$FF,$FF
	dc.b	$00,$00,$FF,$FF,$FF,$FF,$FF,$FF,$00,$03,$FF,$FC,$FC,$00,$FF,$FF
	dc.b	$FC,$03,$00,$00,$03,$FF,$FF,$FF,$F8,$04,$00,$00,$FF,$F8,$FF,$F8
	dcb.b	80,$00
	dc.b	$2F,$FE,$00,$00,$00,$00,$1F,$FF,$F9,$FF,$00,$00,$F8,$00,$FF,$FF
	dc.b	$FF,$FF,$00,$00,$07,$FE,$FF,$FF,$FF,$FF,$00,$00,$00,$00,$FF,$FF
	dc.b	$FF,$83,$00,$08,$00,$08,$FF,$FF,$FF,$7F,$00,$80,$00,$80,$FF,$FF
	dc.b	$80,$00,$7F,$FF,$7F,$FF,$FF,$FF,$00,$07,$FF,$F8,$FC,$00,$FF,$FF
	dc.b	$FC,$03,$00,$00,$03,$FF,$FF,$FF,$F0,$04,$00,$00,$FF,$F8,$FF,$F8
	dcb.b	80,$00
	dc.b	$27,$FE,$00,$00,$00,$00,$1F,$FF,$E7,$FF,$00,$00,$E0,$00,$FF,$FF
	dc.b	$FF,$FF,$00,$00,$03,$FE,$FF,$FF,$FF,$FF,$00,$00,$00,$00,$FF,$FF
	dc.b	$FE,$01,$00,$3C,$00,$3C,$FF,$FF,$FF,$BF,$00,$40,$00,$40,$FF,$FF
	dc.b	$C0,$00,$3F,$FF,$3F,$FF,$FF,$FF,$00,$07,$FF,$88,$F0,$70,$FF,$FF
	dc.b	$FC,$03,$00,$00,$03,$FF,$FF,$FF,$F0,$08,$00,$00,$FF,$C0,$FF,$F0
	dcb.b	80,$00
	dc.b	$13,$FE,$00,$00,$00,$00,$0F,$FF,$9F,$FF,$00,$00,$80,$00,$FF,$FF
	dc.b	$FF,$FF,$00,$00,$02,$DE,$FF,$FF,$FF,$FF,$00,$00,$00,$00,$FF,$FF
	dc.b	$F8,$08,$00,$F6,$00,$F6,$FF,$FF,$FF,$FF,$00,$00,$00,$00,$FF,$FF
	dc.b	$E0,$00,$1F,$FF,$1F,$FF,$FF,$FF,$20,$47,$DE,$00,$C1,$B8,$FF,$FF
	dc.b	$FC,$03,$00,$00,$03,$FF,$FF,$FF,$F0,$70,$00,$00,$FF,$80,$FF,$80
	dcb.b	80,$00
	dc.b	$14,$FE,$00,$00,$00,$00,$0F,$FF,$7F,$FF,$04,$00,$04,$00,$FB,$FF
	dc.b	$FF,$FF,$81,$20,$81,$2C,$7E,$DF,$FF,$FF,$20,$00,$20,$00,$DF,$FF
	dc.b	$E3,$1C,$00,$6B,$00,$6B,$FF,$F7,$3F,$FF,$01,$D0,$01,$D0,$FE,$2F
	dc.b	$F0,$00,$0F,$FF,$0F,$FF,$FF,$FF,$70,$E7,$AC,$40,$A3,$58,$DF,$BF
	dc.b	$F8,$03,$00,$00,$07,$FF,$FF,$FF,$F0,$40,$00,$00,$FF,$80,$FF,$80
	dcb.b	80,$00
	dc.b	$17,$79,$00,$00,$00,$00,$0F,$FF,$FF,$FF,$04,$01,$04,$01,$FB,$FE
	dc.b	$FF,$FF,$83,$02,$83,$4A,$7C,$ED,$FF,$FF,$00,$00,$00,$00,$EF,$FF
	dc.b	$8F,$BC,$00,$1B,$00,$1B,$FF,$E7,$1F,$FB,$C6,$34,$C6,$34,$F9,$CF
	dc.b	$FC,$00,$03,$FF,$03,$FF,$FF,$FF,$F0,$67,$68,$00,$67,$98,$9F,$DF
	dc.b	$F8,$07,$00,$00,$07,$FF,$FF,$FF,$F0,$80,$00,$00,$FF,$00,$FF
	dcb.b	81,$00
	dc.b	$0B,$A7,$00,$00,$00,$00,$07,$FF,$FF,$FF,$0A,$00,$0A,$00,$F5,$FF
	dc.b	$FF,$FF,$81,$02,$81,$02,$5E,$A5,$FF,$FE,$00,$00,$00,$00,$E7,$FF
	dc.b	$FF,$DE,$00,$09,$00,$09,$FF,$F5,$0F,$FD,$E4,$12,$E4,$12,$FA,$2B
	dc.b	$FE,$16,$01,$E9,$01,$E8,$FF,$FF,$7C,$7F,$A0,$00,$23,$80,$DF,$CF
	dc.b	$FF,$07,$00,$00,$00,$FF,$FF,$FF,$E0,$80,$00,$00,$FF,$00,$FF
	dcb.b	81,$00
	dc.b	$0B,$DF,$00,$00,$00,$00,$07,$FF,$FF,$FF,$0A,$06,$0A,$06,$F5,$F9
	dc.b	$FF,$FF,$8D,$27,$8D,$27,$52,$D8,$FF,$FF,$21,$C6,$21,$C6,$DE,$39
	dc.b	$FF,$FE,$C7,$09,$C7,$09,$38,$F5,$1F,$FF,$E8,$01,$E8,$01,$F4,$12
	dc.b	$FF,$3F,$4E,$D6,$4E,$D6,$B1,$E9,$7E,$EF,$AC,$43,$2D,$53,$D3,$BC
	dc.b	$FF,$87,$4F,$00,$4F,$7F,$B0,$FF,$E1,$00,$00,$00,$FE,$00,$FE
	dcb.b	81,$00
	dc.b	$05,$FF,$00,$00,$00,$00,$03,$FF,$FF,$FF,$11,$09,$11,$09,$EA,$F6
	dc.b	$FF,$FF,$93,$62,$93,$6A,$6C,$9D,$FF,$FF,$62,$23,$62,$23,$9D,$DC
	dc.b	$FF,$FE,$28,$89,$28,$89,$D7,$75,$1F,$FF,$E8,$03,$E8,$03,$F4,$FC
	dc.b	$FF,$FF,$D1,$39,$D1,$39,$2E,$C6,$FF,$EF,$32,$C4,$32,$D4,$CD,$3B
	dc.b	$FF,$83,$D1,$00,$D1,$7F,$2E,$FF,$E1,$00,$00,$00,$FE,$00,$FE
	dcb.b	81,$00
	dc.b	$05,$FF,$00,$00,$00,$00,$03,$FF,$FF,$FF,$11,$10,$11,$10,$EE,$E9
	dc.b	$FF,$FF,$A1,$22,$A1,$22,$52,$D5,$FF,$FF,$24,$12,$24,$12,$5A,$2D
	dc.b	$FF,$FE,$21,$89,$21,$89,$5E,$75,$1F,$FF,$88,$79,$88,$79,$F5,$86
	dc.b	$FF,$FF,$03,$10,$03,$10,$DC,$E9,$FF,$FF,$A2,$48,$A2,$48,$55,$B4
	dc.b	$FF,$C3,$58,$00,$58,$3F,$A7,$3F,$E2,$00,$00,$00,$FC,$00,$FC
	dcb.b	81,$00
	dc.b	$03,$FF,$00,$00,$00,$00,$01,$FF,$FF,$FF,$1F,$10,$1F,$10,$E0,$A9
	dc.b	$FF,$FF,$A1,$22,$A1,$22,$52,$D5,$FF,$FF,$24,$12,$24,$12,$5A,$2D
	dc.b	$FF,$FE,$26,$89,$26,$89,$59,$55,$7F,$FF,$08,$11,$68,$11,$F5,$EA
	dc.b	$FF,$FF,$0D,$10,$0D,$10,$92,$A9,$FF,$FF,$A2,$48,$A2,$48,$55,$B4
	dc.b	$FF,$CF,$0E,$00,$0E,$3F,$51,$3F,$E2,$00,$00,$00,$FC,$00,$FC
	dcb.b	81,$00
	dc.b	$03,$FF,$00,$00,$00,$00,$01,$FF,$FF,$FF,$20,$90,$20,$90,$DF,$6B
	dc.b	$FF,$FF,$A1,$22,$A1,$22,$56,$D5,$FF,$FF,$24,$12,$24,$12,$DA,$ED
	dc.b	$FF,$FE,$28,$88,$28,$88,$57,$55,$FF,$FF,$04,$11,$F4,$11,$FB,$AA
	dc.b	$FF,$FD,$11,$12,$11,$10,$AE,$AB,$FF,$FE,$A2,$49,$A2,$48,$55,$B5
	dc.b	$7F,$87,$83,$00,$03,$7F,$DC,$FF,$C4,$00,$00,$00,$F8,$00,$F8
	dcb.b	81,$00
	dc.b	$01,$FF,$00,$00,$00,$00,$00,$FF,$FF,$FF,$20,$89,$20,$89,$D1,$76
	dc.b	$FF,$FF,$D3,$A2,$D3,$A2,$2C,$55,$FF,$FF,$A2,$22,$A2,$22,$55,$D5
	dc.b	$FF,$FE,$28,$88,$28,$88,$57,$55,$FF,$FF,$06,$31,$F6,$31,$F9,$CA
	dc.b	$FF,$FF,$11,$19,$11,$19,$AE,$A6,$FF,$FF,$22,$44,$22,$44,$D5,$AB
	dc.b	$FF,$87,$51,$00,$51,$7F,$AE,$FF,$C4,$00,$00,$00,$F8,$00,$F8
	dcb.b	81,$00
	dc.b	$01,$FF,$00,$00,$00,$00,$00,$FF,$FF,$FF,$71,$C6,$71,$C6,$8A,$29
	dc.b	$FF,$FF,$8D,$71,$8D,$71,$52,$8E,$FF,$FF,$71,$C7,$71,$C7,$8A,$28
	dc.b	$FF,$FE,$77,$5C,$77,$5C,$88,$A3,$F7,$FF,$01,$C3,$F1,$C3,$FE,$34
	dc.b	$FF,$FF,$8E,$96,$8E,$96,$71,$69,$FF,$FF,$77,$E3,$77,$E3,$88,$14
	dc.b	$FF,$C0,$9E,$00,$9E,$3F,$61,$3F,$08,$00,$00,$00,$F0,$00,$F0
	dcb.b	82,$00
	dc.b	$FF,$00,$00,$00,$00,$00,$7F,$FF,$FF,$00,$00,$00,$00,$F7,$D6,$FF
	dc.b	$FF,$00,$00,$00,$00,$8D,$75,$FF,$FF,$00,$00,$00,$00,$75,$C7,$FF
	dc.b	$FE,$00,$00,$00,$00,$77,$5D,$F7,$FF,$00,$00,$F0,$00,$F9,$C3,$FF
	dc.b	$FF,$00,$10,$00,$10,$AE,$AE,$FF,$F7,$00,$08,$00,$00,$77,$EB,$FF
	dc.b	$C0,$00,$00,$00,$3F,$9E,$3F,$08,$00,$00,$00,$F0,$00,$F0
	dcb.b	82,$00
	dc.b	$FF,$00,$00,$00,$00,$00,$7F,$FF,$FF,$00,$00,$00,$00,$82,$08,$FF
	dc.b	$FF,$00,$00,$00,$00,$10,$02,$FF,$FF,$00,$00,$00,$00,$02,$08,$FF
	dc.b	$FF,$00,$00,$00,$00,$00,$00,$F7,$FF,$00,$00,$F0,$00,$FC,$04,$FF
	dc.b	$FF,$00,$10,$00,$10,$10,$28,$FF,$FB,$00,$04,$00,$00,$00,$04,$FF
	dc.b	$80,$00,$00,$00,$7F,$00,$7F,$10,$00,$00,$00,$80,$00,$E0
	dcb.b	82,$00
	dc.b	$7F,$00,$00,$00,$00,$00,$3F,$FF,$FF,$00,$00,$00,$00,$C7,$1C,$FF
	dc.b	$FF,$00,$00,$00,$00,$B9,$47,$FF,$FF,$00,$00,$00,$00,$47,$1C,$FF
	dc.b	$FE,$00,$00,$00,$00,$44,$51,$F7,$FF,$00,$00,$F0,$00,$FF,$1E,$F7
	dc.b	$7F,$08,$B8,$00,$38,$38,$C4,$7F,$F1,$00,$0E,$C0,$00,$C4,$0E,$CF
	dc.b	$00,$00,$00,$30,$FF,$30,$FF,$E0
	dcb.b	88,$00
	dc.b	$7F,$00,$00,$00,$00,$00,$3F,$FF,$FF,$00,$00,$00,$00,$FF,$FF,$FF
	dc.b	$FF,$00,$00,$00,$00,$FF,$FF,$FF,$FE,$00,$00,$00,$00,$FF,$FF,$FF
	dc.b	$FE,$00,$00,$00,$00,$FF,$FF,$F7,$FF,$00,$00,$F0,$00,$FF,$FF,$E0
	dc.b	$3C,$1F,$00,$00,$C3,$FF,$FB,$37,$00,$00,$FF,$F0,$00,$FF,$FF,$00
	dc.b	$00,$00,$00,$FF,$FF,$FF,$FF,$80
	dcb.b	88,$00
	dc.b	$3F,$00,$00,$00,$00,$00,$1F,$FF,$FF,$00,$00,$00,$00,$FF,$FF,$FF
	dc.b	$FF,$00,$00,$00,$00,$FF,$FF,$FF,$FF,$00,$00,$00,$00,$FF,$FF,$7F
	dc.b	$FE,$00,$00,$00,$00,$FF,$FF,$EF,$FF,$00,$00,$E0,$00,$FF,$FF,$E0
	dc.b	$3E,$1E,$00,$01,$C1,$FF,$C1,$0E,$00,$01,$FE,$FC,$01,$FF,$FF,$00
	dc.b	$01,$00,$00,$FF,$FE,$FF,$FE
	dcb.b	89,$00
	dc.b	$3F,$00,$00,$00,$00,$00,$1F,$FF,$FF,$00,$00,$00,$00,$FF,$FF,$FF
	dc.b	$FF,$00,$00,$00,$00,$FF,$FF,$FF,$FF,$00,$00,$00,$00,$FF,$FF,$BF
	dc.b	$FE,$00,$00,$00,$00,$FF,$FF,$9F,$FF,$00,$00,$80,$00,$FF,$FF,$C0
	dc.b	$1C,$3C,$00,$03,$E3,$FF,$E3,$04,$00,$03,$FE,$FC,$01,$FF,$FF,$00
	dc.b	$02,$00,$00,$FF,$FC,$FF,$FC
	dcb.b	89,$00
	dc.b	$3F,$00,$00,$00,$00,$00,$1F,$FF,$FF,$00,$00,$00,$00,$FF,$FF,$FF
	dc.b	$FF,$00,$00,$00,$00,$FF,$FF,$FF,$FF,$00,$00,$00,$00,$FF,$FF,$DF
	dc.b	$FE,$00,$00,$00,$00,$FF,$FF,$7F,$FF,$00,$00,$00,$00,$FF,$FF,$C0
	dc.b	$00,$3C,$00,$03,$FF,$FF,$FF,$00,$00,$03,$FC,$FC,$03,$FF,$FF,$00
	dc.b	$02,$00,$00,$FF,$FC,$FF,$FC
	dcb.b	89,$00
	dc.b	$1F,$00,$00,$00,$00,$00,$0F,$FF,$FF,$07,$00,$07,$00,$FF,$FF,$FF
	dc.b	$FF,$20,$00,$20,$00,$FF,$FF,$FF,$FF,$01,$D0,$01,$D0,$FF,$FF,$EF
	dc.b	$FC,$00,$00,$00,$00,$FF,$FF,$FF,$FF,$00,$04,$00,$04,$FF,$FF,$80
	dc.b	$00,$78,$00,$07,$FF,$FF,$FF,$00,$00,$01,$FC,$FE,$03,$FF,$FF,$00
	dc.b	$04,$00,$00,$FF,$F8,$FF,$F8
	dcb.b	89,$00
	dc.b	$1F,$00,$00,$00,$00,$00,$0F,$FF,$FF,$02,$00,$02,$00,$FF,$7F,$FF
	dc.b	$FF,$60,$00,$60,$00,$FF,$FF,$FF,$FF,$06,$30,$06,$30,$FF,$FF,$F7
	dc.b	$F3,$00,$00,$00,$00,$FF,$FF,$FF,$FF,$00,$00,$00,$00,$FF,$FD,$00
	dc.b	$00,$F0,$00,$0F,$FF,$FF,$FF,$00,$00,$00,$78,$FF,$87,$FF,$FF,$00
	dc.b	$04,$00,$00,$FF,$F8,$FF,$F8
	dcb.b	89,$00
	dc.b	$0F,$00,$00,$00,$00,$00,$07,$FF,$FF,$02,$00,$02,$00,$FF,$3F,$FF
	dc.b	$FF,$20,$00,$20,$00,$FF,$FF,$FF,$FF,$04,$10,$04,$10,$FE,$3F,$FF
	dc.b	$DF,$00,$00,$00,$00,$FF,$FF,$FF,$FF,$00,$00,$00,$00,$FF,$FC,$D8
	dc.b	$7C,$20,$00,$07,$83,$FF,$FF,$00,$00,$00,$38,$FF,$C7,$FF,$FF,$00
	dc.b	$08,$00,$00,$FF,$F0,$FF,$F0
	dcb.b	89,$00
	dc.b	$0F,$00,$00,$00,$00,$00,$07,$FF,$FF,$02,$1C,$02,$1C,$FF,$7F,$FF
	dc.b	$FF,$2C,$D8,$2C,$D8,$FF,$FF,$FF,$FF,$08,$06,$08,$06,$FC,$1F,$FF
	dc.b	$FF,$6D,$98,$6D,$98,$FF,$FF,$FF,$FF,$D9,$84,$D9,$84,$FF,$FF,$FC
	dc.b	$FE,$D8,$7C,$DB,$7D,$FF,$FF,$00,$00,$00,$00,$FF,$FF,$FF,$FF,$00
	dc.b	$08,$00,$00,$FF,$F0,$FF,$F0
	dcb.b	89,$00
	dc.b	$07,$00,$00,$00,$00,$00,$03,$FF,$FF,$02,$22,$02,$22,$FF,$7F,$FF
	dc.b	$FF,$32,$64,$32,$64,$FF,$FF,$FF,$FF,$08,$02,$08,$02,$FC,$E7,$FF
	dc.b	$FF,$26,$64,$26,$64,$FF,$FF,$FF,$FE,$66,$4D,$66,$4C,$FF,$FF,$FF
	dc.b	$FF,$64,$88,$64,$88,$FF,$FD,$FF,$F0,$00,$00,$00,$0F,$FF,$FF,$00
	dc.b	$10,$00,$00,$FF,$E0,$FF,$E0
	dcb.b	89,$00
	dc.b	$07,$00,$00,$00,$00,$00,$03,$FF,$FF,$02,$41,$02,$41,$FF,$E3,$FF
	dc.b	$FF,$22,$44,$22,$44,$F7,$EF,$FF,$FF,$08,$02,$08,$02,$FD,$F7,$FF
	dc.b	$FF,$24,$44,$24,$44,$7E,$EF,$FF,$FF,$44,$44,$44,$44,$EE,$FE,$FF
	dc.b	$FF,$44,$88,$44,$88,$EF,$DC,$FF,$FC,$00,$00,$00,$03,$FF,$FF,$00
	dc.b	$20,$00,$00,$FF,$C0,$FF,$C0
	dcb.b	89,$00
	dc.b	$03,$00,$00,$00,$00,$00,$01,$FF,$FF,$02,$41,$02,$41,$FF,$E3,$FF
	dc.b	$FF,$22,$44,$22,$44,$F7,$EE,$FF,$FF,$08,$02,$08,$02,$FD,$FF,$FF
	dc.b	$FF,$24,$44,$24,$44,$7E,$EE,$FF,$FF,$44,$44,$44,$44,$EE,$EE,$FF
	dc.b	$FE,$44,$89,$44,$88,$EF,$FD,$00,$FF,$FF,$00,$00,$00,$FF,$FF,$00
	dc.b	$20,$00,$00,$FF,$C0,$FF,$C0
	dcb.b	89,$00
	dc.b	$03,$00,$00,$00,$00,$00,$01,$FF,$FF,$32,$41,$32,$41,$FF,$EF,$FF
	dc.b	$FF,$22,$44,$22,$44,$F7,$EE,$FF,$FF,$04,$12,$04,$12,$FF,$FF,$FF
	dc.b	$FF,$24,$44,$24,$44,$7E,$EE,$FF,$FF,$44,$44,$44,$44,$EE,$EE,$FF
	dc.b	$FE,$44,$71,$44,$70,$EE,$F9,$00,$00,$FF,$FF,$00,$00,$FF,$FF,$00
	dc.b	$40,$E0,$00,$1F,$80,$FF,$80
	dcb.b	89,$00
	dc.b	$01,$00,$00,$00,$00,$00,$00,$FF,$FF,$32,$22,$32,$22,$FF,$7F,$FF
	dc.b	$FF,$22,$44,$22,$44,$77,$EE,$FF,$FF,$06,$22,$06,$22,$FF,$F7,$FF
	dc.b	$FF,$74,$44,$74,$44,$FE,$EE,$FF,$FF,$44,$44,$44,$44,$EE,$EE,$FF
	dc.b	$FE,$44,$81,$44,$80,$EF,$F9,$00,$00,$FF,$F0,$00,$00,$FF,$FF,$00
	dc.b	$40,$00,$00,$07,$80,$FF,$80
	dcb.b	89,$00
	dc.b	$01,$00,$00,$00,$00,$00,$00,$FF,$FF,$1C,$1C,$1C,$1C,$FE,$3E,$FF
	dc.b	$FF,$77,$EE,$77,$EE,$FF,$FF,$FF,$FF,$01,$C1,$01,$C1,$FF,$E3,$FF
	dc.b	$FF,$AE,$EE,$AE,$EE,$FF,$FF,$FF,$FF,$EE,$EE,$EE,$EE,$FF,$FF,$FF
	dc.b	$FC,$EE,$FB,$EE,$F8,$FF,$FF,$00,$00,$FF,$00,$00,$00,$FF,$FF,$03
	dc.b	$80,$00,$00,$00,$00,$FC,$00,$0C,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$1F
	dcb.b	71,$00
	dc.b	$FF,$FF,$00,$00,$00,$00,$5C,$5C,$FF,$FF,$00,$00,$00,$00,$77,$EE
	dc.b	$FF,$FF,$00,$00,$00,$00,$F9,$C5,$FF,$FF,$00,$00,$00,$00,$AE,$EE
	dc.b	$FF,$FF,$00,$00,$00,$00,$EE,$EE,$FF,$FE,$01,$05,$01,$04,$EF,$FF
	dc.b	$00,$00,$F0,$00,$00,$00,$FF,$FF,$1F,$80,$03,$00,$07,$80,$E0,$00
	dc.b	$3F,$00,$0C,$00,$1E,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$3F,$80,$DF,$40,$3F,$80
	dcb.b	66,$00
	dc.b	$FF,$FF,$00,$00,$00,$00,$60,$E0,$FF,$FF,$00,$00,$00,$00,$80,$00
	dc.b	$FF,$FF,$00,$00,$00,$00,$7C,$0E,$FF,$FF,$00,$00,$00,$00,$00,$00
	dc.b	$FF,$FF,$00,$00,$00,$00,$00,$00,$FF,$FE,$01,$05,$01,$04,$03,$FF
	dc.b	$00,$01,$00,$00,$00,$00,$FF,$FE,$EF,$80,$07,$C0,$07,$80,$00,$00
	dc.b	$7F,$80,$3E,$00,$3E,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$01,$00,$00,$00,$00,$FF,$F0,$7F,$C0,$FF,$E0
	dcb.b	66,$00
	dc.b	$7F,$FF,$00,$00,$00,$00,$31,$F1,$FF,$FF,$00,$00,$00,$00,$C4,$08
	dc.b	$FF,$FF,$00,$00,$00,$00,$FF,$1F,$FF,$FF,$00,$00,$00,$00,$28,$88
	dc.b	$FF,$F7,$00,$08,$00,$00,$88,$88,$77,$FF,$80,$F8,$00,$F8,$89,$FC
	dc.b	$00,$1E,$00,$00,$00,$18,$FF,$F8,$0F,$C0,$07,$80,$07,$C0,$00,$00
	dc.b	$FF,$80,$7E,$00,$7E,$00,$00,$C0,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$03,$00,$01,$00,$01,$00,$00,$FF,$F8,$FF,$E0,$FF,$F0
	dcb.b	66,$00
	dc.b	$7F,$FF,$00,$00,$00,$00,$3F,$FF,$FF,$FF,$00,$00,$00,$00,$FF,$FF
	dc.b	$FF,$FF,$00,$00,$00,$00,$FF,$FF,$FF,$FF,$00,$00,$00,$00,$FF,$FF
	dc.b	$FF,$C0,$00,$3F,$00,$00,$FF,$FF,$01,$FF,$FE,$00,$1E,$00,$FE,$F8
	dc.b	$00,$FC,$01,$00,$01,$F8,$FF,$F8,$0F,$C1,$07,$E0,$07,$C0,$00,$00
	dc.b	$FF,$40,$FE,$80,$FE,$00,$00,$80,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$07,$00,$03,$00,$03,$00,$00,$F6,$FC,$E9,$F0,$F0,$F0
	dcb.b	66,$00
	dc.b	$7F,$FF,$00,$00,$00,$00,$3F,$FF,$FF,$FF,$00,$00,$00,$00,$FF,$FF
	dc.b	$FF,$FF,$00,$00,$00,$00,$FF,$FF,$FF,$FF,$00,$00,$00,$00,$FF,$FF
	dc.b	$FF,$80,$00,$7F,$00,$00,$FF,$FF,$00,$FE,$FF,$00,$3F,$00,$FF,$01
	dc.b	$01,$F8,$1E,$00,$1F,$F0,$FF,$F0,$0F,$F3,$07,$C1,$07,$E1,$00,$00
	dc.b	$FF,$60,$FE,$80,$FE,$00,$00,$80,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$07,$00,$03,$00,$07,$00,$00,$C1,$72,$F1,$F8,$CE,$70,$1F,$04
	dcb.b	64,$00
	dc.b	$7F,$FF,$00,$00,$00,$00,$3F,$FF,$FF,$FF,$00,$00,$00,$00,$FF,$FF
	dc.b	$FF,$FF,$00,$00,$00,$00,$FF,$FF,$FF,$FF,$00,$00,$00,$00,$FF,$FF
	dc.b	$FF,$80,$00,$7F,$00,$00,$FF,$FF,$00,$7C,$FF,$83,$7F,$83,$FF,$83
	dc.b	$01,$F0,$FE,$00,$FF,$E0,$FF,$E0,$07,$EF,$0F,$F3,$07,$E3,$00,$00
	dc.b	$FF,$F0,$FE,$80,$FE,$00,$00,$80,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$07,$00,$0F,$00,$07,$00,$00,$EF,$F8,$A1,$74,$9E,$78,$3F,$02
	dcb.b	64,$00
	dc.b	$FF,$FF,$00,$00,$00,$00,$7F,$FF,$FF,$FF,$00,$00,$00,$00,$FF,$FF
	dc.b	$FF,$FF,$00,$00,$00,$00,$FF,$FF,$FF,$FF,$00,$00,$00,$00,$FF,$FF
	dc.b	$FF,$00,$00,$FF,$00,$00,$FF,$FF,$00,$00,$FF,$FF,$FF,$FF,$FF,$FF
	dc.b	$03,$E0,$FC,$00,$FF,$C0,$FF,$C0,$0F,$7F,$07,$7F,$0F,$F7,$00,$00
	dc.b	$FE,$FC,$FD,$80,$FE,$00,$01,$80,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$0F,$00,$07,$00,$0F,$00,$00,$27,$FF,$E4,$78,$18,$78,$7E,$02
	dcb.b	64,$00
	dc.b	$FF,$FF,$00,$00,$00,$00,$7F,$FF,$FF,$FF,$00,$00,$00,$00,$FF,$FF
	dc.b	$FF,$FF,$00,$00,$00,$00,$FF,$FF,$FF,$FF,$00,$00,$00,$00,$FF,$FF
	dc.b	$FE,$00,$01,$FF,$00,$01,$FF,$FF,$00,$00,$FF,$FF,$FF,$FF,$FF,$FF
	dc.b	$07,$E0,$F8,$00,$FF,$C0,$FF,$C0,$1F,$FF,$0F,$3F,$0F,$7F,$00,$00
	dc.b	$FD,$7F,$FF,$04,$BC,$8E,$01,$80,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$0F,$00,$1E,$00,$0F,$00,$00,$07,$F9,$F0,$3E,$00,$78,$78,$02
	dc.b	$80
	dcb.b	63,$00
	dc.b	$BF,$FF,$00,$00,$00,$00,$7F,$FF,$FF,$FF,$00,$00,$00,$00,$FF,$FF
	dc.b	$FF,$FF,$00,$00,$00,$00,$FF,$FF,$FF,$FF,$00,$00,$00,$00,$FF,$FF
	dc.b	$FE,$00,$01,$FF,$00,$03,$FF,$FF,$00,$00,$FF,$FF,$FF,$FF,$FF,$FF
	dc.b	$0F,$C0,$F0,$00,$FF,$80,$FF,$80,$1F,$BF,$0F,$7F,$0F,$3F,$00,$00
	dc.b	$7F,$FF,$BD,$8E,$3C,$1F,$01,$80,$80,$02,$00,$00,$00,$00,$00,$00
	dc.b	$00,$1E,$00,$0F,$00,$1E,$00,$00,$FF,$BD,$00,$7E,$00,$3C,$E0,$00
	dc.b	$FF,$FF,$00,$00,$00,$00,$00,$00,$FF
	dcb.b	55,$00
	dc.b	$BF,$FF,$00,$00,$00,$00,$7F,$FF,$FF,$FF,$00,$00,$00,$00,$FF,$FF
	dc.b	$FF,$FF,$00,$00,$00,$00,$FF,$FF,$FF,$FF,$00,$00,$00,$00,$FF,$FF
	dc.b	$FC,$00,$03,$FF,$00,$07,$FF,$FF,$00,$00,$FF,$FF,$FF,$FF,$FF,$FF
	dc.b	$1F,$80,$E0,$00,$FF,$00,$FF,$00,$1F,$FF,$0F,$1E,$0F,$3F,$00,$00
	dc.b	$FE,$7F,$3D,$8E,$3C,$1F,$01,$80,$40,$07,$80,$02,$00,$07,$00,$00
	dc.b	$80,$1E,$00,$3D,$00,$1E,$00,$00,$DF,$FF,$00,$3F,$00,$3F,$E0,$00
	dc.b	$FF,$FF,$FF,$FF,$FF,$FF,$00,$00,$FF,$C0,$FF,$00,$FF,$80
	dcb.b	50,$00
	dc.b	$BF,$FF,$00,$00,$00,$00,$7F,$FF,$9F,$FF,$00,$00,$00,$00,$FF,$FF
	dc.b	$FF,$FF,$00,$00,$00,$00,$FF,$FF,$FF,$FF,$00,$00,$00,$00,$FF,$FF
	dc.b	$FC,$00,$03,$FF,$00,$0F,$FF,$FF,$00,$00,$FF,$FF,$FF,$FF,$FF,$FF
	dc.b	$3F,$81,$C0,$00,$FF,$00,$FF,$00,$C6,$8F,$1F,$7C,$0F,$1E,$00,$40
	dc.b	$DB,$7F,$3C,$04,$3C,$0E,$81,$80,$62,$0A,$40,$07,$80,$07,$C0,$00
	dc.b	$40,$39,$80,$1E,$00,$3C,$00,$01,$7F,$FF,$80,$1F,$00,$3F,$C0,$00
	dc.b	$FF,$FF,$FF,$FF,$FF,$FF,$00,$00,$FF,$E0,$FF,$80,$FF,$C0
	dcb.b	43,$00
	dc.b	$01,$00,$00,$00,$00,$00,$00,$7F,$FE,$00,$00,$00,$00,$FF,$FF,$03
	dc.b	$FF,$00,$00,$60,$00,$FF,$FF,$FF,$FF,$00,$00,$00,$00,$FF,$FF,$FF
	dc.b	$FF,$00,$00,$00,$00,$FF,$FF,$F8,$00,$07,$FF,$00,$1F,$FF,$FF,$00
	dc.b	$00,$FF,$FF,$FF,$FF,$FF,$FF,$3F,$04,$C0,$02,$FE,$01,$FE,$00,$01
	dc.b	$E6,$AE,$49,$DF,$1C,$00,$41,$66,$FD,$98,$03,$3C,$00,$81,$01,$B0
	dc.b	$0C,$0A,$83,$C7,$07,$C0,$00,$3C,$26,$40,$59,$80,$3C,$00,$01,$3E
	dc.b	$20,$80,$17,$00,$0F,$C0,$00,$00,$00,$FF,$FF,$FF,$FF,$00,$00,$00
	dc.b	$30,$FF,$E0,$FF,$C0
	dcb.b	43,$00
	dc.b	$01,$00,$00,$00,$00,$00,$00,$7F,$F8,$00,$00,$00,$01,$FF,$FF,$00
	dc.b	$FF,$00,$00,$FC,$00,$FF,$FF,$FF,$FF,$00,$00,$00,$00,$FF,$FF,$FF
	dc.b	$FF,$00,$00,$00,$00,$FF,$FF,$F8,$00,$07,$FF,$00,$3F,$FF,$FF,$00
	dc.b	$00,$FF,$FF,$FF,$FF,$FF,$FF,$7E,$00,$80,$17,$FC,$0F,$FC,$00,$71
	dc.b	$FE,$8E,$4A,$DF,$01,$00,$43,$27,$E0,$D8,$0D,$3C,$1E,$81,$01,$E0
	dc.b	$24,$CF,$8B,$1F,$C7,$C0,$00,$01,$81,$FC,$3B,$FE,$7C,$00,$03,$7C
	dc.b	$3F,$80,$00,$00,$00,$80,$00,$FF,$FF,$00,$00,$00,$00,$00,$00,$FF
	dc.b	$F8
	dcb.b	47,$00
	dc.b	$01,$00,$00,$00,$00,$00,$00,$7C,$00,$00,$70,$00,$07,$FF,$FF,$00
	dc.b	$1F,$00,$00,$FF,$00,$FF,$FF,$FF,$FF,$00,$00,$00,$00,$FF,$FF,$FF
	dc.b	$FF,$00,$00,$00,$00,$FF,$FF,$F0,$00,$0F,$FF,$00,$7F,$FF,$FF,$00
	dc.b	$00,$FF,$FF,$FF,$FF,$FF,$FF,$FC,$3F,$00,$60,$F8,$1F,$F8,$00,$AE
	dc.b	$3A,$00,$C0,$DF,$07,$00,$47,$79,$ED,$C2,$00,$3C,$1E,$81,$00,$3F
	dc.b	$C7,$E0,$10,$1F,$EF,$80,$00,$FC,$B0,$01,$04,$FE,$7B,$00,$03,$F8
	dc.b	$7E,$00,$11,$00,$20,$80,$07,$60,$73,$E0,$7C,$1F,$80,$FF,$FF,$FE
	dc.b	$78,$01,$F0,$00,$00,$FF,$F0
	dcb.b	41,$00
	dc.b	$01,$00,$00,$00,$00,$00,$00,$60,$00,$03,$C0,$00,$0F,$FF,$FF,$00
	dc.b	$03,$00,$00,$FF,$E0,$FF,$FF,$FF,$FF,$00,$00,$00,$00,$FF,$FF,$FF
	dc.b	$FF,$00,$00,$00,$00,$FF,$FF,$F0,$00,$0F,$FF,$00,$FF,$FF,$FF,$00
	dc.b	$01,$FF,$FE,$FF,$FF,$FF,$FF,$FD,$FF,$00,$80,$F8,$7F,$F8,$00,$EC
	dc.b	$BE,$81,$44,$1E,$03,$00,$C7,$B0,$ED,$07,$00,$78,$1E,$03,$00,$92
	dc.b	$57,$45,$00,$38,$EF,$80,$00,$FF,$B4,$01,$00,$FE,$7B,$00,$03,$F8
	dc.b	$AF,$00,$00,$00,$70,$00,$07,$38,$19,$F8,$1E,$07,$E0,$FF,$FF,$FF
	dc.b	$34,$00,$F8,$00,$00,$FF,$F8
	dcb.b	41,$00
	dc.b	$01,$00,$00,$00,$00,$00,$00,$00,$00,$1F,$00,$00,$3F,$FF,$FF,$00
	dc.b	$00,$00,$00,$FF,$FC,$FF,$FF,$7F,$FF,$00,$00,$00,$00,$FF,$FF,$FF
	dc.b	$FF,$00,$00,$00,$00,$FF,$FF,$E0,$00,$1F,$FF,$00,$FF,$FF,$FF,$00
	dc.b	$01,$FF,$FE,$FF,$FF,$FF,$FF,$F9,$05,$03,$06,$F0,$F8,$F0,$00,$73
	dc.b	$FD,$92,$02,$0C,$00,$40,$C2,$CE,$C3,$4B,$22,$30,$1C,$03,$00,$C1
	dc.b	$BB,$4E,$AB,$30,$44,$06,$00,$0F,$89,$10,$0E,$E0,$70,$00,$03,$F0
	dc.b	$DD,$00,$50,$00,$20,$00,$06,$FF,$FF,$00,$00,$00,$00,$00,$00,$FF
	dc.b	$FE
	dcb.b	47,$00
	dc.b	$02,$00,$00,$00,$00,$00,$01,$00,$00,$7C,$00,$00,$7F,$FF,$FF,$00
	dc.b	$00,$00,$00,$FF,$FF,$FF,$FF,$0F,$FF,$00,$00,$80,$00,$FF,$FF,$FF
	dc.b	$FF,$00,$00,$00,$00,$FF,$FF,$C0,$00,$3F,$FF,$01,$FF,$FF,$FF,$00
	dc.b	$03,$FF,$FC,$FF,$FF,$FF,$FF,$FC,$2B,$04,$37,$E3,$C0,$E0,$07,$B3
	dc.b	$FB,$D2,$00,$0C,$00,$C0,$C0,$4D,$E3,$C9,$22,$32,$1C,$03,$00,$DA
	dc.b	$EF,$57,$1D,$20,$00,$07,$00,$3D,$91,$20,$9E,$C0,$60,$0E,$06,$F0
	dc.b	$DB,$00,$50,$00,$20,$00,$04,$FF,$FF,$00,$00,$00,$00,$00,$00,$FF
	dc.b	$FF
	dcb.b	47,$00
	dc.b	$0C,$00,$01,$00,$00,$00,$03,$03,$80,$E0,$00,$00,$1F,$FF,$FF,$00
	dc.b	$00,$00,$00,$FF,$FF,$FF,$FF,$03,$FF,$00,$00,$F0,$00,$FF,$FF,$FF
	dc.b	$FF,$00,$00,$00,$00,$FF,$FF,$C0,$00,$3F,$FF,$03,$FF,$FF,$FF,$00
	dc.b	$07,$FF,$F8,$FF,$FF,$FF,$FF,$F7,$17,$0F,$F0,$C0,$0F,$C0,$1F,$1C
	dc.b	$B9,$7F,$00,$80,$00,$C0,$C0,$7F,$FC,$FA,$3E,$00,$00,$02,$01,$F7
	dc.b	$DF,$78,$31,$00,$00,$06,$30,$D7,$FF,$E8,$F0,$00,$00,$1E,$06,$E0
	dc.b	$FF,$00,$70,$00,$00,$00,$04,$FF,$FF,$00,$00,$00,$00,$00,$00,$FF
	dc.b	$FF
	dcb.b	47,$00
	dc.b	$10,$00,$03,$00,$00,$00,$0F,$1F,$E0,$80,$00,$00,$07,$FF,$FF,$00
	dc.b	$00,$00,$00,$FF,$FF,$FF,$FF,$00,$7F,$00,$00,$FC,$00,$FF,$FF,$FF
	dc.b	$FF,$00,$00,$00,$00,$FF,$FF,$80,$00,$7F,$FF,$07,$FF,$FF,$FF,$00
	dc.b	$0F,$FF,$F0,$FF,$FF,$FF,$FF,$EE,$80,$1F,$60,$C0,$1F,$C0,$7F,$D9
	dc.b	$B9,$3E,$00,$00,$00,$81,$C0,$71,$D9,$FE,$3E,$00,$00,$00,$00,$B3
	dc.b	$E6,$7C,$19,$00,$00,$00,$18,$9F,$6F,$E0,$F0,$00,$00,$00,$06,$E1
	dc.b	$6B,$00,$F4,$00,$00,$00,$0C,$FF,$FF,$00,$00,$00,$00,$00,$00,$FF
	dc.b	$FE
	dcb.b	47,$00
	dc.b	$20,$00,$0C,$00,$00,$00,$1F,$7F,$F8,$00,$00,$00,$00,$FF,$FF,$00
	dc.b	$00,$00,$00,$FF,$FF,$FF,$FF,$00,$1F,$00,$00,$FF,$C0,$FF,$FF,$FF
	dc.b	$FF,$00,$00,$00,$00,$FF,$FF,$80,$00,$7F,$FF,$0F,$FF,$FF,$FF,$00
	dc.b	$0F,$FF,$F0,$FF,$FF,$FF,$FF,$E0,$07,$1F,$78,$80,$00,$80,$FC,$C2
	dc.b	$78,$3D,$80,$00,$00,$01,$80,$01,$C0,$FE,$3F,$00,$00,$00,$00,$80
	dc.b	$0E,$7F,$E1,$00,$00,$00,$10,$03,$0D,$FC,$F0,$00,$00,$00,$06,$C1
	dc.b	$0F,$00,$FC,$00,$00,$00,$0C,$C0
	dcb.b	56,$00
	dc.b	$C3,$00,$00,$00,$00,$00,$3F,$FF,$FF,$00,$00,$00,$00,$FF,$FF,$00
	dc.b	$00,$00,$00,$3F,$FF,$FF,$FF,$00,$0F,$00,$20,$FF,$A0,$FF,$FF,$FF
	dc.b	$FF,$00,$00,$00,$00,$FF,$FF,$00,$00,$FF,$FF,$1F,$FF,$FF,$FF,$00
	dc.b	$1F,$FF,$E0,$FF,$FF,$FF,$FF,$A0,$EF,$1E,$00,$00,$00,$01,$70,$C3
	dc.b	$78,$3D,$80,$00,$00,$03,$80,$83,$E0,$7C,$1F,$00,$00,$00,$80,$40
	dc.b	$17,$3F,$E0,$00,$00,$80,$08,$03,$8B,$FC,$70,$00,$00,$00,$04,$C3
	dc.b	$93,$00,$60,$00,$0C,$00,$1C,$C0
	dcb.b	55,$00
	dc.b	$01,$1F,$00,$00,$00,$00,$00,$FF,$FF,$FF,$00,$00,$00,$00,$FF,$FF
	dc.b	$C0,$00,$00,$00,$0F,$FF,$FF,$FF,$00,$07,$00,$70,$FF,$70,$FF,$FF
	dc.b	$FF,$FF,$00,$00,$00,$00,$FF,$FF,$00,$00,$FF,$FF,$3F,$FF,$FF,$FF
	dc.b	$00,$3F,$FF,$C0,$FF,$FE,$FF,$FE,$7F,$FF,$00,$00,$00,$00,$01,$80
	dc.b	$FC,$F0,$00,$00,$03,$00,$03,$80,$FE,$7F,$00,$80,$00,$00,$01,$81
	dc.b	$DF,$C7,$C0,$00,$00,$00,$E0,$38,$FF,$FF,$00,$00,$00,$00,$00,$00
	dc.b	$C7,$FB,$00,$10,$00,$0C,$00,$1C,$C0
	dcb.b	55,$00
	dc.b	$02,$7F,$00,$00,$00,$00,$01,$FF,$FF,$FF,$00,$00,$00,$00,$FF,$FF
	dc.b	$F0,$00,$00,$00,$01,$FF,$FF,$FF,$00,$03,$00,$F8,$FE,$F8,$FF,$FF
	dc.b	$FF,$FE,$00,$01,$00,$00,$FF,$FF,$00,$00,$FF,$FF,$7F,$FF,$FF,$FF
	dc.b	$00,$7F,$FF,$80,$FF,$FE,$FF,$FE,$7F,$FF,$00,$00,$00,$00,$01,$80
	dc.b	$FC,$F0,$00,$00,$03,$00,$07,$00,$7F,$FF,$00,$02,$00,$01,$01,$87
	dc.b	$BF,$9F,$00,$00,$C0,$00,$D0,$60,$FF,$FF,$06,$00,$00,$00,$0E,$00
	dc.b	$DF,$DF,$00,$18,$00,$00,$00,$3C,$C0
	dcb.b	55,$00
	dc.b	$03,$FF,$00,$00,$00,$00,$01,$FF,$FF,$FF,$00,$00,$00,$00,$FF,$FF
	dc.b	$FE,$00,$00,$00,$00,$7F,$FF,$FF,$00,$00,$01,$FC,$F9,$FC,$FF,$FF
	dc.b	$FF,$FF,$00,$00,$00,$00,$FF,$FF,$00,$00,$FF,$FF,$FF,$FF,$FF,$FF
	dc.b	$00,$7E,$FF,$80,$FF,$FC,$FF,$FC,$41,$FE,$00,$00,$00,$00,$3E,$81
	dc.b	$09,$F0,$05,$00,$02,$00,$F7,$00,$39,$ED,$00,$04,$00,$03,$07,$9F
	dc.b	$71,$7E,$4E,$80,$80,$00,$CF,$00,$60,$81,$19,$00,$06,$00,$7F,$7E
	dc.b	$E0,$77,$00,$18,$00,$00,$1F,$B8,$80
	dcb.b	55,$00
	dc.b	$02,$FF,$00,$00,$00,$00,$01,$FF,$FF,$FF,$00,$00,$00,$00,$FF,$FF
	dc.b	$FF,$80,$00,$00,$00,$0F,$FF,$FF,$00,$00,$07,$FF,$F7,$FF,$FF,$FF
	dc.b	$7F,$FC,$00,$03,$00,$03,$FF,$FF,$00,$00,$FF,$FF,$FF,$FF,$FF,$FF
	dc.b	$00,$FC,$FF,$00,$FF,$F8,$FF,$F8,$20,$70,$00,$00,$00,$00,$1F,$8F
	dc.b	$01,$F0,$06,$00,$00,$00,$FF,$00,$1E,$F2,$00,$07,$00,$00,$1F,$0F
	dc.b	$FE,$FD,$01,$7A,$00,$FC,$80,$00,$31,$80,$0E,$00,$00,$00,$7E,$7F
	dc.b	$00,$F7,$00,$00,$00,$00,$FF,$78,$80
	dcb.b	55,$00
	dc.b	$02,$FF,$00,$00,$00,$00,$01,$FF,$FF,$FF,$00,$00,$00,$00,$FF,$FF
	dc.b	$FF,$F0,$00,$00,$00,$03,$FF,$FF,$00,$00,$0F,$FF,$EF,$FF,$FF,$FF
	dc.b	$3F,$FC,$80,$03,$80,$03,$FF,$FF,$00,$00,$FF,$FF,$FF,$FF,$FF,$FF
	dc.b	$01,$F8,$FE,$00,$FF,$F0,$FF,$F0,$2F,$FF,$00,$00,$00,$00,$1F,$FF
	dc.b	$DB,$E0,$04,$00,$00,$00,$EE,$00,$0F,$F7,$00,$00,$00,$00,$1E,$00
	dc.b	$FB,$FF,$05,$FE,$03,$FF,$00,$00,$3F,$DF,$00,$00,$00,$00,$00,$3F
	dc.b	$FD,$FF,$00,$00,$00,$00,$FE,$F0,$80
	dcb.b	55,$00
	dc.b	$02,$FF,$00,$00,$00,$00,$01,$FF,$FF,$FF,$00,$00,$00,$00,$FF,$FF
	dc.b	$FF,$FC,$00,$00,$00,$00,$FF,$FF,$00,$00,$1F,$FF,$DF,$FF,$FF,$FF
	dc.b	$1F,$FE,$C0,$01,$C0,$01,$FF,$FF,$00,$00,$FF,$FF,$FF,$FF,$FF,$FF
	dc.b	$03,$F8,$FC,$00,$FF,$F0,$FF,$F0,$17,$FF,$00,$00,$00,$00,$0F,$FF
	dc.b	$BD,$E0,$00,$00,$00,$00,$DE,$00,$0F,$F3,$00,$00,$00,$00,$00,$00
	dc.b	$FF,$FF,$07,$FF,$0F,$FF,$00,$00,$1F,$EF,$80,$00,$00,$00,$00,$1F
	dc.b	$FB,$5F,$00,$80,$00,$00,$FF,$E0
	dcb.b	56,$00
	dc.b	$01,$7F,$00,$00,$00,$00,$00,$FF,$FF,$FF,$00,$00,$00,$00,$FF,$FF
	dc.b	$FF,$FF,$00,$00,$00,$00,$FF,$FF,$00,$00,$3F,$FF,$3F,$FF,$FF,$FF
	dc.b	$0F,$FE,$E0,$01,$E0,$01,$FF,$FF,$00,$00,$FF,$FF,$FF,$FF,$FF,$FF
	dc.b	$07,$F0,$F8,$00,$FF,$E0,$FF,$E0,$0C,$01,$03,$FE,$00,$00,$07,$FF
	dc.b	$BB,$E0,$00,$00,$00,$00,$FC,$00,$07,$F1,$00,$00,$00,$00,$00,$00
	dc.b	$FF,$AF,$0F,$5F,$1F,$8F,$00,$00,$8F,$F4,$00,$03,$80,$00,$00,$0F
	dc.b	$3F,$FF,$C7,$86,$00,$0F,$FF,$C0
	dcb.b	56,$00
	dc.b	$01,$7F,$00,$00,$00,$00,$00,$FF,$FF,$FC,$00,$00,$00,$00,$FF,$FF
	dc.b	$07,$FF,$00,$00,$00,$00,$FF,$FF,$C0,$00,$1F,$FF,$1F,$FF,$FF,$FF
	dc.b	$07,$FE,$F0,$01,$F0,$01,$FF,$FF,$00,$00,$FF,$FF,$FF,$FF,$FF,$FF
	dc.b	$07,$E0,$F8,$00,$FF,$C0,$FF,$C0,$00,$07,$01,$F8,$00,$00,$07,$FF
	dc.b	$EF,$C0,$F0,$00,$00,$00,$F8,$00,$03,$F0,$00,$00,$00,$00,$00,$00
	dc.b	$DE,$C7,$3F,$4F,$1E,$37,$00,$70,$E7,$D3,$80,$00,$80,$00,$20,$0C
	dc.b	$EF,$6F,$01,$9F,$1E,$0F,$3F,$80,$80
	dcb.b	55,$00
	dc.b	$01,$7F,$00,$00,$00,$00,$00,$FF,$FF,$FB,$00,$03,$00,$00,$FF,$FF
	dc.b	$E1,$FF,$E8,$00,$08,$00,$FF,$FF,$E0,$00,$0F,$FF,$0F,$FF,$FF,$FF
	dc.b	$03,$FF,$F8,$00,$F8,$00,$FF,$FF,$00,$00,$FF,$FF,$FF,$FF,$FF,$FF
	dc.b	$0F,$C0,$F0,$00,$FF,$80,$FF,$80,$04,$FC,$00,$00,$00,$03,$03,$07
	dc.b	$AF,$C0,$30,$00,$C0,$00,$F0,$00,$01,$C0,$00,$00,$00,$00,$00,$00
	dc.b	$7F,$F7,$1C,$7F,$3E,$07,$00,$F0,$C0,$0E,$A0,$01,$80,$00,$30,$07
	dc.b	$7D,$FF,$E0,$0E,$1E,$1F,$FF,$00,$40,$00,$80
	dcb.b	53,$00
	dc.b	$01,$7F,$00,$00,$00,$00,$00,$FF,$FF,$E7,$00,$07,$00,$00,$FF,$FF
	dc.b	$80,$FF,$9E,$00,$1E,$00,$FF,$FF,$F0,$00,$07,$FF,$07,$FF,$FF,$FF
	dc.b	$00,$FF,$FC,$00,$FC,$00,$FF,$FF,$00,$00,$FF,$FF,$FF,$FF,$FF,$FF
	dc.b	$1F,$C0,$E0,$00,$FF,$80,$FF,$80,$03,$9B,$00,$78,$00,$07,$01,$FF
	dc.b	$DF,$FF,$60,$00,$80,$00,$E0,$00,$FF,$FF,$00,$00,$00,$00,$00,$00
	dc.b	$BF,$EF,$7E,$1F,$3C,$0F,$00,$00,$B8,$05,$60,$00,$80,$00,$60,$03
	dc.b	$3F,$FE,$F8,$1F,$00,$1E,$FC,$00,$E0,$00,$00,$00,$00,$00,$C0
	dcb.b	49,$00
	dc.b	$01,$7F,$00,$00,$00,$00,$00,$FF,$FF,$DF,$00,$1F,$00,$00,$FF,$FF
	dc.b	$00,$7F,$7F,$00,$7F,$00,$FF,$FF,$F8,$00,$01,$FF,$01,$FF,$FF,$FF
	dc.b	$00,$7F,$FF,$00,$FF,$00,$FF,$FF,$00,$00,$FF,$FF,$FF,$FF,$FF,$FF
	dc.b	$3F,$80,$C0,$00,$FF,$00,$FF,$00,$01,$4F,$00,$3F,$00,$00,$00,$FF
	dc.b	$FF,$FF,$1F,$FF,$3F,$FF,$80,$00,$FF,$FF,$FF,$FF,$FF,$FF,$00,$00
	dc.b	$FF,$FF,$FF,$FE,$FF,$FF,$00,$00,$98,$03,$00,$00,$60,$00,$60,$00
	dc.b	$FF,$CD,$00,$3E,$00,$1E,$00,$00,$30,$00,$C0,$00,$00,$00,$C0
	dcb.b	50,$00
	dc.b	$BF,$00,$00,$00,$00,$00,$7F,$FF,$BE,$00,$3E,$00,$00,$FF,$FF,$00
	dc.b	$1F,$FF,$80,$FF,$80,$FF,$FF,$FE,$00,$00,$FF,$00,$FF,$FF,$FF,$00
	dc.b	$3F,$FF,$80,$FF,$80,$FF,$FF,$80,$00,$7F,$FF,$7F,$FF,$FF,$FF,$7F
	dc.b	$00,$80,$00,$FE,$00,$FE,$00,$00,$FF,$00,$00,$00,$00,$00,$00,$80
	dc.b	$00,$3F,$FF,$7F,$FF,$00,$00,$00,$00,$FF,$FF,$FF,$FF,$00,$00,$00
	dc.b	$01,$FF,$FC,$FF,$FE,$00,$00,$BE,$01,$A0,$00,$40,$00,$E0,$00,$FF
	dc.b	$C0,$00,$1D,$00,$3E,$00,$01,$B8,$00,$C0,$00,$00,$00,$C0
	dcb.b	50,$00
	dc.b	$7F,$00,$00,$00,$00,$00,$3F,$FF,$00,$00,$01,$00,$01,$FF,$FF,$00
	dc.b	$2F,$FF,$C0,$FF,$C0,$FF,$FF,$FF,$00,$00,$7F,$00,$7F,$FF,$FF,$00
	dc.b	$1F,$FF,$C0,$FF,$C0,$FF,$FF,$80,$00,$7F,$FF,$7F,$FF,$FF,$FF,$7E
	dc.b	$00,$80,$00,$FC,$00,$FC,$00,$00,$7F,$00,$00,$00,$00,$00,$00,$80
	dc.b	$00,$FF,$FF,$7F,$FF,$00,$00,$00,$00,$FF,$FF,$FF,$FF,$00,$00,$00
	dc.b	$04,$FF,$EB,$FF,$F0,$00,$01,$A1,$00,$CC,$00,$1E,$00,$C0,$00,$FF
	dc.b	$E5,$00,$1B,$00,$3C,$00,$01,$78,$00,$00,$00,$80,$00,$C0
	dcb.b	50,$00
	dc.b	$5F,$00,$00,$00,$00,$00,$3F,$FF,$7E,$00,$00,$00,$00,$FF,$FF,$00
	dc.b	$0F,$FF,$C0,$FF,$C0,$FF,$FF,$FF,$80,$00,$3F,$00,$3F,$FF,$FF,$00
	dc.b	$0F,$FF,$E0,$FF,$E0,$FF,$FF,$80,$00,$7F,$FF,$7F,$FF,$FF,$FF,$FC
	dc.b	$00,$00,$00,$F8,$00,$F8,$00,$00,$3F,$00,$00,$00,$00,$00,$00,$FF
	dc.b	$FF,$00,$00,$00,$00,$00,$00,$FF,$FF,$00,$00,$00,$00,$00,$00,$CF
	dc.b	$EF,$20,$90,$1F,$00,$00,$0F,$4C,$82,$A1,$00,$1E,$00,$00,$04,$3F
	dc.b	$9A,$00,$40,$00,$3D,$00,$01,$7F,$80,$00,$00,$80,$00,$80,$40
	dcb.b	49,$00
	dc.b	$3F,$00,$00,$00,$00,$00,$1F,$FF,$7F,$00,$00,$00,$00,$FF,$FF,$00
	dc.b	$2F,$7F,$80,$7F,$A0,$FF,$FF,$FF,$C0,$00,$1F,$00,$1F,$FF,$FF,$00
	dc.b	$0F,$FF,$F0,$FF,$F0,$FF,$FF,$C0,$01,$3F,$FE,$3F,$FF,$FF,$FF,$FC
	dc.b	$00,$00,$00,$F8,$00,$F8,$00,$00,$0F,$00,$00,$00,$00,$00,$00,$A6
	dc.b	$07,$1E,$07,$01,$F8,$7F,$FF,$3F,$E1,$C0,$1E,$00,$00,$FF,$FE,$F7
	dc.b	$FF,$00,$80,$0F,$00,$00,$3E,$FF,$EF,$80,$45,$7F,$82,$00,$00,$1F
	dc.b	$FC,$0A,$46,$04,$39,$00,$01,$FF,$C0,$84,$60,$03,$80,$80,$10
	dcb.b	49,$00
	dc.b	$1B,$00,$00,$00,$00,$00,$07,$FF,$7F,$00,$00,$00,$00,$FF,$FF,$80
	dc.b	$6F,$1F,$00,$1F,$60,$FF,$FF,$FF,$E0,$00,$0F,$00,$0F,$FF,$FF,$00
	dc.b	$07,$FF,$F8,$FF,$F8,$FF,$FF,$C0,$03,$3F,$FC,$3F,$FF,$FF,$FF,$F8
	dc.b	$00,$00,$00,$F0,$00,$F0,$00,$00,$00,$00,$00,$00,$00,$00,$00,$73
	dc.b	$81,$0F,$81,$00,$7E,$3F,$FF,$9F,$F9,$E0,$07,$00,$00,$FF,$F8,$3C
	dc.b	$7F,$24,$41,$C3,$80,$00,$1C,$00,$79,$00,$49,$FF,$86,$00,$00,$73
	dc.b	$C1,$92,$47,$0C,$38,$40,$03,$F0,$18,$10,$10,$0F,$E0,$80,$04
	dcb.b	49,$00
	dc.b	$06,$00,$00,$00,$00,$00,$01,$FF,$7F,$00,$00,$00,$00,$FF,$FF,$E0
	dc.b	$EF,$0E,$00,$0E,$E0,$FF,$FF,$FF,$F0,$00,$07,$00,$07,$FF,$FF,$00
	dc.b	$03,$FF,$FC,$FF,$FC,$FF,$FF,$C0,$07,$3F,$F8,$3F,$FF,$FF,$FF,$F0
	dc.b	$00,$00,$00,$E0,$00,$E0,$00,$00,$00,$00,$00,$00,$00,$00,$00,$3F
	dc.b	$FF,$00,$00,$00,$00,$00,$00,$FF,$F4,$00,$0C,$00,$03,$00,$00,$0A
	dc.b	$2F,$16,$21,$E1,$C0,$00,$10,$00,$EA,$00,$9B,$FF,$04,$00,$20,$F3
	dc.b	$CC,$D2,$4B,$0C,$30,$C0,$03,$E7,$C8,$26,$4C,$18,$30,$00,$02
	dcb.b	49,$00
	dc.b	$01,$00,$00,$00,$00,$00,$00,$9F,$7F,$00,$00,$00,$00,$7F,$FF,$F1
	dc.b	$EF,$04,$00,$05,$E0,$FF,$FF,$FF,$F8,$00,$01,$00,$01,$FF,$FF,$00
	dc.b	$00,$FF,$FF,$FF,$FF,$FF,$FF,$C0,$0F,$3F,$F0,$3F,$FF,$FF,$FF,$E0
	dc.b	$00,$00,$00,$C0,$00,$C0,$00,$00,$00,$00,$00,$00,$00,$00,$00,$1F
	dc.b	$FF,$00,$00,$00,$00,$00,$00,$FF,$EF,$00,$1F,$00,$00,$00,$00,$85
	dc.b	$E7,$FB,$F0,$00,$00,$08,$08,$7B,$6C,$FC,$9F,$00,$00,$00,$61,$5C
	dc.b	$73,$7E,$FC,$80,$00,$C1,$03,$FB,$7E,$3C,$F8,$00,$00,$00,$03
	dcb.b	56,$00
	dc.b	$67,$9F,$00,$00,$00,$00,$1F,$FF,$FB,$DF,$00,$00,$03,$C0,$FF,$FF
	dc.b	$FF,$FE,$00,$00,$00,$00,$FF,$FF,$00,$00,$FF,$FF,$FF,$FF,$FF,$FF
	dc.b	$60,$0F,$9F,$F0,$9F,$FF,$FF,$FF,$E0,$00,$00,$00,$C0,$00,$C0,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$07,$FF,$00,$00,$00,$00,$00,$00
	dc.b	$FF,$CE,$00,$3F,$00,$00,$00,$00,$2A,$E7,$9D,$F0,$00,$00,$7C,$08
	dc.b	$B6,$C9,$78,$3F,$00,$00,$01,$C1,$5B,$62,$3C,$F8,$80,$00,$C0,$07
	dc.b	$BF,$F5,$7F,$FA,$00,$00,$00,$06
	dcb.b	56,$00
	dc.b	$18,$EF,$00,$00,$00,$00,$07,$FF,$FB,$BF,$00,$00,$03,$80,$FF,$FF
	dc.b	$FF,$FF,$00,$00,$00,$00,$FF,$FF,$00,$00,$7F,$FF,$7F,$FF,$FF,$FF
	dc.b	$20,$1F,$DF,$E0,$DF,$FF,$FF,$FF,$C0,$00,$00,$00,$80,$00,$80,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$07,$FF,$00,$00,$00,$00,$00,$00
	dc.b	$FF,$C1,$00,$3E,$00,$00,$00,$00,$62,$03,$1D,$F8,$00,$00,$FC,$04
	dc.b	$05,$C3,$F8,$3D,$00,$00,$02,$03,$C3,$01,$BC,$F8,$00,$00,$80,$06
	dc.b	$80,$0B,$7F,$F6,$00,$00,$00,$06
	dcb.b	56,$00
	dc.b	$07,$37,$00,$00,$00,$00,$00,$FF,$FB,$7F,$00,$00,$03,$00,$FF,$FF
	dc.b	$FF,$FF,$00,$00,$00,$00,$FF,$FF,$80,$00,$3F,$FF,$3F,$FF,$FF,$FF
	dc.b	$20,$3F,$DF,$C0,$DF,$FF,$FF,$FF,$80,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$43,$00,$3C,$00,$00,$00,$01,$F7,$07,$00,$F8,$00,$00,$F8,$00
	dc.b	$8F,$EE,$70,$11,$00,$00,$00,$03,$C5,$8F,$3A,$70,$00,$00,$02,$00
	dc.b	$83,$FF,$7C,$00,$00,$00,$00,$00,$80
	dcb.b	56,$00
	dc.b	$C9,$00,$00,$00,$00,$00,$3F,$FA,$FF,$00,$00,$02,$00,$FF,$FF,$FF
	dc.b	$FF,$00,$00,$00,$00,$FF,$FF,$C0,$00,$1F,$FF,$1F,$FF,$FF,$FF,$70
	dc.b	$7F,$8F,$80,$CF,$FE,$FF,$FE,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$FC,$00,$01,$00,$00,$00,$03,$5F,$FD,$80,$00,$00,$00,$E0,$02,$FF
	dc.b	$FF,$00,$00,$00,$00,$00,$00,$FF,$FF,$02,$00,$00,$00,$02,$00,$FF
	dc.b	$FF,$00,$00,$00,$00,$00,$00,$C0
	dcb.b	56,$00
	dc.b	$32,$00,$00,$00,$00,$00,$0F,$39,$FF,$00,$00,$00,$00,$FF,$FF,$FF
	dc.b	$FF,$00,$00,$00,$00,$FF,$FF,$E0,$00,$0F,$FF,$0F,$FF,$FF,$FF,$F0
	dc.b	$FF,$0F,$00,$CF,$FE,$FF,$FE,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$FD,$00,$03,$00,$00,$00,$03,$3F,$FF,$80,$00,$00,$00,$C0,$00,$FF
	dc.b	$FF,$00,$00,$00,$00,$00,$00,$F9,$FF,$02,$00,$00,$00,$06,$00,$FF
	dc.b	$FF,$00,$00,$00,$00,$00,$00,$40,$00,$80,$00,$00,$00,$80
	dcb.b	50,$00
	dc.b	$0C,$00,$00,$00,$00,$00,$03,$43,$FF,$00,$00,$00,$00,$FF,$FF,$FF
	dc.b	$FF,$00,$00,$00,$00,$FF,$FF,$F0,$01,$07,$FE,$07,$FF,$FF,$FF,$F0
	dc.b	$FE,$0F,$00,$CF,$FC,$FF,$FC,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$87,$00,$03,$00,$00,$00,$7B,$7F,$83,$00,$00,$00,$00,$80,$7D,$83
	dc.b	$20,$00,$C0,$00,$00,$7D,$DF,$09,$C1,$06,$00,$00,$00,$F6,$3E,$30
	dc.b	$04,$C0,$01,$00,$00,$CF,$FB,$C0,$00,$80,$00,$00,$00,$80
	dcb.b	50,$00
	dc.b	$03,$00,$00,$00,$00,$00,$00,$9F,$FF,$00,$00,$00,$00,$7F,$FF,$FF
	dc.b	$FF,$00,$00,$00,$00,$FF,$FF,$F8,$03,$01,$FC,$01,$FF,$FF,$FF,$F9
	dc.b	$FC,$06,$00,$C7,$F8,$FF,$F8,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$82,$00,$01,$00,$00,$00,$7D,$FF,$82,$00,$01,$00,$00,$00,$7D,$FF
	dc.b	$BC,$03,$C0,$00,$00,$07,$C3,$0F,$FE,$00,$01,$00,$00,$F6,$01,$BF
	dc.b	$FE,$C0,$01,$00,$00,$D0,$07,$40,$00,$80,$00,$00,$00,$80
	dcb.b	57,$00
	dc.b	$67,$FF,$00,$00,$00,$00,$1F,$FF,$FF,$FF,$00,$00,$00,$00,$FF,$FF
	dc.b	$FE,$07,$00,$F8,$00,$FF,$FF,$FF,$FF,$F8,$00,$00,$C7,$F0,$FF,$F0
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$BB,$00,$00,$00,$00,$00,$7C
	dc.b	$F9,$7B,$00,$00,$00,$00,$00,$FD,$F3,$F9,$1C,$00,$00,$00,$3E,$07
	dc.b	$EF,$FF,$00,$00,$00,$00,$F0,$00,$FF,$FF,$00,$00,$00,$00,$00,$00
	dc.b	$FF
	dcb.b	63,$00
	dc.b	$19,$FF,$00,$00,$00,$00,$07,$FF,$FF,$FF,$00,$00,$00,$00,$FF,$FF
	dc.b	$FF,$0F,$00,$70,$00,$7F,$FF,$FF,$FF,$F0,$00,$00,$C7,$E0,$FF,$E0
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$3D,$00,$00,$00,$00,$00,$7E
	dc.b	$F2,$F8,$00,$00,$00,$00,$01,$FF,$EF,$FF,$10,$00,$00,$00,$1F,$FF
	dc.b	$FF,$FF,$00,$00,$00,$00,$FF,$FF,$FF,$FF,$00,$00,$00,$00,$FF,$FF
	dc.b	$FE,$80,$00,$00,$00,$00,$FF
	dcb.b	57,$00
	dc.b	$06,$7F,$00,$00,$00,$00,$01,$FF,$FF,$FF,$00,$00,$00,$00,$FF,$FF
	dc.b	$FF,$9F,$00,$20,$00,$3F,$FF,$FF,$FF,$F0,$00,$00,$C7,$E0,$FF,$E0
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$61,$00,$1E,$00,$00,$00,$3F
	dc.b	$7A,$0D,$01,$F0,$00,$00,$87,$FA,$F8,$00,$07,$FF,$00,$00,$0F,$FF
	dc.b	$00,$00,$FF,$FF,$00,$00,$FF,$FF,$00,$00,$FF,$FF,$00,$00,$FF,$FF
	dc.b	$03,$40,$FC,$80,$00,$00,$FE,$80
	dcb.b	56,$00
	dc.b	$01,$8F,$00,$00,$00,$00,$00,$7F,$FF,$FF,$00,$00,$00,$00,$FF,$FF
	dc.b	$FF,$DF,$00,$00,$00,$1F,$FF,$FF,$FF,$E0,$00,$00,$C7,$C0,$FF,$C0
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$30,$00,$0F,$00,$00,$00,$1F
	dc.b	$00,$1C,$FF,$E2,$00,$00,$FF,$F7,$F0,$00,$0F,$FF,$00,$00,$1F,$FF
	dc.b	$00,$00,$FF,$FF,$00,$00,$FF,$FF,$00,$00,$FF,$FF,$00,$00,$FF,$FF
	dc.b	$06,$80,$F9,$C0,$00,$00,$FD,$E0
	dcb.b	57,$00
	dc.b	$73,$00,$00,$00,$00,$00,$0F,$FF,$FF,$00,$00,$00,$00,$FF,$FF,$FF
	dc.b	$DF,$00,$00,$00,$1F,$FF,$FF,$FF,$C0,$00,$00,$C7,$80,$FF,$80,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$17,$00,$0F,$00,$00,$00,$0F,$FF
	dc.b	$DC,$FF,$EE,$00,$00,$FF,$EF,$DC,$FB,$3E,$07,$00,$00,$3F,$0F,$7F
	dc.b	$FF,$80,$00,$00,$00,$C0,$00,$FF,$FF,$00,$00,$00,$00,$00,$00,$FA
	dc.b	$20,$01,$C0,$00,$00,$07,$C0
	dcb.b	57,$00
	dc.b	$0C,$00,$00,$00,$00,$00,$03,$FF,$FF,$00,$00,$00,$00,$FF,$FF,$FF
	dc.b	$DF,$00,$00,$00,$1F,$FF,$FF,$FF,$80,$00,$00,$C7,$00,$FF,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$05,$00,$03,$00,$00,$00,$0F,$FF
	dc.b	$49,$FF,$A2,$00,$1C,$FF,$FE,$DE,$F7,$3C,$0F,$00,$00,$3F,$EF,$87
	dc.b	$3F,$07,$C0,$78,$00,$FF,$FF,$E6,$07,$1E,$07,$01,$F8,$FF,$FF,$3F
	dc.b	$F0,$C0,$00,$00,$00,$FF,$80
	dcb.b	57,$00
	dc.b	$03,$00,$00,$00,$00,$00,$00,$3F,$FF,$00,$00,$00,$00,$FF,$FF,$FF
	dc.b	$DF,$00,$00,$00,$1F,$FF,$FF,$FF,$80,$00,$00,$87,$00,$FF,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$09,$00,$00,$00,$00,$00,$06,$83
	dc.b	$DF,$44,$44,$38,$38,$FE,$FC,$E6,$F0,$24,$11,$18,$0E,$3F,$DF,$B1
	dc.b	$9F,$01,$E0,$7E,$00,$FF,$FF,$F3,$81,$0F,$81,$00,$7E,$FF,$FF,$9C
	dc.b	$F8,$E0,$00,$00,$00,$FF
	dcb.b	65,$00
	dc.b	$C7,$FF,$00,$00,$00,$00,$3F,$FF,$FF,$DF,$00,$00,$00,$1F,$FF,$FF
	dc.b	$FF,$00,$00,$00,$86,$00,$FE,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$04,$00,$00,$00,$00,$00,$03,$BE,$0F,$01,$88,$00,$70,$C7,$F8
	dc.b	$C3,$E3,$22,$22,$1C,$1C,$3F,$7E,$3F,$FF,$A0,$00,$40,$00,$F0,$00
	dc.b	$FF,$FF,$00,$00,$00,$00,$00,$00,$FF,$F8
	dcb.b	70,$00
	dc.b	$39,$FF,$00,$00,$00,$00,$07,$FF,$FF,$DF,$00,$00,$00,$1F,$FF,$FF
	dc.b	$FE,$00,$00,$00,$00,$00,$FC,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$02,$00,$00,$00,$00,$00,$01,$BE,$1F,$01,$E0,$00,$00,$FF,$F0
	dc.b	$FF,$FF,$10,$04,$0F,$F8,$1F,$FD,$1F,$FF,$C0,$00,$00,$00,$E0,$00
	dc.b	$FF,$FF,$00,$00,$00,$00,$00,$00,$FF,$F8
	dcb.b	70,$00
	dc.b	$06,$7F,$00,$00,$00,$00,$01,$FF,$FF,$DF,$00,$00,$00,$1E,$FF,$FE
	dc.b	$FC
	dcb.b	32,$00
	dc.b	$01,$00,$00,$00,$00,$00,$00,$CF,$7F,$00,$00,$00,$00,$3F,$80,$DF
	dc.b	$FF,$08,$08,$07,$F0,$0F,$FB,$FF,$FF,$00,$00,$00,$00,$C0,$00,$FF
	dc.b	$FF,$00,$00,$00,$00,$00,$00,$FF,$F0
	dcb.b	70,$00
	dc.b	$01,$9F,$00,$00,$00,$00,$00,$7F,$FF,$DE,$00,$00,$00,$1C,$FF,$FC
	dcb.b	40,$00
	dc.b	$FF,$FF,$00,$00,$00,$00,$00,$00,$80,$0F,$05,$E0,$03,$F0,$0F,$F7
	dc.b	$7F,$FF,$00,$00,$00,$00,$80,$00,$FF,$FF,$00,$00,$00,$00,$00,$00
	dc.b	$FF,$E0
	dcb.b	71,$00
	dc.b	$67,$00,$00,$00,$00,$00,$1F,$FF,$DC,$00,$00,$00,$18,$FF,$F8
	dcb.b	40,$00
	dc.b	$7F,$FF,$00,$00,$00,$00,$00,$00,$01,$E1,$06,$1E,$00,$00,$0E,$1F
	dc.b	$FC
	dcb.b	88,$00
	dc.b	$18,$00,$00,$00,$00,$00,$07,$FF,$DC,$00,$00,$00,$18,$FF,$F8
	dcb.b	40,$00
	dc.b	$1F,$FC,$00,$00,$00,$00,$00,$00,$05,$01,$03,$06,$00,$F8,$03,$FE
	dc.b	$F8
	dcb.b	88,$00
	dc.b	$07,$00,$00,$00,$00,$00,$00,$3F,$D8,$00,$00,$00,$10,$FF,$F0
	dcb.b	40,$00
	dc.b	$03,$E0,$00,$00,$00,$00,$00,$00,$03,$8F,$00,$88,$00,$70,$01,$FC
	dc.b	$F8
	dcb.b	95,$00
	dc.b	$CF,$D0,$00,$00,$00,$00,$3F,$E0
	dcb.b	48,$00
	dc.b	$01,$FF,$00,$00,$00,$00,$00,$00,$F0
	dcb.b	95,$00
	dc.b	$33,$20,$00,$00,$00,$00,$0F,$C0
	dcb.b	49,$00
	dc.b	$FF,$00,$00,$00,$00,$00,$00,$E0
	dcb.b	95,$00
	dc.b	$0C,$C0,$00,$00,$00,$00,$03
	dcb.b	50,$00
	dc.b	$7F,$00,$00,$00,$00,$00,$00,$C0
	dcb.b	95,$00
	dc.b	$03
	dcb.b	56,$00
	dc.b	$1F,$00,$00,$00,$00,$00,$00,$80,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$04,$00,$08,$00,$0C,$00,$03,$00,$07,$00,$0B,$00,$0F,$00
	dc.b	$01,$00,$01,$00,$01,$00,$01,$00,$80,$00,$54,$00,$2A
	dcb.b	42,$00
	dc.b	$02,$7F,$00,$00,$00,$00,$01,$FF,$FF,$FF,$00,$00,$00,$00,$FF,$FF
	dc.b	$F0,$00,$00,$00,$01,$FF,$FF,$FF,$00,$03,$00,$F8,$FE,$F8,$FF,$FF
	dc.b	$FF,$FE,$00,$01,$00,$00,$FF,$FF,$00,$00,$FF,$FF,$7F,$FF,$FF,$FF
	dc.b	$00,$7F,$FF,$80,$FF,$FE,$FF,$FE,$7F,$FF,$00,$00,$00,$00,$01,$80
	dc.b	$FC,$F0,$00,$00,$03,$00,$07,$00,$7F,$FF,$00,$02,$00,$01,$01,$87
	dc.b	$BF,$9F,$00,$00,$C0,$00,$D0,$60,$FF,$FF,$06,$00,$00,$00,$0E,$00
	dc.b	$DF,$DF,$00,$18,$00,$00,$00,$3C,$C0
	dcb.b	55,$00
	dc.b	$03,$FF,$00,$00,$00,$00,$01,$FF,$FF,$FF,$00,$00,$00,$00,$FF,$FF
	dc.b	$FE,$00,$00,$00,$00,$7F,$FF,$FF,$00,$00,$01,$FC,$F9,$FC,$FF,$FF
	dc.b	$FF,$FF,$00,$00,$00,$00,$FF,$FF,$00,$00,$FF,$FF,$FF,$FF,$FF,$FF
	dc.b	$00,$7E,$FF,$80,$FF,$FC,$FF,$FC,$41,$FE,$00,$00,$00,$00,$3E,$81
	dc.b	$09,$F0,$05,$00,$02,$00,$F7,$00,$39,$ED,$00,$04,$00,$03,$07,$9F
	dc.b	$71,$7E,$4E,$80,$80,$00,$CF,$00,$60,$81,$19,$00,$06,$00,$7F,$7E
	dc.b	$E0,$77,$00,$18,$00,$00,$1F,$B8,$80
	dcb.b	55,$00
	dc.b	$02,$FF,$00,$00,$00,$00,$01,$FF,$FF,$FF,$00,$00,$00,$00,$FF,$FF
	dc.b	$FF,$80,$00,$00,$00,$0F,$FF,$FF,$00,$00,$07,$FF,$F7,$FF,$FF,$FF
	dc.b	$7F,$FC,$00,$03,$00,$03,$FF,$FF,$00,$00,$FF,$FF,$FF,$FF,$FF,$FF
	dc.b	$00,$FC,$FF,$00,$FF,$F8,$FF,$F8,$20,$70,$00,$00,$00,$00,$1F,$8F
	dc.b	$01,$F0,$06,$00,$00,$00,$FF,$00,$1E,$F2,$00,$07,$00,$00,$1F,$0F
	dc.b	$FE,$FD,$01,$7A,$00,$FC,$80,$00,$31,$80,$0E,$00,$00,$00,$7E,$7F
	dc.b	$00,$F7,$00,$00,$00,$00,$FF,$78,$80
	dcb.b	55,$00
	dc.b	$02,$FF,$00,$00,$00,$00,$01,$FF,$FF,$FF,$00,$00,$00,$00,$FF,$FF
	dc.b	$FF,$F0,$00,$00,$00,$03,$FF,$FF,$00,$00,$0F,$FF,$EF,$FF,$FF,$FF
	dc.b	$3F,$FC,$80,$03,$80,$03,$FF,$FF,$00,$00,$FF,$FF,$FF,$FF,$FF,$FF
	dc.b	$01,$F8,$FE,$00,$FF,$F0,$FF,$F0,$2F,$FF,$00,$00,$00,$00,$1F,$FF
	dc.b	$DB,$E0,$04,$00,$00,$00,$EE,$00,$0F,$F7,$00,$00,$00,$00,$1E,$00
	dc.b	$FB,$FF,$05,$FE,$03,$FF,$00,$00,$3F,$DF,$00,$00,$00,$00,$00,$3F
	dc.b	$FD,$FF,$00,$00,$00,$00,$FE,$F0,$80
	dcb.b	55,$00
	dc.b	$02,$FF,$00,$00,$00,$00,$01,$FF,$FF,$FF,$00,$00,$00,$00,$FF,$FF
	dc.b	$FF,$FC,$00,$00,$00,$00,$FF,$FF,$00,$00,$1F,$FF,$DF,$FF,$FF,$FF
	dc.b	$1F,$FE,$C0,$01,$C0,$01,$FF,$FF,$00,$00,$FF,$FF,$FF,$FF,$FF,$FF
	dc.b	$03,$F8,$FC,$00,$FF,$F0,$FF,$F0,$17,$FF,$00,$00,$00,$00,$0F,$FF
	dc.b	$BD,$E0,$00,$00,$00,$00,$DE,$00,$0F,$F3,$00,$00,$00,$00,$00,$00
	dc.b	$FF,$FF,$07,$FF,$0F,$FF,$00,$00,$1F,$EF,$80,$00,$00,$00,$00,$1F
	dc.b	$FB,$5F,$00,$80,$00,$00,$FF,$E0
	dcb.b	56,$00
	dc.b	$01,$7F,$00,$00,$00,$00,$00,$FF,$FF,$FF,$00,$00,$00,$00,$FF,$FF
	dc.b	$FF,$FF,$00,$00,$00,$00,$FF,$FF,$00,$00,$3F,$FF,$3F,$FF,$FF,$FF
	dc.b	$0F,$FE,$E0,$01,$E0,$01,$FF,$FF,$00,$00,$FF,$FF,$FF,$FF,$FF,$FF
	dc.b	$07,$F0,$F8,$00,$FF,$E0,$FF,$E0,$0C,$01,$03,$FE,$00,$00,$07,$FF
	dc.b	$BB,$E0,$00,$00,$00,$00,$FC,$00,$07,$F1,$00,$00,$00,$00,$00,$00
	dc.b	$FF,$AF,$0F,$5F,$1F,$8F,$00,$00,$8F,$F4,$00,$03,$80,$00,$00,$0F
	dc.b	$3F,$FF,$C7,$86,$00,$0F,$FF,$C0
	dcb.b	56,$00
	dc.b	$01,$7F,$00,$00,$00,$00,$00,$FF,$FF,$FC,$00,$00,$00,$00,$FF,$FF
	dc.b	$07,$FF,$00,$00,$00,$00,$FF,$FF,$C0,$00,$1F,$FF,$1F,$FF,$FF,$FF
	dc.b	$07,$FE,$F0,$01,$F0,$01,$FF,$FF,$00,$00,$FF,$FF,$FF,$FF,$FF,$FF
	dc.b	$07,$E0,$F8,$00,$FF,$C0,$FF,$C0,$00,$07,$01,$F8,$00,$00,$07,$FF
	dc.b	$EF,$C0,$F0,$00,$00,$00,$F8,$00,$03,$F0,$00,$00,$00,$00,$00,$00
	dc.b	$DE,$C7,$3F,$4F,$1E,$37,$00,$70,$E7,$D3,$80,$00,$80,$00,$20,$0C
	dc.b	$EF,$6F,$01,$9F,$1E,$0F,$3F,$80,$80
	dcb.b	55,$00
	dc.b	$01,$7F,$00,$00,$00,$00,$00,$FF,$FF,$FB,$00,$03,$00,$00,$FF,$FF
	dc.b	$E1,$FF,$E8,$00,$08,$00,$FF,$FF,$E0,$00,$0F,$FF,$0F,$FF,$FF,$FF
	dc.b	$03,$FF,$F8,$00,$F8,$00,$FF,$FF,$00,$00,$FF,$FF,$FF,$FF,$FF,$FF
	dc.b	$0F,$C0,$F0,$00,$FF,$80,$FF,$80,$04,$FC,$00,$00,$00,$03,$03,$07
	dc.b	$AF,$C0,$30,$00,$C0,$00,$F0,$00,$01,$C0,$00,$00,$00,$00,$00,$00
	dc.b	$7F,$F7,$1C,$7F,$3E,$07,$00,$F0,$C0,$0E,$A0,$01,$80,$00,$30,$07
	dc.b	$7D,$FF,$E0,$0E,$1E,$1F,$FF,$00,$40,$00,$80
	dcb.b	53,$00
	dc.b	$01,$7F,$00,$00,$00,$00,$00,$FF,$FF,$E7,$00,$07,$00,$00,$FF,$FF
	dc.b	$80,$FF,$9E,$00,$1E,$00,$FF,$FF,$F0,$00,$07,$FF,$07,$FF,$FF,$FF
	dc.b	$00,$FF,$FC,$00,$FC,$00,$FF,$FF,$00,$00,$FF,$FF,$FF,$FF,$FF,$FF
	dc.b	$1F,$C0,$E0,$00,$FF,$80,$FF,$80,$03,$9B,$00,$78,$00,$07,$01,$FF
	dc.b	$DF,$FF,$60,$00,$80,$00,$E0,$00,$FF,$FF,$00,$00,$00,$00,$00,$00
	dc.b	$BF,$EF,$7E,$1F,$3C,$0F,$00,$00,$B8,$05,$60,$00,$80,$00,$60,$03
	dc.b	$3F,$FE,$F8,$1F,$00,$1E,$FC,$00,$E0,$00,$00,$00,$00,$00,$C0
	dcb.b	49,$00
	dc.b	$01,$7F,$00,$00,$00,$00,$00,$FF,$FF,$DF,$00,$1F,$00,$00,$FF,$FF
	dc.b	$00,$7F,$7F,$00,$7F,$00,$FF,$FF,$F8,$00,$01,$FF,$01,$FF,$FF,$FF
	dc.b	$00,$7F,$FF,$00,$FF,$00,$FF,$FF,$00,$00,$FF,$FF,$FF,$FF,$FF,$FF
	dc.b	$3F,$80,$C0,$00,$FF,$00,$FF,$00,$01,$4F,$00,$3F,$00,$00,$00,$FF
	dc.b	$FF,$FF,$1F,$FF,$3F,$FF,$80,$00,$FF,$FF,$FF,$FF,$FF,$FF,$00,$00
	dc.b	$FF,$FF,$FF,$FE,$FF,$FF,$00,$00,$98,$03,$00,$00,$60,$00,$60,$00
	dc.b	$FF,$CD,$00,$3E,$00,$1E,$00,$00,$30,$00,$C0,$00,$00,$00,$C0
	dcb.b	50,$00
	dc.b	$BF,$00,$00,$00,$00,$00,$7F,$FF,$BE,$00,$3E,$00,$00,$FF,$FF,$00
	dc.b	$1F,$FF,$80,$FF,$80,$FF,$FF,$FE,$00,$00,$FF,$00,$FF,$FF,$FF,$00
	dc.b	$3F,$FF,$80,$FF,$80,$FF,$FF,$80,$00,$7F,$FF,$7F,$FF,$FF,$FF,$7F
	dc.b	$00,$80,$00,$FE,$00,$FE,$00,$00,$FF,$00,$00,$00,$00,$00,$00,$80
	dc.b	$00,$3F,$FF,$7F,$FF,$00,$00,$00,$00,$FF,$FF,$FF,$FF,$00,$00,$00
	dc.b	$01,$FF,$FC,$FF,$FE,$00,$00,$BE,$01,$A0,$00,$40,$00,$E0,$00,$FF
	dc.b	$C0,$00,$1D,$00,$3E,$00,$01,$B8,$00,$C0,$00,$00,$00,$C0
	dcb.b	50,$00
	dc.b	$7F,$00,$00,$00,$00,$00,$3F,$FF,$00,$00,$01,$00,$01,$FF,$FF,$00
	dc.b	$2F,$FF,$C0,$FF,$C0,$FF,$FF,$FF,$00,$00,$7F,$00,$7F,$FF,$FF,$00
	dc.b	$1F,$FF,$C0,$FF,$C0,$FF,$FF,$80,$00,$7F,$FF,$7F,$FF,$FF,$FF,$7E
	dc.b	$00,$80,$00,$FC,$00,$FC,$00,$00,$7F,$00,$00,$00,$00,$00,$00,$80
	dc.b	$00,$FF,$FF,$7F,$FF,$00,$00,$00,$00,$FF,$FF,$FF,$FF,$00,$00,$00
	dc.b	$04,$FF,$EB,$FF,$F0,$00,$01,$A1,$00,$CC,$00,$1E,$00,$C0,$00,$FF
	dc.b	$E5,$00,$1B,$00,$3C,$00,$01,$78,$00,$00,$00,$80,$00,$C0
	dcb.b	50,$00
	dc.b	$5F,$00,$00,$00,$00,$00,$3F,$FF,$7E,$00,$00,$00,$00,$FF,$FF,$00
	dc.b	$0F,$FF,$C0,$FF,$C0,$FF,$FF,$FF,$80,$00,$3F,$00,$3F,$FF,$FF,$00
	dc.b	$0F,$FF,$E0,$FF,$E0,$FF,$FF,$80,$00,$7F,$FF,$7F,$FF,$FF,$FF,$FC
	dc.b	$00,$00,$00,$F8,$00,$F8,$00,$00,$3F,$00,$00,$00,$00,$00,$00,$FF
	dc.b	$FF,$00,$00,$00,$00,$00,$00,$FF,$FF,$00,$00,$00,$00,$00,$00,$CF
	dc.b	$EF,$20,$90,$1F,$00,$00,$0F,$4C,$82,$A1,$00,$1E,$00,$00,$04,$3F
	dc.b	$9A,$00,$40,$00,$3D,$00,$01,$7F,$80,$00,$00,$80,$00,$80,$40
	dcb.b	49,$00
	dc.b	$3F,$00,$00,$00,$00,$00,$1F,$FF,$7F,$00,$00,$00,$00,$FF,$FF,$00
	dc.b	$2F,$7F,$80,$7F,$A0,$FF,$FF,$FF,$C0,$00,$1F,$00,$1F,$FF,$FF,$00
	dc.b	$0F,$FF,$F0,$FF,$F0,$FF,$FF,$C0,$01,$3F,$FE,$3F,$FF,$FF,$FF,$FC
	dc.b	$00,$00,$00,$F8,$00,$F8,$00,$00,$0F,$00,$00,$00,$00,$00,$00,$A6
	dc.b	$07,$1E,$07,$01,$F8,$7F,$FF,$3F,$E1,$C0,$1E,$00,$00,$FF,$FE,$F7
	dc.b	$FF,$00,$80,$0F,$00,$00,$3E,$FF,$EF,$80,$45,$7F,$82,$00,$00,$1F
	dc.b	$FC,$0A,$46,$04,$39,$00,$01,$FF,$C0,$84,$60,$03,$80,$80,$10
	dcb.b	49,$00
	dc.b	$1B,$00,$00,$00,$00,$00,$07,$FF,$7F,$00,$00,$00,$00,$FF,$FF,$80
	dc.b	$6F,$1F,$00,$1F,$60,$FF,$FF,$FF,$E0,$00,$0F,$00,$0F,$FF,$FF,$00
	dc.b	$07,$FF,$F8,$FF,$F8,$FF,$FF,$C0,$03,$3F,$FC,$3F,$FF,$FF,$FF,$F8
	dc.b	$00,$00,$00,$F0,$00,$F0,$00,$00,$00,$00,$00,$00,$00,$00,$00,$73
	dc.b	$81,$0F,$81,$00,$7E,$3F,$FF,$9F,$F9,$E0,$07,$00,$00,$FF,$F8,$3C
	dc.b	$7F,$24,$41,$C3,$80,$00,$1C,$00,$79,$00,$49,$FF,$86,$00,$00,$73
	dc.b	$C1,$92,$47,$0C,$38,$40,$03,$F0,$18,$10,$10,$0F,$E0,$80,$04
	dcb.b	49,$00
	dc.b	$06,$00,$00,$00,$00,$00,$01,$FF,$7F,$00,$00,$00,$00,$FF,$FF,$E0
	dc.b	$EF,$0E,$00,$0E,$E0,$FF,$FF,$FF,$F0,$00,$07,$00,$07,$FF,$FF,$00
	dc.b	$03,$FF,$FC,$FF,$FC,$FF,$FF,$C0,$07,$3F,$F8,$3F,$FF,$FF,$FF,$F0
	dc.b	$00,$00,$00,$E0,$00,$E0,$00,$00,$00,$00,$00,$00,$00,$00,$00,$3F
	dc.b	$FF,$00,$00,$00,$00,$00,$00,$FF,$F4,$00,$0C,$00,$03,$00,$00,$0A
	dc.b	$2F,$16,$21,$E1,$C0,$00,$10,$00,$EA,$00,$9B,$FF,$04,$00,$20,$F3
	dc.b	$CC,$D2,$4B,$0C,$30,$C0,$03,$E7,$C8,$26,$4C,$18,$30,$00,$02
	dcb.b	49,$00
	dc.b	$01,$00,$00,$00,$00,$00,$00,$9F,$7F,$00,$00,$00,$00,$7F,$FF,$F1
	dc.b	$EF,$04,$00,$05,$E0,$FF,$FF,$FF,$F8,$00,$01,$00,$01,$FF,$FF,$00
	dc.b	$00,$FF,$FF,$FF,$FF,$FF,$FF,$C0,$0F,$3F,$F0,$3F,$FF,$FF,$FF,$E0
	dc.b	$00,$00,$00,$C0,$00,$C0,$00,$00,$00,$00,$00,$00,$00,$00,$00,$1F
	dc.b	$FF,$00,$00,$00,$00,$00,$00,$FF,$EF,$00,$1F,$00,$00,$00,$00,$85
	dc.b	$E7,$FB,$F0,$00,$00,$08,$08,$7B,$6C,$FC,$9F,$00,$00,$00,$61,$5C
	dc.b	$73,$7E,$FC,$80,$00,$C1,$03,$FB,$7E,$3C,$F8,$00,$00,$00,$03
	dcb.b	56,$00
	dc.b	$67,$9F,$00,$00,$00,$00,$1F,$FF,$FB,$DF,$00,$00,$03,$C0,$FF,$FF
	dc.b	$FF,$FE,$00,$00,$00,$00,$FF,$FF,$00,$00,$FF,$FF,$FF,$FF,$FF,$FF
	dc.b	$60,$0F,$9F,$F0,$9F,$FF,$FF,$FF,$E0,$00,$00,$00,$C0,$00,$C0,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$07,$FF,$00,$00,$00,$00,$00,$00
	dc.b	$FF,$CE,$00,$3F,$00,$00,$00,$00,$2A,$E7,$9D,$F0,$00,$00,$7C,$08
	dc.b	$B6,$C9,$78,$3F,$00,$00,$01,$C1,$5B,$62,$3C,$F8,$80,$00,$C0,$07
	dc.b	$BF,$F5,$7F,$FA,$00,$00,$00,$06
	dcb.b	56,$00
	dc.b	$18,$EF,$00,$00,$00,$00,$07,$FF,$FB,$BF,$00,$00,$03,$80,$FF,$FF
	dc.b	$FF,$FF,$00,$00,$00,$00,$FF,$FF,$00,$00,$7F,$FF,$7F,$FF,$FF,$FF
	dc.b	$20,$1F,$DF,$E0,$DF,$FF,$FF,$FF,$C0,$00,$00,$00,$80,$00,$80,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$07,$FF,$00,$00,$00,$00,$00,$00
	dc.b	$FF,$C1,$00,$3E,$00,$00,$00,$00,$62,$03,$1D,$F8,$00,$00,$FC,$04
	dc.b	$05,$C3,$F8,$3D,$00,$00,$02,$03,$C3,$01,$BC,$F8,$00,$00,$80,$06
	dc.b	$80,$0B,$7F,$F6,$00,$00,$00,$06
	dcb.b	56,$00
	dc.b	$07,$37,$00,$00,$00,$00,$00,$FF,$FB,$7F,$00,$00,$03,$00,$FF,$FF
	dc.b	$FF,$FF,$00,$00,$00,$00,$FF,$FF,$80,$00,$3F,$FF,$3F,$FF,$FF,$FF
	dc.b	$20,$3F,$DF,$C0,$DF,$FF,$FF,$FF,$80,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$43,$00,$3C,$00,$00,$00,$01,$F7,$07,$00,$F8,$00,$00,$F8,$00
	dc.b	$8F,$EE,$70,$11,$00,$00,$00,$03,$C5,$8F,$3A,$70,$00,$00,$02,$00
	dc.b	$83,$FF,$7C,$00,$00,$00,$00,$00,$80
	dcb.b	56,$00
	dc.b	$C9,$00,$00,$00,$00,$00,$3F,$FA,$FF,$00,$00,$02,$00,$FF,$FF,$FF
	dc.b	$FF,$00,$00,$00,$00,$FF,$FF,$C0,$00,$1F,$FF,$1F,$FF,$FF,$FF,$70
	dc.b	$7F,$8F,$80,$CF,$FE,$FF,$FE,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$FC,$00,$01,$00,$00,$00,$03,$5F,$FD,$80,$00,$00,$00,$E0,$02,$FF
	dc.b	$FF,$00,$00,$00,$00,$00,$00,$FF,$FF,$02,$00,$00,$00,$02,$00,$FF
	dc.b	$FF,$00,$00,$00,$00,$00,$00,$C0
	dcb.b	56,$00
	dc.b	$32,$00,$00,$00,$00,$00,$0F,$39,$FF,$00,$00,$00,$00,$FF,$FF,$FF
	dc.b	$FF,$00,$00,$00,$00,$FF,$FF,$E0,$00,$0F,$FF,$0F,$FF,$FF,$FF,$F0
	dc.b	$FF,$0F,$00,$CF,$FE,$FF,$FE,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$FD,$00,$03,$00,$00,$00,$03,$3F,$FF,$80,$00,$00,$00,$C0,$00,$FF
	dc.b	$FF,$00,$00,$00,$00,$00,$00,$F9,$FF,$02,$00,$00,$00,$06,$00,$FF
	dc.b	$FF,$00,$00,$00,$00,$00,$00,$40,$00,$80,$00,$00,$00,$80
	dcb.b	50,$00
	dc.b	$0C,$00,$00,$00,$00,$00,$03,$43,$FF,$00,$00,$00,$00,$FF,$FF,$FF
	dc.b	$FF,$00,$00,$00,$00,$FF,$FF,$F0,$01,$07,$FE,$07,$FF,$FF,$FF,$F0
	dc.b	$FE,$0F,$00,$CF,$FC,$FF,$FC,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$87,$00,$03,$00,$00,$00,$7B,$7F,$83,$00,$00,$00,$00,$80,$7D,$83
	dc.b	$20,$00,$C0,$00,$00,$7D,$DF,$09,$C1,$06,$00,$00,$00,$F6,$3E,$30
	dc.b	$04,$C0,$01,$00,$00,$CF,$FB,$C0,$00,$80,$00,$00,$00,$80
	dcb.b	50,$00
	dc.b	$03,$00,$00,$00,$00,$00,$00,$9F,$FF,$00,$00,$00,$00,$7F,$FF,$FF
	dc.b	$FF,$00,$00,$00,$00,$FF,$FF,$F8,$03,$01,$FC,$01,$FF,$FF,$FF,$F9
	dc.b	$FC,$06,$00,$C7,$F8,$FF,$F8,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$82,$00,$01,$00,$00,$00,$7D,$FF,$82,$00,$01,$00,$00,$00,$7D,$FF
	dc.b	$BC,$03,$C0,$00,$00,$07,$C3,$0F,$FE,$00,$01,$00,$00,$F6,$01,$BF
	dc.b	$FE,$C0,$01,$00,$00,$D0,$07,$40,$00,$80,$00,$00,$00,$80
	dcb.b	57,$00
	dc.b	$67,$FF,$00,$00,$00,$00,$1F,$FF,$FF,$FF,$00,$00,$00,$00,$FF,$FF
	dc.b	$FE,$07,$00,$F8,$00,$FF,$FF,$FF,$FF,$F8,$00,$00,$C7,$F0,$FF,$F0
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$BB,$00,$00,$00,$00,$00,$7C
	dc.b	$F9,$7B,$00,$00,$00,$00,$00,$FD,$F3,$F9,$1C,$00,$00,$00,$3E,$07
	dc.b	$EF,$FF,$00,$00,$00,$00,$F0,$00,$FF,$FF,$00,$00,$00,$00,$00,$00
	dc.b	$FF
	dcb.b	63,$00
	dc.b	$19,$FF,$00,$00,$00,$00,$07,$FF,$FF,$FF,$00,$00,$00,$00,$FF,$FF
	dc.b	$FF,$0F,$00,$70,$00,$7F,$FF,$FF,$FF,$F0,$00,$00,$C7,$E0,$FF,$E0
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$3D,$00,$00,$00,$00,$00,$7E
	dc.b	$F2,$F8,$00,$00,$00,$00,$01,$FF,$EF,$FF,$10,$00,$00,$00,$1F,$FF
	dc.b	$FF,$FF,$00,$00,$00,$00,$FF,$FF,$FF,$FF,$00,$00,$00,$00,$FF,$FF
	dc.b	$FE,$80,$00,$00,$00,$00,$FF
	dcb.b	57,$00
	dc.b	$06,$7F,$00,$00,$00,$00,$01,$FF,$FF,$FF,$00,$00,$00,$00,$FF,$FF
	dc.b	$FF,$9F,$00,$20,$00,$3F,$FF,$FF,$FF,$F0,$00,$00,$C7,$E0,$FF,$E0
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$61,$00,$1E,$00,$00,$00,$3F
	dc.b	$7A,$0D,$01,$F0,$00,$00,$87,$FA,$F8,$00,$07,$FF,$00,$00,$0F,$FF
	dc.b	$00,$00,$FF,$FF,$00,$00,$FF,$FF,$00,$00,$FF,$FF,$00,$00,$FF,$FF
	dc.b	$03,$40,$FC,$80,$00,$00,$FE,$80
	dcb.b	56,$00
	dc.b	$01,$8F,$00,$00,$00,$00,$00,$7F,$FF,$FF,$00,$00,$00,$00,$FF,$FF
	dc.b	$FF,$DF,$00,$00,$00,$1F,$FF,$FF,$FF,$E0,$00,$00,$C7,$C0,$FF,$C0
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$30,$00,$0F,$00,$00,$00,$1F
	dc.b	$00,$1C,$FF,$E2,$00,$00,$FF,$F7,$F0,$00,$0F,$FF,$00,$00,$1F,$FF
	dc.b	$00,$00,$FF,$FF,$00,$00,$FF,$FF,$00,$00,$FF,$FF,$00,$00,$FF,$FF
	dc.b	$06,$80,$F9,$C0,$00,$00,$FD,$E0
	dcb.b	57,$00
	dc.b	$73,$00,$00,$00,$00,$00,$0F,$FF,$FF,$00,$00,$00,$00,$FF,$FF,$FF
	dc.b	$DF,$00,$00,$00,$1F,$FF,$FF,$FF,$C0,$00,$00,$C7,$80,$FF,$80,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$17,$00,$0F,$00,$00,$00,$0F,$FF
	dc.b	$DC,$FF,$EE,$00,$00,$FF,$EF,$DC,$FB,$3E,$07,$00,$00,$3F,$0F,$7F
	dc.b	$FF,$80,$00,$00,$00,$C0,$00,$FF,$FF,$00,$00,$00,$00,$00,$00,$FA
	dc.b	$20,$01,$C0,$00,$00,$07,$C0
	dcb.b	57,$00
	dc.b	$0C,$00,$00,$00,$00,$00,$03,$FF,$FF,$00,$00,$00,$00,$FF,$FF,$FF
	dc.b	$DF,$00,$00,$00,$1F,$FF,$FF,$FF,$80,$00,$00,$C7,$00,$FF,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$05,$00,$03,$00,$00,$00,$0F,$FF
	dc.b	$49,$FF,$A2,$00,$1C,$FF,$FE,$DE,$F7,$3C,$0F,$00,$00,$3F,$EF,$87
	dc.b	$3F,$07,$C0,$78,$00,$FF,$FF,$E6,$07,$1E,$07,$01,$F8,$FF,$FF,$3F
	dc.b	$F0,$C0,$00,$00,$00,$FF,$80
	dcb.b	57,$00
	dc.b	$03,$00,$00,$00,$00,$00,$00,$3F,$FF,$00,$00,$00,$00,$FF,$FF,$FF
	dc.b	$DF,$00,$00,$00,$1F,$FF,$FF,$FF,$80,$00,$00,$87,$00,$FF,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$09,$00,$00,$00,$00,$00,$06,$83
	dc.b	$DF,$44,$44,$38,$38,$FE,$FC,$E6,$F0,$24,$11,$18,$0E,$3F,$DF,$B1
	dc.b	$9F,$01,$E0,$7E,$00,$FF,$FF,$F3,$81,$0F,$81,$00,$7E,$FF,$FF,$9C
	dc.b	$F8,$E0,$00,$00,$00,$FF
	dcb.b	65,$00
	dc.b	$C7,$FF,$00,$00,$00,$00,$3F,$FF,$FF,$DF,$00,$00,$00,$1F,$FF,$FF
	dc.b	$FF,$00,$00,$00,$86,$00,$FE,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$04,$00,$00,$00,$00,$00,$03,$BE,$0F,$01,$88,$00,$70,$C7,$F8
	dc.b	$C3,$E3,$22,$22,$1C,$1C,$3F,$7E,$3F,$FF,$A0,$00,$40,$00,$F0,$00
	dc.b	$FF,$FF,$00,$00,$00,$00,$00,$00,$FF,$F8
	dcb.b	70,$00
	dc.b	$39,$FF,$00,$00,$00,$00,$07,$FF,$FF,$DF,$00,$00,$00,$1F,$FF,$FF
	dc.b	$FE,$00,$00,$00,$00,$00,$FC,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$02,$00,$00,$00,$00,$00,$01,$BE,$1F,$01,$E0,$00,$00,$FF,$F0
	dc.b	$FF,$FF,$10,$04,$0F,$F8,$1F,$FD,$1F,$FF,$C0,$00,$00,$00,$E0,$00
	dc.b	$FF,$FF,$00,$00,$00,$00,$00,$00,$FF,$F8
	dcb.b	70,$00
	dc.b	$06,$7F,$00,$00,$00,$00,$01,$FF,$FF,$DF,$00,$00,$00,$1E,$FF,$FE
	dc.b	$FC
	dcb.b	32,$00
	dc.b	$01,$00,$00,$00,$00,$00,$00,$CF,$7F,$00,$00,$00,$00,$3F,$80,$DF
	dc.b	$FF,$08,$08,$07,$F0,$0F,$FB,$FF,$FF,$00,$00,$00,$00,$C0,$00,$FF
	dc.b	$FF,$00,$00,$00,$00,$00,$00,$FF,$F0
	dcb.b	70,$00
	dc.b	$01,$9F,$00,$00,$00,$00,$00,$7F,$FF,$DE,$00,$00,$00,$1C,$FF,$FC
	dcb.b	40,$00
	dc.b	$FF,$FF,$00,$00,$00,$00,$00,$00,$80,$0F,$05,$E0,$03,$F0,$0F,$F7
	dc.b	$7F,$FF,$00,$00,$00,$00,$80,$00,$FF,$FF,$00,$00,$00,$00,$00,$00
	dc.b	$FF,$E0
	dcb.b	71,$00
	dc.b	$67,$00,$00,$00,$00,$00,$1F,$FF,$DC,$00,$00,$00,$18,$FF,$F8
	dcb.b	40,$00
	dc.b	$7F,$FF,$00,$00,$00,$00,$00,$00,$01,$E1,$06,$1E,$00,$00,$0E,$1F
	dc.b	$FC
	dcb.b	88,$00
	dc.b	$18,$00,$00,$00,$00,$00,$07,$FF,$DC,$00,$00,$00,$18,$FF,$F8
	dcb.b	40,$00
	dc.b	$1F,$FC,$00,$00,$00,$00,$00,$00,$05,$01,$03,$06,$00,$F8,$03,$FE
	dc.b	$F8
	dcb.b	88,$00
	dc.b	$07,$00,$00,$00,$00,$00,$00,$3F,$D8,$00,$00,$00,$10,$FF,$F0
	dcb.b	40,$00
	dc.b	$03,$E0,$00,$00,$00,$00,$00,$00,$03,$8F,$00,$88,$00,$70,$01,$FC
	dc.b	$F8
	dcb.b	95,$00
	dc.b	$CF,$D0,$00,$00,$00,$00,$3F,$E0
	dcb.b	48,$00
	dc.b	$01,$FF,$00,$00,$00,$00,$00,$00,$F0
	dcb.b	95,$00
	dc.b	$33,$20,$00,$00,$00,$00,$0F,$C0
	dcb.b	49,$00
	dc.b	$FF,$00,$00,$00,$00,$00,$00,$E0
	dcb.b	95,$00
	dc.b	$0C,$C0,$00,$00,$00,$00,$03
	dcb.b	50,$00
	dc.b	$7F,$00,$00,$00,$00,$00,$00,$C0
	dcb.b	95,$00
	dc.b	$03
	dcb.b	56,$00
	dc.b	$1F,$00,$00,$00,$00,$00,$00,$80,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$04,$00,$08,$00,$0C,$00,$03,$00,$07,$00,$0B,$00,$0F,$00
	dc.b	$01,$00,$01,$00,$01,$00,$01,$00,$80,$00,$54,$00,$2A,$00,$00,$45
	dc.b	$FA,$FF,$FE,$20,$D9,$B3,$CA,$6D,$00,$FF,$FA,$4E,$F9,$00,$00,$40
	dc.b	$00,$00,$00,$00,$00,$03,$F2,$00,$00,$00,$00,$00,$00,$00,$00,$00
	dc.b	$00,$00,$00,$00,$00
