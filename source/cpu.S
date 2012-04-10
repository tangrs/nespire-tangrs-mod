#include "nes.inc"

@ NES 2A03 (like 6502, just without decimal mode) CPU emulation core
@ Some caveats:
@ - Code is assumed to be contiguous in memory (apparently "The Magic of
@   Scheherazade" violates this by having code cross from bank 3 to bank 7,
@   but it's not worth it to kill performance just for one obscure game)
@ - Extra memory accesses (in read-modify-write instructions,
@   or indexing carry) are not implemented
@ - Most of the "undocumented" instructions are not implemented

.equ	NES_FLAG_C, 0x01
.equ	NES_FLAG_Z, 0x02
.equ	NES_FLAG_I, 0x04
.equ	NES_FLAG_D, 0x08
.equ	NES_FLAG_B, 0x10
.equ	NES_FLAG_V, 0x40
.equ	NES_FLAG_N, 0x80
.equ	ARM_FLAG_V, 0x10000000
.equ	ARM_FLAG_C, 0x20000000
.equ	ARM_FLAG_Z, 0x40000000
.equ	ARM_FLAG_N, 0x80000000

@ Advance to next instruction. Its first byte must be pre-loaded into r1.
.macro	NEXT	cycles
	subs	cpu_cycles, cpu_cycles, #\cycles * CPU_CYCLE_LENGTH
	TRACE
	addpl	pc, cpu_itable, r1, lsl #2
	b	cpu_leave
.endm

@ To avoid having to deal with the whole Cartesian product of operations and
@ addressing modes, we make the assembler generate them with macros. Each R_*,
@ W_*, or RMW_* macro is a template for instructions that do read, write, or
@ read-modify-write operations, respectively, in a particular addressing mode.

.macro	R_Imm op
	ldrb	r0, [cpu_pc], #1
	ldrb	r1, [cpu_pc], #1
	\op
	NEXT	2
.endm

.macro	RMW_Reg reg, op
	ldrb	r1, [cpu_pc], #1
	\op	\reg
	NEXT	2
.endm
.macro	RMW_A op; RMW_Reg cpu_a, \op; .endm
.macro	RMW_X op; RMW_Reg cpu_x, \op; .endm
.macro	RMW_Y op; RMW_Reg cpu_y, \op; .endm

.macro	R_Zp op
	ldrb	r2, [cpu_pc], #1
	ldrb	r1, [cpu_pc], #1
	ldrb	r0, [r9, r2]
	\op
	NEXT	3
.endm
.macro	W_Zp op
	ldrb	r2, [cpu_pc], #1
	ldrb	r1, [cpu_pc], #1
	\op
	strb	r0, [r9, r2]
	NEXT	3
.endm
.macro	RMW_Zp op
	ldrb	r2, [cpu_pc], #1
	ldrb	r1, [cpu_pc], #1
	ldrb	r0, [r9, r2]
	\op
	strb	r0, [r9, r2]
	NEXT	5
.endm

.macro	R_Zp_XY index, op
	ldrb	r2, [cpu_pc], #1
	ldrb	r1, [cpu_pc], #1
	add	r2, \index, r2, lsl #24
	ldrb	r0, [r9, r2, lsr #24]
	\op
	NEXT	4
.endm
.macro	W_Zp_XY index, op
	ldrb	r2, [cpu_pc], #1
	ldrb	r1, [cpu_pc], #1
	\op
	add	r2, \index, r2, lsl #24
	strb	r0, [r9, r2, lsr #24]
	NEXT	4
.endm
.macro	RMW_Zp_XY index, op
	ldrb	r2, [cpu_pc], #1
	ldrb	r1, [cpu_pc], #1
	add	r2, \index, r2, lsl #24
	ldrb	r0, [r9, r2, lsr #24]
	\op
	strb	r0, [r9, r2, lsr #24]
	NEXT	6
.endm
.macro R_Zp_X op; R_Zp_XY cpu_x, \op; .endm
.macro R_Zp_Y op; R_Zp_XY cpu_y, \op; .endm
.macro W_Zp_X op; W_Zp_XY cpu_x, \op; .endm
.macro W_Zp_Y op; W_Zp_XY cpu_y, \op; .endm
.macro RMW_Zp_X op; RMW_Zp_XY cpu_x, \op; .endm

.macro	R_Abs op
	ldrb	r2, [cpu_pc], #1
	ldrb	r3, [cpu_pc], #1
	ldrb	r1, [cpu_pc], #1
	bl	mem_read_split
	\op
	NEXT	4
.endm
.macro	W_Abs op
	ldrb	r2, [cpu_pc], #1
	ldrb	r3, [cpu_pc], #1
	ldrb	r1, [cpu_pc], #1
	\op
	bl	mem_write_split
	NEXT	4
.endm
.macro	RMW_Abs op
	ldrb	r2, [cpu_pc], #1
	ldrb	r3, [cpu_pc], #1
	ldrb	r1, [cpu_pc], #1
	bl	mem_read_split
	\op
	bl	mem_write
	NEXT	6
.endm

.macro	R_Abs_XY index, op
	ldrb	r2, [cpu_pc], #1
	ldrb	r3, [cpu_pc], #1
	ldrb	r1, [cpu_pc], #1
	add	r2, r2, \index, lsr #24
	tst	r2, #0x100
	subne	cpu_cycles, cpu_cycles, #CPU_CYCLE_LENGTH
	bl	mem_read_split
	\op
	NEXT	4
.endm
.macro	W_Abs_XY index, op
	ldrb	r2, [cpu_pc], #1
	ldrb	r3, [cpu_pc], #1
	ldrb	r1, [cpu_pc], #1
	add	r2, r2, \index, lsr #24
	\op
	bl	mem_write_split
	NEXT	5
.endm
.macro	RMW_Abs_XY index, op
	ldrb	r2, [cpu_pc], #1
	ldrb	r3, [cpu_pc], #1
	ldrb	r1, [cpu_pc], #1
	add	r2, r2, \index, lsr #24
	bl	mem_read_split
	\op
	bl	mem_write
	NEXT	7
.endm
.macro R_Abs_X op; R_Abs_XY cpu_x, \op; .endm
.macro R_Abs_Y op; R_Abs_XY cpu_y, \op; .endm
.macro W_Abs_X op; W_Abs_XY cpu_x, \op; .endm
.macro W_Abs_Y op; W_Abs_XY cpu_y, \op; .endm
.macro RMW_Abs_X op; RMW_Abs_XY cpu_x, \op; .endm
.macro RMW_Abs_Y op; RMW_Abs_XY cpu_y, \op; .endm

.macro	R_Ind_X op
	ldrb	r3, [cpu_pc], #1
	ldrb	r1, [cpu_pc], #1
	add	r3, cpu_x, r3, lsl #24
	ldrb	r2, [r9, r3, lsr #24]
	add	r3, r3, #0x01000000
	ldrb	r3, [r9, r3, lsr #24]
	bl	mem_read_split
	\op
	NEXT	6
.endm
.macro	W_Ind_X op
	ldrb	r3, [cpu_pc], #1
	ldrb	r1, [cpu_pc], #1
	\op
	add	r3, cpu_x, r3, lsl #24
	ldrb	r2, [r9, r3, lsr #24]
	add	r3, r3, #0x01000000
	ldrb	r3, [r9, r3, lsr #24]
	bl	mem_write_split
	NEXT	6
.endm
.macro	RMW_Ind_X op
	ldrb	r3, [cpu_pc], #1
	ldrb	r1, [cpu_pc], #1
	add	r3, cpu_x, r3, lsl #24
	ldrb	r2, [r9, r3, lsr #24]
	add	r3, r3, #0x01000000
	ldrb	r3, [r9, r3, lsr #24]
	bl	mem_read_split
	\op
	bl	mem_write
	NEXT	8
.endm

.macro	R_Ind_Y op
	ldrb	r3, [cpu_pc], #1
	ldrb	r1, [cpu_pc], #1
	ldrb	r2, [r9, r3]
	add	r3, r3, #1
	and	r3, r3, #0xFF
	ldrb	r3, [r9, r3]
	add	r2, r2, cpu_y, lsr #24
	tst	r2, #0x100
	subne	cpu_cycles, cpu_cycles, #CPU_CYCLE_LENGTH
	bl	mem_read_split
	\op
	NEXT	5
.endm
.macro	W_Ind_Y op
	ldrb	r3, [cpu_pc], #1
	ldrb	r1, [cpu_pc], #1
	\op
	ldrb	r2, [r9, r3]
	add	r3, r3, #1
	and	r3, r3, #0xFF
	ldrb	r3, [r9, r3]
	add	r2, r2, cpu_y, lsr #24
	bl	mem_write_split
	NEXT	6
.endm
.macro	RMW_Ind_Y op
	ldrb	r3, [cpu_pc], #1
	ldrb	r1, [cpu_pc], #1
	ldrb	r2, [r9, r3]
	add	r3, r3, #1
	and	r3, r3, #0xFF
	ldrb	r3, [r9, r3]
	add	r2, r2, cpu_y, lsr #24
	bl	mem_read_split
	\op
	bl	mem_write
	NEXT	8
.endm

@ Read operations

.macro	OP_LDA
	bic	cpu_flags, cpu_flags, #ARM_FLAG_N | ARM_FLAG_Z
	movs	cpu_a, r0, lsl #24
	orrmi	cpu_flags, cpu_flags, #ARM_FLAG_N
	orreq	cpu_flags, cpu_flags, #ARM_FLAG_Z
.endm
.macro	OP_LDX
	bic	cpu_flags, cpu_flags, #ARM_FLAG_N | ARM_FLAG_Z
	movs	cpu_x, r0, lsl #24
	orrmi	cpu_flags, cpu_flags, #ARM_FLAG_N
	orreq	cpu_flags, cpu_flags, #ARM_FLAG_Z
.endm
.macro	OP_LDY
	bic	cpu_flags, cpu_flags, #ARM_FLAG_N | ARM_FLAG_Z
	movs	cpu_y, r0, lsl #24
	orrmi	cpu_flags, cpu_flags, #ARM_FLAG_N
	orreq	cpu_flags, cpu_flags, #ARM_FLAG_Z
.endm
.macro	OP_ORA
	bic	cpu_flags, cpu_flags, #ARM_FLAG_N | ARM_FLAG_Z
	orrs	cpu_a, cpu_a, r0, lsl #24
	orrmi	cpu_flags, cpu_flags, #ARM_FLAG_N
	orreq	cpu_flags, cpu_flags, #ARM_FLAG_Z
.endm
.macro	OP_AND
	bic	cpu_flags, cpu_flags, #ARM_FLAG_N | ARM_FLAG_Z
	ands	cpu_a, cpu_a, r0, lsl #24
	orrmi	cpu_flags, cpu_flags, #ARM_FLAG_N
	orreq	cpu_flags, cpu_flags, #ARM_FLAG_Z
.endm
.macro	OP_EOR
	bic	cpu_flags, cpu_flags, #ARM_FLAG_N | ARM_FLAG_Z
	eors	cpu_a, cpu_a, r0, lsl #24
	orrmi	cpu_flags, cpu_flags, #ARM_FLAG_N
	orreq	cpu_flags, cpu_flags, #ARM_FLAG_Z
.endm
.macro	OP_CMP
	@ ARM sets V, 6502 does not, so must deal with flags manually
	bic	cpu_flags, cpu_flags, #ARM_FLAG_N | ARM_FLAG_Z | ARM_FLAG_C
	cmp	cpu_a, r0, lsl #24
	orrmi	cpu_flags, cpu_flags, #ARM_FLAG_N
	orreq	cpu_flags, cpu_flags, #ARM_FLAG_Z
	orrcs	cpu_flags, cpu_flags, #ARM_FLAG_C
.endm
.macro	OP_CPX
	bic	cpu_flags, cpu_flags, #ARM_FLAG_N | ARM_FLAG_Z | ARM_FLAG_C
	cmp	cpu_x, r0, lsl #24
	orrmi	cpu_flags, cpu_flags, #ARM_FLAG_N
	orreq	cpu_flags, cpu_flags, #ARM_FLAG_Z
	orrcs	cpu_flags, cpu_flags, #ARM_FLAG_C
.endm
.macro	OP_CPY
	bic	cpu_flags, cpu_flags, #ARM_FLAG_N | ARM_FLAG_Z | ARM_FLAG_C
	cmp	cpu_y, r0, lsl #24
	orrmi	cpu_flags, cpu_flags, #ARM_FLAG_N
	orreq	cpu_flags, cpu_flags, #ARM_FLAG_Z
	orrcs	cpu_flags, cpu_flags, #ARM_FLAG_C
.endm
.macro	OP_ADC
	msr	cpsr_f, cpu_flags
	subcs	r0, r0, #0x100
	adcs	cpu_a, cpu_a, r0, ror #8
	mrs	cpu_flags, cpsr
.endm
.macro	OP_SBC
	msr	cpsr_f, cpu_flags
	subcc	r0, r0, #0x100
	sbcs	cpu_a, cpu_a, r0, ror #8
	mrs	cpu_flags, cpsr
.endm
.macro	OP_BIT
	bic	cpu_flags, #ARM_FLAG_N | ARM_FLAG_Z | ARM_FLAG_V
	tst	cpu_a, r0, lsl #24
	orreq	cpu_flags, cpu_flags, #ARM_FLAG_Z
	movs	r0, r0, lsl #25
	orrcs	cpu_flags, cpu_flags, #ARM_FLAG_N
	orrmi	cpu_flags, cpu_flags, #ARM_FLAG_V
.endm

@ Write operations

.macro	OP_STA
	mov	r0, cpu_a, lsr #24
.endm
.macro	OP_STX
	mov	r0, cpu_x, lsr #24
.endm
.macro	OP_STY
	mov	r0, cpu_y, lsr #24
.endm

@ Read-modify-write operations

.macro	OP_ASL
	msr	cpsr_f, cpu_flags
	movs	r0, r0, lsl #25
	mrs	cpu_flags, cpsr
	mov	r0, r0, lsr #24
.endm
.macro	OP_ASLR	reg
	msr	cpsr_f, cpu_flags
	movs	\reg, \reg, lsl #1
	mrs	cpu_flags, cpsr
.endm
.macro	OP_ROL
	mov	r0, r0, lsl #24
	tst	cpu_flags, #ARM_FLAG_C
	addne	r0, r0, #0x800000
	msr	cpsr_f, cpu_flags
	movs	r0, r0, lsl #1
	mrs	cpu_flags, cpsr
	mov	r0, r0, lsr #24
.endm
.macro	OP_ROLR	reg
	tst	cpu_flags, #ARM_FLAG_C
	addne	\reg, \reg, #0x800000
	msr	cpsr_f, cpu_flags
	movs	\reg, \reg, lsl #1
	mrs	cpu_flags, cpsr
.endm
.macro	OP_LSR
	msr	cpsr_f, cpu_flags
	movs	r0, r0, lsr #1
	mrs	cpu_flags, cpsr
.endm
.macro	OP_LSRR	reg
	msr	cpsr_f, cpu_flags
	movs	\reg, \reg, lsr #25
	mov	\reg, \reg, lsl #24
	mrs	cpu_flags, cpsr
.endm
.macro	OP_ROR
	msr	cpsr_f, cpu_flags
	movs	r0, r0, rrx
	mrs	cpu_flags, cpsr
	orr	r0, r0, lsr #24
.endm
.macro	OP_RORR	reg
	mov	\reg, \reg, lsr #24
	msr	cpsr_f, cpu_flags
	movs	\reg, \reg, rrx
	mrs	cpu_flags, cpsr
	orr	\reg, \reg, lsl #24
	and	\reg, \reg, #0xFF000000
.endm
.macro	OP_DEC
	bic	cpu_flags, cpu_flags, #ARM_FLAG_N | ARM_FLAG_Z
	sub	r0, r0, #1
	movs	r3, r0, lsl #24
	orrmi	cpu_flags, cpu_flags, #ARM_FLAG_N
	orreq	cpu_flags, cpu_flags, #ARM_FLAG_Z
.endm
.macro	OP_DECR	reg
	bic	cpu_flags, cpu_flags, #ARM_FLAG_N | ARM_FLAG_Z
	subs	\reg, \reg, #0x01000000
	orrmi	cpu_flags, cpu_flags, #ARM_FLAG_N
	orreq	cpu_flags, cpu_flags, #ARM_FLAG_Z
.endm
.macro	OP_INC
	bic	cpu_flags, cpu_flags, #ARM_FLAG_N | ARM_FLAG_Z
	add	r0, r0, #1
	movs	r3, r0, lsl #24
	orrmi	cpu_flags, cpu_flags, #ARM_FLAG_N
	orreq	cpu_flags, cpu_flags, #ARM_FLAG_Z
.endm
.macro	OP_INCR	reg
	bic	cpu_flags, cpu_flags, #ARM_FLAG_N | ARM_FLAG_Z
	adds	\reg, \reg, #0x01000000
	orrmi	cpu_flags, cpu_flags, #ARM_FLAG_N
	orreq	cpu_flags, cpu_flags, #ARM_FLAG_Z
.endm

#define R(op, arg) R_##arg OP_##op
#define W(op, arg) W_##arg OP_##op
#define RMW(op, arg) RMW_##arg OP_##op

@ Other stuff...

.macro SPUSH reg
	strb	\reg, [r9, cpu_sp]
	sub	cpu_sp, cpu_sp, #1
	orr	cpu_sp, cpu_sp, #0x100
.endm
.macro SPULL reg
	add	cpu_sp, cpu_sp, #1
	bic	cpu_sp, cpu_sp, #0x200
	orr	cpu_sp, cpu_sp, #0x100
	ldrb	\reg, [r9, cpu_sp]
.endm

.macro INTERRUPT num, flags
	.if num == 0xFFFC
		subs	cpu_sp, cpu_sp, #3
		orr	cpu_sp, cpu_sp, #0x100
	.else
		bl	push_pc
		mov	r2, #\flags
		bl	push_flags
	.endif
	ldr	r0, [r9, #s_flags_di]
	ldr	r2, [r9, #s_mem_map + 28]
	orr	r0, r0, #NES_FLAG_I
	str	r0, [r9, #s_flags_di]
	add	r2, r2, #0x10000
	ldrh	r2, [r2, #\num - 0x10000]
	bl	mem_jump
	NEXT	7
.endm

.macro BRANCH flag, value
	tst	cpu_flags, #ARM_FLAG_\flag
	ldrsb	r2, [cpu_pc], #1
	.if \value
		bne	take_branch
	.else
		beq	take_branch
	.endif
	ldrb	r1, [cpu_pc], #1
	NEXT	2
.endm
take_branch:
	@ Get PC
	ldr	r0, [r9, #s_pc_base]
	sub	cpu_pc, cpu_pc, r0
	@ Add the branch offset already stored in r2
	add	r2, cpu_pc, r2
	bic	r2, r2, #0xFF000000
	bic	r2, r2, #0x00FF0000
	@ Extra cycle if page changed
	eor	r0, cpu_pc, r2
	tst	r0, #0xFF00
	subne	cpu_cycles, cpu_cycles, #CPU_CYCLE_LENGTH
	@ Set new PC
	bl	mem_jump
	NEXT	3

.macro CHANGE_FLAG op, flag
	.if NES_FLAG_\flag & 0xC3
		ldrb	r1, [cpu_pc], #1
		\op	cpu_flags, cpu_flags, #ARM_FLAG_\flag
	.else
		ldr	r0, [r9, #s_flags_di]
		ldrb	r1, [cpu_pc], #1
		\op	r0, r0, #NES_FLAG_\flag
		str	r0, [r9, #s_flags_di]
	.endif
	NEXT	2
.endm

push_flags:
	ldr	r0, [r9, #s_flags_di]
	msr	cpsr_f, cpu_flags
	orrmi	r0, r0, #NES_FLAG_N
	orrvs	r0, r0, #NES_FLAG_V
	orreq	r0, r0, #NES_FLAG_Z
	orrcs	r0, r0, #NES_FLAG_C
	orr	r0, r0, r2
	SPUSH	r0
	bx	lr
pull_flags:
	SPULL	r0
	and	r2, r0, #0x0C
	str	r2, [r9, #s_flags_di]
	bic	cpu_flags, cpu_flags, #ARM_FLAG_N|ARM_FLAG_Z|ARM_FLAG_C|ARM_FLAG_V
	and	r2, r0, #NES_FLAG_N
	orr	cpu_flags, cpu_flags, r2, lsl #24
	and	r2, r0, #NES_FLAG_V
	orr	cpu_flags, cpu_flags, r2, lsl #22
	and	r2, r0, #NES_FLAG_Z | NES_FLAG_C
	orr	cpu_flags, cpu_flags, r2, lsl #29
	bx	lr
push_pc:
	ldr	r0, [r9, #s_pc_base]
	sub	r0, cpu_pc, r0
	mov	r1, r0, lsr #8
	SPUSH	r1
	SPUSH	r0
	bx	lr

.global	reset
reset:
	mov	r0, #0
	str	r0, [r9, #s_ppu_scanline]
	mov	cpu_cycles, #-1

	strb	cpu_cycles, [r9, #s_nmi_reset]  @ 0xFF = reset

main_loop:
	add	cpu_cycles, cpu_cycles, #0x100
	add	cpu_cycles, cpu_cycles, #0x055
	adr	cpu_itable, insn_table

	ldr	r2, [r9, #s_interrupts]
	ldr	r0, [r9, #s_flags_di]
	movs	r2, r2
	bmi	nmi_or_reset
	beq	cpu_enter
	tst	r0, #NES_FLAG_I
	beq	irq

cpu_enter:
	ldrb	r1, [cpu_pc], #1
	TRACE
	add	pc, cpu_itable, r1, lsl #2
cpu_leave:
	sub	cpu_pc, cpu_pc, #1

	bl	ppu_next_scanline

	@ TODO: this should be for MMC3 only
	ldr	r0, [r9, #s_ppu_control]
	tst	r0, #0x1800
	beq	1f
	ldr	r0, [r9, #s_ppu_scanline]
	cmp	r0, #241
	blcc	mmc3_scanline
1:

	b	main_loop

nmi_or_reset:
	tst	r2, #0x7F000000
	bic	r2, r2, #0xFF000000
	str	r2, [r9, #s_interrupts]
	bne	intr_reset
	INTERRUPT 0xFFFA, 0x20
intr_reset:
	INTERRUPT 0xFFFC, 0x00
irq:
	INTERRUPT 0xFFFE, 0x20

insn_table:
	b insn_00;b insn_01;b insn_02;b insn_03;b insn_04;b insn_05;b insn_06;b insn_07
	b insn_08;b insn_09;b insn_0a;b insn_0b;b insn_0c;b insn_0d;b insn_0e;b insn_0f
	b insn_10;b insn_11;b insn_12;b insn_13;b insn_14;b insn_15;b insn_16;b insn_17
	b insn_18;b insn_19;b insn_1a;b insn_1b;b insn_1c;b insn_1d;b insn_1e;b insn_1f
	b insn_20;b insn_21;b insn_22;b insn_23;b insn_24;b insn_25;b insn_26;b insn_27
	b insn_28;b insn_29;b insn_2a;b insn_2b;b insn_2c;b insn_2d;b insn_2e;b insn_2f
	b insn_30;b insn_31;b insn_32;b insn_33;b insn_34;b insn_35;b insn_36;b insn_37
	b insn_38;b insn_39;b insn_3a;b insn_3b;b insn_3c;b insn_3d;b insn_3e;b insn_3f
	b insn_40;b insn_41;b insn_42;b insn_43;b insn_44;b insn_45;b insn_46;b insn_47
	b insn_48;b insn_49;b insn_4a;b insn_4b;b insn_4c;b insn_4d;b insn_4e;b insn_4f
	b insn_50;b insn_51;b insn_52;b insn_53;b insn_54;b insn_55;b insn_56;b insn_57
	b insn_58;b insn_59;b insn_5a;b insn_5b;b insn_5c;b insn_5d;b insn_5e;b insn_5f
	b insn_60;b insn_61;b insn_62;b insn_63;b insn_64;b insn_65;b insn_66;b insn_67
	b insn_68;b insn_69;b insn_6a;b insn_6b;b insn_6c;b insn_6d;b insn_6e;b insn_6f
	b insn_70;b insn_71;b insn_72;b insn_73;b insn_74;b insn_75;b insn_76;b insn_77
	b insn_78;b insn_79;b insn_7a;b insn_7b;b insn_7c;b insn_7d;b insn_7e;b insn_7f
	b insn_80;b insn_81;b insn_82;b insn_83;b insn_84;b insn_85;b insn_86;b insn_87
	b insn_88;b insn_89;b insn_8a;b insn_8b;b insn_8c;b insn_8d;b insn_8e;b insn_8f
	b insn_90;b insn_91;b insn_92;b insn_93;b insn_94;b insn_95;b insn_96;b insn_97
	b insn_98;b insn_99;b insn_9a;b insn_9b;b insn_9c;b insn_9d;b insn_9e;b insn_9f
	b insn_a0;b insn_a1;b insn_a2;b insn_a3;b insn_a4;b insn_a5;b insn_a6;b insn_a7
	b insn_a8;b insn_a9;b insn_aa;b insn_ab;b insn_ac;b insn_ad;b insn_ae;b insn_af
	b insn_b0;b insn_b1;b insn_b2;b insn_b3;b insn_b4;b insn_b5;b insn_b6;b insn_b7
	b insn_b8;b insn_b9;b insn_ba;b insn_bb;b insn_bc;b insn_bd;b insn_be;b insn_bf
	b insn_c0;b insn_c1;b insn_c2;b insn_c3;b insn_c4;b insn_c5;b insn_c6;b insn_c7
	b insn_c8;b insn_c9;b insn_ca;b insn_cb;b insn_cc;b insn_cd;b insn_ce;b insn_cf
	b insn_d0;b insn_d1;b insn_d2;b insn_d3;b insn_d4;b insn_d5;b insn_d6;b insn_d7
	b insn_d8;b insn_d9;b insn_da;b insn_db;b insn_dc;b insn_dd;b insn_de;b insn_df
	b insn_e0;b insn_e1;b insn_e2;b insn_e3;b insn_e4;b insn_e5;b insn_e6;b insn_e7
	b insn_e8;b insn_e9;b insn_ea;b insn_eb;b insn_ec;b insn_ed;b insn_ee;b insn_ef
	b insn_f0;b insn_f1;b insn_f2;b insn_f3;b insn_f4;b insn_f5;b insn_f6;b insn_f7
	b insn_f8;b insn_f9;b insn_fa;b insn_fb;b insn_fc;b insn_fd;b insn_fe;b insn_ff

insn_00: @ BRK
	add	cpu_pc, cpu_pc, #1
	INTERRUPT 0xFFFE, 0x30
insn_01: R(ORA, Ind_X)
insn_05: R(ORA, Zp)
insn_06: RMW(ASL, Zp)
insn_08: @ PHP
	ldrb	r1, [cpu_pc], #1
	mov	r2, #0x30
	bl	push_flags
	NEXT	3
insn_09: R(ORA, Imm)
insn_0a: RMW(ASLR, A)
insn_0d: R(ORA, Abs)
insn_0e: RMW(ASL, Abs)
insn_10: BRANCH N, 0 @ BPL
insn_11: R(ORA, Ind_Y)
insn_15: R(ORA, Zp_X)
insn_16: RMW(ASL, Zp_X)
insn_18: CHANGE_FLAG bic, C
insn_19: R(ORA, Abs_Y)
insn_1d: R(ORA, Abs_X)
insn_1e: RMW(ASL, Abs_X)
insn_20: @ JSR Absolute
	ldrb	r2, [cpu_pc], #1
	ldrb	r3, [cpu_pc]
	bl	push_pc
	bl	mem_jump_split
	NEXT	6
insn_21: R(AND, Ind_X)
insn_24: R(BIT, Zp)
insn_25: R(AND, Zp)
insn_26: RMW(ROL, Zp)
insn_28: @ PLP
	ldrb	r1, [cpu_pc], #1
	bl	pull_flags
	NEXT	4
insn_29: R(AND, Imm)
insn_2a: RMW(ROLR, A)
insn_2c: R(BIT, Abs)
insn_2d: R(AND, Abs)
insn_2e: RMW(ROL, Abs)
insn_30: BRANCH N, 1
insn_31: R(AND, Ind_Y)
insn_35: R(AND, Zp_X)
insn_36: RMW(ROL, Zp_X)
insn_38: CHANGE_FLAG orr, C
insn_39: R(AND, Abs_Y)
insn_3d: R(AND, Abs_X)
insn_3e: RMW(ROL, Abs_X)
insn_40: @ RTI
	bl	pull_flags
	SPULL	r2
	SPULL	r3
	bl	mem_jump_split
	NEXT	6
insn_41: R(EOR, Ind_X)
insn_45: R(EOR, Zp)
insn_46: RMW(LSR, Zp)
insn_48: @ PHA
	mov	r0, cpu_a, lsr #24
	ldrb	r1, [cpu_pc], #1
	SPUSH	r0
	NEXT	3
insn_49: R(EOR, Imm)
insn_4a: RMW(LSRR, A)
insn_4c: @ JMP Absolute
	ldrb	r2, [cpu_pc], #1
	ldrb	r3, [cpu_pc], #1
	bl	mem_jump_split
	NEXT	3
insn_4d: R(EOR, Abs)
insn_4e: RMW(LSR, Abs)
insn_50: BRANCH V, 0
insn_51: R(EOR, Ind_Y)
insn_55: R(EOR, Zp_X)
insn_56: RMW(LSR, Zp_X)
insn_58: CHANGE_FLAG bic, I
insn_59: R(EOR, Abs_Y)
insn_5d: R(EOR, Abs_X)
insn_5e: RMW(LSR, Abs_X)
insn_60: @ RTS
	SPULL	r2
	SPULL	r3
	add	r2, r2, #1
	bl	mem_jump_split
	NEXT	6
insn_61: R(ADC, Ind_X)
insn_65: R(ADC, Zp)
insn_66: RMW(ROR, Zp)
insn_68: @ PLA
	SPULL	r0
	ldrb	r1, [cpu_pc], #1
	msr	cpsr_f, cpu_flags
	mov	r0, r0, lsl #24
	movs	cpu_a, r0
	mrs	cpu_flags, cpsr
	NEXT	4
insn_69: R(ADC, Imm)
insn_6a: RMW(RORR, A)
insn_6c: @ JMP Indirect
	ldrb	r2, [cpu_pc], #1
	ldrb	r3, [cpu_pc], #1
	bl	mem_read_split
	mov	r1, r0
	add	r2, r2, #1
	tst	r2, #0xFF
	subeq	r2, r2, #0x100          @ Correct for "bug"
	bl	mem_read
	add	r2, r1, r0, lsl #8
	bl	mem_jump
	NEXT	5
insn_6d: R(ADC, Abs)
insn_6e: RMW(ROR, Abs)
insn_70: BRANCH V, 1
insn_71: R(ADC, Ind_Y)
insn_75: R(ADC, Zp_X)
insn_76: RMW(ROR, Zp_X)
insn_78: CHANGE_FLAG orr, I
insn_79: R(ADC, Abs_Y)
insn_7d: R(ADC, Abs_X)
insn_7e: RMW(ROR, Abs_X)
insn_81: W(STA, Ind_X)
insn_84: W(STY, Zp)
insn_85: W(STA, Zp)
insn_86: W(STX, Zp)
insn_88: RMW(DECR, Y)
insn_8a: @ TXA
	ldrb	r1, [cpu_pc], #1
	msr	cpsr_f, cpu_flags
	movs	cpu_a, cpu_x
	mrs	cpu_flags, cpsr
	NEXT	2
insn_8c: W(STY, Abs)
insn_8d: W(STA, Abs)
insn_8e: W(STX, Abs)
insn_90: BRANCH C, 0
insn_91: W(STA, Ind_Y)
insn_94: W(STY, Zp_X)
insn_95: W(STA, Zp_X)
insn_96: W(STX, Zp_Y)
insn_98: @ TYA
	ldrb	r1, [cpu_pc], #1
	msr	cpsr_f, cpu_flags
	movs	cpu_a, cpu_y
	mrs	cpu_flags, cpsr
	NEXT	2
insn_99: W(STA, Abs_Y)
insn_9a: @ TXS
	ldrb	r1, [cpu_pc], #1
	mov	cpu_sp, cpu_x, lsr #24
	orr	cpu_sp, cpu_sp, #0x100
	NEXT	2
insn_9d: W(STA, Abs_X)
insn_a0: R(LDY, Imm)
insn_a1: R(LDA, Ind_X)
insn_a2: R(LDX, Imm)
insn_a4: R(LDY, Zp)
insn_a5: R(LDA, Zp)
insn_a6: R(LDX, Zp)
insn_a8: @ TAY
	ldrb	r1, [cpu_pc], #1
	msr	cpsr_f, cpu_flags
	movs	cpu_y, cpu_a
	mrs	cpu_flags, cpsr
	NEXT	2
insn_a9: R(LDA, Imm)
insn_aa: @ TAX
	ldrb	r1, [cpu_pc], #1
	msr	cpsr_f, cpu_flags
	movs	cpu_x, cpu_a
	mrs	cpu_flags, cpsr
	NEXT	2
insn_ac: R(LDY, Abs)
insn_ad: R(LDA, Abs)
insn_ae: R(LDX, Abs)
insn_b0: BRANCH C, 1
insn_b1: R(LDA, Ind_Y)
insn_b4: R(LDY, Zp_X)
insn_b5: R(LDA, Zp_X)
insn_b6: R(LDX, Zp_Y)
insn_b8: CHANGE_FLAG bic, V
insn_b9: R(LDA, Abs_Y)
insn_ba: @ TSX
	ldrb	r1, [cpu_pc], #1
	msr	cpsr_f, cpu_flags
	mov	r0, cpu_sp, lsl #24
	movs	cpu_x, r0
	mrs	cpu_flags, cpsr
	NEXT	2
insn_bc: R(LDY, Abs_X)
insn_bd: R(LDA, Abs_X)
insn_be: R(LDX, Abs_Y)
insn_c0: R(CPY, Imm)
insn_c1: R(CMP, Ind_X)
insn_c4: R(CPY, Zp)
insn_c5: R(CMP, Zp)
insn_c6: RMW(DEC, Zp)
insn_c8: RMW(INCR, Y)
insn_c9: R(CMP, Imm)
insn_ca: RMW(DECR, X)
insn_cc: R(CPY, Abs)
insn_cd: R(CMP, Abs)
insn_ce: RMW(DEC, Abs)
insn_d0: BRANCH Z, 0
insn_d1: R(CMP, Ind_Y)
insn_d5: R(CMP, Zp_X)
insn_d6: RMW(DEC, Zp_X)
insn_d8: CHANGE_FLAG bic, D
insn_d9: R(CMP, Abs_Y)
insn_dd: R(CMP, Abs_X)
insn_de: RMW(DEC, Abs_X)
insn_e0: R(CPX, Imm)
insn_e1: R(SBC, Ind_X)
insn_e4: R(CPX, Zp)
insn_e5: R(SBC, Zp)
insn_e6: RMW(INC, Zp)
insn_e8: RMW(INCR, X)
insn_eb: @ undocumented SBC #Imm
insn_e9: R(SBC, Imm)
insn_ec: R(CPX, Abs)
insn_ed: R(SBC, Abs)
insn_ee: RMW(INC, Abs)
insn_f0: BRANCH Z, 1
insn_f1: R(SBC, Ind_Y)
insn_f5: R(SBC, Zp_X)
insn_f6: RMW(INC, Zp_X)
insn_f8: CHANGE_FLAG orr, D
insn_f9: R(SBC, Abs_Y)
insn_fd: R(SBC, Abs_X)
insn_fe: RMW(INC, Abs_X)

@ No-ops
insn_14: @ NOP Zp,X
insn_34: @ NOP Zp,X
insn_54: @ NOP Zp,X
insn_74: @ NOP Zp,X
insn_d4: @ NOP Zp,X
insn_f4: @ NOP Zp,X
	sub	cpu_cycles, cpu_cycles, #CPU_CYCLE_LENGTH
insn_04: @ NOP Zp
insn_44: @ NOP Zp
insn_64: @ NOP Zp
	sub	cpu_cycles, cpu_cycles, #CPU_CYCLE_LENGTH
insn_80: @ NOP Imm
insn_82: @ NOP Imm
insn_89: @ NOP Imm
insn_c2: @ NOP Imm
insn_e2: @ NOP Imm
	add	cpu_pc, cpu_pc, #1
insn_1a: @ NOP
insn_3a: @ NOP
insn_5a: @ NOP
insn_7a: @ NOP
insn_da: @ NOP
insn_ea: @ NOP (official)
insn_fa: @ NOP
	ldrb	r1, [cpu_pc], #1
	NEXT	2

@ Opcodes with undocumented functionality (not implemented)
insn_03:
insn_07:
insn_0b:
insn_0c:
insn_0f:
insn_13:
insn_17:
insn_1b:
insn_1c:
insn_1f:
insn_23:
insn_27:
insn_2b:
insn_2f:
insn_33:
insn_37:
insn_3b:
insn_3c:
insn_3f:
insn_43:
insn_47:
insn_4b:
insn_4f:
insn_53:
insn_57:
insn_5b:
insn_5c:
insn_5f:
insn_63:
insn_67:
insn_6b:
insn_6f:
insn_73:
insn_77:
insn_7b:
insn_7c:
insn_7f:
insn_83:
insn_87:
insn_8b:
insn_8f:
insn_93:
insn_97:
insn_9b:
insn_9c:
insn_9e:
insn_9f:
insn_a3:
insn_a7:
insn_ab:
insn_af:
insn_b3:
insn_b7:
insn_bb:
insn_bf:
insn_c3:
insn_c7:
insn_cb:
insn_cf:
insn_d3:
insn_d7:
insn_db:
insn_dc:
insn_df:
insn_e3:
insn_e7:
insn_ef:
insn_f3:
insn_f7:
insn_fb:
insn_fc:
insn_ff:
@ Opcodes that hang the CPU
insn_02:
insn_12:
insn_22:
insn_32:
insn_42:
insn_52:
insn_62:
insn_72:
insn_92:
insn_b2:
insn_d2:
insn_f2:
	ERROR	0x0000
