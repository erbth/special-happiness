FDD=/dev/fd0

.PHONY: all
all: MyOS.bin size

MyOS.bin: Loader.bin Kernel.bin
	cat $^ > MyOS.bin

%.bin: %.asm
	nasm -f bin -o $@ $<

# print object size
.PHONY: size
size:
	ls -lh *.bin

.PHONY: floppy
floppy: MyOS.bin
	dd if=MyOS.bin of=$(FDD)

.PHONY: clean
clean:
	rm -f *.bin
