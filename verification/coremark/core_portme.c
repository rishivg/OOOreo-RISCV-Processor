#include "coremark.h"
#include <stdarg.h>
#include <stdio.h>

#ifndef CPU_HZ
#define CPU_HZ 1000000
#endif
#if VALIDATION_RUN
volatile ee_s32 seed1_volatile=0x3415,seed2_volatile=0x3415;
#else
volatile ee_s32 seed1_volatile=0,seed2_volatile=0;
#endif
volatile ee_s32 seed3_volatile=0x66,seed4_volatile=ITERATIONS,seed5_volatile=0;
ee_u32 default_num_contexts=1;
static uint64_t started,stopped;

static uint64_t cycles(void) {
    uint32_t high,low,again;
    do {
        __asm__ volatile("rdcycleh %0":"=r"(high));
        __asm__ volatile("rdcycle %0":"=r"(low));
        __asm__ volatile("rdcycleh %0":"=r"(again));
    } while (high!=again);
    return ((uint64_t)high<<32)|low;
}
void start_time(void) { started=cycles(); }
void stop_time(void) { stopped=cycles(); }
CORE_TICKS get_time(void) { return stopped-started; }
secs_ret time_in_secs(CORE_TICKS ticks) { return ticks/CPU_HZ; }
void portable_init(core_portable *p,int *argc,char *argv[]) {
    (void)argc;(void)argv;p->portable_id=1;
}
void portable_fini(core_portable *p) { p->portable_id=0; }
int ee_printf(const char *format,...) {
    char buffer[256];
    va_list args;
    va_start(args,format);
    int n=vsnprintf(buffer,sizeof(buffer),format,args);
    va_end(args);
    extern int _write(int,const void *,size_t);
    if (n>0) _write(1,buffer,(size_t)n<sizeof(buffer)?(size_t)n:sizeof(buffer)-1);
    return n;
}
