;***********************************************************************
;* Assembler macros to control VIC sprites (no multiplexing)
;* Version 0.11
;* Last changed:

;; <h2>Assembler macros to control VIC sprites (no multiplexing)</h2>

.if .not .definedmacro(showSprite)

.ifndef VIC_BASE
    VIC_BASE=$D000
.endif

_overlay_implicit=0	;value indicates that with this sprite macro overlay sprites need to be set and placed explicitely

.macro showSprite n
  lda VIC_BASE+$15
  ora #1<<(n)
  sta VIC_BASE+$15
.endmacro

.macro hideSprite n
  lda VIC_BASE+$15
  and #255 - (1<<(n))
  sta VIC_BASE+$15
.endmacro

.macro enableMultiColorSprite n
  lda VIC_BASE+$1c
  ora #1<<(n)
  sta VIC_BASE+$1c
.endmacro

.macro disableMultiColorSprite n
  lda VIC_BASE+$1c
  and #255 - (1<<(n))
  sta VIC_BASE+$1c
.endmacro

.macro enableXexpandSprite n
  lda VIC_BASE+$1d
  ora #1<<(n)
  sta VIC_BASE+$1d
.endmacro

.macro disableXexpandSprite n
  lda VIC_BASE+$1d
  and #255 - (1<<(n))
  sta VIC_BASE+$1d
.endmacro

.macro enableYexpandSprite n
  lda VIC_BASE+$17
  ora #1<<(n)
  sta VIC_BASE+$17
.endmacro

.macro disableYexpandSprite n
  lda VIC_BASE+$17
  and #255 - (1<<(n))
  sta VIC_BASE+$17
.endmacro

.macro spriteBeforeBackground n
  lda VIC_BASE+$1b
  and #255 - (1<<(n))
  sta VIC_BASE+$1b
.endmacro

.macro spriteBehindBackground n
  lda VIC_BASE+$1b
  ora #1<<(n)
  sta VIC_BASE+$1b
.endmacro

.macro setSpriteColor n,arg
  .if (.xmatch ({arg}, {A}))  
    sta VIC_BASE+$27+n
  .elseif (.xmatch ({arg}, {X}))  
    stx VIC_BASE+$27+n
  .elseif (.xmatch ({arg}, {Y}))  
    sty VIC_BASE+$27+n
  .else
    lda #arg
    sta VIC_BASE+$27+n
  .endif
.endmacro

.macro getSpriteColor n,reg
  .ifblank reg
     lda VIC_BASE+$27+n
  .elseif (.xmatch ({reg}, {A}))  
     lda VIC_BASE+$27+n
  .elseif (.xmatch ({reg}, {X}))  
     ldx VIC_BASE+$27+n
  .elseif (.xmatch ({reg}, {Y}))  
     ldy VIC_BASE+$27+n
  .else
     .error "No proper register stated, must be A, X or Y"
  .endif
.endmacro

.macro setSpriteMultiColor1 arg
  .if (.xmatch ({arg}, {A}))  
    sta VIC_BASE+$25
  .elseif (.xmatch ({arg}, {X}))  
    stx VIC_BASE+$25
  .elseif (.xmatch ({arg}, {Y}))  
    sty VIC_BASE+$25
  .else
    lda #arg
    sta VIC_BASE+$25
  .endif
.endmacro

.macro getSpriteMultiColor1 reg
  .ifblank reg
     lda VIC_BASE+$25
  .elseif (.xmatch ({reg}, {A}))  
     lda VIC_BASE+$25
  .elseif (.xmatch ({reg}, {X}))  
     ldx VIC_BASE+$25
  .elseif (.xmatch ({reg}, {Y}))  
     ldy VIC_BASE+$25
  .else
     .error "No proper register stated, must be A, X or Y"
  .endif
.endmacro

.macro setSpriteMultiColor2 arg
  .if (.xmatch ({arg}, {A}))  
    sta VIC_BASE+$26
  .elseif (.xmatch ({arg}, {X}))  
    stx VIC_BASE+$26
  .elseif (.xmatch ({arg}, {Y}))  
    sty VIC_BASE+$26
  .else
    lda #arg
    sta VIC_BASE+$26
  .endif
.endmacro

.macro getSpriteMultiColor2 reg
  .ifblank reg
     lda VIC_BASE+$26
  .elseif (.xmatch ({reg}, {A}))  
     lda VIC_BASE+$26
  .elseif (.xmatch ({reg}, {X}))  
     ldx VIC_BASE+$26
  .elseif (.xmatch ({reg}, {Y}))  
     ldy VIC_BASE+$26
  .else
     .error "No proper register stated, must be A, X or Y"
  .endif
.endmacro

.macro setSpriteCostume n,arg
  .if (.xmatch ({arg}, {A}))  
    sta SCREEN_BASE+$3f8+n
  .elseif (.xmatch ({arg}, {X}))  
    stx SCREEN_BASE+$3f8+n
  .elseif (.xmatch ({arg}, {Y}))  
    sty SCREEN_BASE+$3f8+n
  .else
.if .const(arg) && arg>255
    lda #((arg) & $3fc0) >> 6	;values > 255 are interpreted as sprite memory address 
.else
    lda #arg
.endif
    sta SCREEN_BASE+$3f8+n
  .endif
.endmacro

.macro getSpriteCostume n,reg
  .ifblank reg
     lda SCREEN_BASE+$3f8+n
  .elseif (.xmatch ({reg}, {A}))  
     lda SCREEN_BASE+$3f8+n
  .elseif (.xmatch ({reg}, {X}))  
     ldx SCREEN_BASE+$3f8+n
  .elseif (.xmatch ({reg}, {Y}))  
     ldy SCREEN_BASE+$3f8+n
  .else
     .error "No proper register stated, must be A, X or Y"
  .endif
.endmacro

.macro setSpriteX n,arg
  .if (.xmatch ({arg}, {AX}))
    sta VIC_BASE+n+n
    cpx #0
    if ne
      lda VIC_BASE+$10
      ora #1<<(n)
      sta VIC_BASE+$10
    else
      lda VIC_BASE+$10
      and #255 - (1<<(n))
      sta VIC_BASE+$10
    endif
  .else
     lda #<arg
     sta VIC_BASE+n+n
     .if arg>255
        lda VIC_BASE+$10
        ora #1<<(n)
        sta VIC_BASE+$10
     .else
        lda VIC_BASE+$10
        and #255 - (1<<(n))
        sta VIC_BASE+$10
     .endif
  .endif
.endmacro

.macro setSpriteY n,arg
  .if (.xmatch ({arg}, {A}))
    sta VIC_BASE+n+n+1
  .elseif (.xmatch ({arg}, {X}))  
    stx VIC_BASE+n+n+1
  .elseif (.xmatch ({arg}, {Y}))  
    sty VIC_BASE+n+n+1
  .else
    ldy #arg
    sty VIC_BASE+n+n+1
  .endif
.endmacro

.macro getSpriteX n,reg
  .if (.xmatch ({arg}, {AX}))
    ldx #00
    lda VIC_BASE+$10
    and #1<<(n)
    if ne
      inx
    endif
    lda VIC_BASE+n+n
  .else
     .error "No proper register stated, must be AX"
  .endif
.endmacro

.macro getSpriteY n,reg
  .if (.xmatch ({reg}, {A}))
    lda VIC_BASE+n+n+1
  .elseif (.xmatch ({reg}, {X}))  
    ldx VIC_BASE+n+n+1
  .elseif (.xmatch ({reg}, {Y}))  
    ldy VIC_BASE+n+n+1
  .else
     .error "No proper register stated, must be A, X or Y"
  .endif
.endmacro

.macro setSpriteXY n,arg1,arg2
  setSpriteY n,arg2
  setSpriteX n,arg1
.endmacro

.macro updateSpriteAttributes n
  .ifblank (.xmatch ({reg}, {A}))  
     ;
  .elseif (.xmatch ({reg}, {X}))  
     txa
  .elseif (.xmatch ({reg}, {Y}))  
     tya
  .else
     lda #n
  .endif
  .import _simpleUpdateSpriteAttributes
  jsr _simpleUpdateSpriteAttributes
.endmacro

.endif


