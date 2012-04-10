#include "nes.inc"

.globl	ppu_next_scanline
ppu_next_scanline:
	push	{r4-r8, r10-r11, lr}

	ldr	r10, [r9, #s_ppu_flags]

	ldr	r0, [r9, #s_ppu_scanline]

	add	r0, r0, #1

	cmp	r0, #-1          @ Vblank is over
	biceq	r10, r10, #0xC00000

	cmp	r0, #241         @ Vblank is starting
	bne	1f
	mov	r0, #-21
	orr	r10, r10, #0x800000
	and	r2, r10, #0x80   @ NMI enabled?
	strb	r2, [r9, #s_nmi_reset]
1:

	str	r0, [r9, #s_ppu_scanline]

	cmp	r0, #240
	bcs	rendering_off

	tst	r10, #0x1800
	beq	1f
	cmp	r0, #0
	@ Line 0:      Move to (X,Y) position specified in s_ppu_scroll
	@ Lines 1-239: Move back to X position specified in s_ppu_scroll
	ldr	r1, [r9, #s_ppu_address]
	ldr	r0, [r9, #s_ppu_scroll]
	moveq	r2,     #0xFF00
	addeq	r2, r2, #0x00FF
	movne	r2,     #0x0400
	addne	r2, r2, #0x001F
	and	r0, r0, r2
	bic	r1, r1, r2
	orr	r1, r1, r0
	str	r1, [r9, #s_ppu_address]
1:

	ldr	r0, [r9, #s_frameskip_cur]
	cmp	r0, #0
	bne	frameskipped

	@ Allocate scanline pixel buffer
	sub	sp, sp, #272

	@ Step I: Render background
	tst	r10, #0x0800
	beq	background_disabled
	mov	r1, r10, lsl #8
	and	r1, r1, #0x1000

	ldr	r2, [r9, #s_ppu_address]
	and	r8, r2, #0x1F
	add	r1, r1, r2, lsr #12
	bl	get_name_table_pointers

	mov	r11, #33
	ldr	r6, =0x08040201
	ldr	r7, =0xEEEEEEEE
draw_chr:
	@ Get attribute for this block
	ldrb	r12, [r0, r8, lsr #2]

	@ Get character
	ldrb	r3, [r2, r8]

	tst	r2, #0x40               @ Assuming nametable is 128-byte aligned
	movne	r12, r12, lsr #4
	tst	r8, #0x02
	moveq	r12, r12, lsl #2
	and	r12, r12, #0x0C
	orr	r12, r12, #0x03
	orr	r12, r12, lsl #8
	orr	r12, r12, lsl #16

	@ Get pixels for appropriate row of character
	add	r4, r1, r3, lsl #4
	mov	r3, r4, lsr #10
	add	r3, r9, r3, lsl #2
	ldr	r3, [r3, #s_ppu_mem_map]
	ldrb	r3, [r4, r3]!           @ Low plane
	ldrb	r4, [r4, #8]            @ High plane

	@ Move to next character over
	add	r8, r8, #1
	cmp	r8, #0x20
	bleq	swap_name_table

	@ Unpack each pixel into a nybble
	mul	r3, r6, r3
	mul	r4, r6, r4
	orr	r3, r7, r3, lsr #3
	orr	r4, r7, r4, lsr #3
	and	r4, r3, r4, ror #31

	@ Unpack nybbles into bytes
	and	r3, r12, r4, lsr #4
	and	r4, r12, r4
	stmia	sp!, {r3-r4}

	subs	r11, r11, #1
	bne	draw_chr
	sub	sp, sp, #264

	@ Blank out left 8 pixels
	tst	r10, #0x0200
	bne	background_done
	ldr	r0, [r9, #s_ppu_scroll]
	mov	r3, #0
	add	r0, sp, r0, lsr #29
	strb	r3, [r0]
	strb	r3, [r0, #1]
	strb	r3, [r0, #2]
	strb	r3, [r0, #3]
	strb	r3, [r0, #4]
	strb	r3, [r0, #5]
	strb	r3, [r0, #6]
	strb	r3, [r0, #7]
background_done:

	ldr	r0, [r9, #s_ppu_scroll]
	add	sp, sp, r0, lsr #29

	@ Step II: Sprites
	tst	r10, #0x1000
	beq	no_sprites

	@ Get sprite height (minus 1)
	tst	r10, #0x0020
	moveq	r12, #7
	movne	r12, #15

	ldrb	r1, [r9, #s_spr_loc_table_valid]
	movs	r1, r1
	bleq	refresh_spr_loc_table

	ldr	r0, [r9, #s_ppu_scanline]

	add	r2, r9, #s_spr_loc_table
	add	r2, r2, r0, lsl #3
	ldrb	r1, [r2, r0]!

	cmp	r1, #0
	beq	no_sprites

	@ Only up to 8 sprites are actually stored in the table
	cmp	r1, #8
	movcs	r1, #8

	sub	r0, r0, #1
sprite_loop:
	ldrb	r4, [r2, #1]!
	add	r8, r9, #s_ppu_oam_ram
	ldr	r4, [r8, r4]

	@ Get offset from the top
	and	r6, r4, #0xFF
	sub	r5, r0, r6

	bl	fetch_sprite_bits

	@ Get palette
	mov	r8, r4, lsr #14
	and	r8, r8, #0x0C
	orr	r8, r8, #0x30

	tst	r4, #0x400000
	movne	r5, r5, lsl #7
	moveq	r3, #31
	movne	r3, #1

	mov	r6, #8
	add	r11, sp, r4, lsr #24
	tst	r4, #0x200000
	bne	sprite_draw_low_pri
sprite_draw_high_pri:
	ldrb	lr, [r11], #1
	and	r7, r5, #0x80
	orr	r7, r8, r7, lsr #7
	tst	r5, #0x8000
	addne	r7, r7, #2
	tst	r7, #3
	beq	1f
	tst	lr, #0x20
	streqb	r7, [r11, #-1]
1:	mov	r5, r5, ror r3
	subs	r6, r6, #1
	bne	sprite_draw_high_pri
	b	sprite_next
sprite_draw_low_pri:
	ldrb	lr, [r11], #1
	and	r7, r5, #0x80
	orr	r7, r8, r7, lsr #7
	tst	r5, #0x8000
	addne	r7, r7, #2
	tst	r7, #3
	beq	1f
	tst	lr, #3
	orrne	r7, lr, #0x20
	strb	r7, [r11, #-1]
1:	mov	r5, r5, ror r3
	subs	r6, r6, #1
	bne	sprite_draw_low_pri
sprite_next:
	subs	r1, r1, #1
	bne	sprite_loop
no_sprites:

	@ Step III: Draw to screen
	mov	r4, #0xC0000000
	ldr	r4, [r4, #0x10]
	add	r5, r9, #s_palette_cache

	ldr	r0, [r9, #s_hw_color]
	ldrb	r1, [r9, #s_palette_cache_valid]
	movs	r0, r0
	bne	draw_color

	movs	r1, r1
	bleq	refresh_palette_cache_bw

	@ Draw in black and white
	ldr	r0, [r9, #s_ppu_scanline]
	add	r0, r0, r0, lsl #2
	add	r4, r4, r0, lsl #5
	add	r4, r4, #0x10

	mov	r8, #256
1:	ldrb	r0, [sp], #1
	ldrb	r1, [sp], #1
	ldrb	r2, [sp], #1
	ldrb	r3, [sp], #1
	ldrb	r0, [r5, r0]
	ldrb	r1, [r5, r1]
	ldrb	r2, [r5, r2]
	ldrb	r3, [r5, r3]
	orr	r0, r1, r0, lsl #4
	orr	r0, r0, r2, lsl #12
	orr	r0, r0, r3, lsl #8
	strh	r0, [r4], #2
	subs	r8, r8, #4
	bne	1b

	b	draw_done
draw_color:
	movs	r1, r1
	bleq	refresh_palette_cache_color

	ldr	r0, [r9, #s_ppu_scanline]
	add	r0, r0, r0, lsl #2
	add	r4, r4, r0, lsl #7
	add	r4, r4, #0x40

	mov	r8, #256
1:	ldrb	r0, [sp], #1
	ldrb	r1, [sp], #1
	ldrb	r2, [sp], #1
	ldrb	r3, [sp], #1
	add	r0, r0
	add	r1, r1
	add	r2, r2
	add	r3, r3
	ldrh	r0, [r5, r0]
	ldrh	r1, [r5, r1]
	ldrh	r2, [r5, r2]
	ldrh	r3, [r5, r3]
	orr	r0, r1, lsl #16
	str	r0, [r4], #4
	orr	r2, r3, lsl #16
	str	r2, [r4], #4
	subs	r8, r8, #4
	bne	1b


draw_done:
	ldr	r0, [r9, #s_ppu_scroll]
	add	sp, sp, #16
	sub	sp, sp, r0, lsr #29

frameskipped:
	@ Check for sprite 0 hit
	@ (TODO: should only occur when two opaque pixels collide)
	tst	r10, #0x1000
	beq	sprite_0_done
	tst	r10, #0x0020
	moveq	r12, #7
	movne	r12, #15
	ldr	r0, [r9, #s_ppu_scanline]
	ldr	r4, [r9, #s_ppu_oam_ram]
	sub	r0, r0, #1
	and	r6, r4, #0xFF
	sub	r5, r0, r6
	cmp	r5, r12
	bls	sprite_0_check
sprite_0_done:

	tst	r10, #0x1800
	beq	rendering_off
	@ Move down by one pixel
	ldr	r1, [r9, #s_ppu_address]
	add	r1, r1, #0x1000
	cmp	r1, #0x8000
	bcc	1f
	bic	r1, r1, #0x8000
	add	r1, r1, #0x0020
	ands	r2, r1, #0x03E0
	subeq	r1, r1, #0x0400  @ If Y wraps 31->0, no name table change
	cmp	r2, #0x03C0
	eoreq	r1, r1, #0x0BC0  @ If Y wraps 29->0, name table change
1:	str	r1, [r9, #s_ppu_address]

rendering_off:
	str	r10, [r9, #s_ppu_flags]
	ldr	r0, [r9, #s_ppu_scanline]
	cmp	r0, #-21
	bleq	newframe
	pop	{r4-r8, r10-r11, pc}

	.pool

swap_name_table:
	ldr	r2, [r9, #s_ppu_address]
	mov	r8, #0
	eor	r2, r2, #0x0400
get_name_table_pointers:
	and	r2, r2, #0x0FE0
	orr	r2, r2, #0x2000
	mov	r5, r2, lsr #10
	add	r5, r9, r5, lsl #2
	ldr	r5, [r5, #s_ppu_mem_map]

	and	r0, r2, #0xFC00
	orr	r0, r0, r2, lsr #4
	orr	r0, r0, #0x03C0
	bic	r0, r0, #7

	add	r2, r5, r2
	add	r0, r5, r0

	bx	lr

background_disabled:
	@ Weird NES behavior: if rendering is completely disabled (both BG and sprite),
	@ and PPUADDR points inside palette, draw that color.
	@ Otherwise, just draw color 0
	tst	r10, #0x1800
	bne	1f
	ldr	r0, [r9, #s_ppu_address]
	ands	lr, r0, #0x3F00
	and	r0, r0, #0x1F
	orr	r0, r0, #0x20          @ use alternate palette (doesn't map $04,$08,$0C -> $00)
	orr	r0, r0, r0, lsl #8
	orr	r0, r0, r0, lsl #16
	cmp	lr, #0x3F00
1:	movne	r0, #0

	mov	r11, #264
1:	subs	r11, r11, #4
	str	r0, [sp, r11]
	bne	1b
	b	background_done

sprite_0_check:
	bl	fetch_sprite_bits
	movs	r5, r5
	orrne	r10, r10, #0x400000
	b	sprite_0_done

fetch_sprite_bits:
	@ Vertical flip
	tst	r4, #0x800000
	rsbne	r5, r5, r12

	@ Get CHR address
	tst	r10, #0x0020
	moveq	r8, r10, lsl #9
	movne	r8, r4, lsl #4
	and	r8, r8, #0x1000
	moveq	r6, #0xFF
	movne	r6, #0xFE
	and	r6, r6, r4, lsr #8
	addne	r6, r6, r5, lsr #3
	and	r5, r5, #7

	add	r6, r8, r6, lsl #4
	mov	r8, r6, lsr #10
	add	r8, r9, r8, lsl #2
	ldr	r8, [r8, #s_ppu_mem_map]
	add	r6, r8, r6

	ldrb	r5, [r6, r5]!        @ low plane
	ldrb	r6, [r6, #8]         @ high plane

	orr	r5, r5, r6, lsl #8

	@ Check if sprite needs to be clipped against left edge of screen
	cmp	r4, #0x08000000
	bxcs	lr
clip_sprite:
	tst	r10, #0x0400
	bxne	lr
	mov	r3, r4, lsr #24
	add	r3, pc, r3, lsl #2
	ldr	r3, [r3, #sprite_clip_table - (.+4)]
	tst	r4, #0x400000
	biceq	r5, r5, r3
	bicne	r5, r5, r3, lsr #16
	bx	lr
sprite_clip_table:
	.word	0xFFFFFFFF
	.word	0x7F7FFEFE
	.word	0x3F3FFCFC
	.word	0x1F1FF8F8
	.word	0x0F0FF0F0
	.word	0x0707E0E0
	.word	0x0303C0C0
	.word	0x01018080

refresh_spr_loc_table:
	@ Start by clearing the table (0 sprites for every scanline)
	add	r1, r9, #s_spr_loc_table
	mov	r2, #0
	mov	r3, #240
1:	strb	r2, [r1], #9
	subs	r3, r3, #1
	bne	1b

	add	r2, r9, #s_spr_loc_table
	add	r2, r2, #9

	@ Loop over each sprite
	add	r0, r9, #s_ppu_oam_ram
	sub	r0, r0, #4
	mov	r6, #64
spr_loc_loop1:
	@ Get first scanline (minus one) of sprite
	ldrb	r3, [r0, #4]!

	rsbs	r4, r3, #239    @ Number of visible scanlines
	bls	spr_loc_done
	cmp	r4, r12
	addhi	r4, r12, #1

	add	r1, r2, r3, lsl #3
	add	r1, r1, r3

	@ Loop over each scanline this sprite is in,
	@ appending the sprite index to each one's list
spr_loc_loop2:
	ldrb	r5, [r1]
	add	r5, r5, #1
	cmp	r5, #8
	strlsb	r0, [r1, r5]    @ Assuming OAM is 256-byte aligned
	strb	r5, [r1], #9
	subs	r4, r4, #1
	bne	spr_loc_loop2
spr_loc_done:
	subs	r6, r6, #1
	bne	spr_loc_loop1

	mov	r0, #1
	strb	r0, [r9, #s_spr_loc_table_valid]
	bx	lr

refresh_palette_cache_bw:
	adr	r0, nes_color_to_gray_table
	add	r1, r9, #s_ppu_palette
	add	r2, r5, #0x40
	mov	r3, #0x1F
1:	ldrb	r6, [r1, r3]
	ldrb	r6, [r0, r6]
	strb	r6, [r2, #-1]!
	subs	r3, r3, #1
	bpl	1b
	mov	r3, #0x1F
1:	tst	r3, #0x03
	ldreqb	r6, [r1]
	ldrneb	r6, [r1, r3]
	ldrb	r6, [r0, r6]
	strb	r6, [r2, #-1]!
	subs	r3, r3, #1
	bpl	1b
	strb	r3, [r9, #s_palette_cache_valid]
	bx	lr

refresh_palette_cache_color:
	adr	r0, nes_color_to_rgb_table
	add	r1, r9, #s_ppu_palette
	add	r2, r5, #0x80
	mov	r3, #0x1F
1:	ldrb	r6, [r1, r3]
	add	r6, r6
	ldrh	r6, [r0, r6]
	strh	r6, [r2, #-2]!
	subs	r3, r3, #1
	bpl	1b
	mov	r3, #0x1F
1:	tst	r3, #0x03
	ldreqb	r6, [r1]
	ldrneb	r6, [r1, r3]
	add	r6, r6
	ldrh	r6, [r0, r6]
	strh	r6, [r2, #-2]!
	subs	r3, r3, #1
	bpl	1b
	strb	r3, [r9, #s_palette_cache_valid]
	bx	lr

.globl invert_colors
invert_colors:
	adr	r0, nes_color_to_gray_table
	mov	r2, #64
1:	subs	r2, r2, #1
	ldrb	r1, [r0, r2]
	eor	r1, r1, #0x0F
	strb	r1, [r0, r2]
	bne	1b
	adr	r0, nes_color_to_rgb_table
	mov	r2, #128
1:	subs	r2, r2, #4
	ldr	r1, [r0, r2]
	mvn	r1, r1
	str	r1, [r0, r2]
	bne	1b
	strb	r2, [r9, #s_palette_cache_valid]
	bx	lr

.globl toggle_border
toggle_border:
	ldr	r1, [r9, #s_border_color]
	mvn	r1, r1
	str	r1, [r9, #s_border_color]
	mov	r0, #0xC0000000
	ldr	r0, [r0, #0x10]
	ldr	r2, [r9, #s_hw_color]
	movs	r2, r2
	mov	r2, #0x9600
	lslne	r2, #2
1:	str	r1, [r0], #4
	subs	r2, #4
	bne	1b
	bx	lr

nes_color_to_gray_table:
	.byte	 6, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 0, 0, 0
	.byte	10, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 0, 0, 0
	.byte	15,10,10,10,10,10,10,10,10,10,10,10,10, 5, 0, 0
	.byte	15,13,13,13,13,13,13,13,13,13,13,13,13,11, 0, 0

@	.byte	 7, 3, 4, 4, 5, 6, 6, 4, 3, 3, 4, 3, 3, 0, 0, 0
@	.byte	11, 7, 6, 7, 7, 8, 8, 8, 7, 7, 8, 7, 7, 0, 0, 0
@	.byte	15,10, 9, 8,11,11,10,11,12,10,11,12,12, 7, 0, 0
@	.byte	15,13,13,13,13,13,12,13,14,14,13,14,14,12, 0, 0

nes_color_to_rgb_table:
	.hword	0x73ae,0x20d1,0x0015,0x4013,0x880e,0xa802,0xa000,0x7840
	.hword	0x4160,0x0220,0x0280,0x01e2,0x19eb,0x0000,0x0000,0x0000
	.hword	0xbdf7,0x039d,0x21dd,0x801e,0xb817,0xe00b,0xd940,0xca61
	.hword	0x8b80,0x04a0,0x0540,0x0487,0x0411,0x0000,0x0000,0x0000
	.hword	0xffff,0x3dff,0x5cbf,0x445f,0xf3df,0xfbb6,0xfbac,0xfcc7
	.hword	0xf5e7,0x8682,0x4ee9,0x5fd3,0x075b,0x7bcf,0x0000,0x0000
	.hword	0xffff,0xaf3f,0xc6bf,0xd65f,0xfe3f,0xfe3b,0xfdf6,0xfed5
	.hword	0xff34,0xe7f4,0xaf97,0xb7f9,0x9ffe,0xc638,0x0000,0x0000
