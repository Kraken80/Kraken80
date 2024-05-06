#include "../tools/ti84pce.inc"
#define SAFERAM pixelShadow2

; COMPILE
; ../tools/spasm64.exe troll.asm -E troll.8xp

	.org userMem-2
	.db tExtTok,tAsm84CeCmp
main:
	ld hl,hook
	ld de,SAFERAM
	push de
	ld bc,hook_end-hook_begin
	ldir
	pop hl
	
	call _SetParserHook
	
	;  ld a,1 ; page 1 - RAM
	; bcall(SetParserHook)
	; ld a,1 ; page 1 - RAM
	; enable hook
	;ld a,(iy+$36)
	;or a,$01
	;ld (iy+$36),a
	
	ret
	
hook:
	.org SAFERAM
hook_begin:
	.db $83
	cp a,1
	jr nz,end_routine_2
	; compare bytes
	push bc
	push de
	push hl
	ld hl,(begPC)
	ld de,compare
	ld b,4
_:
	ld a,(de)
	cp a,(hl)
	inc hl
	inc de
	jr nz,end_routine
	djnz -_
	
	; last byte must be $00 or $64
	ld a,(hl)
	or a,a
	jr z,+_
	cp a,$64
	jr nz,end_routine
_:
	; write +12 to OP1
	; (00 81 12 00 00 00 00 00 00 00 00)
	ld hl,OP1+2
	ld (hl),$12
end_routine:
	pop hl
	pop de
	pop bc
end_routine_2:
	cp a,a ; set zero flag
	ret
compare:
	.db $39,$70,$31,$30 ; 9+10
hook_end: