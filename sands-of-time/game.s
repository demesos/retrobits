; Game
; by Wil
; One Hour Game Jam #

.include "LAMAlib.inc"
.include "constants.inc"
.include "spritemacros.inc"
.include "LAMAlib-sprites.inc"
.include "wait_anykey_off_on.inc"

.if .not .definedmacro(scrcode)
        .MACPACK cbm
.endif

.if .not .definedmacro(jne)
        .MACPACK longbranch
.endif

.if .not .definedmacro(add)
        .MACPACK generic
.endif

        makesys 31," onehourgamejam"

begin_part_once:
.import ohgj_intro
        disable_NMI
.ifdef SPRMUCO1
        setSpriteMultiColor1 SPRMUCO1
.endif
.ifdef SPRMUCO2
        setSpriteMultiColor2 SPRMUCO2
.endif

;-----------------------------------------------------
;-- resource installation routines -------------------

;Sprite data
install_file "spr_small_guy.prg", SPRITE_BASE

        jmp over_it
;-- end of resource installation routines ------------
;-----------------------------------------------------

end_part_once:

;-----------------------------------------------------
;-- imported modules, subroutines, and data ----------

.include "petscii.asm"

.scope displayPETSCII
DISPLAY_BY_NUM=1
TRANSPARENT_MODIFIERS=1
.include "modules/m_displayPETSCII.s"
.endscope

; be sure to match the scope name
.macro displayPETSCII addr
        ldax #addr
        m_run displayPETSCII
.endmacro

isr:
        asl $d019
        jsr MUSIC_BASE+3
        jmp $ea31

.scope charset
EFFECT=0                 ;Effects: 1 italic
                        ;         2 italic, including lower case
                        ;         3 bold
                        ;         4 bold, including lower case
                        ;         5 lower half bold
                        ;         6 lower half bold, including lower case
                        ;         7 thin
                        ;         8 thin, including lower case
.include "modules/m_copycharset.s"
.endscope

.scope playersprite
SPR_ADDR=SPRITE_BASE
SPR_NUM=0
JOY_CONTROL=2
ACCELERATION=2
ACCELERATION_DOWNSCALE=2
DECELERATION=1
JUMP_TRIGGER=1
JUMP_LAUNCH_SPEED=10
JUMP_BOOST_DURATION=4
MOV_DIRS=14
BOUNCE_ON_CEILING=0
MAXFALLSPEED=31
MOV_SPEED_Y=5
MOV_SPEED_X=5
CHECK_CHAR_COLLISION=1
ADJUST_YSCROLL=0
WALKABLE_CHAR2=96        ;Shift-Space
CONFIGURABLE_SPR_COSTUME=1
.include "spr_small_guy.inc"
.include "m_spriteman.s"
.endscope


;-- end of modules, subroutines, and data ------------
;-----------------------------------------------------

;-----------------------------------------------------
;-- variables ----------------------------------------
.zeropage
scr_ptr: .res 2

.code
game_time: .res 1

;-- end of init variables ----------------------------
;-----------------------------------------------------

over_it:
;-----------------------------------------------------
;-- init routines ------------------------------------

        m_init playersprite
        m_init charset
        lda #0
        m_call displayPETSCII,set_transparent   ;make displayPETSCII interpret @ as transparent
;-- end of init routines -----------------------------
;-----------------------------------------------------

title:
        m_run charset
        m_call playersprite,hide
        displayPETSCII petsciiimg0

        set_cursor_pos 17,0
        textcolor 7
        print "  beat the sands of time or get crushed!\n"
        textcolor 1
        print "\n\n            a game by wil"
        print "\n\n      for the one hour game jam 570"

        wait_anykey_off_on

        ;play_sound sfx1,2      ;play sound effect sfx1 on voice2
        ;play_sound sfx1        ;play sound effect sfx1 on voice3 (default)


gamecode:
        displayPETSCII petsciiimg1
        placesprite playersprite,160,200
        m_call playersprite,show
        lda $d01f       ;emtpy sprite-bg collision
        jsr paint_spaces_yellow
        pokew game_time,$88
        do
            do_every 5
                jsr sand_physics
                dec game_time
                beq lost
            end_every
            m_run playersprite
            lda playersprite::spriteY
            cmp #213-13*8
            bcc win
            lda $d01f
            bne lost
            sync_to_rasterline256
        loop
        rts

lost:
        lda #(SPRITE_BASE/$40)+2
        sta SCREEN_BASE+$3f8+playersprite::SPR_NUM
        for x,1,to,50
            store x
            do_every 5
                jsr sand_physics
            end_every
            sync_to_rasterline256
            restore x
        next
        jmp gamecode

win:
        for x,1,to,10
            store x
            set_cursor_pos 24,0
            textcolor 0
            print "    you have beaten the sands of time!"
            delay_ms 300
            set_cursor_pos 24,0
            textcolor 1
            print "    you have beaten the sands of time!"
            delay_ms 300
            restore x
        next
        wait_anykey_off_on
        jmp title

.code
sand_physics:
        for (scr_ptr),SCREEN_BASE+920,downto,SCREEN_BASE+40
            ldy #1
            lda (scr_ptr),y
            cmp #81
            if eq
                ldy #41
                lda (scr_ptr),y
                switch A
                case 32
move_sand_grain:
                    lda #81
                    sta (scr_ptr),y
                    lda #32
                    ldy #1
                    sta (scr_ptr),y
                    break
                case 81
                    rand8 1
                    if eq
                        ldy #40
                        lda (scr_ptr),y
                        cmp #32
                        beq move_sand_grain
                        ldy #42
                        lda (scr_ptr),y
                        cmp #32
                        beq move_sand_grain
                    else
                        ldy #42
                        lda (scr_ptr),y
                        cmp #32
                        beq move_sand_grain
                        ldy #40
                        lda (scr_ptr),y
                        cmp #32
                        beq move_sand_grain
                    endif
                case 223 ;77
                    ldy #42
                    lda (scr_ptr),y
                    cmp #32
                    beq move_sand_grain
                case 233 ;78
                    ldy #40
                    lda (scr_ptr),y
                    cmp #32
                    beq move_sand_grain
                endswitch
            endif
        next
        rts


paint_spaces_yellow:
        ldy #0
        for (scr_ptr),SCREEN_BASE+40,to,SCREEN_BASE+920
            lda (scr_ptr),y
            and #%10111111
            cmp #32
            if eq
                lda scr_ptr+1
                tax
                eor #(>SCREEN_BASE)^($d8)
                sta scr_ptr+1
                lda #7
                sta (scr_ptr),y
                stx scr_ptr+1
            endif
        next
        rts

