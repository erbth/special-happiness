OBJ_BASE:=../$(OBJ_BASE)
OBJ_DIR=$(OBJ_BASE)/$(MODULE)

MODULE=Image
TARGET=MyOS

MODULE_LOADER:=Loader
MODULE_KERNEL:=Kernel

OBJMOD_LOADER:=$(OBJ_BASE)/$(MODULE_LOADER)/$(MODULE_LOADER).o
OBJMOD_KERNEL:=$(OBJ_BASE)/$(MODULE_KERNEL)/$(MODULE_KERNEL).o

LINKER_SCRIPT:=flat_binary.lds

.PHONY: all clean floppy
all: $(OBJ_DIR)/$(TARGET).bin

$(OBJ_DIR)/$(TARGET).bin: $(OBJMOD_LOADER) $(OBJMOD_KERNEL) $(LINKER_SCRIPT)
	$(LD) -T $(LINKER_SCRIPT) --unresolved-symbols=report-all -o $@

$(OBJ_DIR)/$(TARGET).bin: | $(OBJ_DIR)

$(OBJ_DIR):
	mkdir -p $@

clean:
	rm -rf $(OBJ_DIR)

floppy: $(OBJ_DIR)/$(TARGET).bin
	$(SUDO) $(DD) if=$< of=$(FD)
