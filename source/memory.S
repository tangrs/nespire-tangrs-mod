#include "nes.inc"

.globl	mem_read_split
.globl	mem_read
.globl	mem_write_split
.globl	mem_write
.globl	mem_jump_split
.globl	mem_jump

@ Input:
@   r2 = address low byte (split), full address (unsplit)
@   r3 = address high byte (split)
@ Output:
@   r0 = byte read
@   r2 = full address
@   r3 invalidated
@   All other registers preserved

mem_read_split:
	add	r2, r2, r3, lsl #8
mem_read:
	mov	r3, r2, lsr #13
	add	pc, pc, r3, lsl #4
	nop
mem_read_ram:
@ 0000-1FFF: RAM
	bic	r3, r2, #0x11800
	ldrb	r0, [r9, r3]
	bx	lr
	nop
@ 2000-3FFF: PPU registers
	and	r3, r2, #7
	add	r3, pc, r3, lsl #2
	add	pc, r3, #ppu_read_table - (. + 4)
	nop
@ 4000-5FFF: 2A03 registers
	sub	r3, r2, #0x4000
	cmp	r3, #0x16
	beq	mem_read_4016
	b	mem_read_bad
@ 6000-7FFF: SRAM
	add	r3, r9, #s_sram - 0x6000
	ldrb	r0, [r3, r2]
	bx	lr
	nop
@ 8000-9FFF: ROM
	ldr	r3, [r9, #s_mem_map + 0x10]
	ldrb	r0, [r3, r2]
	bx	lr
	nop
@ A000-BFFF: ROM
	ldr	r3, [r9, #s_mem_map + 0x14]
	ldrb	r0, [r3, r2]
	bx	lr
	nop
@ C000-DFFF: ROM
	ldr	r3, [r9, #s_mem_map + 0x18]
	ldrb	r0, [r3, r2]
	bx	lr
	nop
@ E000-FFFF: ROM
	ldr	r3, [r9, #s_mem_map + 0x1C]
	ldrb	r0, [r3, r2]
	bx	lr
	nop
@ 10000-100FE: RAM (overflow)
	b	mem_read_ram
mem_read_bad:
	@ TODO: print debug message
	mov	r0, #0
	bx	lr
ppu_read_table:
	b	mem_read_bad
	b	mem_read_bad
	b	mem_read_2002
	b	mem_read_bad
	b	mem_read_2004
	b	mem_read_bad
	b	mem_read_bad
mem_read_2007:
	ldr	r2, [r9, #s_ppu_address]
	bic	r2, r2, #0xC000
	mov	r3, r2, lsr #10
	add	r3, r9, r3, lsl #2

	@ Buffered VRAM read
	ldr	r3, [r3, #s_ppu_mem_map]
	ldrb	r0, [r9, #s_ppu_data]
	ldrb	r3, [r3, r2]
	strb	r3, [r9, #s_ppu_data]

	@ Palette is read directly
	cmp	r2, #0x3F00
	andcs	r2, r2, #0x1F
	addcs	r3, r9, #s_ppu_palette
	ldrcsb	r0, [r3, r2]

	@ Advance ppu_address by 1 or 32
	ldr	r3, [r9, #s_ppu_control]
	ldr	r2, [r9, #s_ppu_address]
	tst	r3, #0x04
	addeq	r2, r2, #0x0001
	addne	r2, r2, #0x0020
	bic	r2, r2, #0x8000
	str	r2, [r9, #s_ppu_address]
	@ Fix our flagrant mangling of r2
	mov	r2, #0x2000
	add	r2, r2, #0x7
	bx	lr
mem_read_2004:
	ldrb	r3, [r9, #s_ppu_oam_addr]
	add	r0, r9, #s_ppu_oam_ram
	ldrb	r0, [r0, r3]
	and	r3, r3, #0x03
	cmp	r3, #0x02
	andeq	r0, r0, #0xE3
	bx	lr
mem_read_2002:
	ldrb	r0, [r9, #s_ppu_status]
	mov	r3, #0x00
	strb	r3, [r9, #s_ppu_scroll+2]
	bic	r3, r0, #0x80
	strb	r3, [r9, #s_ppu_status]
	bx	lr

mem_read_4016:
	ldr	r3, [r9, #s_input_queue]
	and	r0, r3, #1
	mov	r3, r3, asr #1
	str	r3, [r9, #s_input_queue]
	bx	lr

@ Input:
@   r0 = byte to write (high bits ignored)
@   r2 = address low byte (split), full address (unsplit)
@   r3 = address high byte (split)
@ Output:
@   r0, r2, r3 invalidated
@   All other registers preserved

mem_write_split:
	add	r2, r2, r3, lsl #8
mem_write:
	@push	{r0}
	@mov	r3, r2, lsr #13
	@add	r3, r9, r3, lsl #2
	@ldr	r0, [r3, #0xC00]
	@add	r0, r0, #1
	@str	r0, [r3, #0xC00]
	@pop	{r0}
	mov	r3, r2, lsr #13
	add	pc, pc, r3, lsl #4
	nop
@ 0000-1FFF: RAM
mem_write_ram:
	bic	r3, r2, #0x11800
	strb	r0, [r9, r3]
	bx	lr
	nop
@ 2000-3FFF: PPU registers
	and	r3, r2, #7
	add	r3, pc, r3, lsl #2
	add	pc, r3, #ppu_write_table - (. + 4)
	nop
@ 4000-5FFF: APU registers
	sub	r3, r2, #0x4000
	b	mem_write_4000_to_4017
	nop
	nop
@ 6000-7FFF: SRAM
	add	r3, r9, #s_sram - 0x6000
	strb	r0, [r3, r2]
	bx	lr
	nop
@ 8000-FFFF: Mapper registers
	.rept	4
		str	lr, [sp, #-4]!
		adr	lr, return_from_mapper
		ldr	pc, [r9, #s_mapper]
		nop
	.endr
@ 10000-100FE: RAM (overflow)
	b	mem_write_ram
return_from_mapper:
	ldr	r0, [r9, #s_pc_base]
	ldr	lr, [sp], #4
	sub	r4, r4, #1
	sub	r2, r4, r0
	b	mem_jump

ppu_write_table:
	b	mem_write_2000
	b	mem_write_2001
	bx	lr	@ No-op
	b	mem_write_2003
	b	mem_write_2004
	b	mem_write_2005
	b	mem_write_2006
@ Reg 2007:
mem_write_2007:
	ldr	r2, [r9, #s_ppu_address]
	bic	r2, r2, #0xC000

	cmp	r2, #0x3F00
	bcs	mem_write_2007_palette
	mov	r3, r2, lsr #10
	add	r3, r9, r3, lsl #2
	ldr	r3, [r3, #s_ppu_mem_map]
	strb	r0, [r3, r2]    @ TODO: don't allow write to CHR-ROM

	b	mem_write_2007_common
mem_write_2007_palette:
	and	r0, r0, #0x3F
	and	r2, r2, #0x1F

	@ +00/+10, +04/+14, +08/+18, +0C/+1C are mirrored pairs
	add	r3, r9, #s_ppu_palette
	tst	r2, #0x03
	strb	r0, [r3, r2]
	eoreq	r2, r2, #0x10
	streqb	r0, [r3, r2]

	mov	r0, #0
	strb	r0, [r9, #s_palette_cache_valid]
mem_write_2007_common:
	@ Advance ppu_address by 1 or 32
	ldr	r3, [r9, #s_ppu_control]
	ldr	r2, [r9, #s_ppu_address]
	tst	r3, #0x04
	addeq	r2, r2, #0x0001
	addne	r2, r2, #0x0020
	bic	r2, r2, #0x8000
	str	r2, [r9, #s_ppu_address]
	bx	lr

@ Reg 2006: Set PPU address, first hi byte, then lo
mem_write_2006:
	ldr	r3, [r9, #s_ppu_scroll]
	tst	r3, #0x10000
	eor	r3, r3, #0x10000
	str	r3, [r9, #s_ppu_scroll]
	bne	mem_write_2006_second
mem_write_2006_first:
	and	r0, r0, #0x3F
	strb	r0, [r9, #s_ppu_scroll + 1]
	bx	lr
mem_write_2006_second:
	strb	r0, [r9, #s_ppu_scroll]
	strb	r0, [r9, #s_ppu_address]
	mov	r0, r3, lsr #8
	strb	r0, [r9, #s_ppu_address + 1]
	bx	lr
@ Reg 2005: Set scroll position, first x, then y
mem_write_2005:
	ldr	r3, [r9, #s_ppu_scroll]
	and	r0, r0, #0xFF
	tst	r3, #0x10000
	eor	r3, r3, #0x10000
	bne	mem_write_2005_second
mem_write_2005_first:
	bic	r3, r3, #0xE0000000
	bic	r3, r3, #0x0000001F
	orr	r3, r3, r0, ror #3
	str	r3, [r9, #s_ppu_scroll]
	bx	lr
mem_write_2005_second:
	mov	r0, r0, ror #3
	bic	r3, r3, #0x03E0
	orr	r3, r3, r0, lsl #5
	bic	r3, r3, #0x7000
	orr	r3, r3, r0, lsr #17
	str	r3, [r9, #s_ppu_scroll]
	bx	lr
@ Reg 2004: Sprite data
mem_write_2004:
	ldrb	r3, [r9, #s_ppu_oam_addr]
	add	r2, r9, #s_ppu_oam_ram
	strb	r0, [r2, r3]
	add	r3, r3, #1
	strb	r3, [r9, #s_ppu_oam_addr]
	mov	r0, #0
	strb	r0, [r9, #s_spr_loc_table_valid]
	bx	lr
@ Reg 2003: Sprite address
mem_write_2003:
	strb	r0, [r9, #s_ppu_oam_addr]
	bx	lr
@ Reg 2001: PPU Mask
mem_write_2001:
	strb	r0, [r9, #s_ppu_mask]
	bx	lr
@ Reg 2000: PPU Control
mem_write_2000:
	@ TODO: if sprites changed 8x8 <-> 8x16, invalidate table
	ldr	r3, [r9, #s_ppu_scroll]
	strb	r0, [r9, #s_ppu_control]
	bic	r3, #0x0C00
	and	r0, r0, #0x03
	orr	r3, r3, r0, lsl #10
	str	r3, [r9, #s_ppu_scroll]
	@ TODO: Generate NMI if 2002.b7 set and 2000.b7 changed from 0 to 1
	bx	lr

mem_write_4000_to_4017:
	cmp	r3, #0x14
	beq	mem_write_4014
	cmp	r3, #0x16
	bxne	lr
mem_write_4016:
	ldr	r0, [r9, #s_input_status]
	str	r0, [r9, #s_input_queue]
	bx	lr

mem_write_4014:
	push	{r1}

	@ Store 256 bytes to OAM RAM
	mov	r0, r0, lsl #8
	mov	r2, r0, lsr #13
	add	r2, r9, r2, lsl #2
	ldr	r2, [r2, #s_mem_map]
	add	r0, r2, r0

	ldrb	r3, [r9, #s_ppu_oam_addr]
	add	r2, r9, #s_ppu_oam_ram
	add	r2, r2, r3
	rsb	r3, r3, #0x100
mem_write_4014_loop:
	ldrb	r1, [r0], #1
	subs	r3, r3, #1
	strb	r1, [r2], #1
	bne	mem_write_4014_loop

	ldrb	r3, [r9, #s_ppu_oam_addr]
	add	r2, r9, #s_ppu_oam_ram
	cmp	r3, #0
	beq	mem_write_4014_done
mem_write_4014_loop2:
	ldrb	r1, [r0], #1
	subs	r3, r3, #1
	strb	r1, [r2], #1
	bne	mem_write_4014_loop2
mem_write_4014_done:
	mov	r0, #0
	strb	r0, [r9, #s_spr_loc_table_valid]
	pop	{r1}
	@ CPU is paused for 513 cycles while the transfer completes
	sub	cpu_cycles, cpu_cycles, #512 * CPU_CYCLE_LENGTH
	sub	cpu_cycles, cpu_cycles, #1 * CPU_CYCLE_LENGTH
	bx	lr

mem_jump_split:
	add	r2, r2, r3, lsl #8
mem_jump:
	@ Most jumps will probably be to ROM. Optimize for higher addresses
	cmp	r2, #0x6000
	bcc	mem_jump_low
mem_jump_ok:
	mov	r0, r2, lsr #13
	add	r0, r9, r0, lsl #2
	ldr	r0, [r0, #s_mem_map]
	str	r0, [r9, #s_pc_base]

	add	cpu_pc, r0, r2
	ldrb	r1, [cpu_pc], #1
	bx	lr
mem_jump_low:
	cmp	r2, #0x2000
	biccc	r2, r2, #0x1800   @ RAM mirroring
	bcc	mem_jump_ok
	@ Jump to 2000-5FFF range - should never happen.
	ERROR	0x0001
