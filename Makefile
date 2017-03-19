NFLAGS=-f elf
OBJ_DIR=obj

NASM=nasm
LD=ld
SIZE=size
AWK=awk
DD=dd
SUDO=sudo

FD=/dev/fd0

TARGET=MyOS
STAGE1=Stage1
STAGE2=Stage2

# Order matters!
COMPONENTS=$(STAGE1).o $(STAGE2).o

# Order matters!
STAGE1_OBJ=Loader_stage1.o
STAGE2_OBJ=Loader_stage2.o \
           Loader_floppy.o

.PHONY: all
all: $(OBJ_DIR) $(OBJ_DIR)/$(TARGET).bin

$(OBJ_DIR)/$(TARGET).bin: $(COMPONENTS:%=$(OBJ_DIR)/%)
	$(LD) -T flat_binary.lds -o $@ $^

$(OBJ_DIR)/$(STAGE1).o: $(STAGE1_OBJ:%=$(OBJ_DIR)/%)
	$(LD) -T intermediate.lds -r -o $@ $^

$(OBJ_DIR)/$(STAGE2).o: $(STAGE2_OBJ:%=$(OBJ_DIR)/%)
	$(LD) -T intermediate.lds -r -o $@ $^

$(OBJ_DIR)/Loader_stage1.o: Loader_stage1.asm $(OBJ_DIR)/$(STAGE2).o
	$(NASM) $(NFLAGS) -dSTAGE2_SIZE=$(shell $(SIZE) $(OBJ_DIR)/$(STAGE2).o|$(AWK) 'NR==2{print $$1+$$2+$$3}') -o $@ $<

$(OBJ_DIR)/%.o: %.asm
	$(NASM) $(NFLAGS) -o $@ $^

.PHONY: clean
clean:
	rm -rf $(OBJ_DIR)

$(OBJ_DIR):
	mkdir $(OBJ_DIR)

.PHONY: floppy
floppy: $(OBJ_DIR) $(OBJ_DIR)/$(TARGET).bin
	$(SUDO) $(DD) if=$(OBJ_DIR)/$(TARGET).bin of=$(FD)
