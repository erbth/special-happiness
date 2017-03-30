; This file is ment to define size constants that can only be computed after the
; entire bootloader is linked, e.g. because they depend on the loader's size.
; actually, this file is also part of the bootloader, but it's size can easily
; determined from it's code (if any) and definitions herein.

section .text

global LOADER_SIZE
LOADER_SIZE dd ((SIZE_WITHOUT + (end_of_section - $) + 1FFH) / 200H) * 200H

end_of_section:
