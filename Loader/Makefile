NFLAGS:=-f elf
OBJ_BASE:=../$(OBJ_BASE)
OBJ_DIR=$(OBJ_BASE)/$(MODULE)

MODULE=Loader
TARGET=Loader
STAGE1=Stage1
STAGE2=Stage2

# Order matters!
BINARY_COMPONENTS=$(STAGE1).o $(STAGE2).o

# Order matters!
STAGE1_OBJ=Loader_stage1.o
STAGE2_OBJ=Loader_stage2.o \
           Loader_floppy.o

.PHONY: all
all: $(OBJ_DIR) $(OBJ_DIR)/$(TARGET).bin

$(OBJ_DIR)/$(TARGET).bin: $(BINARY_COMPONENTS:%=$(OBJ_DIR)/%)
	$(LD) -T flat_binary_align512.lds -o $@ $^

$(OBJ_DIR)/$(STAGE1).o: $(STAGE1_OBJ:%=$(OBJ_DIR)/%)
	$(LD) -T intermediate_align512.lds -r -o $@ $^

$(OBJ_DIR)/$(STAGE2).o: $(STAGE2_OBJ:%=$(OBJ_DIR)/%)
	$(LD) -T intermediate.lds -r -o $@ $^

$(OBJ_DIR)/Loader_stage1.o: Loader_stage1.asm $(OBJ_DIR)/$(STAGE2).o
	$(NASM) $(NFLAGS) -dSTAGE2_SIZE=$(shell $(SIZE) $(OBJ_DIR)/$(STAGE2).o|$(AWK) 'NR==2{print $$1+$$2+$$3}') -o $@ $<

$(STAGE1_OBJ:%=$(OBJ_DIR)/%): | $(OBJ_DIR)
$(STAGE2_OBJ:%=$(OBJ_DIR)/%): | $(OBJ_DIR)
$(LOADER_COMPONENTS:%=$(OBJ_DIR)/%): | $(OBJ_DIR)
$(BINARY_COMPONENTS:%=$(OBJ_DIR)/%): | $(OBJ_DIR)
$(OBJ_DIR)/$(TARGET): | $(OBJ_DIR)

$(OBJ_DIR)/%.o: %.asm
	$(NASM) $(NFLAGS) -o $@ $<

.PHONY: clean
clean:
	rm -rf $(OBJ_DIR)

$(OBJ_DIR):
	mkdir -p $(OBJ_DIR)
