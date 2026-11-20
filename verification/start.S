.section .text.init,"ax"
.globl _start
_start:
  .option push
  .option norelax
  la sp, __stack_top
  .option pop
  la t0, __bss_start
  la t1, __bss_end
1:
  bgeu t0, t1, 2f
  sw zero, 0(t0)
  addi t0, t0, 4
  j 1b
2:
  li a0, 0
  li a1, 0
  call main
  call _exit
.globl _exit
_exit:
  slli a0, a0, 1
  ori a0, a0, 1
  la t0, tohost
  sw a0, 0(t0)
  sw zero, 4(t0)
3:
  j 3b
.section .tohost,"aw"
.balign 8
.globl tohost
tohost: .dword 0
.globl fromhost
fromhost: .dword 0
