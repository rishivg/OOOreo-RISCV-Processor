.section .text.init,"ax"
.globl _start
_start:
  la t0, cold_data
  .option push
  .option norvc
  # Each cold load delays its branch. The untaken path contains reserved RV32 loads.
  .rept 64
    lw t1,0(t0)
    beq t1,zero,1f
    .word 0x00003203
    .word 0x00006203
    .word 0x00007203
    j failed
  1: addi t0,t0,32
  .endr
  la t0,tohost
  li t1,1
  sw t1,0(t0)
  sw zero,4(t0)
2: j 2b
failed:
  la t0,tohost
  li t1,3
  sw t1,0(t0)
  sw zero,4(t0)
  j 2b
  .option pop
.section .rodata
.balign 4096
cold_data: .zero 2048
.section .tohost,"aw"
.balign 8
.globl tohost
tohost: .dword 0
.globl fromhost
fromhost: .dword 0
