#ifndef _NE2000_H
#define _NE2000_H

#include <stddef.h>
#include <stdint.h>
#include "NE2000_internal.h"

/* Prototypes */
NE2000* NE2000_initialize(isabus_device* isadev);
void NE2000_print_state(NE2000* ne);
void NE2000_debuggerloop(NE2000* ne);

#endif /* _NE2000_H */
