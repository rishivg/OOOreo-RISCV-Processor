/* Bare-metal link for the self-checking testcode: sections padded to 32-byte
   multiples (generate_memory_file.py requires it), text at the reset PC. */
OUTPUT_ARCH("riscv")
ENTRY(_start)
SECTIONS
{
  . = 0xaaaaa000;
  .text : { *(.text) *(.text*) . = ALIGN(32); }
  . = ALIGN(4096);
  .data : { *(.data) *(.data*) *(.sdata*) . = ALIGN(32); }
  .bss  : { *(.bss) *(.bss*) *(.sbss*) . = ALIGN(32); }
}
