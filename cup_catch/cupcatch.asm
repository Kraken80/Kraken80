#include "ti83plus.inc"

; COMPILE
; spasm cupcatch.asm cupcatch.bin
; ../postprocess cupcatch.bin cupcatch.8xp CUPCATCH

#define APD_SAFE $86EC ; 768 bytes, to 89EC

#define CUP_POSITION APD_SAFE

#define BALL_X APD_SAFE+1
#define BALL_X_VEL APD_SAFE+2 ; 2 bytes 
#define BALL_X_TMP APD_SAFE+4

#define BALL_Y APD_SAFE+5
#define BALL_Y_VEL APD_SAFE+6 ; 2 bytes
#define BALL_Y_TMP APD_SAFE+8

#define NUM_WINS APD_SAFE+9

#define CUP_SPEED 3

	.org $9D93
	.db $BB,$6D
	
	ld a,R ; random seed using dram refresh
	ld b,a
_:
	call random
	djnz -_
	
	; take register B as a seed
	
	bcall(_RunIndicOff)
	bcall(_grbufclr)
	
	ld a,32
	ld (CUP_POSITION),a
	;call draw_sprites_no_redraw_ball ; draw for the first time
	
	xor a
	ld (NUM_WINS),a
	
serve:
	;serve ball
	ld a,45
	ld (BALL_X),a
	; ld a,45
	ld (BALL_Y),a
	
	call random
	ld a,h
	or %10000000
	ld h,a
	; or a
	rr h
	rr l
	or a
	rr h
	rr l
	ld c,75
	call divide_hl_by_c
	ex de,hl
	call random
	rl h
	ex de,hl
	jp pe,+_
	call neg_hl ; 50 / 50 it goes left instead of right
_:
	ld (BALL_X_VEL),hl
	
	call random
	ld c,235
	call divide_hl_by_c
	ld de,1000
	add hl,de
	call neg_hl
	ld (BALL_Y_VEL),hl
	
	ld a,(BALL_X)
	ld d,a
	ld a,(BALL_Y)
	ld e,a
	ld hl,ball
	
	call draw_sprites ; draw for first time
	
game_loop:

	call draw_sprites ; undraw sprites
	
	call random
	
; check ball
	ld a,(BALL_Y)
	; is 48 < A < 128
	cp 48
	jr c,skip_range_check
	rla ; checking if A is over 127
	jr c,skip_range_check
	
	; range check
	ld a,(BALL_X)
	ld bc,(CUP_POSITION) ; only c is loaded with data we want
	add a,4 ; ball hits left lid
	sub c
	; if negative, fail
	jp m,fail
	cp 12 + 2 +1; ball hits right lid or in cup
	jr nc,fail
	jr success
fail:
	bcall(_HomeUp)
	ld hl,failure_message
	bcall(_PutS)
	ret
success:
	ld a,(NUM_WINS)
	inc a
	cp 5
	jr z,win
	ld (NUM_WINS),a
	;call draw_sprites_no_redraw_ball
	; delete cup so that it will redraw the cup and not redraw the ball
	jp serve
win:
	bcall(_HomeUp)
	ld hl,win_message
	bcall(_PutS)
	ret
skip_range_check:
	
	ld a,$FD
	out ($01),a
	nop ; delay
	nop
	in a,($01)
	bit 6,a
	ret z ; checking for CLEAR key
	
	; move cup
	ld a,$FE
	out ($01),a
	nop ; delay
	nop
	in a,($01)
	ld de,CUP_POSITION ; de used as ptr to CUP_POSITION
	cp $FD
	jr nz,++_
	call random
	ld a,(de) ; its ok that A is clobbered here
	sub a,CUP_SPEED
	jp p,+_
	xor a ; ld a,0
_:
	ld (de),a
_:
	cp $FB
	jr nz,++_
	call random
	call random
	ld a,(de)
	add a,CUP_SPEED
 	cp 88 ; we halt one step at 87
	jr c,+_
	ld a,87
_:
	ld (de),a
_:

	; move ball
	; basically
	; BALL_X += BALL_X_VEL_H
	; BALL_X_TMP += BALL_X_VEL_L
	; IF CARRY, BALL_X++
	ld bc,(BALL_X) ; only c is loaded with X
	ld hl,(BALL_X_VEL)
	ld a,(BALL_X_TMP) ; only a is loaded with TMP
	
	call process_vel
	; ld (BALL_X), c
	; ld (BALL_X_VEL), l
	; ld (BALL_X_VEL+1), h
	; ld (BALL_X_TMP), b
	ld (BALL_X),bc
	ld (BALL_X_VEL),hl
	ld a,b
	ld (BALL_X_TMP),a
	
	;same thing with Y
	ld bc,(BALL_Y)
	ld hl,(BALL_Y_VEL)
	ld a,(BALL_Y_TMP)
	
	call process_vel
	ld de,50
	add hl,de ; gravity
	
	ld (BALL_Y),bc
	ld (BALL_Y_VEL),hl
	ld a,b
	ld (BALL_Y_TMP),a
	
	
	
	; end of move ball
	
	call draw_sprites ; re-draw

	bcall(_GrBufCpy)
	;halt
	;halt
	
	jp game_loop
	;ret
	
; DESTROY: a (a is perserved in b), bc
process_vel:
	add a,l
	jr nc,+_
	inc c
_:
	ld b,a ; perserve A
	ld a,c
	add a,h
	ld c,a
	ret
	
draw_sprites:
	ld a,(BALL_X)
	ld d,a
	ld a,(BALL_Y)
	ld e,a
	ld hl,ball
	call draw_sprite
draw_sprites_no_redraw_ball:
	ld a,(CUP_POSITION)
	ld d,a
	ld e,51
	ld hl,cup
	call draw_sprite
	ret

; serve_ball:
; 	ld a,45
; 	ld (BALL_X),a
; 	ld a,45
; 	ld (BALL_Y),a
; 	
; 	call random
; 	ld a,h
; 	or %10000000
; 	ld h,a
; 	or a
; 	rr h
; 	rr l
; 	or a
; 	rr h
; 	rr l
; 	ld c,75
; 	call divide_hl_by_c
; 	ex de,hl
; 	call random
; 	rl h
; 	ex de,hl
; 	jp pe,+_
; 	call neg_hl ; 50 / 50 it goes left instead of right
; _:
; 	ld (BALL_X_VEL),hl
; 	
; 	call random
; 	ld c,235
; 	call divide_hl_by_c
; 	ld de,1000
; 	add hl,de
; 	call neg_hl
; 	ld (BALL_Y_VEL),hl
; 	
; 	ld a,(BALL_X)
; 	ld d,a
; 	ld a,(BALL_Y)
; 	ld e,a
; 	ld hl,ball
; 	call draw_sprite ; draw for first time
; 	ret

;INPUTS: hl
;OUTPUTS: hl two's complement negative
;DESTROYS: A
neg_hl:
	ld a,h
	cpl
	ld h,a
	ld a,l
	cpl
	ld l,a
	inc hl
	ret
	
; INPUTS: hl as dividend, c as divisor
; OUTPUTS: hl = quotient, a = remainder
; DESTROYS: bc
divide_hl_by_c:
	xor a
	ld b,16
_:
	add hl,hl
	rla
	cp c
	jr c,+_
	sub c
	inc l
_:
	djnz --_
	ret
; taken from https://map.grauw.nl/sources/external/z80bits.html#4.2
; and edited slightly
; OUTPUT: random number in hl
; DESTROYS: none
random:
	push af
	push de
random_SMC:
	ld de,0 ; SMC
	ld a,d
	ld h,e
	ld l,253
	or a
	sbc hl,de
	sbc a,0
	sbc hl,de
	ld d,0
	sbc a,d
	ld e,a
	sbc hl,de
	jr nc,+_
	inc hl
_:
	ld (random_SMC+1),hl
	pop de
	pop af
	ret

;INPUTS: h = X-coord, l = Y-coord
;OUTPUT: hl = memory location
;DESTROYS: a
get_xy:
	;hl = l*12 + h/8 + PlotSScreen
	ld a,l
	add a,l ; 2l
	add a,l ; 3l
	ld l,a
	ld a,h
	rra
	rra
	rra
	and %00011111
	ld h,0
	add hl,hl ; 6l
	add hl,hl ; 12l
	push de
	ld de,PlotSScreen ; +PlotSScreen
	add hl,de
	pop de
	add a,l ; +h/8
	ld l,a
	ret nc
	inc h
	ret

; INPUTS: hl = sprite, d = X-coord, e = Y-coord
; DESTROYS: a, bc, de, hl
draw_sprite:
	ld a,e
	cp 53
	ret nc ; don't draw

	ld b,(hl)
	inc hl
	ld a,d
	and %00000111
	inc a
	ld c,a
	ex de,hl
	call get_xy
	; de = sprite pointer
	; hl = screen pointer
row:
	push bc
	ld b,c
	ld a,(de)
	ld c,0
	or a ; clear carry flag
	
	; we shift left once because B is actually 1 over
	; the amount of times we want to shift right
	; this is to fix 256 shift rights when B=0
	rl c
	rla
	; critical bit placed in the carry flag
_:
	rra
	rr c
	djnz -_
	
	xor (hl)
	ld (hl),a
	inc hl
	ld a,c
	xor (hl)
	ld (hl),a
	
	ld c,12 - 1 ; b is already zero right now
	add hl,bc
	inc de
	
	pop bc
	djnz row
	ret
	
; spike:
; 	.db 6
; 	.db %00101000
; 	.db %00011010
; 	.db %01111100
; 	.db %00111110
; 	.db %01011000
; 	.db %00010100
ball:
	.db 6
	.db %00011000
	.db %00100100
	.db %01000010
	.db %01000010
	.db %00100100
	.db %00011000
cup:
	.db 12
	.db %00111100
	.db %01000010
	.db %10000001
	.db %11000011
	.db %10111101
	.db %10000001
	.db %10000001
	.db %11000011
	.db %01000010
	.db %01000010
	.db %01000010
	.db %00111100
	
failure_message:
.db "You lose",$00
win_message:
.db "You win",$00

; #define NUM_ROWS 63
; lcd_delay:
; 	push af
; 	call $000B ; should make the delay. might destroy A?
; 	pop af
; 	ret
; DESTROYS: a, bc, de, hl
; lcd_copy:
; 	di
; 	ld hl,12*(63-NUM_ROWS) + PlotSScreen
; 	ld a,$80 + 63-NUM_ROWS
; 	out ($10),a ; set row
; 	ld c,$1F ; c holds column
; _:
; 	inc c
; 	ld a,c
; 	cp $2C
; 	jr z,++_ ; return if c == $2C
; 	call lcd_delay
; 	out ($10),a ; set column
; 	ld b,NUM_ROWS
; 	ld de,12
; _:
; 	ld a,(hl)
; 	call lcd_delay
; 	out ($11),a
; 	add hl,de
; 	djnz -_
; 	
; 	call lcd_delay
; 	ld a,$80 + 63-NUM_ROWS
; 	out ($10),a	; set row
; 	ld de,-12*NUM_ROWS + 1 ; shift over one column
; 	add hl,de
; 	jr --_
; _:
; 	ei
; 	ret
