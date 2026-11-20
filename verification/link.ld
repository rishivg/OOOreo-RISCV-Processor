OUTPUT_ARCH(riscv)
ENTRY(_start)
SECTIONS {
  . = 0xaaaaa000;
  .text : { KEEP(*(.text.init)) *(.text .text.*) }
  . = ALIGN(32);
  .rodata : { *(.rodata .rodata.* .srodata .srodata.*) }
  . = ALIGN(32);
  .data : { *(.data .data.* .sdata .sdata.*) }
  . = ALIGN(32);
  .tohost : { KEEP(*(.tohost)) }
  . = ALIGN(32);
  .bss (NOLOAD) : { __bss_start = .; *(.bss .bss.* .sbss .sbss.*) *(COMMON) . = ALIGN(16); __bss_end = .; }
  __heap_start = .;
  __stack_top = 0xab2aa000;
  ASSERT(__heap_start < __stack_top - 0x100000, "program overlaps stack")
}
