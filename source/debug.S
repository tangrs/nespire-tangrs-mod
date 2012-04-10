#include "nes.inc"
#ifdef DEBUG

.globl	chrout
chrout:
	mov	r1,     #0x90000000
	add	r1, r1, #0x00020000
	strb	r0, [r1]
	bx	lr

.globl	hexout
hexout:
	mov	r2,     #0x90000000
	add	r2, r2, #0x00020000
hexloop:
	sub	r1, r1, #4
	mov	r3, r0, lsr r1
	and	r3, #15
	cmp	r3, #10
	addcc	r3, r3, #'0'
	addcs	r3, r3, #'A'-10
	strb	r3, [r2]
	cmp	r1, #0
	bne	hexloop
	bx	lr

.globl	fps_counter
fps_counter:
	push	{r0-r3,lr}
	ldr	r2, [r9, #s_frame_count]
	add	r2, r2, #1
	str	r2, [r9, #s_frame_count]
	ldr	r0, [r9, #s_frame_count_rtc]
	mov	r1, #0x90000000
	add	r1, r1, #0x00090000
	ldr	r1, [r1]
	str	r1, [r9, #s_frame_count_rtc]
	cmp	r0, r1
	popeq	{r0-r3,pc}
	mov	r0, r2
	mov	r1, #32
	bl	hexout
	mov	r0, #10
	bl	chrout
	mov	r2, #0
	str	r2, [r9, #s_frame_count]
	pop	{r0-r3,pc}

.globl	trace_read
trace_read:
	push	{r0-r12,lr}
	mov	r0, #'R'
	bl	chrout
	mov	r0, r2
	mov	r1, #16
	bl	hexout
	mov	r0, #13
	bl	chrout
	mov	r0, #10
	bl	chrout
	pop	{r0-r12,lr}
	b	mem_read+4

.globl	trace_write
trace_write:
	push	{r0-r12,lr}
	mov	r4, r0
	mov	r0, #'W'
	bl	chrout
	mov	r0, r2
	mov	r1, #16
	bl	hexout
	mov	r0, #'='
	bl	chrout
	mov	r0, r4
	mov	r1, #8
	bl	hexout
	mov	r0, #13
	bl	chrout
	mov	r0, #10
	bl	chrout
	pop	{r0-r12,lr}
	b	mem_write+4

.globl	trace
trace:
	push	{r0-r12, lr}
	mrs	r12, cpsr

	mov	r0, #'P'; bl chrout
	mov	r0, #'C'; bl chrout
	mov	r0, #'='; bl chrout

	ldr	r0, [r9, #s_pc_base]
	sub	r0, cpu_pc, r0
	sub	r0, r0, #1
	mov	r1, #16
	bl	hexout

	mov	r0, #'['; bl chrout
	ldrb	r0, [cpu_pc, #-1]
	mov	r1, #8
	bl	hexout
	mov	r0, #']'; bl chrout

	mov	r0, #' '; bl chrout

	mov	r0, #'A'; bl chrout
	mov	r0, #'='; bl chrout
	mov	r0, cpu_a, lsr #24; mov r1, #8; bl hexout

	mov	r0, #' '; bl chrout

	mov	r0, #'X'; bl chrout
	mov	r0, #'='; bl chrout
	mov	r0, cpu_x, lsr #24; mov r1, #8; bl hexout

	mov	r0, #' '; bl chrout

	mov	r0, #'Y'; bl chrout
	mov	r0, #'='; bl chrout
	mov	r0, cpu_y, lsr #24; mov r1, #8; bl hexout

	mov	r0, #' '; bl chrout

	mov	r0, #'F'; bl chrout
	mov	r0, #'='; bl chrout
	ldr	r4, [r9, #s_flags_di]
	mov	r0, #'N'; tst cpu_flags, #0x80000000; moveq r0, #'n'; bl chrout
	mov	r0, #'V'; tst cpu_flags, #0x10000000; moveq r0, #'v'; bl chrout
	mov	r0, #'-'; bl chrout
	mov	r0, #'-'; bl chrout
	mov	r0, #'D'; tst r4, #0x08;              moveq r0, #'d'; bl chrout
	mov	r0, #'I'; tst r4, #0x04;              moveq r0, #'i'; bl chrout
	mov	r0, #'Z'; tst cpu_flags, #0x40000000; moveq r0, #'z'; bl chrout
	mov	r0, #'C'; tst cpu_flags, #0x20000000; moveq r0, #'c'; bl chrout

	mov	r0, #' '; bl chrout

	mov	r0, #'S'; bl chrout
	mov	r0, #'='; bl chrout
	mov	r0, cpu_sp; mov r1, #8; bl hexout

	mov	r0, #' '; bl chrout
	ldr	r0, [r9, #s_ppu_scanline]
	mov	r1, #16; bl hexout
	mov	r0, #':'; bl chrout
	mov	r0, #0x0100
	add	r0, #0x0054
	sub	r0, cpu_cycles
	mov	r1, #16; bl hexout

	mov	r0, #13; bl chrout
	mov	r0, #10; bl chrout

	msr	cpsr_f, r12
	pop	{r0-r12, pc}
#endif
