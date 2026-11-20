#ifndef OOO_RVMODEL_MACROS_H
#define OOO_RVMODEL_MACROS_H
#define STANDARD_SM_SUPPORTED
#define RVMODEL_DATA_SECTION \
  .pushsection .tohost,"aw",@progbits; \
  .balign 8; .global tohost; tohost: .dword 0; \
  .global fromhost; fromhost: .dword 0; .popsection;
#define RVMODEL_HALT_PASS \
  li t0,1; la t1,tohost; sw t0,0(t1); sw zero,4(t1); 1: j 1b;
#define RVMODEL_HALT_FAIL \
  li t0,3; la t1,tohost; sw t0,0(t1); sw zero,4(t1); 1: j 1b;
#define RVMODEL_IO_INIT(_R1,_R2,_R3)
#define RVMODEL_IO_WRITE_STR(_R1,_R2,_R3,_STR_PTR) \
  li _R2,0x10000000; \
  1: lbu _R1,0(_STR_PTR); beqz _R1,2f; sb _R1,0(_R2); \
  addi _STR_PTR,_STR_PTR,1; j 1b; 2:
#define RVMODEL_MTIME_ADDRESS 0x0200bff8
#define RVMODEL_MTIMECMP_ADDRESS 0x02004000
#define RVMODEL_MSIP_ADDRESS 0x02000000
#define RVMODEL_INTERRUPT_LATENCY 4096
#define RVMODEL_TIMER_INT_SOON_DELAY 1000
#define RVMODEL_MAX_CYCLES_PER_TIMER_TICK 5000
#define RVMODEL_SET_MEXT_INT(_R1,_R2) \
  li _R1,0x80000800; li _R2,0x10000018; sw _R1,0(_R2);
#define RVMODEL_CLR_MEXT_INT(_R1,_R2) \
  li _R1,0x800; li _R2,0x10000018; sw _R1,0(_R2);
#endif
