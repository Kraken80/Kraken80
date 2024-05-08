.MEMORYMAP
DEFAULTSLOT 0
SLOT 0 START $C000 SIZE $4000 NAME "ROM"
SLOT 1 START $0000 SIZE $2000 NAME "CHR"
.ENDME

.ROMBANKMAP
BANKSTOTAL 2
BANKSIZE $4000
BANKS 1
BANKSIZE $2000
BANKS 1
.ENDRO

PPU_CTRL = $2000
PPU_MASK = $2001
PPU_STATUS = $2002
PPU_SCROLL = $2005
PPU_ADDR = $2006
PPU_WRITE = $2007
PPU_DMA_LOW = $2003
PPU_DMA_START_TRANSFER = $4014
CONTROLLER_1_PORT = $4016
CONTROLLER_2_PORT = $4017

CONTROLLER_1 = $E0 ; (A, B, Select, Start, Up, Down, Left, Right) as bits
CONTROLLER_2 = $E1
X_SCROLL_LOW = $E2
X_SCROLL_HIGH = $E3
Y_SCROLL = $E4
ENTITY_SLOT_ITER = $E9

PLAYER_GRAPHICS = $A1
PLAYER_X_SUBPIXEL = $A2
PLAYER_X = $A3
PLAYER_Y_SUBPIXEL = $A4
PLAYER_Y = $A5

FIRST_ROOM_PROGRESS = $F1

ROOM = $0300 ; to $03DF. Each row is 16 bytes, with 14 rows
DOOR_NORTH = $0400
DOOR_SOUTH = $0402
DOOR_EAST = $0404
DOOR_WEST = $0406

DISABLE_INTERRUPTS = $0407

ENTITY_SLOTS = $A0 ; 8 slots, to $DF
; first slot is always the player
; 8 bytes per slot
; [0] = id ; (first two bits of ID may be converted to additional data)
; [1] = additional data (last 4 bits = animationState)
; [2:3] = x
; [4:5] = y
; [6] = additional data
; [7] = additional data

CHR_BLANK = $0A
TILE_AIR = $00
TILE_BRICK = $01

APU_FLAGS = $4015

; 	.inesprg 1   ; 1x 16KB PRG code
; 	.ineschr 1   ; 1x  8KB CHR data
; 	.inesmap 0   ; mapper 0 = NROM, no bank swapping
; 	.inesmir 1   ; background mirroring

	; .prg 0
	.bank 0 slot 0
	.orga $C000
	; code
RESET:
	SEI          ; disable IRQs
  	CLD          ; disable decimal mode
  	LDX #$40
  	STX $4017    ; disable APU frame IRQ
  	LDX #$FF
  	TXS          ; Set up stack
 	INX          ; now X = 0
  	STX PPU_CTRL    ; disable NMI
  	STX PPU_MASK    ; disable rendering
  	STX $4010    ; disable DMC IRQs
	
	LDA #%00001111
	STA APU_FLAGS ; enable sound
	LDA #$FF
	STA $400F

	JSR vblank_wait ; First wait for vblank to make sure PPU is ready

clrmem:
	LDA #$00
	STA $00, x
	STA $0100, x
	STA $0300, x
	STA $0400, x
	STA $0500, x
	STA $0600, x
	STA $0700, x
	LDA #$FE
	STA $0200, x
	INX
	BNE clrmem
   
	; init some RAM 
	LDA #1
	STA $A0 ; place player in slot 0
; 	LDA #$40
; 	STA PLAYER_X
; 	LDA #$40
; 	STA PLAYER_Y
  
  
	LDA #2
	STA $10
; 	LDA #$40
; 	STA $13
; 	LDA #$60
; 	STA $15
	JSR place_new_entity ; placed in slot 1
	
	JSR reset_player_and_ghost_position
  
	JSR vblank_wait ; Second wait for vblank, PPU is ready after this
	
; 	LDA #%10000000
; 	STA $2001
	
	; set PPU address
	LDA PPU_STATUS ; read PPU status to reset the high/low latch
	LDA #$3F
	STA PPU_ADDR
	LDA #$10
	STA PPU_ADDR
	
	LDX #$00
load_pallete_loop:
	LDA.w color_palette, x
	STA PPU_WRITE
	INX
	CPX #32
	BNE load_pallete_loop
	
	; copy from level_1 to $0300, $D0 bytes
	; LDX #$00
; -:
	; LDA.w level_1, x
	; STA $0300, x
	; INX
	; CPX #$D0
	; BNE -
	
	LDA #(level_1 & $00FF)
	STA LEVEL_PTR+0
	LDA #(level_1 & $FF00) >> 8
	STA LEVEL_PTR+1
	
	JSR load_level
	JSR load_level_to_ppu
	
; 	LDA #$00
; 	STA $10
; 	LDA #$80
; 	STA $11
; 	STA $12
; 	
; 	JSR draw_sprite
	
; 	LDA #$80
; 	STA $0200        ; put sprite 0 in center ($80) of screen vert
; 	STA $0203        ; put sprite 0 in center ($80) of screen horiz
; 	LDA #$00
; 	STA $0201        ; tile number = 0
; 	STA $0202        ; color = 0, no flipping

	LDA #%10010000 ; enable V-blank interrupt, sprites on pattern table 0, bg on pattern table 1, autoincrement of 1
	STA PPU_CTRL
	
	LDA #%00011110 ; enable sprites, enable background, show left 8 pixels
	STA PPU_MASK

forever:
	JMP forever
	JMP forever
	

LEVEL_PTR = $0A
LOAD_PTR_HIGH = $0F
LOAD_PTR_LOW = $0E
TILE_STACK = $0C

	; INPUT: $0A:$0B = level pointer
load_level:
	LDA #0
	STA TILE_STACK
	STA LOAD_PTR_HIGH
	STA LOAD_PTR_LOW
	
	; copy eight bytes to $0400 from LEVEL_PTR, LEVEL_PTR += 8
	LDY #7
-:
	LDA [LEVEL_PTR], Y
	STA $0400, Y
	DEY
	BPL -
	
	LDA LEVEL_PTR+0
	CLC
	ADC #8
	STA LEVEL_PTR+0
	BCC +
	INC LEVEL_PTR+1
+:
	
load_level_loop:
	JSR read_bit
	BCS +
	; if zero, place block
	LDX TILE_STACK
	LDA #1
	JSR place_block
	JMP load_level_loop
+:
	; if one...
	JSR read_bit
	BCS +
	; if 10, place air
	LDA #0
	JSR place_block
	JMP load_level_loop
+:
	LDX #4
get_four_bits_loop:
	JSR read_bit
	ROL $01
	DEX
	BNE get_four_bits_loop
	LDA $01
	AND #$0F
	; CMP #0
	BNE +
	RTS ; action zero - end loading
+:
	CMP #1
	BNE skip_16_byte_copy_loop
	; action one - copy last 16 bytes
	LDY #16
	LDX TILE_STACK
-:
	LDA $02F0, x
	STA $0300, x
	INX
	DEY
	BNE -
	STX TILE_STACK
	JMP load_level_loop
skip_16_byte_copy_loop:
	; ADC #0 ; block placing
	JSR place_block
	JMP load_level_loop
	

; INPUT: A = which block 
place_block:
	LDX TILE_STACK
	STA $0300, X
	INC TILE_STACK
	RTS
	
	; carry clear = bit reset
	; carry set = bit set
read_bit:
	JSR peek_bit
	JSR advance_read_head
	RTS
	
	; carry clear = bit reset
	; carry set = bit set
peek_bit:
	; preserve registers
	; STA $03
	STX $04
	; STY $05
	LDA LOAD_PTR_LOW
	AND #$07
	TAX
	INX
	LDA LOAD_PTR_HIGH
	STA $00
	LDA LOAD_PTR_LOW
	LSR $00
	ROR A
	LSR $00
	ROR A
	LSR $00
	ROR A
	TAY
	LDA [LEVEL_PTR], y
-:
	LSR A
	DEX
	BNE -
	; LDA $03
	LDX $04
	; LDY $05
	RTS

advance_read_head:
	INC $0E
	BNE +
	INC $0F
+:
	RTS
	
entity_update:
	LDX ENTITY_SLOT_ARRAY_OFFSET
	LDA ENTITY_SLOTS+0, x
	ASL A
	TAX
	LDA.w entity_update_vector_table+0, x
	STA $00
	LDA.w entity_update_vector_table+1, x
	STA $01
	JMP ($0000)
	
grunt_update:
	; if playerX > selfX increase X
	; if playerX <= selfX decrease X
	LDA #3
	STA $00
	LDA #0
	JSR move_toward_player
	LDA #1
	STA $00
	LDA #2
	JSR move_toward_player
	RTS

; if Y = 0, move X, if Y = 2, move Y
; $00 = speed
move_toward_player:
	TAY
	CLC
	ADC ENTITY_SLOT_ARRAY_OFFSET
	TAX
	LDA ENTITY_SLOTS+3, x
	CMP PLAYER_X, y
	BCS +
	CLC
	ADC $00
	JMP ++
+:
	SEC
	SBC $00
++:
	STA ENTITY_SLOTS+3, x
	RTS
	
no_update:
	RTS
	
player_update:
	JSR clear_low_zpg
	
	LDA CONTROLLER_1
	
	LSR A ; right
	BCC skip_set_x_dir_1
	INC $00
skip_set_x_dir_1:

	LSR A ; left
	BCC skip_set_x_dir_minus_1
	DEC $00
skip_set_x_dir_minus_1:

	LSR A ; down
	BCC skip_set_y_dir_1
	INC $02
skip_set_y_dir_1:
	
	LSR A ; up
	BCC skip_set_y_dir_minus_1
	DEC $02
skip_set_y_dir_minus_1:
	; calculate magnitude
	
	; if both are zero, zero magnitude
	LDA $00
	ORA $02
	BEQ set_0_magnitude
	LDA $00
	EOR $02
	LSR A
	BCC set_sqrt2_2_magnitude
	; BCS set_1_magnitude
set_1_magnitude: ; orthogonal movement
	LDA #$00
	STA $04
	LDA #$02
	STA $05
	JMP end_set_magnitude
set_sqrt2_2_magnitude: ; diagonal movement in each direction
	LDA #$6A
	STA $04
	LDA #$01
	STA $05
	JMP end_set_magnitude
set_0_magnitude: ; no movement
	LDA #$00
	STA $04
	STA $05
	; JMP end_set_magnitude
end_set_magnitude:
	; preserve directions
	LDA $02
	STA $07
	LDA $00
	STA $06
	
	; LDA $06
	; CMP #0
	BEQ +
	ROL A ; set A to high bit of A
	ROL A
	AND #1
	EOR #1
	STA PLAYER_GRAPHICS
+:

	; copy
	LDA $04
	STA $00
	STA $02
	LDA $05
	STA $01
	STA $03
	
	; negate if needed
	LDX #$00
	LDA $06
	JSR apply_dir_to_16_bit_magnitude
	LDX #$02
	LDA $07
	JSR apply_dir_to_16_bit_magnitude
	
	; add to player position
	CLC
	LDA PLAYER_X_SUBPIXEL
	ADC $00
	STA PLAYER_X_SUBPIXEL
	LDA PLAYER_X
	ADC $01
	STA PLAYER_X
	
	CLC
	LDA PLAYER_Y_SUBPIXEL
	ADC $02
	STA PLAYER_Y_SUBPIXEL
	LDA PLAYER_Y
	ADC $03
	STA PLAYER_Y
	
	; now, check for screen transistion
	; if x < 8, go west
	; if x > 256-8, go east
	; if y < K+8, go north
	; if y > 256-K-8, go south
	
	LDY #0
	; LDA PLAYER_Y
	CMP #(16+8)
	BCS +
	LDA #(256-32-8)-2
	STA PLAYER_Y
	; set north
	LDA.w DOOR_NORTH+0
	LDX.w DOOR_NORTH+1
	JMP change_screens
+:
	INY
	CMP #(256-32-8+1)
	BCC +
	LDA #(16+8)+2
	STA PLAYER_Y
	LDA.w DOOR_SOUTH+0
	LDX.w DOOR_SOUTH+1
	JMP change_screens
+:
	INY
	LDA PLAYER_X
	CMP #(4)
	BCS +
	LDA #(256-16+1)-2
	STA PLAYER_X
	LDA.w DOOR_WEST+0
	LDX.w DOOR_WEST+1
	JMP change_screens
+:
	INY
	CMP #(256-16+1)
	BCC +
	LDA #(4)+2
	STA PLAYER_X
	LDA.w DOOR_EAST+0
	LDX.w DOOR_EAST+1
	JMP change_screens
+:
	JMP no_change_screens
change_screens:
	STA LEVEL_PTR+0
	STX LEVEL_PTR+1
	
	; if level pointer = level 1
	CMP #(level_1 & $00FF) ; first check low byte
	BNE +
	CPX #(level_1 & $FF00) >> 8
	BNE +
	; y = door entered
	; TODO
	; if MAZE_ROOM_PROGRESS = 0 and y = 2, advance
	; if MAZE_ROOM_PROGRESS = 1 and y = 0, advance
	; if MAZE_ROOM_PROGRESS = 2 and y = 3, advance
	; if MAZE_ROOM_PROGRESS = 3 and y = 1, set level pointer to different room
	
+:
	
	JSR vblank_wait
	
	JSR load_level_full

	LDA PLAYER_X
	LDX PLAYER_Y
	STA OLD_X
	STX OLD_Y
no_change_screens:
	RTS

	; INPUT: $10:$17 as sprite
	; OUTPUT: carry flag set if despawned
place_new_entity:
	CLC
	LDA #0
search_loop:
	; search ENTITY_SLOTS for place to put it
	TAX
	LDY ENTITY_SLOTS, x
	; CPX #0
	BEQ found_empty_slot
	ADC #8
	CMP #$40
	BNE search_loop
	; did not find empty slot - despawn
	SEC
	RTS
found_empty_slot:
	TAY
	LDX #0
copy_entity_to_slots_loop:
	LDA $10, x
	STA ENTITY_SLOTS, y
	INX
	INY
	CPX #8
	BNE copy_entity_to_slots_loop
	; CLC
	RTS

; sets all $00 to $0F to zero
clear_low_zpg:
	LDX #$00
	TXA
-:
	STA $00, x
	INX
	CPX #$10
	BNE -
	RTS
	
draw_blank_strip:
	LDX #64
	LDA #CHR_BLANK
-:
	STA PPU_WRITE
	DEX
	BNE -
	RTS
	
load_level_to_ppu:
	LDA PPU_STATUS ; read PPU status to reset the high/low latch
	LDA #$20
	STA PPU_ADDR
	LDA #$00
	STA PPU_ADDR
	
	JSR draw_blank_strip
	
	JSR clear_low_zpg
	
load_level_ppu_loop:
	; $04:$05 = loop counter
	
	LDA #0
	STA $03
	
	; $06 = (loop counter & 16 == 16) * 2
	LDA $04
	AND #$10
	LSR A
	LSR A
	LSR A
	STA $06
	
	; X = (loop counter FEDC BA98 7654 3210) => (X 8765 3210)
	LDA $05
	LSR A
	LDA $04
	ROR A
	AND #$F0
	STA $07
	LDA $04
	AND #$0F
	ORA $07

	TAX
	LDA $0300, x ; get tile
	
	ASL A
	ROL $03
	ASL A
	ROL $03
	ADC #(tile_composition & $00FF)
	STA $02
	LDA $03
	ADC #(tile_composition >> 8)
	STA $03
	
	; $02:$03 = 16-bit pointer to the 4 tiles making up the meta-tile
	
	LDY $06
	LDA [$02], y
	STA PPU_WRITE
	INY
	LDA [$02], y
	STA PPU_WRITE
	
	; add 1 to 16 bit counter
	INC $04
	BNE +
	INC $05
+:

	; cmp loop_counter, (480 - 64)
	LDA $04
	CMP #$A0
	BNE load_level_ppu_loop
	LDA $05
	CMP #$01
	BNE load_level_ppu_loop
	
	JSR draw_blank_strip
	
	JSR clear_low_zpg
load_level_ppu_attrib_loop:
	; $04 = loop counter
	; X = (loop counter 7654 3210) -> (X 543z 210z)
	LDA $04
	ASL A
	AND #$0E
	STA $06
	LDA $04
	ASL A
	ASL A
	AND #$E0
	ORA $06
	TAX
	
	JSR add_to_attribute_block
	INX
	JSR add_to_attribute_block
	; add x,16
	TXA
	EOR #$11
	TAX
	JSR add_to_attribute_block
	INX
	JSR add_to_attribute_block
	
	LDA $05
	STA PPU_WRITE
	
	INC $04
	LDA $04
	CMP #64
	BNE load_level_ppu_attrib_loop
	
	RTS
	
add_to_attribute_block:
	LDA $02F0, x ; get tile
	TAY
	LDA.w tile_palettes, y ; get pallete for that tile
	
	LSR A
	ROR $05
	LSR A
	ROR $05
	
	RTS

	; $F0 and $F1 as "sprite stack pointer"
	; input: ENTITY_SLOT_ARRAY_OFFSET properly set
	; clobbers $00, $01, $02, $03, $04
draw_entity:
	; animation_set_table
	
	; sprite data table entry = animation_set_table[spriteID]
	
	; alternative routine for if more than 128 animation sets
; 	LDA $10
; 	
; 	ASL A
; 	ROL $01
; 	
; 	CLC
; 	ADC #(animation_set_table & $00FF)
; 	STA $00
; 	LDA $01
; 	ADC #((animation_set_table & $FF00) >> 8)
; 	STA $01
	
	; set $10 and $11 as ptr to sprite data
	LDX ENTITY_SLOT_ARRAY_OFFSET
	LDA ENTITY_SLOTS+0, x ; ID
	; CMP #0
	BNE +
	RTS
+:
	ASL A
	STA $00
	LDA ENTITY_SLOTS+3, x ; X
	STA $12
	LDA ENTITY_SLOTS+5, x ; Y
	STA $13
	LDA ENTITY_SLOTS+1, x ; animation set
	AND #$0F
	ASL A
	TAY ; STA $00
	LDX $00	; LDA ENTITY_SLOTS+0, x ; ID
			; ASL A
			; TAX
	LDA.w animation_set_table, x
	STA $02
	LDA.w animation_set_table+1, x
	STA $03

	; LDY $00
	LDA [$02], y
	STA $10
	INY
	LDA [$02], y
	STA $11
	
	; input: $10:$11 as pointer to sprite, $12 and $13 as sprite X and Y
draw_sprite:
	
	; tablePtr = tablePtr - $F0
	LDA $10
	SEC
	SBC $F0
	BCS +
	DEC $11
+:
	STA $10
	; Y = $F0
	LDY $F0
	
	LDA [$10], y
	TAX
	
	; $F0 = $F0 + #(X*4)
	ASL A
	ASL A
	; CLC
	ADC $F0
	STA $F0
	
	; tablePtr = tablePtr + 1
	INC $10
	BNE +
	INC $11
+:
	
	
draw_sprite_loop:
	LDA [$10],Y
	CLC
	ADC $13 ; add Y
	STA $0200,Y
	INY
	
	LDA [$10],Y
	STA $0200,Y
	INY
	
	LDA [$10],Y
	STA $0200,Y
	INY
	
	LDA [$10],Y
	CLC
	ADC $12 ; add X
	STA $0200,Y
	INY
	
	DEX
	BNE draw_sprite_loop
	RTS
	
	; INPUT: if X = 0, reads controller 1. if X = 1, reads controller 2
	
	; (CONTROLLER_1_PORT gives A, B, Select, Start, Up, Down, Left, Right when read)
	; (bit zero gives you the status of that button)
	
	; OUTPUT:
	; (A, B, Select, Start, Up, Down, Left, Right) as bits in CONTROLLER_1 and CONTROLLER_2
read_controller_port:
	LDA #$00
	STA <CONTROLLER_1,x
	LDY #$08
controller_port_read_loop:
	LDA CONTROLLER_1_PORT,x
	LSR A
	ROL <CONTROLLER_1,x
	DEY
	BNE controller_port_read_loop
	RTS
	
vblank_wait:
	BIT PPU_STATUS
	BPL vblank_wait
	RTS
	
apply_dir_to_16_bit_magnitude:
	BEQ set_magnitude_zero
	BPL + ; do nothing
	; negate magnitude
	LDA $00, x
	EOR #$FF
	STA $00, x
	LDA $01, x
	EOR #$FF
	STA $01, x
	
	INC $00, x
	BNE +
	INC $01, x
+:
	RTS
set_magnitude_zero:
	LDA #$00
	STA $00, x
	STA $01, x
	RTS
	
; allow_movement:
; 	LDX ENTITY_SLOT_ARRAY_OFFSET
	; store collision box in position 
;	LDA COLL_BOX_X_POSITION
;	STA ENTITY_SLOTS+3, x
;	LDA COLL_BOX_Y_POSITION
;	STA ENTITY_SLOTS+5, x
	
	; LDA ENTITY_SLOTS+3, x
	; STA ENTITY_SLOTS+6, x
	; LDA ENTITY_SLOTS+5, x
	; STA ENTITY_SLOTS+7, x
;	RTS
	
ENTITY_SLOT_ARRAY_OFFSET = $E5
SIZE_TABLE_OFFSET = $E6

COLL_BOX_X_POSITION = $0C
COLL_BOX_Y_POSITION = $0D
HORIZONTAL_MOVE_LEGAL = $0E
VERTICAL_MOVE_LEGAL = $0F
OLD_X = $E7
OLD_Y = $E8

	; INPUT: x = entity one slot, y = entity two slot
	; OUTPUT: A = 1 if collide, A = 0 if no collision 
check_entities_collision:
	STX $00
	STY $02
	
	; size data table + spriteID[x]*4 -> $10:$11
	LDX #2
-:
	LDA $00, x ; first itr: LDY y; second iter: LDY x
	; CPY #0
	ASL A
	ASL A
	ASL A ; times 8
	STA $0B, x ; x = $0B, y = $0D
	TAY
	LDA ENTITY_SLOTS+0, y
	BEQ entities_not_colliding ; cant collide with entity ID 0 since its nothing
	ASL A
	ASL A
	; CLC
	ADC #(size_data_table & $00FF)
	STA $10, x
	LDA #0
	ADC #((size_data_table & $FF00) >> 8)
	STA $11, x
	
	DEX
	DEX
	BPL -

	; INPUT: $10:$11 = box one, $12:$13 = box two
	; OUTPUT: A = 1 if collide, else A = 0
check_boxes_collision:

	; move boxes to zero page
	LDY #3
-:
	LDA [$10], y
	STA $03, y
	LDA [$12], y
	STA $07, y
	DEY
	BPL -
	
	; a.xy = a.xy + X entity pos 
	LDX $0B
	LDA ENTITY_SLOTS+3, x 
	CLC
	ADC $03
	STA $03
	LDA ENTITY_SLOTS+5, x
	CLC
	ADC $04
	STA $04
	
	; b.xy = b.xy + Y entity pos
	LDX $0D
	LDA ENTITY_SLOTS+3, x 
	CLC
	ADC $07
	STA $07
	LDA ENTITY_SLOTS+5, x
	CLC
	ADC $08
	STA $08
	
	
	; $03 = a.x    $07 = b.x
	; $04 = a.y    $08 = b.y
	; $05 = a.w    $09 = b.w
	; $06 = a.h    $0A = b.h
	
	; if
	; a.x < b.x + b.width &&
	; a.x + a.width > b.x &&
	; a.y < b.y + b.height &&
	; a.y + a.height > b.y
	; then set collision
	
	LDX #1
-:

	LDA $03, x
	CLC
	ADC $05, x
	CMP $07, x
	BMI entities_not_colliding
	BEQ entities_not_colliding
	
	LDA $07, x
	CLC
	ADC $09, x
	CMP $03, x
	BMI entities_not_colliding
	BEQ entities_not_colliding
	
	DEX
	BPL -
	
	LDA #1
	RTS
entities_not_colliding:
	LDA #0
	RTS
	
; X = slot
init_entity_ptr:
	TXA
	ASL A
	ASL A
	ASL A
	STA ENTITY_SLOT_ARRAY_OFFSET
	RTS

; X = slot
init_entity_movement:
	JSR init_entity_ptr
	TAX ; LDA ENTITY_SLOT_ARRAY_OFFSET
	LDA ENTITY_SLOTS+0, x ; get sprite ID
	; size (x,y,w,h) = size_data_table[sprite ID * 4]
	; CMP #0
	BEQ +
	ASL A
	ASL A
	TAY
	STY SIZE_TABLE_OFFSET
	
	LDA ENTITY_SLOTS+3, x ; X position
	STA OLD_X
	LDA ENTITY_SLOTS+5, x ; Y position
	STA OLD_Y
	
	CLC
	RTS
+:
	SEC ; indicate the slot is empty
	RTS

handle_collision:
	; try X movement, try Y movement indivdually
	; if movement causes clip where there was none before, prohibit movement
	
	; see if horizontal movement is legal
	; if RIGHT, set 1 3
	; if LEFT, set 0 2
	
	; TODO: doesnt work...
	
	LDX ENTITY_SLOT_ARRAY_OFFSET
	LDA ENTITY_SLOTS+3, x ; new X position
	CMP OLD_X
	BEQ horizontal_movement_allowed
	STA COLL_BOX_X_POSITION
	; CMP OLD_X
	; OLD_X is less than new X, RIGHT
	LDA #%000001010
	BCS +
	; OLD_X is more than new X, LET
	LSR A ; LDA %00000101
+:
	STA CORNERS_TO_CHECK
	LDA OLD_Y ; old Y position
	STA COLL_BOX_Y_POSITION
	JSR detect_collision_box
	; STA HORIZONTAL_MOVE_LEGAL
	
	; LDA HORIZONTAL_MOVE_LEGAL
	; CMP #0
	BEQ horizontal_movement_allowed
	; prevent horizontal movement
	LDA OLD_X ; old X position
	STA ENTITY_SLOTS+3, x ; new X position
horizontal_movement_allowed:

	; if UP, set 0 1
	; if DOWN, set 2 3
	LDA ENTITY_SLOTS+3, x ; current X position
	STA COLL_BOX_X_POSITION
	LDA ENTITY_SLOTS+5, x ; new Y position
	CMP OLD_Y
	BEQ vertical_movement_allowed
	STA COLL_BOX_Y_POSITION
	; CMP OLD_Y
	LDA #%00001100
	BCS +
	LDA #%00000011
+:
	STA CORNERS_TO_CHECK
	JSR detect_collision_box
	; STA VERTICAL_MOVE_LEGAL

	; LDA VERTICAL_MOVE_LEGAL
	BEQ vertical_movement_allowed
	; prevent vertical movement
	LDA OLD_Y ; old Y position
	STA ENTITY_SLOTS+5, x ; new Y position
vertical_movement_allowed:
	
	RTS
	
	; JSR detect_collision_box
	; BNE +
	; JSR allow_movement
	; JMP ++
; +:
	; JSR prevent_movement
; ++:

	; LDA ENTITY_SLOTS+3, x ; new X position
	; STA COLL_BOX_X_POSITION
	; LDA COLL_BOX_NEW_Y_POSITION
	; STA COLL_BOX_Y_POSITION
	; JSR detect_collision_box
	; BNE +
	; JMP allow_movement; JSR allow_movement \ RTS
; +:
	; RTS ; JMP prevent_movement ; JSR prevent_movement \ RTS
	
CORNER_X1 = $04
CORNER_Y1 = $05
CORNER_X2 = $06
CORNER_Y2 = $07
IS_CLIP = $08 ; NUM_CLIPS = $08
	; INPUT: CORNER_X1, CORNER_Y1, CORNER_X2, CORNER_Y2
	; OUTPUT: IS_CLIP
SAVE_X = $00
; SAVE_Y = $01
CORNERS_TO_CHECK = $09
; 0 1
; 2 3
detect_collision_box:
	STX SAVE_X

	LDY SIZE_TABLE_OFFSET
	
	LDA COLL_BOX_X_POSITION
	CLC
	ADC.w size_data_table+0, y ; collision box X-offset
	STA CORNER_X1
	; CLC
	ADC.w size_data_table+2, y ; collision box width
	STA CORNER_X2
	
	LDA COLL_BOX_Y_POSITION
	; CLC
	ADC.w size_data_table+1, y ; collision box Y-offset
	STA CORNER_Y1
	; CLC
	ADC.w size_data_table+3, y ; collision box height
	STA CORNER_Y2
	
	; alt : if no corners clip, do nothing
	; if any corners clip, go back to old position
	LSR CORNERS_TO_CHECK
	BCC +
	LDX CORNER_X1
	LDY CORNER_Y1
	JSR collide_pixel_block
	BNE set_clip
+:

	LSR CORNERS_TO_CHECK
	BCC +
	LDX CORNER_X2
	LDY CORNER_Y1
	JSR collide_pixel_block
	BNE set_clip
+:
	
	LSR CORNERS_TO_CHECK
	BCC +
	LDX CORNER_X1
	LDY CORNER_Y2
	JSR collide_pixel_block
	BNE set_clip
+:

	LSR CORNERS_TO_CHECK
	BCC +
	LDX CORNER_X2
	LDY CORNER_Y2
	JSR collide_pixel_block
	BNE set_clip
+:
; reset_clip:
	LDX SAVE_X
	LDA #0
	STA IS_CLIP
	RTS
set_clip:
	LDX SAVE_X
	LDA #1
	STA IS_CLIP
	RTS
	
; 	LDX CORNER_X1
; 	LDY CORNER_Y1
; 	JSR collide_pixel_block
; 	LDX CORNER_X2
; 	LDY CORNER_Y1
; 	JSR collide_pixel_block
; 	
; 	; if num clips == 0 or num clips == 2, $09 = 0
; 	; if num clips == 1, $09 = 1
; 	LDA NUM_CLIPS
; 	AND #$01
; 	STA $09
; 
; 	LDX CORNER_X1
; 	LDY CORNER_Y2
; 	JSR collide_pixel_block
; 	LDX CORNER_X2
; 	LDY CORNER_Y2
; 	JSR collide_pixel_block
; 	
; 	LDX ENTITY_SLOT_ARRAY_OFFSET
; 	LDA NUM_CLIPS
; 	; CMP #0
; 	BEQ no_clips
; 	CMP #1
; 	BEQ clip_correction
; 	CMP #4
; 	BEQ correct_downward ; upward kick would get stuck, downward kick does not
; 	JMP revert_to_old_position
; clip_correction:
; 	; LDX ENTITY_SLOT_ARRAY_OFFSET
; 	LDA ENTITY_SLOTS+5, x
; 	LDY $09
; 	BEQ correct_upward
; correct_downward: ; else correct upward
; 	; add 16 to entity Y position, remove last 4 bits of entity Y
; 	CLC
; 	ADC #16
; correct_upward:
; 	; remove last 4 bits of entity Y
; 	AND #$F0
; end_clip_correction:
; 	STA ENTITY_SLOTS+5, x
; no_clips:
; 	; write new position into old position
; 	; LDX ENTITY_SLOT_ARRAY_OFFSET
; 	LDA ENTITY_SLOTS+3, x
; 	STA ENTITY_SLOTS+6, x
; 	LDA ENTITY_SLOTS+5, x
; 	STA ENTITY_SLOTS+7, x
; 	RTS
; revert_to_old_position:
; 	; write old position into new position
; 	; LDX ENTITY_SLOT_ARRAY_OFFSET
; 	LDA ENTITY_SLOTS+6, x
; 	STA ENTITY_SLOTS+3, x
; 	LDA ENTITY_SLOTS+7, x
; 	STA ENTITY_SLOTS+5, x
	; RTS

	; INPUT: x = X, y = Y
	; OUTPUT: $02 = block, A = tile impassability
collide_pixel_block:
	; STX $00
	; STY $01
	; 0300 + 16*((Y/16) - 1) + X/16
	TXA ; LDA $00
	LSR A
	LSR A
	LSR A
	LSR A
	STA $02
	
	TYA ; LDA $01
	AND #$F0
	SEC
	SBC #16
	CLC
	ADC $02
	TAX
	LDA $0300, x
	STA $02
	
	TAX
	LDA.w tile_impassability, x
	RTS

load_level_full:
	LDA #0
	STA PPU_CTRL ; disable v-blank interrupt
	STA PPU_MASK ; disable rendering
	
	JSR load_level
	JSR load_level_to_ppu
	
	JSR vblank_wait
	
	LDA #%10010000 ; enable V-blank interrupt, sprites on pattern table 0, bg on pattern table 1, autoincrement of 1
	STA PPU_CTRL
	LDA #%00011110 ; enable sprites, enable background, show left 8 pixels
	STA PPU_MASK
	LDA #0
	STA PPU_SCROLL ; X
	STA PPU_SCROLL ; Y
	RTS
	
reset_player_and_ghost_position:
	LDA #$40
	STA PLAYER_X
	STA $A8+$03
	
	LDA #$28
	STA PLAYER_Y
	LDA #$60
	STA $A8+$05
	RTS

APU_DRUM_VOLUME = $400C ; %00110000
APU_DRUM_SOUND = $400E

DRUM_ENVELOPE = $F2
DRUM_SOUND = $F3

NMI:
	; vblank
	
	;trying to figure out NMI
	; BIT $4210
	
	; DMA transfer page 02 to sprite table
	LDA #$00 ; LDA #$LOW
	STA PPU_DMA_LOW
	LDA #$02 ; LDA #$HIGH
	STA PPU_DMA_START_TRANSFER ; start transfer
	
	; INC X_SCROLL_LOW
	LDA #0
	STA PPU_SCROLL ; X
	STA PPU_SCROLL ; Y
	; LDA.w DISABLE_INTERRUPTS
	; BNE +
	; RTI
; +:

	; get controller inputs
	
	; latch both controllers
	LDA #$01
	STA CONTROLLER_1_PORT
	LDA #$00
	STA CONTROLLER_1_PORT
	
	TAX ; LDX #$00
	JSR read_controller_port
	INX ; LDX #$01
	JSR read_controller_port
	
	; sound engine
	; lda #%10111111 ;Duty 10, Volume F
    ; sta $4000
 
    ; lda #$C9    ;0C9 is a C# in NTSC mode
    ; sta $4002
    ; lda #$00
    ; sta $4003
	
	; LDA #%00111111
	; STA $400C
	; LDA #%00000010
	; STA $400D
	; LDA #$FF
	; STA $400F
	
	LDA CONTROLLER_1
	BPL +
	LDA #8
	STA DRUM_ENVELOPE
+:
	
	LDA #02
	STA DRUM_SOUND
	
	LDX DRUM_ENVELOPE
	; CPX #0
	BEQ +
	DEC DRUM_ENVELOPE
+:
	LDA.w drum_envelope, X
	ORA #%00110000
	STA APU_DRUM_VOLUME ; %0011XXXX
	LDA DRUM_SOUND
	STA APU_DRUM_SOUND ; X000XXXX
	
	
	; game engine
	; (A, B, Select, Start, Up, Down, Left, Right) as bits
	
	; if just one direction pressed, moveSpeed
	; if both directions pressed; moveSpeed * 0.707106781187
	
	LDX #0
	
entity_move_loop:
	STX ENTITY_SLOT_ITER
	JSR init_entity_movement ; INIT ENTITY MOVEMENT - done for each entity
	BCS +
	JSR entity_update
	JSR handle_collision
+:
	LDX ENTITY_SLOT_ITER
	INX
	CPX #8
	BNE entity_move_loop
	
	LDX #0
	LDY #1
	JSR check_entities_collision
	BEQ no_collision
	JSR reset_player_and_ghost_position
	; reset level
	LDA #(level_1 & $00FF)
	STA LEVEL_PTR
	LDA #(level_1 & $FF00) >> 8
	STA LEVEL_PTR+1
	JSR load_level_full
no_collision:
	
	; ; check collision loop
	; LDY #0
; --:
	; LDX #0
; -:
	; JSR check_entities_collision
	; LDX $00 ; preserve X
	; LDY $02 ; preserve Y
	; CMP #0 ; compare A with zero
	; BEQ no_collision
	; ; LDA #$40
	; ; STA PLAYER_X
	; ; STA PLAYER_Y
	; ; ; reset ghost position
	; ; STA $A8+$03
	; ; LDA #$60
	; ; STA $A8+$05
; no_collision:
	; ; STA $FE
	; INX
	; CPX #8
	; BNE -
	; INY
	; CPY #8
	; BNE --
	
	; reset sprite stack pointer
	LDA #$00
	STA $F0
	
	; put sprites
	LDX #0
-:
	STX ENTITY_SLOT_ITER
	JSR init_entity_ptr
	JSR draw_entity
	LDX ENTITY_SLOT_ITER
	INX
	CPX #8
	BNE -
	
	RTI

	.orga $E000
	; code


	; compression:
	; 0 = block
	; 10 = air
	; 11xxxx = rest of stuff
	
	; xxxx values and their meanings (numbers are xxxx+2)
	; 2 = end data
	; 3 = repeat last 16 tiles
level_1:
room_0_0:
	.dw 0 ; north
	.dw room_0_1 ; south
	.dw 0 ; west
	.dw 0 ; east
	.db $00, $00, $AA, $AA
	.db $0A, $A8, $42, $05
	.db $54, $A0, $80, $02
	.db $04, $94, $52, $A3
	.db $80, $02, $04, $54
	.db $A0, $80, $4A, $1A
	.db $15, $50, $55, $55
	.db $40, $01, $80, $01
	
room_0_1:
	.dw room_0_0 ; north
	.dw room_0_2 ; south
	.dw room_1_1 ; east
	.dw 0 ; west
	.db $0A, $00, $A8, $AA
	.db $AA, $AA, $54, $A1
	.db $42, $A9, $50, $05
	.db $14, $14, $40, $A9
	.db $46, $09, $28, $40
	.db $40, $25, $34, $8E
	.db $01, $55, $55, $05
	.db $14, $00, $18, $00
	
room_0_2:
	.dw room_0_1 ; north
	.dw -1 ; south
	.dw 0 ; east
	.dw 0 ; west
	.db $0A, $00, $A8, $AA
	.db $2A, $A0, $8A, $2A
	.db $A0, $52, $55, $40
	.db $55, $15, $40, $A9
	.db $0A, $A0, $54, $2A
	.db $A0, $2A, $55, $40
	.db $55, $28, $A0, $92
	.db $14, $50, $49, $15
	.db $50, $55, $55, $40
	.db $01, $80, $01
	
room_1_1:
	.dw room_0_0
	.dw 0
	.dw -1
	.dw room_0_1
	.db $00, $50, $54, $AA
	.db $AA, $AA, $2A, $55
	.db $55, $55, $24, $00
	.db $50, $01, $00, $00
	.db $00, $00, $00, $00
	.db $00, $00, $00, $00
	.db $00, $00, $00, $00
	.db $00, $00, $60, $00
	
drum_envelope: ; end = drum_envelope[8]
	.db $00, $01, $02, $03, $04, $05, $06, $08, $0F
	
entity_update_vector_table:
	.dw no_update
	.dw player_update
	.dw grunt_update

tile_composition:
	; 4 bytes tile composition for meta-tile
	.db $0A, $0A, $0A, $0A ; air 
	.db $10, $11, $12, $13 ; brick
	.db $10, $11, $12, $13 ; red brick
	
tile_impassability:
	; 1 byte for if the tile prevents walking (1) or allows walking through it (0)
	.db $00 ; air
	.db $01 ; brick
	.db $01 ; red brick
	
tile_palettes:
	; 1 byte for each pallete
	.db $00, ; air
	.db $01, ; brick
	.db $02,  ; red brick
color_palette:
	.db $00,$35,$23,$24, $00,$26,$17,$07, $00,$01,$00,$01, $00,$20,$10,$00
	.db $0B,$11,$21,$31, $00,$09,$19,$3A, $00,$28,$18,$13, $00,$01,$00,$01
	
animation_set_table:
	.dw $0000
	.dw player_animations ; entity ID 1
	.dw grunt_animations ; entity ID 2
	
player_animations:
	.dw player_sprite_right ; entity ID 0
	.dw player_sprite_left
	
grunt_animations:
	.dw grunt_sprite_right
	.dw grunt_sprite_left
	
	; initial = number of sprites in meta-sprite
	; [0] = Y-position
	; [1] = Tile graphic number
	; [2] = flags
	; [3] = X-Position

size_data_table:
	; [0] = x-offset
	; [1] = y-offset
	; [2] = width
	; [3] = height
	
	.db 0, 0, 0, 0 ; element 0
player_size: ; element 1
	.db 2, 2, 11, 13
grunt_size:
	.db 2, 2, 11, 13
	
grunt_sprite_right:
	.db 4
	.db $00,$01,$03,$00
	.db $00,$02,$03,$08
	.db $08,$03,$03,$00
	.db $08,$03,$43,$08
grunt_sprite_left:
	.db 4
	.db $00,$02,$43,$00
	.db $00,$01,$43,$08
	.db $08,$03,$03,$00
	.db $08,$03,$43,$08

player_sprite_right:
	.db 4
	.db $00,$01,$00,$00
	.db $00,$02,$00,$08
	.db $08,$03,$00,$00
	.db $08,$03,$40,$08
player_sprite_left:
	.db 4
	.db $00,$02,$40,$00
	.db $00,$01,$40,$08
	.db $08,$03,$00,$00
	.db $08,$03,$40,$08

	; NOP
	.orga $FFFA
	; 6502 vector table
	.dw NMI
	.dw RESET
	.db $00,$00 ; IRQ

	.bank 1 slot 1
	.org $0000
	; graphics (sprites)
	;.incpng "sprites.png"
	.incbin sprites.chr
	; .include "sprites.inc"
	
	.org $1000
	; graphics (tiles)
	
	;

	.incbin background.chr
