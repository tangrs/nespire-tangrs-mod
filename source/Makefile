PREFIX=arm-none-eabi-

nes.bin : nes.elf
	$(PREFIX)objcopy -Obinary $< $@

nes.elf : main.o cpu.o debug.o memory.o ppu.o rom.o
	$(PREFIX)ld main.o cpu.o debug.o memory.o ppu.o rom.o -o $@

%.o : %.S
	$(PREFIX)gcc -c $< -o $@
