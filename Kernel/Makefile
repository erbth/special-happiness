NFLAGS:=-f elf
OBJ_BASE:=../$(OBJ_BASE)
OBJ_DIR=$(OBJ_BASE)/$(MODULE)

NASM=nasm
LD=ld
SIZE=size
AWK=awk

MODULE=Kernel
TARGET=Kernel

# Order matters!
OBJS= Entry.o \
      Text.o

.PHONY: all
all: $(OBJ_DIR)/$(TARGET).bin

$(OBJ_DIR)/$(TARGET).bin: $(OBJS:%=$(OBJ_DIR)/%)
	$(LD) -T flat_binary.lds -o $@ $^

$(OBJ_DIR)/%.o: %.asm
	$(NASM) $(NFLAGS) -o $@ $<

$(OBJS:%=$(OBJ_DIR)/%): | $(OBJ_DIR)
$(OBJ_DIR)/$(TARGET): | $(OBJ_DIR)

.PHONY: clean
clean:
	rm -rf $(OBJ_DIR)

$(OBJ_DIR):
	mkdir -p $(OBJ_DIR)
