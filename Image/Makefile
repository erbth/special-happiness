OBJ_BASE:=../$(OBJ_BASE)
OBJ_DIR=$(OBJ_BASE)/$(MODULE)

MODULE=Image
TARGET=MyOS

# Order matters!
OS_BINARIES=Loader/Loader.bin #Kernel/Kernel.bin

.PHONY: all clean floppy
all: $(OBJ_DIR)/$(TARGET).bin

$(OBJ_DIR)/$(TARGET).bin: $(OS_BINARIES:%=$(OBJ_BASE)/%)
	$(CAT) $^ > $@

$(OBJ_DIR)/$(TARGET).bin: | $(OBJ_DIR)

$(OBJ_DIR):
	mkdir -p $@

clean:
	rm -rf $(OBJ_DIR)

floppy: $(OBJ_DIR)/$(TARGET).bin
	$(SUDO) $(DD) if=$< of=$(FD)
