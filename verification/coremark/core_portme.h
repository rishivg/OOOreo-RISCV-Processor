#ifndef CORE_PORTME_H
#define CORE_PORTME_H
#include <stddef.h>
#include <stdint.h>
#define HAS_FLOAT 0
#define HAS_TIME_H 0
#define HAS_STDIO 0
#define HAS_PRINTF 0
#define COMPILER_VERSION "GCC " __VERSION__
#define COMPILER_FLAGS "-O2 -march=rv32imac_zicsr_zifencei -mabi=ilp32 -msmall-data-limit=0 -ffreestanding"
#define MEM_LOCATION "STACK"
typedef int16_t ee_s16;
typedef int32_t ee_s32;
typedef uint8_t ee_u8;
typedef uint16_t ee_u16;
typedef uint32_t ee_u32;
typedef double ee_f32;
typedef uintptr_t ee_ptr_int;
typedef size_t ee_size_t;
#define align_mem(x) (void *)(4+(((ee_ptr_int)(x)-1)&~(ee_ptr_int)3))
#define CORETIMETYPE uint64_t
typedef uint64_t CORE_TICKS;
#define SEED_METHOD SEED_VOLATILE
#define MEM_METHOD MEM_STACK
#define MULTITHREAD 1
#define USE_PTHREAD 0
#define USE_FORK 0
#define USE_SOCKET 0
#define MAIN_HAS_NOARGC 0
#define MAIN_HAS_NORETURN 0
typedef struct { ee_u8 portable_id; } core_portable;
extern ee_u32 default_num_contexts;
void portable_init(core_portable *,int *,char *[]);
void portable_fini(core_portable *);
int ee_printf(const char *,...);
#endif
