FDD=/dev/fd0

.PHONY: all
all: MyOS.bin

MyOS.bin: Loader.bin Kernel.bin
	cat $^ > MyOS.bin

%.bin: %.asm
	nasm -f bin -o $@ $<

.PHONY: floppy
floppy: MyOS.bin
	dd if=MyOS.bin of=$(FDD)

.PHONY: clean
clean:
	rm -f *.bin
