; Moonlander Game
; by Wil
; One Hour Game Jam #454

.include "LAMAlib.inc"
.include "spritemacros.inc"
.include "wait_anykey_off_on.inc"

        .MACPACK cbm
        .MACPACK longbranch

.include "constants.inc"

        makesys 31," moonlander game"

begin_part_once:
        disable_NMI
        setSpriteMultiColor1 SPRMUCO1
        setSpriteMultiColor2 SPRMUCO2
        jmp over_it

;-----------------------------------------------------
;-- modules, subroutines, and data -------------------

        include_file_as "spr-moonlander.prg", sprites
THRUST_DOWN=((SPRITE_BASE & $3fc0) >> 6)+5
THRUST_RIGHT=((SPRITE_BASE & $3fc0) >> 6)+7
THRUST_LEFT=((SPRITE_BASE & $3fc0) >> 6)+8

end_part_once:

.scope landersprite
SPR_ADDR=SPRITE_BASE
CUSTOM_ANIMATIONS=1
.include "m_spriteman.s"
.endscope

.scope thrustsprite
SPR_ADDR=SPRITE_BASE+5*$40
SPR_NUM=1
.include "m_spriteman.s"
.endscope

.include "displayPETSCII.s"

.include "moonlander-petscii.asm"

;-- end of modules, subroutines, and data ------------
;-----------------------------------------------------

over_it:
;-----------------------------------------------------
;-- init routines ------------------------------------

install_file sprites,SPRITE_BASE

        set_transparent 0       ;make displayPETSCII interpret @ as transparent

;-- end of init routines -----------------------------
;-----------------------------------------------------

title:
        ldax #petsciiimg0
        jsr displayPETSCII
        poke 53269,0    ;hide all sprites
        lda $d01f       ;reset sprite-background-collision

        delay_ms_abort_on_fire 500
        do
            textcolor 7
            set_cursor_pos 12,11
            print "press fire to start"
            delay_ms_abort_on_fire 900
            bcc exit_title
            set_cursor_pos 12,11
            print "                   "
            delay_ms_abort_on_fire 900
        loop until cc
exit_title:
        poke lives,3

gamecode:
        ldax #petsciiimg1
        jsr displayPETSCII

        pokew vx,0
        pokew vy,0
        pokew finex,0
        pokew finey,0
        pokew fuel,FUEL

        pokew landersprite::spriteX,160
        poke  landersprite::spriteY,50
        m_call landersprite,place_sprite
        m_init landersprite
        m_call landersprite,show

        m_init thrustsprite
        m_call thrustsprite,hide

        jsr print_lives

        do
            ldy landersprite::spriteY
            cpy #MINY_COLLISION
            if cc
                spriteBeforeBackground 0
                lda $d01f   ;dummy read
            else
                spriteBehindBackground 0
                lda $d01f
                and #1
                if ne       ; we touched ground!
                    ldax vy
                    cmpax #MAXLANDINGSPEED
                    jpl crash
                    ldax landersprite::spriteX
                    cmpax #LANDINGX1
                    jcc crash
                    cmpax #LANDINGX2+1
                    jcs crash
                    jmp success
                endif
            endif

            poke thrust_action,0


            lda $dc00
            sta joyvalue
            lsr joyvalue
            if cc ;up
                lda fuel
                ora fuel+1
                if ne
                    poke thrust_action,THRUST_DOWN
                    dec16 fuel
                    ldax vy
                    subax #THRUST
                    stax vy
                endif
            endif
            lsr joyvalue ;no action for down
            lsr joyvalue
            if cc ;left
                lda fuel
                ora fuel+1
                if ne
                    lda thrust_action
                    if eq
                        poke thrust_action,THRUST_LEFT
                    endif
                    dec16 fuel
                    dec16 vx
                endif
            endif
            lsr joyvalue
            if cc ;left
                lda fuel
                ora fuel+1
                if ne
                    lda thrust_action
                    if eq
                        poke thrust_action,THRUST_RIGHT
                    endif
                    dec16 fuel
                    inc16 vx
                endif
            endif
          ;lsr joyvalue ;no action for fire button

        ;physics
            ldax vy
            addax #GRAVITY
            stax vy

            ldax finey
            addax vy
            cpx #0
            if ne
                if pl
loop1:
                    inc landersprite::spriteY
                    dex
                    bne loop1
                else
loop2:
                    dec landersprite::spriteY
                    inx
                    bne loop2
                endif
            endif
            stax finey

            ldax finex
            addax vx
            cpx #0
            if ne
                if pl
loop3:
                    inc16 landersprite::spriteX
                    dex
                    bne loop3
                else
loop4:
                    dec16 landersprite::spriteX
                    inx
                    bne loop4
                endif
            endif
            stax finex

            m_run landersprite
            m_call landersprite,place_sprite

            ldax landersprite::spriteX
            stax thrustsprite::spriteX
            lda landersprite::spriteY
            sta thrustsprite::spriteY

            ldx thrust_action
            if eq
                m_call thrustsprite,hide
            else
                m_call thrustsprite,show
                cpx #THRUST_DOWN
                if eq
                    inc animation
                    lda animation
                    lsr
                    lsr
                    lsr
                    if cs
                        inx
                    endif
                    setSpriteCostume 1,X
                    inc thrustsprite::spriteY
                    inc thrustsprite::spriteY
                    inc thrustsprite::spriteY
                else
                    setSpriteCostume 1,X
                endif
                m_call thrustsprite,place_sprite
                m_call thrustsprite,show
            endif

            sync_to_rasterline256
        loop
        rts

crash:
        m_call thrustsprite,hide

        lda #((SPRITE_BASE & $3fc0) >> 6)
        ldx #5
        m_call landersprite,play_animation

        do
            m_call landersprite,run
            sync_to_rasterline256
            lda landersprite::playing_animation
        loop until eq  ;animation just finished

        dec lives
        if eq
            jsr print_lives
            ldax #petsciiimg2
            jsr displayPETSCII
            delay_ms_abort_on_fire 5000
            jmp title
        else
            delay_ms 500
            jmp gamecode
        endif

success:
        m_call thrustsprite,hide
        delay_ms 1000
        ldax #petsciiimg3
        jsr displayPETSCII
        delay_ms_abort_on_fire 5000
        jmp title

.proc print_lives
        textcolor 7
        set_cursor_pos 0,32
        lda lives
        print "lives:",A
        rts
.endproc

lives:
        .byte 3
animation:
        .byte 0
joyvalue:
        .byte 0
vx:
        .byte 0,0
vy:
        .byte 0,0
finex:
        .byte 0,0
finey:
        .byte 0,0
fuel:
        .byte 0,0
thrust_action:
        .byte 0

