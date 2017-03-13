NASM=nasm
CAT=cat
DD=dd
SUDO=sudo

FD=/dev/fd0

.PHONY: all
all: MyOS.bin

MyOS.bin: Loader.bin
	$(CAT) $^ > $@

Loader.bin: Loader_stage1.bin Loader_stage2.bin
	$(CAT) $^ > $@

%.bin: %.asm
	$(NASM) -f bin -o $@ $^

.PHONY: clean
clean:
	rm -f *.bin

floppy: MyOS.bin
	$(SUDO) $(DD) if=$< of=$(FD)
