NFLAGS:=-f elf -F dwarf -I $(OBJ_BASE)/Loader/ -I ../Loader/ -I include/
CFLAGS:=-ffreestanding -O2 -Wall -Wextra -Werror -std=gnu99 -fno-asynchronous-unwind-tables -Iinclude -I $(OBJ_BASE)/Loader -I ../Loader
OBJ_BASE:=../$(OBJ_BASE)
OBJ_DIR=$(OBJ_BASE)/$(MODULE)

MODULE=Kernel
TARGET=Kernel.o

# Order matters!
OBJS= Entry.asm.o \
	  kernel.c.o \
	  Kernel_SystemMemoryMap.c.o \
	  stdio.c.o \
	  util.c.o \
	  string.c.o \
	  MemoryManagement.c.o \
	  MemoryManagement_asm.asm.o \
	  isr_handlers.asm.o \
	  asm_utils.asm.o \
	  isapnp.c.o \
	  NE2000.c.o \
	  NE2000.asm.o \
      Text.asm.o

.PHONY: all
all: $(OBJ_DIR)/$(TARGET)

$(OBJ_DIR)/$(TARGET): $(OBJS:%=$(OBJ_DIR)/%)
	$(CC) -T object_module.lds $(CFLAGS) -nostdlib -lgcc -Wl,-r -Wl,-d -o $@ $^

$(OBJ_DIR)/%.asm.o: %.asm
	$(NASM) $(NFLAGS) -o $@ $<

$(OBJ_DIR)/%.c.o: %.c
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
