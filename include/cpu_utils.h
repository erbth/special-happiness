#ifndef CPU_UTILS_H
#define CPU_UTILS_H

#include <stdint.h>

extern __attribute__((cdecl)) __attribute__((noreturn)) void cpu_halt (void);

extern __attribute__((cdecl)) uint64_t rdmsr64 (uint32_t msr);
extern __attribute__((cdecl)) uint32_t rdmsr32 (uint32_t msr);
extern __attribute__((cdecl)) uint32_t wrmsr64 (uint32_t msr, uint64_t value);

extern __attribute__((cdecl)) void hypercall0 (uint32_t nr);
extern __attribute__((cdecl)) void hypercall1 (uint32_t nr, uint32_t arg);

extern __attribute__((cdecl)) uint64_t read_tsc (void);

#endif /* CPU_UTILS_H */
