.macro wait_anykey_off_on	;poor man's version, only joystick movements and some keys (including space) work
:	lda $dc00
	and $dc01
	cmp #$7f
	bne :-
:	lda $dc00
	and $dc01
	cmp #$7f
	beq :-
.endmacro