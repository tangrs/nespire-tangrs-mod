#include "nes.inc"

	.string	"PRG"

.globl _start
_start:
	push	{r4-r11, lr}
	@ Allocate the state data structure from the stack and zero it out
	mov	r1, sp
	sub	sp, sp, #s_SIZE
	bic	sp, sp, #s_ALIGN - 1
	mov	r9, sp
	mov	r0, #0
	mov	r2, #s_SIZE
1:	subs	r2, r2, #4
	str	r0, [r9, r2]
	bne	1b
	str	r1, [r9, #s_saved_sp]

	@ Check hardware type
	ldr	r0, =0x900A0000
	ldr	r0, [r0]
	bic	r0, #0xFF000000
	cmp	r0, #0x10
	bne	1f
	@ Non-CX
	mov	r0, #0xDC000000
	add	r0, #0x08
	adr	r1, interrupt_handler_noncx
	mvn	r2, #0
	mov	r3, #0
	mov	r4, #3
	b	2f
1:
	sub	r0, #0x100
	cmp	r0, #0x001
	bne	unknown_hardware
	@ CX
	mov	r0, #0xDC000000
	add	r0, #0x10
	adr	r1, interrupt_handler_cx
	mov	r2, #0
	mov	r3, #1
	mov	r4, #1
2:
	str	r0, [r9, #s_hw_irq_masks]
	str	r1, [r9, #s_hw_irq_handler]
	str	r2, [r9, #s_hw_keypad_invert]
	str	r3, [r9, #s_hw_color]
	str	r4, [r9, #s_frameskip]

	bl	toggle_border

	bl	init_interrupts

	bl	init_keypad

	bl	load_rom

	@ Set CPU to power-on state
	mov	cpu_a, #0
	mov	cpu_x, #0
	mov	cpu_y, #0
	mov	cpu_sp, #0x100          @ RESET will bring this to 0x1FD
	mov	cpu_flags, #0

	@ Start CPU emulation
	b	reset

.globl	exit_emulator
exit_emulator:
	bl	restore_interrupts
unknown_hardware:
	ldr	sp, [r9, #s_saved_sp]
	pop	{r4-r11, pc}

init_interrupts:
	str	r9, [pc, #state_ptr - (.+8)]

	msr	cpsr_c, #0xD3           @ Interrupts off

	@ Disable everything except the timer interrupt (IRQ 19)
	ldr	r0, [r9, #s_hw_irq_masks]
	ldr	r2, [r0]
	str	r2, [r9, #s_saved_irq_mask]
	str	r2, [r0, #4]
	mov	r2, #1 << 19
	str	r2, [r0]

	@ Set the IRQ vector
	mov	r1, #0xA4000000
	ldr	r2, [r1, #0x38]
	str	r2, [r9, #s_saved_irq_handler]
	ldr	r2, [r9, #s_hw_irq_handler]
	str	r2, [r1, #0x38]

	msr	cpsr_c, #0x13           @ Interrupts on
	bx	lr

interrupt_handler_cx:
	push	{r0-r1, lr}
	ldr	r0, =0x900D0000
	mov	r1, #1
	str	r1, [r0, #0x0C]
	b	interrupt_handler_common
interrupt_handler_noncx:
	push	{r0-r1, lr}
	mov	r0, #0xDC000000
	ldr	r1, =0x900A0000
	ldr	lr, [r0, #0x24]
	ldr	lr, [r0, #0x28]
	mov	lr, #1
	str	lr, [r1, #0x20]
	mov	lr, #1 << 19
	str	lr, [r0, #0x04]
	mov	lr, #8
	str	lr, [r0, #0x2C]
interrupt_handler_common:
	@ Advance the frame timer by 3/300 of a second
	ldr	r1, [pc, #state_ptr - (.+8)]
	ldrb	lr, [r1, #s_frame_timer]
	add	lr, lr, #3
	strb	lr, [r1, #s_frame_timer]
	pop	{r0-r1, lr}
	subs	pc, lr, #4
	.pool
state_ptr:
	.word	0

restore_interrupts:
	msr	cpsr_c, #0xD3           @ Interrupts off

	ldr	r0, [r9, #s_hw_irq_masks]
	mvn	r2, #0
	str	r2, [r0, #4]
	ldr	r2, [r9, #s_saved_irq_mask]
	str	r2, [r0]

	mov	r1, #0xA4000000
	ldr	r2, [r9, #s_saved_irq_handler]
	str	r2, [r1, #0x38]
	bx	lr

.globl newframe
newframe:
	str	lr, [sp, #-4]!

	ldr	r0, [r9, #s_frameskip_cur]
	ldr	r10, [r9, #s_frameskip]
	subs	r0, r0, #1
	addmi	r0, r0, r10
	str	r0, [r9, #s_frameskip_cur]

	mov	r8, #0
pause_loop:

#define num_command_keys 11
	@ Scan keypad
	ldr	r3, [r9, #s_hw_keypad_invert]
	mov	r4, #0
	ldr	r5, =0x900E0010
	mov	r6, #num_command_keys - 1
	ldr	r7, [r9, #s_keypad_command_map]
1:	ldrb	r0, [r7, r6]
	and	r1, r0, #0x60
	ldr	r1, [r5, r1, lsr #3]
	eor	r1, r3, r1, ror r0
	and	r1, #1
	orr	r4, r1, lsl r6
	subs	r6, #1
	bpl	1b

	ldr	r5, [r9, #s_command_keys_pressed]
	str	r4, [r9, #s_command_keys_pressed]
	bic	r5, r4, r5

//	tst	r5, #1 << 0;	movne	r10, #1
//	tst	r5, #1 << 1;	movne	r10, #2
//	tst	r5, #1 << 2;	movne	r10, #3
//	tst	r5, #1 << 3;	movne	r10, #4
//	tst	r5, #1 << 4;	movne	r10, #5
//	tst	r5, #1 << 5;	movne	r10, #6
	tst	r5, #1 << 6;	blne	toggle_border	@ B (Border)
	tst	r5, #1 << 7;	blne	invert_colors   @ R (Reverse)
	tst	r5, #1 << 8;	bne	exit_emulator   @ Q (Quit)
	tst	r5, #1 << 9;	mvnne	r8, r8          @ P (Pause)
	tst	r4, #1 << 10;	bne	fast_forward    @ *

	@ Keep looping until the frame timer reaches 5/300 (1/60) of a second
	ldrb	r0, [r9, #s_frame_timer]
	subs	r0, r0, #5
	movcc	r0, #0
	mcrcc	p15, 0, r0, c7, c0, 4
	bcc	pause_loop
	strb	r0, [r9, #s_frame_timer]
#ifdef DEBUG
	bl	fps_counter
#endif
	movs	r8, r8
	bne	pause_loop
fast_forward:
	str	r10, [r9, #s_frameskip]

	ldr	lr, [sp], #4
	ldr	pc, [r9, #s_keypad_update_input]

init_keypad:
	str	lr, [sp, #-4]!

	@ Temporarily enable access to the ADC (if it wasn't enabled already)
	@ and get the last read value from channel 3 (keypad type)
	@ Would use the system call, but it wasn't present yet in Ndless 1.7
	ldr	r0, =0x900B0018
	ldr	r1, [r0]
	bic	r2, r1, #0x10
	str	r2, [r0]
	mov	r2, #0xC4000000
	ldr	r2, [r2, #0x170]
	str	r1, [r0]

	sub	r2, #0x40
	cmp	r2, #0x59 - 0x40
	adrcc	r2, touchpad_command_map
	adrcs	r2, clickpad_command_map
	str	r2, [r9, #s_keypad_command_map]
	adrcc	r2, touchpad_update_input
	adrcs	r2, clickpad_update_input
	str	r2, [r9, #s_keypad_update_input]

	ldrcs	pc, [sp], #4

	mov	r0, #0xFF
	mov	r1, #0xFF
	adr	r2, touchpad_info_page
	swi	e_touchpad_write
	mov	r0, #0x04
	mov	r1, #0x07
	add	r2, r9, #s_touchpad_size
	swi	e_touchpad_read
	mov	r0, #0xFF
	mov	r1, #0xFF
	adr	r2, touchpad_main_page
	swi	e_touchpad_write

	ldr	pc, [sp], #4

touchpad_info_page:
	.byte	0x10
touchpad_main_page:
	.byte	0x04

	@       1    2    3    4    5    6    B    R    Q    P    *
clickpad_command_map:
	.byte	0x17,0x15,0x13,0x27,0x25,0x23,0x64,0x24,0x26,0x28,0x31
touchpad_command_map:
	.byte	0x17,0x64,0x13,0x27,0x56,0x23,0x45,0x20,0x21,0x22,0x48

	.align	4

clickpad_update_input:
	mvn	r2, #0xFF
	ldr	r0, =0x900E0000
	ldrd	r0, [r0, #0x18]
	ldr	r3, [r9, #s_hw_keypad_invert]
	eor	r0, r3
	eor	r1, r3
	tst	r0, #1 << 25;	orrne	r2, r2, #0x08	@ Caps (Start)
	tst	r1, #1 << 7;	orrne	r2, r2, #0x01	@ Esc (A)
	tst	r1, #1 << 9;	orrne	r2, r2, #0x02	@ Tab (B)
	tst	r1, #1 << 16;	orrne	r2, r2, #0x10	@ Up
	tst	r1, #1 << 18;	orrne	r2, r2, #0x80	@ Right
	tst	r1, #1 << 20;	orrne	r2, r2, #0x20	@ Down
	tst	r1, #1 << 22;	orrne	r2, r2, #0x40	@ Left
	tst	r1, #1 << 24;	orrne	r2, r2, #0x04	@ Clear (Select)
	str	r2, [r9, #s_input_status]
	bx	lr

touchpad_update_input:
    push {r4, lr}
	mvn	r2, #0xFF
	ldr	r0, =0x900E0000
	ldr r4, [r0, #0x14]
	ldrd	r0, [r0, #0x18]
	ldr	r3, [r9, #s_hw_keypad_invert]
	eor	r0, r3
	eor	r1, r3
	eor r4, r3
	tst	r0, #1 << 17;	orrne	r2, r2, #0x08	@ Var (Start)
	tst	r1, #1 << 3;	orrne	r2, r2, #0x01	@ Doc (A)
	tst	r1, #1 << 5;	orrne	r2, r2, #0x02	@ Menu (B)
	tst	r1, #1 << 6;	orrne	r2, r2, #0x10	@ 8 (Up)
	tst	r4, #1 << 3;	orrne	r2, r2, #0x80	@ 6 (Right)
	tst	r0, #1 << 22;	orrne	r2, r2, #0x20	@ 5 (Down)
	tst	r4, #1 << 7;	orrne	r2, r2, #0x40	@ 4 (Left)
	tst	r0, #1 << 25;	orrne	r2, r2, #0x04	@ Del (Select)
	str	r2, [r9, #s_input_status]
	pop {r4, pc}

	.pool
