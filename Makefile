NFLAGS=-f elf
OBJ_DIR=obj

NASM=nasm
LD=ld
SIZE=size
AWK=awk
OBJCOPY=objcopy
DD=dd
SUDO=sudo

FD=/dev/fd0

TARGET=MyOS
STAGE1=Stage1
STAGE2=Stage2
LOADER=Loader
LOADER_SIZE_CONSTANTS=Loader_size_constants
KERNEL=Kernel
ENTRY=Entry

# Order matters!
BINARY_COMPONENTS= $(LOADER).o $(KERNEL).o

# Order matters!
LOADER_COMPONENTS=$(STAGE1).o $(STAGE2).o

# Order matters!
KERNEL_COMPONENTS=$(ENTRY).o text.o

# Order matters!
STAGE1_OBJ=Loader_stage1.o
STAGE2_OBJ=Loader_stage2.o \
           Loader_floppy.o

.PHONY: all
all: $(OBJ_DIR) $(OBJ_DIR)/$(TARGET).bin

$(OBJ_DIR)/$(TARGET).bin: $(BINARY_COMPONENTS:%=$(OBJ_DIR)/%)
	$(LD) -T flat_binary.lds -o $@ $^

$(OBJ_DIR)/$(LOADER).o: $(LOADER_COMPONENTS:%=$(OBJ_DIR)/%) $(OBJ_DIR)/$(LOADER_SIZE_CONSTANTS).o
	$(LD) -T intermediate_align512.lds -r -o $@ $^

$(OBJ_DIR)/$(STAGE1).o: $(STAGE1_OBJ:%=$(OBJ_DIR)/%)
	$(LD) -T intermediate_align512.lds -r -o $@ $^

$(OBJ_DIR)/$(STAGE2).o: $(STAGE2_OBJ:%=$(OBJ_DIR)/%)
	$(LD) -T intermediate.lds -r -o $@ $^

$(OBJ_DIR)/Loader_stage1.o: Loader_stage1.asm $(OBJ_DIR)/$(STAGE2).o
	$(NASM) $(NFLAGS) -dSTAGE2_SIZE=$(shell $(SIZE) $(OBJ_DIR)/$(STAGE2).o|$(AWK) 'NR==2{print $$1+$$2+$$3}') -o $@ $<

$(OBJ_DIR)/Loader_stage2.o: Loader_stage2.asm $(OBJ_DIR)/$(KERNEL).o
	 $(NASM) $(NFLAGS) -dKERNEL_SIZE=$(shell $(SIZE) $(OBJ_DIR)/$(KERNEL).o|$(AWK) 'NR==2{print $$1+$$2+$$3}') -o $@ $<

$(OBJ_DIR)/$(LOADER_SIZE_CONSTANTS).o: $(LOADER_SIZE_CONSTANTS).asm $(LOADER_COMPONENTS:%=$(OBJ_DIR)/%)
	$(NASM) $(NFLAGS) -dSIZE_WITHOUT=$(shell $(SIZE) -t $(LOADER_COMPONENTS:%=$(OBJ_DIR)/%)|$(AWK) 'END{print $$1+$$2+$$3}') -o $@ $<

$(OBJ_DIR)/$(KERNEL).o: $(KERNEL_COMPONENTS:%=$(OBJ_DIR)/%)
	$(LD) -T intermediate_align512.lds -r -o $@ $^

$(OBJ_DIR)/%.o: %.asm
	$(NASM) $(NFLAGS) -o $@ $<

.PHONY: clean
clean:
	rm -rf $(OBJ_DIR)

$(OBJ_DIR):
	mkdir $(OBJ_DIR)

.PHONY: floppy
floppy: $(OBJ_DIR) $(OBJ_DIR)/$(TARGET).bin
	$(SUDO) $(DD) if=$(OBJ_DIR)/$(TARGET).bin of=$(FD)
