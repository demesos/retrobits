; Olympic Swim Game
; by Wil
; One Hour Game Jam #556

.include "LAMAlib.inc"
.include "constants.inc"
.include "spritemacros.inc"
.include "module-macros.inc"
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

SPR_BASE1=SPRITE_BASE
SPR_BASE2=SPR_BASE1+4*$40
SPR_BASE3=SPR_BASE1+9*$40
install_file "spr-swimmer.prg", SPR_BASE1

;Music (or empty music for sound effects)
install_file "silence_9000.prg", MUSIC_BASE

        jmp over_it
;-- end of resource installation routines ------------
;-----------------------------------------------------

end_part_once:

;-----------------------------------------------------
;-- imported modules, subroutines, and data ----------

.macro play_sound sound_src,voice
  .if .paramcount > 0
        lda #<sound_src
        ldy #>sound_src
  .endif
  .if .paramcount = 2
        ldx #(voice-1)*7
  .else
        ldx #14       ;voice #3 as default
  .endif
        jsr MUSIC_BASE+6
.endmacro

isr0:   ;triggered at rasterline 251, below the screen.
        asl $d019       ;acknowledge interrupt

        poke $d016,$c0  ;reset horizontal shift
titlemode=*+1
        lda #1
        if eq   ;game mode
            poke $d021,9
            pokew $314,isr1
            poke $d012,50+9*8

            ldy yshift
            dey
            cpy #192
            if cc
                ldy #199
                sty yshift
                jmp hardshift
            endif
            sty yshift
        else
            cmp #2
            if eq ;game over /game doen display mode
                poke $d021,9
                pokew $314,isr1
                poke $d012,50+9*8
                jmp $ea81
            else ;title mode
                poke $d016,$c8
                jsr MUSIC_BASE+3
                jmp $ea31
            endif
        endif
        jmp $ea81

hardshift:
        cli
.repeat 25-9,i
        ldy SCREEN_BASE+(i+11)*40
        ldx #256-40
:
        lda SCREEN_BASE+(i+11)*40+1-256-40,x
        sta SCREEN_BASE+(i+11)*40  -256-40,x
        inx
        bne :-
        sty SCREEN_BASE+(i+11)*40+39
.endrep
        jmp $ea81

isr1:
        asl $d019
        pokew $314,isr0
yshift=*+1
        lda #191
        sta $d016
        poke $d021,8
        poke $d012,251
        jsr MUSIC_BASE+3
        jmp $ea31

.macro joy2button_count_bounces
  .scope
        poke bounces,0
wait_press:
        lda $dc00
        and #$10
        bne wait_press

count_bounces:
        for x,0,to,255
            lda $dc00
            and #$10
            if ne
                inc bounces
            endif
        next

bounces=*+1
        lda #0
  .endscope
.endmacro

;PETSCII gfx
.include "seine_petscii.asm"

.scope displayPETSCII
DISPLAY_BY_NUM=1
ENABLE_TRANSPARENT=1
TRANSPARENT_CHARACTER=0
TRANSPARENT_MODIFIERS=1
.include "modules/m_displayPETSCII.s"
.endscope

; be sure to match the scope name
.macro displayPETSCII addr
        ldax #addr
        m_run displayPETSCII
.endmacro

;Sprite control code

.scope playersprite
SPR_ADDR=SPR_BASE1
SPR_NUM=0
JOY_CONTROL=2     ;joystick port 2
MIN_Y=115
MAX_Y=240
MOV_DIRS=3        ;1+2 = enable control of directions up and down
MOV_SPEED_Y=1
ANIMATION_STATES=4
ANIMATION_DIRS=1
ANIMATION_DELAY=3
ANIMATE_ALWAYS=1
CONFIGURABLE_SPR_COSTUME=1
.include "m_spriteman.s"
.endscope

.scope spectator1
SPR_ADDR=SPR_BASE2
SPR_NUM=1
.include "m_spriteman.s"
.endscope

.scope spectator2
SPR_ADDR=SPR_BASE2+$c0
SPR_NUM=2
.include "m_spriteman.s"
.endscope

.scope spectator3
SPR_ADDR=SPR_BASE2+$100
SPR_NUM=3
.include "m_spriteman.s"
.endscope

.scope obstacle1
SPR_ADDR=SPR_BASE3
SPR_NUM=4
.include "m_spriteman.s"
.endscope

.scope obstacle2
SPR_ADDR=SPR_BASE3+$40
SPR_NUM=5
.include "m_spriteman.s"
.endscope

.scope obstacle3
SPR_ADDR=SPR_BASE3+$80
SPR_NUM=6
.include "m_spriteman.s"
.endscope

.scope obstacle4
SPR_ADDR=SPR_BASE3+$C0
SPR_NUM=7
.include "m_spriteman.s"
.endscope

;charset
.scope charset
EFFECT=0                ;Effects: 1 italic
                        ;         2 italic, including lower case
                        ;         3 bold
                        ;         4 bold, including lower case
                        ;         5 lower half bold
                        ;         6 lower half bold, including lower case
                        ;         7 thin
                        ;         8 thin, including lower case
.include "modules/m_copycharset.s"
.endscope

;-- end of modules, subroutines, and data ------------
;-----------------------------------------------------

over_it:
;-----------------------------------------------------
;-- init routines ------------------------------------

        ; self-destruct first part

        lda #0
        m_call displayPETSCII,set_transparent

        lda #0
        jsr MUSIC_BASE
        set_raster_irq 0,isr0

        poke 648,>SCREEN_BASE
        m_init charset


;-- end of init routines -----------------------------
;-----------------------------------------------------

title:
        m_run charset
        poke titlemode,1
        poke 53269,0

        displayPETSCII petsciiimg0
        wait_anykey_off_on

gamecode:
        ;init game
        displayPETSCII petsciiimg1
        memset $d800+9*40,$dbe7,9
        m_init playersprite
        m_call playersprite,show
        placesprite playersprite,120,150
        poke titlemode,0


        m_init spectator1
        placesprite spectator1,115,53
        m_call spectator1,show

        m_init spectator2
        placesprite spectator2,175,53
        m_call spectator2,show

        m_init spectator3
        placesprite spectator3,233,53
        m_call spectator3,show


        m_init obstacle1
        placesprite obstacle1,320,120
        m_call obstacle1,show

        m_init obstacle2
        placesprite obstacle2,350,145
        m_call obstacle2,show

        m_init obstacle3
        placesprite obstacle3,200,170
        m_call obstacle3,show

        m_init obstacle4
        placesprite obstacle4,390,185
        m_call obstacle4,show

        lda $D01E       ;reset sprite collision register

        ;game loop
        do
            sync_to_rasterline256

            do_every 10
                ldax playersprite::spriteX
                addax #1
                stax playersprite::spriteX
                cmpax #320
                jcs game_won
            end_every

            do_every 2
                ldax obstacle1::spriteX
                subax #1
                stax obstacle1::spriteX
                cmpax #1
                if cc
                    ldax #350
                    stax obstacle1::spriteX
                    lda playersprite::spriteY
                    sta obstacle1::spriteY
                endif
                m_call obstacle1,place_sprite
            end_every

            do_skip_every 3
            ldax obstacle2::spriteX
            subax #1
            stax obstacle2::spriteX
            cmpax #1
            if cc
                ldax #350
                stax obstacle2::spriteX
                lda playersprite::spriteY
                sta obstacle2::spriteY
            endif
            m_call obstacle2,place_sprite
            end_skip_every

            do_every 2
                ldax obstacle3::spriteX
                subax #1
                stax obstacle3::spriteX
                cmpax #1
                if cc
                    ldax #350
                    stax obstacle3::spriteX
                    lda playersprite::spriteY
                    sta obstacle3::spriteY
                endif
                m_call obstacle3,place_sprite
            end_every

            do_skip_every 3
            ldax obstacle4::spriteX
            subax #1
            stax obstacle4::spriteX
            cmpax #1
            if cc
                ldax #350
                stax obstacle4::spriteX
                lda playersprite::spriteY
                sta obstacle4::spriteY
            endif
            m_call obstacle4,place_sprite
            end_skip_every

.scope
            do_every 8
                lda SCREEN_BASE+8*40+20
                eor #$80      ;switch between checker board pattern and inverted checkboard pattern
                sta SCREEN_BASE+8*40+20
            end_every
.endscope

            lda $D01E
            and #1
            bne game_lost

            m_run playersprite
        loop
        rts

.proc game_won
        poke titlemode,2
        displayPETSCII petsciiimg3
        delay_ms 500
        delay_ms_abort_on_fire 10000
        jmp title
.endproc

.proc game_lost
        poke titlemode,2
        displayPETSCII petsciiimg2
        delay_ms 500
        delay_ms_abort_on_fire 10000
        jmp title
.endproc

