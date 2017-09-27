export OBJ_BASE:=bin

export NASM=nasm
export CC="/home/therb/opt/cross/bin/i686-elf-gcc"
export LD="/home/therb/opt/cross/bin/i686-elf-ld"
export SIZE="/home/therb/opt/cross/bin/i686-elf-size"
export AWK=awk
export CAT=cat
export DD=dd
export SUDO=sudo

export FD=/dev/fd0

SUBDIRS_COMPONENTS=Loader #Kernel
SUBDIR_IMAGE=Image

SUBDIRS=$(SUBDIRS_COMPONENTS) $(SUBDIR_IMAGE)

.PHONY: all $(SUBDIRS) floppy clean $(SUBDIRS:%=%-clean)

all: $(SUBDIRS)

$(SUBDIRS):
	$(MAKE) -C $@

$(SUBDIR_IMAGE): $(SUBDIRS_COMPONENTS)

clean: $(SUBDIRS:%=%-clean)
	if [ -d $(OBJ_BASE) ]; then rmdir $(OBJ_BASE); fi

$(SUBDIRS:%=%-clean):
	$(MAKE) -C $(@:%-clean=%) clean

floppy: $(SUBDIR_IMAGE)
	$(MAKE) -C $(SUBDIR_IMAGE) floppy
