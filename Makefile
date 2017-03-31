export OBJ_BASE:=bin

export NASM=nasm
export LD=ld
export SIZE=size
export AWK=awk
export CAT=cat
export DD=dd
export SUDO=sudo

export FD=/dev/fd0

SUBDIRS_COMPONENTS=Loader Kernel
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
