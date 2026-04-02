;***********************************************************************
;* Module: Sprite Manager
;* Version 0.314159
;* Last changed: 2025-03-01 22:14:43
;
; to be configured and included with
; .scope sprite1
;   SPR_ADDR=xxxx       ;16 bit address of sprite definitions
;   SPR_FILENAME="filename.prg" ;
;   .include "../common/m_spriteman.s"
; .endscope
;
; usage from the main program
;
; m_init sprite1
; m_run sprite1

.include "LAMAlib.inc"
.include "spritemacros.inc"
.include "module-macros.inc"

;***********************************************************************
;* parameters - can be overwritten from main
;* without a default value the constant must be set by the main program

def_const SPR_ADDR,$340
def_const CONFIGURABLE_SPR_COSTUME,0    ;if 1, the procedure set_spr_base_costume can be used to change the sprite's appearance
def_const SPR_NUM,0

def_const JOY_CONTROL,0 ;0..none, 1..joyport1, 2..joyport2, 4..wasdspace, combinations possible by adding the up the respective values
def_const JOY_REMOTECONTROL,0	;address of value to be used when JOY_CONTROL=8
def_const MOV_DIRS,$f   ;1 up, 2 down, 4 left, 8 right, sum defines movements, e.g. 12 = only left-right
def_const MOV_SPEED_X,2 ;<=7, if ACCELERATION is on, this is the maximum moving speed in x direction
def_const MOV_SPEED_Y,1 ;<=7, if ACCELERATION is on, this is the maximum moving speed in y direction

def_const ACCELERATION,0
def_const ACCELERATION_DOWNSCALE,2      ;scales by (1<<ACCELERATION_DOWNSCALE)
def_const DECELERATION,1
def_const GRAVITY,1
def_const MAXFALLSPEED,15       ;must be smaller than 8 * (1<<ACCELERATION_DOWNSCALE)
def_const JUMP_TRIGGER,0        ;0..none, 1..up, 2..fire
def_const JUMP_LAUNCH_SPEED,15  ;how fast the figure launches off, influences jump height
def_const JUMP_BOOST_DURATION,5 ;for how many frames the button can be pressed to jump higher
def_const BOUNCE_ON_CEILING,0           ;if yes, hitting your head while jumping bounces you downwards

def_const CHECK_BOUNDARIES,1
def_const MIN_Y,50
def_const MAX_Y,229
def_const MIN_X,24
def_const MAX_X,320
def_const ANIMATION_STATES,0    ;0..no animation, must be a potential of 2
def_const ANIMATION_DIRS,2      ;1,2,4
def_const ANIMATION_DELAY,2
def_const ANIMATE_ALWAYS,0

def_const CUSTOM_ANIMATIONS,0   ;if 1, enables the play_animation method
def_const CUSTOM_ANIMATION_DELAY,(1<<ANIMATION_DELAY)

def_const OVERLAY,0                     ;if 1, sprite address are always calculated in double steps, also affects twin sprite
def_const HANDLE_OVERLAY_SPRITE,OVERLAY ;if 1, sprite is displayed with two hw sprites, also affects twin sprite

def_const TWIN,0                        ;if 1, there will be a second sprite that moves and animates with the main sprite
def_const TWIN_DX,0             ;offset of the twin in X direction
def_const TWIN_DY,-21           ;offset of the twin in Y direction
def_const TWIN_COSTUME_OFFSET,0 ;twin costume will be main costume plus this offset

def_const CARRIER,0     ;if > 0 sprite can "hold" anther sprite
def_const IN_FRONT,0    ;if > 0 defines how many pixels in front the sprite is carried and in_frontX and in_frontY are reported
def_const CARRY_OFFSET_Y,0

def_const ATTACHER,0    ;if > 0 sprite can "attach" to anther sprite

def_const PURSUER,0     ;if > 0 sprite can pursue anther sprite
def_const PURSUEDISTANCE,2      ;if > 0 sprite will keep a minium distance when pursueing
def_const PURSUEDIST_X,PURSUEDISTANCE   ;indiviual distance for X direction
def_const PURSUEDIST_Y,PURSUEDISTANCE   ;indiviual distance for Y direction
def_const EVADER,0     ;if > 0 sprite can flee from anther sprite
def_const MAXDISTANCE,0 ;if > 0 the pursueing/evading will only work within a minimum distance

def_const CHECK_CHAR_COLLISION,0
def_const LEFT_EMPTY,0           ;unused pixels of sprite on left side
def_const RIGHT_EMPTY,0          ;unused pixels of sprite on right side
def_const TOP_EMPTY,0            ;unused pixels of sprite on top side
def_const BOTTOM_EMPTY,0         ;unused pixels of sprite on bottom side
def_const ADJUST_YSCROLL,0       ;adjust for vertical raster scroll value in $D011
def_const ADJUST_XSCROLL,0       ;adjust for horizontal raster scroll value in $D016
def_const WALKABLE_CHARS_COUNT,2 ;number of walkable characters defined below
def_const WALKABLE_CHAR1,32      ;character code for the first walkable character
def_const WALKABLE_CHAR2,96      ;character code for the second walkable character, only checked if WALKABLE_CHARS_COUNT>=2
def_const WALKABLE_CHAR3,-1      ;character code for the third walkable character, only checked if WALKABLE_CHARS_COUNT>=3

def_const ENABLE_CALC_SCREEN_ADDR,0 ;add method calc_screen_addr
def_const CALC_SCREEN_ADDR_PTR,0 ;the adress of the sprites upper left corner will be written into this location
def_const CHAR_X_OFFSET,LEFT_EMPTY ;offsets for screen address calculation
def_const CHAR_Y_OFFSET,TOP_EMPTY ;offsets for screen address calculation


;***********************************************************************
;* module implementation

init:
.if HANDLE_OVERLAY_SPRITE=0
  .if CONFIGURABLE_SPR_COSTUME
        lda spr_base_costume
        setSpriteCostume SPR_NUM,A
    .if TWIN>0
        clc
        adc #TWIN_COSTUME_OFFSET
        setSpriteCostume SPR_NUM+1,A
        updateSpriteAttributes SPR_NUM+1
    .endif
  .else
        setSpriteCostume SPR_NUM,((SPR_ADDR & $3fc0) >> 6)
    .if TWIN>0
        setSpriteCostume SPR_NUM+1,((SPR_ADDR & $3fc0) >> 6)+TWIN_COSTUME_OFFSET
        updateSpriteAttributes SPR_NUM+1
    .endif
  .endif
        updateSpriteAttributes SPR_NUM
        jmp place_sprite
.else
        setSpriteCostume SPR_NUM,((SPR_ADDR & $3fc0) >> 6)+1
        setSpriteCostume SPR_NUM+1,((SPR_ADDR & $3fc0) >> 6)
        updateSpriteAttributes SPR_NUM
        updateSpriteAttributes SPR_NUM+1
  .if TWIN>0
        setSpriteCostume SPR_NUM+2,((SPR_ADDR & $3fc0) >> 6)+TWIN_COSTUME_OFFSET+1
        setSpriteCostume SPR_NUM+3,((SPR_ADDR & $3fc0) >> 6)+TWIN_COSTUME_OFFSET
        updateSpriteAttributes SPR_NUM+2
        updateSpriteAttributes SPR_NUM+3
  .endif
        jmp place_sprite
.endif

.if CUSTOM_ANIMATIONS>0
play_animation:
        stx playing_animation
        sta costume_during_animation
        poke anim_counter,1     ;immediate change in first iteration
        rts
playing_animation: .byte $ff
.endif

show:
.if TWIN=0
        showSprite SPR_NUM
  .if HANDLE_OVERLAY_SPRITE>0
        showSprite SPR_NUM+1
  .endif
.else
        showSprite SPR_NUM
        showSprite SPR_NUM+1
  .if HANDLE_OVERLAY_SPRITE>0
        showSprite SPR_NUM+2
        showSprite SPR_NUM+3
  .endif
.endif
        rts

hide:
.if TWIN=0
        hideSprite SPR_NUM
  .if HANDLE_OVERLAY_SPRITE>0
        hideSprite SPR_NUM+1
  .endif
.else
        hideSprite SPR_NUM
        hideSprite SPR_NUM+1
  .if HANDLE_OVERLAY_SPRITE>0
        hideSprite SPR_NUM+2
        hideSprite SPR_NUM+3
  .endif
.endif
        rts

spriteX:
        .byte 0,0
spriteY:
        .byte 0
.if JOY_CONTROL>0 || PURSUER>0
mov_speed_x:
        .byte MOV_SPEED_X
mov_speed_y:
        .byte MOV_SPEED_Y
.endif

.if IN_FRONT>0
  .ifndef IN_FRONT_DY
IN_FRONT_DY=IN_FRONT*MOV_SPEED_Y/MOV_SPEED_X
  .endif
in_frontX:
        .byte 0,0
in_frontY:
        .byte 0
.endif

.if CARRIER>0
carry_sprite:
        stax carryX
        incax
        stax carryX2
        incax
        stax carryY
        poke carrying,1

update_carry:
  .if IN_FRONT>0
        ldax spriteX
        stax in_frontX
        lda spriteY
        sta in_frontY
  .endif
        rts
.endif

.if PURSUER>0
pursue_sprite:
        stax pursueX
        incax
        stax pursueX2
        incax
        stax pursueY
        poke pursueing,1
  .if EVADER
        poke pursue_right,8^$ff
        poke pursue_leftt,4^$ff
        poke pursue_up,1^$ff
        poke pursue_down,2^$ff
  .endif
        rts

  .if EVADER
evade_sprite:
        stax pursueX
        incax
        stax pursueX2
        incax
        stax pursueY
        poke pursueing,2
        poke pursue_right,4^$ff
        poke pursue_leftt,8^$ff
        poke pursue_up,2^$ff
        poke pursue_down,1^$ff
        rts
  .endif

pursueing: .byte 0
.endif

.if ATTACHER>0
attach_sprite:
        stax attachX
        addax #1
        stax attachX2
        adcax #1
        stax attachY
        poke attached,1
        rts
.endif

.if JOY_CONTROL>0 || PURSUER>0
joyvalue:
        .byte 0
movement_enabled:
        .byte 1
.endif

.if ANIMATION_STATES>0 .or CUSTOM_ANIMATIONS>0
anim_counter:
        .byte 0
.endif
.if ANIMATION_STATES>0
spr_costume:
  .if CONFIGURABLE_SPR_COSTUME
        .byte 0
  .else
        .byte ((SPR_ADDR & $3fc0) >> 6)
  .endif
.endif

.if CONFIGURABLE_SPR_COSTUME
spr_base_costume:
        .byte ((SPR_ADDR & $3fc0) >> 6)

set_spr_base_costume:
        sta spr_base_costume
  .if ANIMATION_STATES=0
    .if HANDLE_OVERLAY_SPRITE=0
        setSpriteCostume SPR_NUM,A
      .if TWIN>0
        .if TWIN_COSTUME_OFFSET>0
        clc
        adc #TWIN_COSTUME_OFFSET
        .endif
        setSpriteCostume SPR_NUM+1,A
      .endif
    .else
        setSpriteCostume SPR_NUM+1,A
        clc
        adc #1
        setSpriteCostume SPR_NUM,A
      .if TWIN>0
        .if TWIN_COSTUME_OFFSET>0
        clc
        adc #TWIN_COSTUME_OFFSET
        .endif
        setSpriteCostume SPR_NUM+3,A
        sec
        sbc #1
        setSpriteCostume SPR_NUM+2,A
      .endif
    .endif
  .endif ;.if ANIMATION_STATES=0
        rts
.endif

place_sprite:

.if ATTACHER>0
attached=*+1
        lda #00
        if ne
attachX=*+1
            lda $affe
attachX2=*+1
            ldx $affe
            stax spriteX
attachY=*+1
            lda $affe
            sta spriteY
        endif
.endif ;.if ATTACHER

        ldax spriteX
        ldy spriteY
        setSpriteY SPR_NUM,Y
        setSpriteX SPR_NUM,AX

.if HANDLE_OVERLAY_SPRITE>0
        ldax spriteX
          ;ldy spriteY
        setSpriteY SPR_NUM+1,Y
        setSpriteX SPR_NUM+1,AX
  .if TWIN>0
        ldax spriteX
    .if TWIN_DX<>0
        addax #TWIN_DX
    .endif
        store AX
        setSpriteX SPR_NUM+2,AX
        restore AX
        setSpriteX SPR_NUM+3,AX
    .if TWIN_DY<>0
        tya
        clc
        adc #<(256+TWIN_DY)
        setSpriteY SPR_NUM+2,A
        setSpriteY SPR_NUM+3,A
    .else
        setSpriteY SPR_NUM+2,Y
        setSpriteY SPR_NUM+3,Y
    .endif
  .endif
.else
  .if TWIN>0
        ldax spriteX
    .if TWIN_DX<>0
        addax #TWIN_DX
    .endif
        setSpriteX SPR_NUM+1,AX
    .if TWIN_DY<>0
        tya
        clc
        adc #<(256+TWIN_DY)
        setSpriteY SPR_NUM+1,A
    .else
        setSpriteY SPR_NUM+1,Y
    .endif
  .endif
.endif

.if CARRIER>0
carrying=*+1
        lda #0
        if ne
  .if IN_FRONT>0
            ldax in_frontX
  .else
            ldax spriteX
  .endif
carryX=*+1
            sta $AFFE
carryX2=*+1
            stx $AFFE
  .if IN_FRONT>0
            lda in_frontY
  .else
            lda spriteY
  .endif
            adc #CARRY_OFFSET_Y
carryY=*+1
            sta $AFFE
        endif
.endif
; TODO: skip this if custom animation is in progress

.if ANIMATION_STATES>0
        lda anim_counter
  .repeat ANIMATION_DELAY
        lsr
  .endrep
        and #(ANIMATION_STATES-1)<<OVERLAY
        clc
        adc spr_costume
  .if CONFIGURABLE_SPR_COSTUME
        adc spr_base_costume
  .endif

  .if HANDLE_OVERLAY_SPRITE=0
        setSpriteCostume SPR_NUM, A
    .if TWIN>0
        clc
        adc #TWIN_COSTUME_OFFSET
        setSpriteCostume SPR_NUM+1, A
    .endif
  .else
        setSpriteCostume SPR_NUM+1, A
        clc
        adc #1
        setSpriteCostume SPR_NUM, A
    .if TWIN>0
        adc #TWIN_COSTUME_OFFSET
        setSpriteCostume SPR_NUM+2, A
        sec
        sbc #1
        setSpriteCostume SPR_NUM+3, A
    .endif
  .endif

.endif
an_rts: rts

.if MAXDISTANCE
cancel_movement:
        poke joyvalue,$ff
        bne end_y_movement
.endif

run:
.if CUSTOM_ANIMATIONS>0
        lda playing_animation
        if pl
            dec anim_counter
            bne an_rts
            lda #CUSTOM_ANIMATION_DELAY
            sta anim_counter

            dec playing_animation
            bmi an_rts

costume_during_animation=*+1
            lda #$af
  .if HANDLE_OVERLAY_SPRITE=0
            setSpriteCostume SPR_NUM, A
    .if TWIN>0
            clc
            adc #TWIN_COSTUME_OFFSET
            setSpriteCostume SPR_NUM+1, A
    .endif
            inc costume_during_animation
    .if OVERLAY>0
            inc costume_during_animation
    .endif
  .else
            setSpriteCostume SPR_NUM+1, A
            clc
            adc #1
            setSpriteCostume SPR_NUM, A
    .if TWIN>0
            adc #TWIN_COSTUME_OFFSET
            setSpriteCostume SPR_NUM+2, A
            sec
            sbc #1
            setSpriteCostume SPR_NUM+3, A
    .endif

            inc costume_during_animation
            inc costume_during_animation
  .endif ;.if HANDLE_OVERLAY_SPRITE>0
            rts ;TODO continue normally to sprite control, prob no rts does it
        endif ;if pl
.endif ;.if CUSTOM_ANIMATIONS>0

.if JOY_CONTROL>0 || PURSUER>0
        lda movement_enabled
        beq an_rts

  .if PURSUER>0
        lda pursueing
    .if JOY_CONTROL
        beq joy_control
    .else
        beq an_rts
    .endif

    .if PURSUEDIST_X=0 .and PURSUEDIST_Y=0
pursueX=*+1
        lda $AFFE
pursueX2=*+1
        ldx $AFFE
        cmpax spriteX
        if ne
pursue_right=*+1
            lda #8^$ff
            if cc
pursue_leftt=*+1
                lda #4^$ff
            endif
        else
            lda #0^$ff
        endif
pursueY=*+1
        ldy $AFFE
        cpy spriteY
        if ne
            if cc
pursue_up=*+1
                and #1^$ff
            else
pursue_down=*+1
                and #2^$ff
            endif
        endif
        sta joyvalue
    .else
              ;pursue, but keep a minimum distance
        lda #$ff
        sta joyvalue
pursueX=*+1
        lda $AFFE
pursueX2=*+1
        ldx $AFFE
        subax spriteX
        if cc
            adc #PURSUEDIST_X
      .if MAXDISTANCE
            bcc end_y_movement
            inx
            bne end_y_movement
      .else
            bcc joyleft1
            inx
            beq end_x_movement
      .endif
pursue_leftt=*+1
joyleft1:   lda #4^$ff
            sta joyvalue
        else
            sbc #PURSUEDIST_X+1
      .if MAXDISTANCE
            bcs end_y_movement
            dex
            bpl end_y_movement
      .else
            bcs joyright1   ;or is it Joyride ?
            dex
            bmi end_x_movement
      .endif
pursue_right=*+1
joyright1:  lda #8^$ff
            sta joyvalue
        endif
end_x_movement:
pursueY=*+1
        lda $AFFE
        sec
        sbc spriteY
        if cc
            adc #PURSUEDIST_Y
      .if MAXDISTANCE
            bcc cancel_movement
      .else
            bcs end_y_movement
      .endif
joyup1:     lda joyvalue
pursue_up=*+1
            and #1^$ff
            sta joyvalue
        else
            sbc #PURSUEDIST_Y+1
      .if MAXDISTANCE
            bcs cancel_movement
      .else
            bcc end_y_movement
      .endif
joydown1:   lda joyvalue
pursue_down=*+1
            and #2^$ff
            sta joyvalue
        endif
end_y_movement:
    .endif ;if PURSUEDISTANCE=0

    .if ANIMATION_STATES>0
      .if ANIMATE_ALWAYS=0
        lda joyvalue
        and #MOV_DIRS
        cmp #MOV_DIRS
        if ne
            inc anim_counter
        endif
      .else
        inc anim_counter
      .endif
    .endif
    .if JOY_CONTROL
        jmp after_joy_control
    .endif
  .endif ;.if PURSUER>0
  .if JOY_CONTROL
joy_control:
    .if JOY_CONTROL & 4 > 0
        readWASDspace
      .if JOY_CONTROL & 2 > 0
        and $dc00
      .endif
      .if JOY_CONTROL & 1 > 0
        and $dc01
      .endif
    .elseif JOY_CONTROL & 2 > 0
        lda $dc00
      .if JOY_CONTROL & 1 > 0
        and $dc01
      .endif
    .elseif JOY_CONTROL & 1 > 0
        lda $dc01
    .else
	lda JOY_REMOTECONTROL
    .endif
        sta joyvalue
    .if ANIMATION_STATES>0
      .if ANIMATE_ALWAYS=0
        and #MOV_DIRS
        cmp #MOV_DIRS
        if ne
            inc anim_counter
        endif
      .else
        inc anim_counter
      .endif
    .endif ;.if ANIMATION_STATES>0
  .endif ;.if PURSUER>0

after_joy_control:
  .if ACCELERATION=0
        lda #0
        sta current_speed_y
        sta current_speed_x
  .endif

; code for boosted jump counter --------------------------------------------
  .if ACCELERATION .and GRAVITY .and JUMP_TRIGGER .and JUMP_BOOST_DURATION>1
boost_counter=*+1
        ldy #00
        if ne
            dec boost_counter
        endif
  .endif

joy_up:
        lsr joyvalue
            ; code for jump --------------------------------------------
  .if GRAVITY .and ACCELERATION .and JUMP_TRIGGER=1
        if cc
            lda onground
            if ne
                poke current_speed_y,$100-JUMP_LAUNCH_SPEED
    .if JUMP_BOOST_DURATION>1
                poke boost_counter,JUMP_BOOST_DURATION
            else
                lda boost_counter
                if ne
                    poke current_speed_y,$100-JUMP_LAUNCH_SPEED
                endif
    .endif
            endif
        endif
  .endif

  .if MOV_DIRS & 1>0
        if cc
    .if ACCELERATION=0
            lda mov_speed_y
            neg
            sta current_speed_y
    .elseif ACCELERATION=1
            ldy current_speed_y
            dey
            cpy #$100-(MOV_SPEED_Y+DECELERATION)*(1 << ACCELERATION_DOWNSCALE)
            if mi
                ldy #$100-(MOV_SPEED_Y+DECELERATION)*(1 << ACCELERATION_DOWNSCALE)
            endif
            sty current_speed_y
    .else ;ACCELERATION is 2 or larger
            lda current_speed_y
            sec
            sbc #ACCELERATION
            cmp #$100-(MOV_SPEED_Y+DECELERATION)*(1 << ACCELERATION_DOWNSCALE)
            if mi
                lda #$100-(MOV_SPEED_Y+DECELERATION)*(1 << ACCELERATION_DOWNSCALE)
            endif
            sta current_speed_y
    .endif ;if ACCELERATION=0
        endif
  .endif ;.if MOV_DIRS & 1>0
joy_down:
        lsr joyvalue
  .if MOV_DIRS & 2>0
        if cc
    .if ACCELERATION=0
            lda mov_speed_y
            sta current_speed_y
    .elseif ACCELERATION=1
            ldy current_speed_y
            iny
            cpy #(MOV_SPEED_Y+DECELERATION)*(1 << ACCELERATION_DOWNSCALE)
            if pl
                ldy #(MOV_SPEED_Y+DECELERATION)*(1 << ACCELERATION_DOWNSCALE)
            endif
            sty current_speed_y
    .else ;ACCELERATION is 2 or larger
            lda current_speed_y
            clc
            adc #ACCELERATION
            cmp #(MOV_SPEED_Y+DECELERATION)*(1 << ACCELERATION_DOWNSCALE)
            if pl
                lda #(MOV_SPEED_Y+DECELERATION)*(1 << ACCELERATION_DOWNSCALE)
            endif
            sta current_speed_y

    .endif ;if ACCELERATION=0
        endif
  .endif ;.if MOV_DIRS & 2>0
joy_left:
        lsr joyvalue
  .if MOV_DIRS & 4>0
        if cc
    .if ACCELERATION=0
            lda mov_speed_x
            neg
            sta current_speed_x
    .elseif ACCELERATION=1
            ldy current_speed_x
            dey
            cpy #$100-(MOV_SPEED_X+DECELERATION)*(1 << ACCELERATION_DOWNSCALE)
            if mi
                ldy #$100-(MOV_SPEED_X+DECELERATION)*(1 << ACCELERATION_DOWNSCALE)
            endif
            sty current_speed_x
    .else ;ACCELERATION is 2 or larger
            lda current_speed_x
            sec
            sbc #ACCELERATION
            cmp #$100-(MOV_SPEED_X+DECELERATION)*(1 << ACCELERATION_DOWNSCALE)
            if mi
                lda #$100-(MOV_SPEED_X+DECELERATION)*(1 << ACCELERATION_DOWNSCALE)
            endif
            sta current_speed_x
    .endif ;if ACCELERATION=0
        endif
  .endif ;.if MOV_DIRS & 4>0
joy_right:
        lsr joyvalue
  .if MOV_DIRS & 8>0
        if cc
    .if ACCELERATION=0
            lda mov_speed_x
            sta current_speed_x
    .elseif ACCELERATION=1
            ldy current_speed_x
            iny
            cpy #(MOV_SPEED_X+DECELERATION)*(1 << ACCELERATION_DOWNSCALE)
            if pl
                ldy #MOV_SPEED_X*(1 << ACCELERATION_DOWNSCALE)
            endif
            sty current_speed_x
    .else ;ACCELERATION is 2 or larger
            lda current_speed_x
            clc
            adc #ACCELERATION
            cmp #(MOV_SPEED_X+DECELERATION)*(1 << ACCELERATION_DOWNSCALE)
            if pl
                lda #(MOV_SPEED_X+DECELERATION)*(1 << ACCELERATION_DOWNSCALE)
            endif
            sta current_speed_x
    .endif ;if ACCELERATION=0
        endif
  .endif ;.if MOV_DIRS & 8>0
joy_fire:
            ; code for jump --------------------------------------------
  .if GRAVITY .and ACCELERATION .and JUMP_TRIGGER=2
        lsr joyvalue
        if cc
            lda onground
            if ne
                poke current_speed_y,$100-JUMP_LAUNCH_SPEED
    .if JUMP_BOOST_DURATION>1
                poke boost_counter,JUMP_BOOST_DURATION
            else
                lda boost_counter
                if ne
                    poke current_speed_y,$100-JUMP_LAUNCH_SPEED
                endif
    .endif
            endif
        endif
  .endif ;.if GRAVITY .and ACCELERATION .and JUMP_TRIGGER=2
;-----------------------------------------------------
;-- code for move model ------------------------------

; vertical moves -------------------------------------

current_speed_y=*+1
        lda #0

  .if ACCELERATION>0
    .if GRAVITY>0
        clc
gravity=*+1
        adc #GRAVITY
        cmp #MAXFALLSPEED
        if pl
            lda #MAXFALLSPEED
        endif
        sta current_speed_y
    .elseif DECELERATION>0
        if eq
            jmp y_move_done
        endif
        if mi
            clc
            adc #DECELERATION
        else
            sec
            sbc #DECELERATION
        endif
        sta current_speed_y
    .endif

    .if ACCELERATION_DOWNSCALE=0
        cmp #0
    .else
      .repeat ACCELERATION_DOWNSCALE
        cmp #$80      ; Put bit 7 into carry
        ror             ; Rotate right with carry
      .endrep
    .endif
  .endif ;.if ACCELERATION>0

  .if ACCELERATION .and CHECK_CHAR_COLLISION .and IN_FRONT
        if eq
            jmp y_move_done     ;no action if vy==0
        endif
        clc                   ;prepare for next adc
  .else
        clc                   ;prepare for next adc
        beq y_move_done       ;no action if vy==0
  .endif

        ;clc
        adc spriteY
        sta spriteY

        if cc
        ; move down ------------------------------------------
  .if CHECK_CHAR_COLLISION>0
            jsr check_below
            bcc mov_down_is_allowed

  ;          .if ACCELERATION>0 .and GRAVITY>0
  ;            poke onground,1
  ;          .endif

    .if ADJUST_YSCROLL
            lda $d011                    ;load Y-scroll register
            clc
            adc #30+BOTTOM_EMPTY-3-1     ;add sprite dimension
            and #7                       ;cut off other bits
            sta ora_arg1                 ;use as argument of ORA opcode
    .endif
            lda spriteY
            and #%11111000                 ;mask out lower bits
ora_arg1=*+1
            ora #(30+BOTTOM_EMPTY-1) & 7   ;set intented lower bits
            cmp spriteY
            if cs
              ;sec
                sbc #%00001000               ;subtract 8 if coordinate increased
            endif
            sta spriteY                    ;write back adjusted Y coordinated
            ldy #0
            sty current_speed_y
    .if ACCELERATION .and GRAVITY
            iny
        .byte $2c ;BIT to skip following ldy #0
    .endif
  .endif ;.if CHECK_CHAR_COLLISION>0
mov_down_is_allowed:
  .if ACCELERATION .and GRAVITY
            ldy #0      ;potentially skipped by BIT
            sty onground
  .endif
  .if IN_FRONT>0
            lda spriteY
            clc
            adc #IN_FRONT_DY
            sta in_frontY
  .endif
  .if CHECK_BOUNDARIES>0
            lda #MAX_Y+BOTTOM_EMPTY
            cmp spriteY
    .if ANIMATION_STATES>0
            bcs set_animation_costume_down
    .else
            bcs y_move_done
    .endif
            sta spriteY
    .if ACCELERATION>0
            ldy #0
            sty current_speed_y
      .if GRAVITY>0
            iny
            sty onground
      .endif
    .endif
  .endif

  .if ANIMATION_STATES>0
set_animation_costume_down:
    .if ANIMATION_DIRS=4
      .if CONFIGURABLE_SPR_COSTUME
            poke spr_costume, 2*(1+OVERLAY)*ANIMATION_STATES
      .else
            poke spr_costume,((SPR_ADDR & $3fc0) >> 6) + 2*(1+OVERLAY)*ANIMATION_STATES
      .endif
    .endif
  .endif
        else
        ; move up ---------------------------------------------
  .if CHECK_CHAR_COLLISION>0
            jsr check_above
            bcc mov_up_is_allowed
    .if ADJUST_YSCROLL
            lda $d011                    ;load Y-scroll register
            clc
            adc #51-TOP_EMPTY-3          ;add sprite dimension
            and #7                       ;cut off other bits
            sta ora_arg2                 ;use as argument of ORA opcode
    .endif
            lda spriteY
            and #%11111000               ;mask out lower bits
ora_arg2=*+1
            ora #(51-TOP_EMPTY) & 7    ;set intented lower bits
            cmp spriteY
            if cc
              ;clc
                adc #%00001000               ;subtract 8 if coordinate increased
            endif
            sta spriteY                    ;write back adjusted Y coordinated

    .if ACCELERATION>0
            ldy #0
      .if GRAVITY .and JUMP_TRIGGER .and JUMP_BOOST_DURATION>1
            sty boost_counter
        .if BOUNCE_ON_CEILING
            lda current_speed_y
            neg
            sta current_speed_y
        .else
            sty current_speed_y
        .endif
      .else
            sty current_speed_y
      .endif
    .endif
  .endif ;.if CHECK_CHAR_COLLISION>0
mov_up_is_allowed:
  .if ACCELERATION .and GRAVITY
            ldy #0      ;potentially skipped by BIT
            sty onground
  .endif
  .if IN_FRONT>0
            lda spriteY
            sec
            sbc #IN_FRONT_DY
            sta in_frontY
  .endif
  .if CHECK_BOUNDARIES>0
            lda #MIN_Y-TOP_EMPTY
            cmp spriteY
    .if ANIMATION_STATES>0
            bcc set_animation_costume_up
    .else
            bcc y_move_done
    .endif
            sta spriteY
    .if ACCELERATION>0
            ldy #0
      .if GRAVITY .and JUMP_TRIGGER .and JUMP_BOOST_DURATION>1
            sty boost_counter
        .if BOUNCE_ON_CEILING
            lda current_speed_y
            neg
            sta current_speed_y
        .else
            sty current_speed_y
        .endif
      .else
            sty current_speed_y
      .endif
    .endif
  .endif
  .if ANIMATION_STATES>0
set_animation_costume_up:
    .if ANIMATION_DIRS=4
      .if CONFIGURABLE_SPR_COSTUME
            poke spr_costume, 3*(1+OVERLAY)*ANIMATION_STATES
      .else
            poke spr_costume,((SPR_ADDR & $3fc0) >> 6) + 3*(1+OVERLAY)*ANIMATION_STATES
      .endif
    .endif
  .endif
        endif

y_move_done:
; horizontal moves ----------------------------------

current_speed_x=*+1
        lda #0
  .if ACCELERATION>0
    .if DECELERATION>0
        if eq
            jmp x_move_done
        endif
        if mi
            clc
            adc #DECELERATION
        else
            sec
            sbc #DECELERATION
        endif
        sta current_speed_x
    .endif

    .repeat ACCELERATION_DOWNSCALE
        cmp #$80        ; Put bit 7 into carry
        ror             ; Rotate right with carry
    .endrep
  .endif ;.if ACCELERATION>0

  .if CHECK_CHAR_COLLISION>0
        if eq
            jmp x_move_done     ;long branch necessary if there is CHECK_CHAR_COLLISION code
        endif
  .else
        beq x_move_done       ;shorter coder
  .endif

        clc
        if pl ; move right ------------------------------------------
            adc spriteX
            sta spriteX
            if cs
                inc spriteX+1
            endif

  .if CHECK_CHAR_COLLISION>0
            jsr check_right
            if cs
    .if ADJUST_XSCROLL
                lda $d016                    ;load X-scroll register
                clc
                adc #RIGHT_EMPTY             ;add sprite dimension
                and #7                       ;cut off other bits
                sta ora_arg3                 ;use as argument of ORA opcode
    .endif
                ldax spriteX
                and #%11111000             ;mask out lower bits
ora_arg3=*+1
                ora #(RIGHT_EMPTY) & 7     ;set intented lower bits
                cmp spriteX
                if cs
                ;sec
                    sbc #%00001000               ;subtract 8 if coordinate increased
                    if cc
                        dex
                    endif
                endif
                stax spriteX                   ;write back adjusted Y coordinated
    .if ACCELERATION>0
                ldy #0
                sty current_speed_x
    .endif
            endif
  .endif ;.if CHECK_CHAR_COLLISION>0

  .if CHECK_CHAR_COLLISION=0
            ldx spriteX+1  ;complete ldax spriteX
  .endif
  .if IN_FRONT>0
            ldax spriteX
            clc
            adcax #IN_FRONT
            stax in_frontX
  .endif

  .if CHECK_BOUNDARIES>0
            ldax #MAX_X+RIGHT_EMPTY
            cmpax spriteX
            if cc
                stax spriteX
            endif
  .endif

  .if ANIMATION_STATES>0
set_animation_costume_right:
    .if ANIMATION_DIRS>1
      .if CONFIGURABLE_SPR_COSTUME
            poke spr_costume, 0
      .else
            poke spr_costume,((SPR_ADDR & $3fc0) >> 6)
      .endif
    .endif
  .endif

        else ; move left --------------------------------------------
            adc spriteX
            sta spriteX
            if cc
                dec spriteX+1
            endif

  .if CHECK_CHAR_COLLISION>0
            jsr check_left
            if cs
    .if ADJUST_XSCROLL
                lda $d016                    ;load X-scroll register
                clc
                adc #24-LEFT_EMPTY           ;add sprite dimension
                and #7                       ;cut off other bits
                sta ora_arg4                 ;use as argument of ORA opcode
    .endif
                ldax spriteX
                and #%11111000             ;mask out lower bits
ora_arg4=*+1
                ora #(24-LEFT_EMPTY) & 7   ;set intented lower bits
                cmp spriteX
                if cc
                ;clc
                    adc #%00001000               ;subtract 8 if coordinate increased
                    if cs
                        inx
                    endif
                endif
                stax spriteX                   ;write back adjusted Y coordinated
    .if ACCELERATION>0
                ldy #0
                sty current_speed_x
    .endif
            endif
  .endif ;.if CHECK_CHAR_COLLISION>0

  .if CHECK_CHAR_COLLISION=0
            ldx spriteX+1  ;complete ldax spriteX
  .endif
  .if IN_FRONT>0
            ldax spriteX
            sec
            sbcax #IN_FRONT
            stax in_frontX
  .endif

  .if CHECK_BOUNDARIES>0
            ldax #MIN_X-LEFT_EMPTY
            cmpax spriteX
            if cs
                stax spriteX
            endif
  .endif

  .if ANIMATION_STATES>0
set_animation_costume_left:
    .if ANIMATION_DIRS>1
      .if CONFIGURABLE_SPR_COSTUME
            poke spr_costume, (1+OVERLAY)*ANIMATION_STATES
      .else
            poke spr_costume,((SPR_ADDR & $3fc0) >> 6) + (1+OVERLAY)*ANIMATION_STATES
      .endif
    .endif
  .endif

        endif

x_move_done:
.else ;.if JOY_CONTROL>0 || PURSUER>0
  .if ANIMATE_ALWAYS
        inc anim_counter
  .endif
.endif ;.if JOY_CONTROL>0 || PURSUER>0
        jsr place_sprite
        rts

.if CHECK_CHAR_COLLISION>0

;-----------------------------------------------------
;-- horizontal check above and below -----------------

check_above:
  .if ADJUST_YSCROLL
        lda #51-TOP_EMPTY-3
  .else
        lda #51-TOP_EMPTY
  .endif
        .byte $2c       ;skip next two bytes with a bit $xxxx command
check_below:
  .if ADJUST_YSCROLL
        lda #30+BOTTOM_EMPTY-3
  .else
        lda #30+BOTTOM_EMPTY
  .endif

        sta set_y_offset

        ;x2 = (x-1-RIGHT_EMPTY-sx) // 8
  .if ADJUST_XSCROLL>0
        lda $d016
        and #7
        clc
        adc #RIGHT_EMPTY+1
        rsc spriteX
  .else
        lda spriteX
        sec
        sbc #RIGHT_EMPTY+1
  .endif
        bcc hibyte_is_0
        ldx spriteX+1
        cpx #1  ;set carry if X>=1
hibyte_is_0:
        ror     ;divide, including C
        lsr
        lsr
        sta X2

        ;x1 = (x-24+LEFT_EMPTY-sx) // 8
  .if ADJUST_XSCROLL>0
        lda $d016
        and #7
        clc
        adc #24-LEFT_EMPTY
        rsc spriteX
  .else
        lda spriteX
        sec
        sbc #24-LEFT_EMPTY
  .endif
        bcc hibyte_is_0_
        ldx spriteX+1
        cpx #1  ;set carry if X>=1
hibyte_is_0_:
        ror     ;divide, including C
        lsr
        lsr
        sta X1

  .if ADJUST_YSCROLL
        lda $d011
        and #7
        clc
set_y_offset=*+1
        adc #51-TOP_EMPTY-3   ;30+BOTTOM_EMPTY-3
        rsc spriteY
  .else
        lda spriteY
        sec
set_y_offset=*+1
        sbc #51-TOP_EMPTY     ;30+BOTTOM_EMPTY
  .endif
        lsr
        lsr
        lsr

check_X1_to_X2:
        tay
        lda screen_lines_lo,y
        sta scr_addr
        lda screen_lines_hi,y
        sta scr_addr+1
X1=*+1
        ldx #$af
        .byte $24       ;skip over next byte with BIT zp
check_next_column:
        inx
scr_addr=*+1
        lda $affe,x
  .repeat WALKABLE_CHARS_COUNT,i
    .if .ident(.sprintf("WALKABLE_CHAR%i",i+1))>-1
        cmp #.ident(.sprintf("WALKABLE_CHAR%i",i+1))
        beq walk
    .endif
  .endrep
        bne we_touched
walk:
X2=*+1
        cpx #$af
        bne check_next_column
        clc
        rts
we_touched:
        sec     ;we touched something
        rts

;-----------------------------------------------------
;-- vertical check left and right --------------------

check_left:
        lda #24-LEFT_EMPTY
        .byte $2c       ;skip next two bytes with a bit $xxxx command
check_right:
        lda #RIGHT_EMPTY+1

        sta set_x_offset

  .if ADJUST_XSCROLL>0
        lda $d016
        and #7
        clc
set_x_offset=*+1
        adc #RIGHT_EMPTY+1    ;24-LEFT_EMPTY
        rsc spriteX
  .else
        lda spriteX
        sec
set_x_offset=*+1
        sbc #RIGHT_EMPTY+1    ;24-LEFT_EMPTY
  .endif
        bcc hibyte_is_0__
        ldx spriteX+1
        cpx #1  ;set carry if X>=1
hibyte_is_0__:
        ror     ;divide, including C
        lsr
        lsr
        tax

        ;y1=(y-30+ts-sy+3) // 8
  .if ADJUST_YSCROLL
        lda $d011
        and #7
        clc
        adc #30+BOTTOM_EMPTY-3
        rsc spriteY
  .else
        lda spriteY
        sec
        sbc #30+BOTTOM_EMPTY
  .endif
        lsr
        lsr
        lsr
        sta Y2

        ;y1=(y-50+TOP_EMPTY-sy+3) // 8
  .if ADJUST_YSCROLL
        lda $d011
        and #7
        clc
        adc #50-TOP_EMPTY-3
        rsc spriteY
  .else
        lda spriteY
        sec
        sbc #50-TOP_EMPTY
  .endif
        lsr
        lsr
        lsr
        tay

check_Y1_to_Y2:
        lda screen_lines_lo,y
        sta scr_addr1
        lda screen_lines_hi,y
        sta scr_addr1+1

        .byte $24       ;skip over next byte with BIT zp
check_next_row:
        iny
scr_addr1=*+1
        lda $affe,x
        cmp #WALKABLE_CHAR1
  .repeat WALKABLE_CHARS_COUNT,i
    .if .ident(.sprintf("WALKABLE_CHAR%i",i+1))>-1
        cmp #.ident(.sprintf("WALKABLE_CHAR%i",i+1))
        beq walk_
    .endif
  .endrep
        bne we_touched_
walk_:
        txa
        .byte $cb,$100-$28      ;sbx #40
Y2=*+1
        cpy #$af
        bne check_next_row
        clc
        rts

we_touched_:
        sec     ;we touched something
        rts

.endif ;CHECK_CHAR_COLLISION

.if CHECK_CHAR_COLLISION>0 || ENABLE_CALC_SCREEN_ADDR>0

screen_lines_lo:
  .repeat 25,i
        .byte <(SCREEN_BASE+i*40)
  .endrep
screen_lines_hi:
  .repeat 25,i
        .byte >(SCREEN_BASE+i*40)
  .endrep

.endif

;-----------------------------------------------------
;-- check chars under sprite -------------------------

.if ENABLE_CALC_SCREEN_ADDR
calc_screen_addr:
        lda #32-CHAR_X_OFFSET

        ;x1 = (x-24+CHAR_X_OFFSET-sx) // 8
  .if ADJUST_XSCROLL>0
        lda $d016
        and #7
        clc
        adc #24-CHAR_X_OFFSET
        rsc spriteX
  .else
        lda spriteX
        sec
        sbc #24-CHAR_X_OFFSET
  .endif
        bcc @hibyte_is_0
        ldx spriteX+1
        cpx #1  ;set carry if X>=1
@hibyte_is_0:
        ror     ;divide, including C
        lsr
        lsr
        sta X1_

  .if ADJUST_YSCROLL
        lda $d011
        and #7
        clc
        adc #43-CHAR_Y_OFFSET-3
        rsc spriteY
  .else
        lda spriteY
        sec
        sbc #43-CHAR_Y_OFFSET
  .endif
        lsr
        lsr
        lsr

        tay
        lda screen_lines_lo,y
        clc
X1_=*+1
        adc #$af
        sta CALC_SCREEN_ADDR_PTR
        lda screen_lines_hi,y
        adc #0
        sta CALC_SCREEN_ADDR_PTR+1
        rts

.endif

.if ACCELERATION>0 .and GRAVITY>0
onground: .byte 0
.endif

;***********************************************************************
;* macros

.if .not .definedmacro(placesprite)

  .macro placesprite m_spritename,xpos,ypos
    .ifnblank xpos
        pokew m_spritename::spriteX,xpos
    .endif
    .ifnblank ypos
        poke  m_spritename::spriteY,ypos
    .endif
        m_call m_spritename,place_sprite
  .endmacro

  .macro playanimation m_spritename,firstcostume,frames
    .if .const(firstcostume) && firstcostume>255
        lda #((firstcostume) & $3fc0) >> 6  ;values > 255 are interpreted as sprite memory address
    .else
        lda #firstcostume
    .endif
        ldx #frames
        m_call m_spritename,play_animation
  .endmacro

.endif
