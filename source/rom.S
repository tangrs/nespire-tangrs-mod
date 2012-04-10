#include "nes.inc"

map_prg_32kB:
	ldr	r1, [r9, #s_prg_size]
	ldr	r2, [r9, #s_prg_ptr]
	and	r0, r1, r0, lsl #15
	add	r0, r0, r2
map_prg_32kB_from_pointer:
	sub	r0, r0, #0x8000
	str	r0, [r9, #s_mem_map + 16]    @ 8000
	str	r0, [r9, #s_mem_map + 20]    @ A000
	str	r0, [r9, #s_mem_map + 24]    @ C000
	str	r0, [r9, #s_mem_map + 28]    @ E000
	bx	lr
map_prg_16kB_to_8000:
	ldr	r1, [r9, #s_prg_size]
	ldr	r2, [r9, #s_prg_ptr]
	and	r0, r1, r0, lsl #14
	add	r0, r0, r2
	sub	r0, r0, #0x8000
	str	r0, [r9, #s_mem_map + 16]    @ 8000
	str	r0, [r9, #s_mem_map + 20]    @ A000
	bx	lr
map_prg_16kB_to_C000:
	ldr	r1, [r9, #s_prg_size]
	ldr	r2, [r9, #s_prg_ptr]
	and	r0, r1, r0, lsl #14
	add	r0, r0, r2
	sub	r0, r0, #0xC000
	str	r0, [r9, #s_mem_map + 24]    @ C000
	str	r0, [r9, #s_mem_map + 28]    @ E000
	bx	lr

map_prg_8kB:
	ldr	r2, [r9, #s_prg_size]
	ldr	r3, [r9, #s_prg_ptr]
	and	r0, r2, r0, lsl #13
	add	r0, r0, r3
	sub	r0, r0, r1
	add	r1, r9, r1, lsr #11
	str	r0, [r1, #s_mem_map]
	bx	lr


map_chr_8kB:
	ldr	r2, [r9, #s_chr_size]
	ldr	r3, [r9, #s_chr_ptr]
	and	r0, r2, r0, lsl #13
	add	r0, r0, r3
	str	r0, [r9, #s_ppu_mem_map + 0x00]    @ 0000
	str	r0, [r9, #s_ppu_mem_map + 0x04]    @ 0400
	str	r0, [r9, #s_ppu_mem_map + 0x08]    @ 0800
	str	r0, [r9, #s_ppu_mem_map + 0x0C]    @ 0C00
	str	r0, [r9, #s_ppu_mem_map + 0x10]    @ 1000
	str	r0, [r9, #s_ppu_mem_map + 0x14]    @ 1400
	str	r0, [r9, #s_ppu_mem_map + 0x18]    @ 1800
	str	r0, [r9, #s_ppu_mem_map + 0x1C]    @ 1C00
	bx	lr
map_chr_4kB_to_0000:
	mov	r1, #0x0000
	b	map_chr_4kB
map_chr_4kB_to_1000:
	mov	r1, #0x1000
map_chr_4kB:
	ldr	r2, [r9, #s_chr_size]
	ldr	r3, [r9, #s_chr_ptr]
	and	r0, r2, r0, lsl #12
	add	r0, r0, r3
	sub	r0, r0, r1
	add	r1, r9, r1, lsr #8
	str	r0, [r1, #s_ppu_mem_map + 0x00]    @ +0000
	str	r0, [r1, #s_ppu_mem_map + 0x04]    @ +0400
	str	r0, [r1, #s_ppu_mem_map + 0x08]    @ +0800
	str	r0, [r1, #s_ppu_mem_map + 0x0C]    @ +0C00
	bx	lr
map_chr_2kB:
	ldr	r2, [r9, #s_chr_size]
	ldr	r3, [r9, #s_chr_ptr]
	and	r0, r2, r0, lsl #10
	add	r0, r0, r3
	sub	r0, r0, r1
	add	r1, r9, r1, lsr #8
	str	r0, [r1, #s_ppu_mem_map + 0x00]    @ +0000
	str	r0, [r1, #s_ppu_mem_map + 0x04]    @ +0400
	bx	lr
map_chr_1kB:
	ldr	r2, [r9, #s_chr_size]
	ldr	r3, [r9, #s_chr_ptr]
	and	r0, r2, r0, lsl #10
	add	r0, r0, r3
	sub	r0, r0, r1
	add	r1, r9, r1, lsr #8
	str	r0, [r1, #s_ppu_mem_map]
	bx	lr

mirror_1screen_lo:
	add	r0, r9, #s_name_table_ram
	b	mirror_1screen
mirror_1screen_hi:
	add	r0, r9, #s_name_table_ram + 0x0400
mirror_1screen:
	str	r0, [r9, #s_ppu_mem_map + 0x20]    @ 2000
	sub	r0, r0, #0x0400
	str	r0, [r9, #s_ppu_mem_map + 0x24]    @ 2400
	sub	r0, r0, #0x0400
	str	r0, [r9, #s_ppu_mem_map + 0x28]    @ 2800
	sub	r0, r0, #0x0400
	str	r0, [r9, #s_ppu_mem_map + 0x2C]    @ 2C00
	sub	r0, r0, #0x0400
	str	r0, [r9, #s_ppu_mem_map + 0x30]    @ 3000
	sub	r0, r0, #0x0400
	str	r0, [r9, #s_ppu_mem_map + 0x34]    @ 3400
	sub	r0, r0, #0x0400
	str	r0, [r9, #s_ppu_mem_map + 0x38]    @ 3800
	sub	r0, r0, #0x0400
	str	r0, [r9, #s_ppu_mem_map + 0x3C]    @ 3C00
	bx	lr

mirror_vert:
	add	r0, r9, #s_name_table_ram - 0x2000
	str	r0, [r9, #s_ppu_mem_map + 0x20]    @ 2000
	str	r0, [r9, #s_ppu_mem_map + 0x24]    @ 2400
	add	r0, r9, #s_name_table_ram - 0x2800
	str	r0, [r9, #s_ppu_mem_map + 0x28]    @ 2800
	str	r0, [r9, #s_ppu_mem_map + 0x2C]    @ 2C00
	add	r0, r9, #s_name_table_ram - 0x3000
	str	r0, [r9, #s_ppu_mem_map + 0x30]    @ 3000
	str	r0, [r9, #s_ppu_mem_map + 0x34]    @ 3400
	add	r0, r9, #s_name_table_ram - 0x3800
	str	r0, [r9, #s_ppu_mem_map + 0x38]    @ 3800
	str	r0, [r9, #s_ppu_mem_map + 0x3C]    @ 3C00
	bx	lr

mirror_horiz:
	add	r0, r9, #s_name_table_ram - 0x2000
	str	r0, [r9, #s_ppu_mem_map + 0x20]    @ 2000
	add	r0, r9, #s_name_table_ram - 0x2400
	str	r0, [r9, #s_ppu_mem_map + 0x24]    @ 2400
	str	r0, [r9, #s_ppu_mem_map + 0x28]    @ 2800
	add	r0, r9, #s_name_table_ram - 0x2800
	str	r0, [r9, #s_ppu_mem_map + 0x2C]    @ 2C00
	add	r0, r9, #s_name_table_ram - 0x3000
	str	r0, [r9, #s_ppu_mem_map + 0x30]    @ 2000
	add	r0, r9, #s_name_table_ram - 0x3400
	str	r0, [r9, #s_ppu_mem_map + 0x34]    @ 2400
	str	r0, [r9, #s_ppu_mem_map + 0x38]    @ 2800
	add	r0, r9, #s_name_table_ram - 0x3800
	str	r0, [r9, #s_ppu_mem_map + 0x3C]    @ 2C00
	bx	lr

mirror_4screen:
	add	r0, r9, #s_name_table_ram - 0x2000
	str	r0, [r9, #s_ppu_mem_map + 0x20]    @ 2000
	str	r0, [r9, #s_ppu_mem_map + 0x24]    @ 2400
	str	r0, [r9, #s_ppu_mem_map + 0x28]    @ 2800
	str	r0, [r9, #s_ppu_mem_map + 0x2C]    @ 2C00
	add	r0, r9, #s_name_table_ram - 0x3000
	str	r0, [r9, #s_ppu_mem_map + 0x30]    @ 3000
	str	r0, [r9, #s_ppu_mem_map + 0x34]    @ 3400
	str	r0, [r9, #s_ppu_mem_map + 0x38]    @ 3800
	str	r0, [r9, #s_ppu_mem_map + 0x3C]    @ 3C00
	bx	lr

.globl	load_rom
load_rom:
	push	{r4-r11, lr}
	adr	r4, rom_file

	str	r4, [r9, #s_rom_header]

	ldr	r1, [r4]
	ldr	r2, =0x1A53454E
	cmp	r1, r2
	CERROR	ne, 0x8000

	add	r1, r4, #0x10
	ldrb	r3, [r4, #4]  @ Number of PRG-ROM banks
	cmp	r3, #0
	moveq	r3, #0x100
	mov	r3, r3, lsl #14
	str	r1, [r9, #s_prg_ptr]
	sub	r2, r3, #1
	str	r2, [r9, #s_prg_size]

	ldrb	r0, [r4, #5]  @ Number of CHR-ROM banks
	cmp	r0, #0
	addeq	r1, r9, #s_chr_ram
	moveq	r0, #0x2000
	addne	r1, r1, r3
	movne	r0, r0, lsl #13 
	str	r1, [r9, #s_chr_ptr]
	sub	r2, r0, #1
	str	r2, [r9, #s_chr_size]

	@ Initialize CPU memory map
	@ RAM
	str	r9, [r9, #s_mem_map + 0]     @ 0000
	@ SRAM
	add	r1, r9, #s_sram - 0x6000
	str	r1, [r9, #s_mem_map + 12]    @ 6000
	@ ROM low
	mov	r0, #0
	bl	map_prg_16kB_to_8000
	@ ROM high
	mov	r0, #-1
	bl	map_prg_16kB_to_C000
	@ RAM wraparound
	sub	r1, r9, #0x10000
	str	r1, [r9, #s_mem_map + 32]    @ 10000

	@ Initialize PPU memory map
	mov	r0, #0
	bl	map_chr_8kB

	@ Name table
	ldrb	r6, [r4, #6]
	adr	lr, 1f
	tst	r6, #8
	bne	mirror_4screen
	tst	r6, #1
	bne	mirror_vert
	beq	mirror_horiz
1:

	@ Get low 4 bits of mapper number
	mov	r0, r6, lsr #4
	@ Get high 4 bits of mapper number (unless it looks like
	@ there's junk in the header, in which case ignore them)
	ldr	r1, [r4, #12]
	movs	r1, r1
	ldreqb	r1, [r4, #7]
	andeq	r1, r1, #0xF0
	orreq	r0, r0, r1

	adr	r1, mapper_table
	adr	r2, mapper_table_end
1:	cmp	r2, r1
	CERROR	eq, 0x8001
	ldrh	r5, [r2, #-2]!
	ldrh	r4, [r2, #-2]!
	cmp	r0, r4
	bne	1b
	add	r0, r1, r5
	str	r0, [r9, #s_mapper]

	pop	{r4-r11, pc}
	.pool

mapper_table:
.macro MAPPER n, addr; .hword \n, \addr - mapper_table; .endm
	MAPPER   0, mapper_NROM
	MAPPER   1, mapper_MMC1
	MAPPER   2, mapper_UxROM
	MAPPER   3, mapper_CNROM
	MAPPER   4, mapper_MMC3
	MAPPER   7, mapper_AxROM
	MAPPER  11, mapper_Color_Dreams
	MAPPER  34, mapper_BxROM
	MAPPER  66, mapper_GxROM
	MAPPER 228, mapper_Action_Enterprises
mapper_table_end:

mapper_NROM:
	bx	lr

#define s_mmc1_shift_reg   (s_mapper_state)
#define s_mmc1_control     (s_mapper_state+4)
#define s_mmc1_chr0        (s_mapper_state+5)
#define s_mmc1_chr1        (s_mapper_state+6)
#define s_mmc1_prg         (s_mapper_state+7)
mapper_MMC1:
	push	{lr}
	ldrb	r3, [r9, #s_mmc1_shift_reg]
	tst	r0, #0x80
	bne	mmc1_reset
	and	r0, r0, #1
	movs	r3, r3, lsr #1
	orr	r0, r3, r0, lsl #4
	strb	r0, [r9, #s_mmc1_shift_reg]
	popcc	{pc}
	and	r2, r2, #0x6000
	add	r2, r9, r2, lsr #13
	strb	r0, [r2, #s_mmc1_control]
	b	mmc1_update
mmc1_reset:
	ldrb	r0, [r9, #s_mmc1_control]
	orr	r0, r0, #0x0C
	strb	r0, [r9, #s_mmc1_control]
mmc1_update:
	mov	r0, #0x10
	strb	r0, [r9, #s_mmc1_shift_reg]

	ldrb	r3, [r9, #s_mmc1_control]
	adr	lr, 1f
	and	r3, r3, #3
	add	pc, pc, r3, lsl #2
	nop
	b	mirror_1screen_lo
	b	mirror_1screen_hi
	b	mirror_vert
	b	mirror_horiz
1:

	@ Update CHR
	ldrb	r3, [r9, #s_mmc1_control]
	ldrb	r0, [r9, #s_mmc1_chr0]
	tst	r3, #0x10
	bne	1f
	mov	r0, r0, lsr #1
	bl	map_chr_8kB
	b	2f
1:	bl	map_chr_4kB_to_0000
	ldrb	r0, [r9, #s_mmc1_chr1]
	bl	map_chr_4kB_to_1000
2:

	@ Update PRG
	ldrb	r3, [r9, #s_mmc1_control]
	ldrb	r0, [r9, #s_mmc1_prg]
	@ Mode 0-1
	tst	r3, #0x08
	bne	1f
	mov	r0, r0, lsr #1
	bl	map_prg_32kB
	pop	{pc}
1:

	@ Mode 2
	tst	r3, #0x04
	bne	1f
	bl	map_prg_16kB_to_C000
	mov	r0, #0
	bl	map_prg_16kB_to_8000
	pop	{pc}
	@ Mode 3
1:	bl	map_prg_16kB_to_8000
	mov	r0, #-1
	bl	map_prg_16kB_to_C000
	pop	{pc}

mapper_UxROM:
	b	map_prg_16kB_to_8000

mapper_CNROM:
	b	map_chr_8kB

#define s_mmc3_bank              (s_mapper_state)
#define s_mmc3_bank_select       (s_mapper_state+8)
#define s_mmc3_counter_reload    (s_mapper_state+9)
#define s_mmc3_counter           (s_mapper_state+10)
#define s_mmc3_counter_reset     (s_mapper_state+11)
#define s_mmc3_irq_enabled       (s_mapper_state+12)
mapper_MMC3:
	and	r1, r2, #0x6000
	and	r2, r2, #0x0001
	orr	r2, r2, r1, lsr #12
	add	pc, pc, r2, lsl #2
	nop
	b	mmc3_bank_select
	b	mmc3_bank_data
	b	mmc3_mirroring
	bx	lr
	b	mmc3_irq_latch
	b	mmc3_irq_reload
	b	mmc3_irq_disable
	b	mmc3_irq_enable
mmc3_bank_select:
	strb	r0, [r9, #s_mmc3_bank_select]
	b	mmc3_update
mmc3_bank_data:
	ldrb	r1, [r9, #s_mmc3_bank_select]
	and	r3, r1, #7
	add	r3, r3, r9
	strb	r0, [r3, #s_mmc3_bank]
	b	mmc3_update
mmc3_mirroring:
	@ Don't do anything if game uses 4-screen mirroring
	ldr	r3, [r9, #s_rom_header]
	ldrb	r3, [r3, #6]
	tst	r3, #8
	bxne	lr
	tst	r0, #1
	beq	mirror_vert
	b	mirror_horiz
mmc3_irq_latch:
	strb	r0, [r9, #s_mmc3_counter_reload]
	bx	lr
mmc3_irq_reload:
	mov	r0, #0xFF
	strb	r0, [r9, #s_mmc3_counter_reset]
	bx	lr
mmc3_irq_disable:
	mov	r0, #0
	strb	r0, [r9, #s_irq_from_mapper]
mmc3_irq_enable:
	and	r0, r2, #1
	strb	r0, [r9, #s_mmc3_irq_enabled]
	bx	lr
.globl mmc3_scanline
mmc3_scanline:
	ldrb	r0, [r9, #s_mmc3_counter]

	ldrb	r1, [r9, #s_mmc3_counter_reset]
	bic	r1, r0, r1
	subs	r1, r1, #1
	ldrmib	r1, [r9, #s_mmc3_counter_reload]
	strb	r1, [r9, #s_mmc3_counter]
	mov	r2, #0
	strb	r2, [r9, #s_mmc3_counter_reset]

	cmp	r1, #0
	bxne	lr
	cmp	r0, #0
	bxeq	lr

	ldrb	r0, [r9, #s_mmc3_irq_enabled]
	strb	r0, [r9, #s_irq_from_mapper]
	bx	lr
mmc3_update:
	push	{r4, r5, lr}
	ldrb	r5, [r9, #s_mmc3_bank_select]

	mov	r4, #0x1000
	and	r4, r4, r5, lsl #5
	ldrb	r0, [r9, #s_mmc3_bank+0]; eor	r1, r4, #0x0000; bl	map_chr_2kB
	ldrb	r0, [r9, #s_mmc3_bank+1]; eor	r1, r4, #0x0800; bl	map_chr_2kB
	ldrb	r0, [r9, #s_mmc3_bank+2]; eor	r1, r4, #0x1000; bl	map_chr_1kB
	ldrb	r0, [r9, #s_mmc3_bank+3]; eor	r1, r4, #0x1400; bl	map_chr_1kB
	ldrb	r0, [r9, #s_mmc3_bank+4]; eor	r1, r4, #0x1800; bl	map_chr_1kB
	ldrb	r0, [r9, #s_mmc3_bank+5]; eor	r1, r4, #0x1C00; bl	map_chr_1kB

	mov	r4, #0x4000
	and	r4, r4, r5, lsl #8
	ldrb	r0, [r9, #s_mmc3_bank+6]; eor	r1, r4, #0x8000; bl	map_prg_8kB
	ldrb	r0, [r9, #s_mmc3_bank+7]; mov	r1,     #0xA000; bl	map_prg_8kB
	mov	r0, #-2;                  eor	r1, r4, #0xC000; bl	map_prg_8kB

	pop	{r4, r5, pc}

mapper_AxROM:
	push	{r4, lr}
	mov	r4, r0
	tst	r4, #0x10
	bleq	mirror_1screen_lo
	blne	mirror_1screen_hi
	mov	r0, r4
	pop	{r4, lr}
	b	map_prg_32kB

mapper_Color_Dreams:
	push	{r4, lr}
	mov	r4, r0
	bl	map_prg_32kB
	mov	r0, r4, lsr #4
	pop	{r4, lr}
	b	map_chr_8kB

mapper_BxROM:
	b	map_prg_32kB

mapper_GxROM:
	push	{r4, lr}
	mov	r4, r0
	bl	map_chr_8kB
	mov	r0, r4, lsr #4
	pop	{r4, lr}
	b	map_prg_32kB

mapper_Action_Enterprises:
	push	{r4, lr}
	mov	r4, r2
	and	r0, r0, #3
	orr	r0, r0, r2, lsl #2
	bl	map_chr_8kB
	mov	r0, r4, lsr #7
	and	r0, r0, #0x3F
	mov	r0, r0, lsl #15
	ldr	r1, [r9, #s_prg_size]
	ldr	r2, [r9, #s_prg_ptr]
	cmp	r0, r1
	andhi	r0, r0, r1
	add	r0, r0, r2
	bl	map_prg_32kB_from_pointer
	bl	mirror_vert
	pop	{r4, pc}

rom_file:
