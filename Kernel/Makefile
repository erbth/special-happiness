NFLAGS:=-f elf -F dwarf -I $(OBJ_BASE)/Loader -I ../Loader
CFLAGS:=-ffreestanding -O2 -Wall -Wextra -Werror -std=gnu99 -fno-asynchronous-unwind-tables -Iinclude -I $(OBJ_BASE)/Loader -I ../Loader
OBJ_BASE:=../$(OBJ_BASE)
OBJ_DIR=$(OBJ_BASE)/$(MODULE)

MODULE=Kernel
TARGET=Kernel.o

# Order matters!
OBJS= Entry.o \
	  kernel.o \
	  Kernel_SystemMemoryMap.o \
	  stdio.o \
	  string.o \
	  MemoryManagement.o \
	  MemoryManagement_asm.o \
	  isapnp.o \
	  NE2000.o \
      Text.o

.PHONY: all
all: $(OBJ_DIR)/$(TARGET)

$(OBJ_DIR)/$(TARGET): $(OBJS:%=$(OBJ_DIR)/%)
	$(CC) -T object_module.lds $(CFLAGS) -nostdlib -lgcc -Wl,-r -Wl,-d -o $@ $^

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
