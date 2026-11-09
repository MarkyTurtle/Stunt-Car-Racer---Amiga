;-------------------------------------------------------------------------------
; renderer.i - (the enhanced game) a choice of renderers for the race's view: F5.
;
; The view's work is in stages (original/docs/RENDER.md): the points projected, the edges stepped
; into edge buffers and the row table, then the drawing - the horizon, the mountains, the track's
; rows far to near. Renderer 0 is the release's: the CPU steps and fills every polygon. Renderer 1
; draws the parts that can be drawn another way a different way (below). Both are in memory, and
; F5 (the helper block's flag, HelperRenderer) chooses between them, read once a view
; (RendererLatch) so that a view is drawn all one way. The picture need not be the same pixel for
; pixel - renderer 1's polygons are the blitter's lines and fills - but is to be close to it:
; enhanced/tools/test_renderers.py measures how close.
;
; The stages that differ are called through RenderMountains, RenderFarRows and RenderNearRows
; (they keep the registers the stages they stand for were called with, so are bra to them); a
; renderer that does not draw a stage another way leaves it to renderer 0's routine.
;
;   stage                 renderer 0 (the release's)      renderer 1
;   the mountains         DrawMountains                   BlitMountains (renderer_blit.i)
;   the far rows          DrawFarRows                     (renderer 0's)
;   the near rows         DrawNearRows                    (renderer 0's)
;-------------------------------------------------------------------------------

HelperRenderer	equ	$188			; F5: the renderer, 0-3 (helper_c0.s)

RendererSel:	dc.b	0			; this view's renderer (RendererLatch)
	even

;-------------------------------------------------------------------------------
; RendererLatch - RaceView's start: F5's flag taken for this view. All registers kept
;-------------------------------------------------------------------------------
RendererLatch:
	movem.w	d0-d1,-(a7)
	move.b	(HelperRenderer).w,d0
	move.b	d0,RendererSel
	move.b	RendererPrev,d1
	move.b	d0,RendererPrev
	cmp.b	d0,d1
	beq.s	.same
	cmpi.b	#2,d0				; F5 pressed to or from a renderer of the preset detail (2, 3):
	bcc.s	.apply				; the flags of F4, F9 and F10 set (free to change after)
	cmpi.b	#2,d1
	bcs.s	.same
.apply:	clr.b	(HelperHalfRes).w		; 0, 1: the full detail; 2: the track drawn less far ahead;
	clr.b	(HelperMountainsOff).w		; 3: that, at half height, and no mountains
	clr.b	(HelperFarShort).w
	cmpi.b	#2,d0
	bcs.s	.same
	st	(HelperFarShort).w
	cmpi.b	#3,d0
	bne.s	.same
	st	(HelperHalfRes).w
	st	(HelperMountainsOff).w
.same:	movem.w	(a7)+,d0-d1
	rts

RendererPrev:	dc.b	0			; the renderer last latched
	even

;-------------------------------------------------------------------------------
; The stages, by renderer. Each is branched to with the registers it would be called with
;-------------------------------------------------------------------------------
RenderMountains:
	cmpi.b	#1,RendererSel
	bne.w	DrawMountains
	bra.w	BlitMountains

RenderFarRows:
	bra.w	DrawFarRows

RenderNearRows:
	bra.w	DrawNearRows

	include	"renderer_blit.i"
	include	"renderer_surf.i"
