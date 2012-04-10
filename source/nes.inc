//#define DEBUG

//#define TRACE bl trace
#define TRACE

#ifdef DEBUG
.macro	ERROR	code
	bkpt	#\code
.endm
.macro	CERROR	cond, code
	b\cond	.+8
	b	.+8
	bkpt	#\code
.endm
#else
.macro	ERROR	code
	b	exit_emulator
.endm
.macro	CERROR	cond, code
	b\cond	exit_emulator
.endm
#endif

// System calls
#define e_touchpad_read 75
#define e_touchpad_write 76

// Global data structure: r9 points to this at all times
// Note some requirements:
// * to do "ldr reg, [r9, #s_xxx]", offset must be below 0x1000
// * to do "add reg, r9, #s_xxx",   offset must be representable as a shifted byte
// When changing an existing offset, don't forget to "del *.o"!

#define s_wram                  0x0000  // 0800 bytes

// CPU data
#define s_mem_map               0x0800  // 0024 bytes (9 entries, 4 bytes each)
#define s_flags_di              0x0824  // 0004 bytes
#define s_pc_base               0x0828  // 0004 bytes
#define s_interrupts            0x082C
#define s_irq_from_apu          0x082C
#define s_irq_from_mapper       0x082D
#define s_nmi_reset             0x082F  // set to FF for reset, 80 for nmi

#define s_input_status          0x0840
#define s_input_queue           0x0844

// PPU ("Picture Processing Unit") data
#define s_ppu_mem_map           0x0880  // 0040 bytes
#define s_ppu_palette           0x08C0  // 0020 bytes
#define s_ppu_flags             0x08E0
#define s_ppu_control           s_ppu_flags+0   // $2000
#define s_ppu_mask              s_ppu_flags+1   // $2001
#define s_ppu_status            s_ppu_flags+2   // $2002
#define s_ppu_oam_addr          0x08E4          // $2003
#define s_ppu_scroll            0x08E8          // $2005 (x/y toggle in bit 16, x fine in bits 29-31)
#define s_ppu_address           0x08EC          // $2006
#define s_ppu_data              0x08F0          // $2007 buffer
#define s_ppu_scanline          0x08F4
#define s_ppu_oam_ram           0x0900  // 0100 bytes - must be 256-byte aligned

// Emulation data (no relation to anything in an actual NES)
#define s_frame_count           0x0A00
#define s_frame_count_rtc       0x0A04
#define s_saved_sp              0x0A08
#define s_frame_timer           0x0A0C
#define s_touchpad_size         0x0A10
#define s_keypad_command_map    0x0A14
#define s_keypad_update_input   0x0A18
#define s_command_keys_pressed  0x0A1C
#define s_saved_irq_mask        0x0A20
#define s_saved_irq_handler     0x0A24
#define s_frameskip             0x0A28
#define s_frameskip_cur         0x0A2C
#define s_spr_loc_table_valid   0x0A30
#define s_hw_irq_masks          0x0A34
#define s_hw_irq_handler        0x0A38
#define s_hw_keypad_invert      0x0A3C
#define s_palette_cache         0x0A40  // 0080 bytes
#define s_palette_cache_valid   0x0AC0
#define s_hw_color              0x0AC4
#define s_border_color          0x0AC8

// ROM data
#define s_rom_header            0x0AE0
#define s_mapper                0x0AEC
#define s_prg_size              0x0AF0
#define s_prg_ptr               0x0AF4
#define s_chr_size              0x0AF8
#define s_chr_ptr               0x0AFC

#define s_mapper_state          0x0B00  // 0010 bytes

// The big stuff
#define s_spr_loc_table         0x0B90  // 0870 bytes (9 * 240)
#define s_name_table_ram        0x1400  // 1000 bytes - must be 128-byte aligned
#define s_chr_ram               0x2400  // 2000 bytes
#define s_sram                  0x4400  // 2000 bytes

#define s_SIZE                  0x6400
#define s_ALIGN                 0x0100

// CPU register usage:
// r0 = general purpose temporary
// r1 = next instruction byte
// r2 = address low byte or full address
// r3 = address high byte
#define cpu_pc          r4
#define cpu_cycles      r5
#define cpu_a           r6
#define cpu_x           r7
#define cpu_y           r8
#define cpu_sp          r10
#define cpu_flags       r11
#define cpu_itable      r12

#define CPU_CYCLE_LENGTH 3
