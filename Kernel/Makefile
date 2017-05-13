NFLAGS:=-f elf
CFLAGS:=-ffreestanding -O2 -Wall -Wextra -Werror -std=gnu99 -fno-asynchronous-unwind-tables -Iinclude
OBJ_BASE:=../$(OBJ_BASE)
OBJ_DIR=$(OBJ_BASE)/$(MODULE)

LD=$(CC)

MODULE=Kernel
TARGET=Kernel.bin

# Order matters!
OBJS= Entry.o \
	  kernel.o \
	  string.o \
	  isapnp.o \
      Text.o

.PHONY: all
all: $(OBJ_DIR)/$(TARGET) $(OBJ_DIR)/isapnp.s

$(OBJ_DIR)/$(TARGET): $(OBJS:%=$(OBJ_DIR)/%)
	$(LD) -T flat_binary.lds $(CFLAGS) -nostdlib -lgcc -o $@ $^

$(OBJ_DIR)/%.o: %.asm
	$(NASM) $(NFLAGS) -o $@ $<

$(OBJ_DIR)/%.o: %.c
	$(CC) $(CFLAGS) -o $@ -c $<

$(OBJ_DIR)/%.s: %.c
	$(CC) $(CFLAGS) -S -o $@ $<

$(OBJS:%=$(OBJ_DIR)/%): | $(OBJ_DIR)
$(OBJ_DIR)/$(TARGET): | $(OBJ_DIR)

.PHONY: clean
clean:
	rm -rf $(OBJ_DIR)

$(OBJ_DIR):
	mkdir -p $(OBJ_DIR)
