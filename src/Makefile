export OBJ_DIR:=../bin

export NASM=nasm
export CC="/home/therb/opt/cross/bin/i686-elf-gcc"
export LD="/home/therb/opt/cross/bin/i686-elf-ld"
export SIZE="/home/therb/opt/cross/bin/i686-elf-size"
export AWK=awk
export CAT=cat
export DD=dd
export QEMU=qemu-system-i386
export HTOINC:=../tools/htoinc.sh

export FD=/dev/fd0

export NFLAGS:=-f elf -F dwarf -I $(OBJ_DIR)/ -I ../include/
export CFLAGS:=-ffreestanding -O3 -Wall -Wextra -Werror -Wno-error=unused-parameter -Wno-error=unused-variable -std=gnu11 -fno-asynchronous-unwind-tables -I../include

OS_OBJECT:=special_happiness.img

STAGE1_OBJECT:=stage1.o
BOOTSTRAPPED_OBJECT:=bootstrapped.o
DYNAMIC_OBJECT:=dynamic.o

STAGE1_OBJS := \
	stage1_x86.asm.o

BOOTSTRAPPED_OBJS := \
	stage2_x86.asm.o \
	EarlyDynamicMemory16.asm.o \
	EarlyDynamicMemory32.asm.o \
	stage2_i386.c.o \
	cpu_utils.asm.o

DYNAMIC_OBJS :=

INTERMEDIATE_OBJS := $(STAGE1_OBJECT) $(BOOTSTRAPPED_OBJECT)

.PHONY: all
all: $(OBJ_DIR)/$(OS_OBJECT)

$(OBJ_DIR)/$(OS_OBJECT): ../linker_scripts/special_happiness.lds $(INTERMEDIATE_OBJS:%=$(OBJ_DIR)/%) | $(OBJ_DIR)
	$(LD) -T $< -o $@ $(INTERMEDIATE_OBJS:%=$(OBJ_DIR)/%)

$(OBJ_DIR)/$(STAGE1_OBJECT): ../linker_scripts/stage1.lds $(STAGE1_OBJS:%=$(OBJ_DIR)/%) | $(OBJ_DIR)
	$(LD) -r -d -T $< -o $@ $(STAGE1_OBJS:%=$(OBJ_DIR)/%)

$(OBJ_DIR)/$(BOOTSTRAPPED_OBJECT): ../linker_scripts/bootstrapped.lds $(BOOTSTRAPPED_OBJS:%=$(OBJ_DIR)/%) | $(OBJ_DIR)
	$(LD) -r -T $< -o $@ $(BOOTSTRAPPED_OBJS:%=$(OBJ_DIR)/%)

$(OBJ_DIR)/$(DYNAMIC_OBJECT): ../linker_scripts/dynamic.lds $(DYNAMIC_OBJS:%=$(OBJ_DIR)/%) | $(OBJ_DIR)
	$(LD) -r -T $< -o $@ $(DYNAMIC_OBJS:%=$(OBJ_DIR)/%)

$(OBJ_DIR)/%.asm.o: %.asm | $(OBJ_DIR)
	$(NASM) $(NFLAGS) -o $@ $<

$(OBJ_DIR)/%.c.o: %.c
	$(CC) $(CFLAGS) -o $@ -c $<


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
