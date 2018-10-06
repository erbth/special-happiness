export OBJ_DIR:=../bin
export INC_DIR:=../include

export NASM=nasm
export CC="/home/therb/opt/cross/bin/i686-elf-gcc"
export LDCC=$(CC)
export LD="/home/therb/opt/cross/bin/i686-elf-ld"
export SIZE="/home/therb/opt/cross/bin/i686-elf-size"
export AWK=awk
export CAT=cat
export DD=dd
export QEMU=qemu-system-i386
export HTOINC:=../tools/htoinc.sh
export INCTOH:=../tools/inctoh.sh

export FD=/dev/fd0

export NFLAGS:=-f elf -F dwarf -I $(OBJ_DIR)/ -I $(INC_DIR)/
export CFLAGS:=-ffreestanding -O3 -Wall -Wextra -Werror -Wno-error=unused-parameter -Wno-error=unused-variable -std=gnu11 -fno-asynchronous-unwind-tables -I$(INC_DIR) -I$(OBJ_DIR)
export LDCFALGS=$(CFLAGS)

OS_OBJECT:=special_happiness.img

STAGE1_OBJECT:=stage1.o
BOOTSTRAPPED_OBJECT:=bootstrapped.o

STAGE1_OBJS := \
	stage1_x86.asm.o

BOOTSTRAPPED_OBJS := \
	stage2_x86.asm.o \
	EarlyDynamicMemory16.asm.o \
	SystemMemoryMap16.asm.o \
	stage2_i386.c.o \
	cpu_utils.asm.o \
	PageFrameAllocator.c.o \
	SystemMemoryMap.c.o \
	MemoryAllocator.c.o

INTERMEDIATE_OBJS := $(STAGE1_OBJECT) $(BOOTSTRAPPED_OBJECT)

.PHONY: all
all: $(OBJ_DIR)/$(OS_OBJECT)

$(OBJ_DIR)/$(OS_OBJECT): ../linker_scripts/special_happiness.lds $(INTERMEDIATE_OBJS:%=$(OBJ_DIR)/%) | $(OBJ_DIR)
	$(LD) -T $< -o $@ $(INTERMEDIATE_OBJS:%=$(OBJ_DIR)/%)

$(OBJ_DIR)/$(STAGE1_OBJECT): ../linker_scripts/stage1.lds $(STAGE1_OBJS:%=$(OBJ_DIR)/%) | $(OBJ_DIR)
	$(LD) -r -d -T $< -o $@ $(STAGE1_OBJS:%=$(OBJ_DIR)/%)

$(OBJ_DIR)/$(BOOTSTRAPPED_OBJECT): ../linker_scripts/bootstrapped.lds $(BOOTSTRAPPED_OBJS:%=$(OBJ_DIR)/%) | $(OBJ_DIR)
	$(LDCC) $(LDCFLAGS) -r -T $< -o $@ $(BOOTSTRAPPED_OBJS:%=$(OBJ_DIR)/%) -nostdlib -lgcc


$(OBJ_DIR)/%.asm.o: %.asm | $(OBJ_DIR)
	$(NASM) $(NFLAGS) -o $@ $<

$(OBJ_DIR)/%.c.o: %.c $(OBJ_DIR)/SystemMemoryMap.inc.h
	$(CC) $(CFLAGS) -o $@ -c $<


$(OBJ_DIR)/%.inc.h: $(INC_DIR)/%.inc $(INCTOH) | $(OBJ_DIR)
	$(INCTOH) $< $@


.PHONY: floppy
floppy: $(OBJ_DIR)/$(OS_OBJECT)
	$(DD) if=$< of=$(FD)

.PHONY: qemu
qemu: $(OBJ_DIR)/$(OS_OBJECT)
	$(QEMU) -drive file=$<,format=raw,if=floppy,index=0 -boot a

$(OBJ_DIR):
	mkdir -p $@

.PHONY: clean
clean:
	rm -rf $(OBJ_DIR)
