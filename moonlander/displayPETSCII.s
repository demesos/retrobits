;-----------------------------------------------
; PETSCII Decode and display
; to use, load address of compressed PETSCII img in A/X
; and call displayPETSCII:
;  lda #<petsciiimg5
;  ldx #>petsciiimg5
;  jsr displayPETSCII
;
; Version 1.2 June 2023
; Last changed: 2024-09-09 15:13:23
;-----------------------------------------------

.include "LAMAlib.inc"

        .export displayPETSCII

zpptr=_llzp_word1

;uncomment the following line to allow decoding from RAM $D000-$DFFF
;note that your IRQ must be able to handle an all RAM configuration or being turned off
;DECODE_FROM_D000=1

.macro disable_transparent
        lda #$c9        ;opcode CMP to overwrite BEQ
        sta ::_transparent_petscii_char +2
        sta ::_transparent_petscii_char2+2
.endmacro

.macro set_transparent screencode
        lda #screencode
        sta ::_transparent_petscii_char +1
        sta ::_transparent_petscii_char2+1
        lda #$f0        ;opcode BEQ
        sta ::_transparent_petscii_char +2
        sta ::_transparent_petscii_char2+2
.endmacro

displayPETSCII:
.ifndef DECODE_FROM_D000
DECODE_FROM_D000=0
.endif

decode_routine:
        .SCOPE
        sta zpptr
        stx zpptr+1
.if ::DECODE_FROM_D000=1
        lda $1
        pha
        poke 1,$34      ;all RAM configuration
.endif
        lda PTRSCRHI
        sta scr+2
        sta scr2+2
        lda #$d8
        sta colr+2
        sta colr2+2
        lda #0
        sta scr+1
        sta scr2+1
        sta colr+1
        sta colr2+1


        ldy #00
        lda (zpptr),y
.if ::DECODE_FROM_D000=1
        inc $1  ;enable I/O
.endif
        sta $D020
.if ::DECODE_FROM_D000=1
        dec $1  ;all RAM configuration
.endif
        iny
        lda (zpptr),y
.if ::DECODE_FROM_D000=1
        inc $1  ;enable I/O
.endif
        sta $D021
.if ::DECODE_FROM_D000=1
        dec $1  ;all RAM configuration
.endif
        and #$E0
        sta mrk+1
        sta mrk2+1
        lda #$E0
        sta zpptr+2
        lda #$10
        sta zpptr+3
        ;sta zpptr ; set zpptr
        ldx #00

loop1:
        iny
        bne skphi
        inc zpptr+1
skphi:  lda (zpptr),y

        ;is it a special char?
mrk:    eor #$E0
        bit zpptr+2
        beq special
mrk2:   eor #$E0

        ;skip writing if transparent char
::_transparent_petscii_char:
        cmp #00
        bcc skip_transparent
scr:    sta $400,x
col:    lda #00
.if ::DECODE_FROM_D000=1
        inc $1  ;enable I/O
.endif
colr:   sta $d800,x
.if ::DECODE_FROM_D000=1
        dec $1  ;all RAM configuration
.endif
skip_transparent:
        inx
        cpx #250
        bne loop1

        jsr updatetargetptrs

cnt0:
        jmp loop1

special:
        bit zpptr+3
        beq repcode
        ;color code
        ;lda (zpptr),y
        sta col+1
        sta col2+1
        jmp loop1

repcode:;lda (zpptr),y
        and #$0f
        beq exit_rts
        sta rep+1

        iny

        bne skphi2
        inc zpptr+1
skphi2: lda (zpptr),y
        sta loop2+1
        sty rcvy+1      ;save y for later

rep:    ldy #00
.if ::DECODE_FROM_D000=1
        inc $1  ;enable I/O
.endif
loop2:  lda #00

::_transparent_petscii_char2:
        cmp #00
        bcc skip_transparent2

scr2:   sta $400,x
col2:   lda #00
colr2:  sta $d800,x
skip_transparent2:
        inx
        cpx #250
        bne endofloop
        jsr updatetargetptrs

endofloop:
        dey
        bne loop2
.if ::DECODE_FROM_D000=1
        dec $1  ;all RAM configuration
.endif
rcvy:   ldy #00
        jmp loop1

updatetargetptrs:
        clc
        lda scr+1
        adc #250
        sta scr+1
        sta colr+1
        sta scr2+1
        sta colr2+1

        bcc endofsr

        inc colr+2
        inc colr2+2
        lda scr+2
        adc #00
        sta scr+2
        sta scr2+2
        and #7
        cmp #7
        bne endofsr

        pla     ;remove return address from stack
        pla     ;next rts ends displayPETSCII

.if ::DECODE_FROM_D000=1
        pla
        sta $1
.endif

endofsr:
        ldx #00

.if ::DECODE_FROM_D000=1
        rts
exit_rts:
        pla
        sta $1
        rts
.else
exit_rts:
        rts
.endif

        .ENDSCOPE
