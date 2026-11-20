OUTPUT_ARCH(riscv)
ENTRY(rvtest_entry_point)
PROVIDE(__stack_size = 0x20000);
PROVIDE(__num_harts = 1);
MEMORY { ram (rwx) : ORIGIN = 0xaaaaa000, LENGTH = 0x4000000 }
SECTIONS {
  .text.init ORIGIN(ram) : { *(.text.init) } > ram
  .text.rvtest : { *(.text.rvtest .text.rvtest.*) } > ram
  . = ALIGN(0x4000);
  .rodata : { *(.rodata .rodata.* .srodata .srodata.*) } > ram
  .data : { *(.data .data.* .sdata .sdata.*) } > ram
  .tohost : { KEEP(*(.tohost)) } > ram
  . = ALIGN(16);
  .bss : { __bss_start = .; *(.sbss .sbss.* .bss .bss.*) *(COMMON) . = ALIGN(16); __bss_end = .; } > ram
  __stack_bottom = .;
  . += __stack_size * __num_harts;
  __stack_top = .;
  . = ALIGN(0x1000);
  .text.rvmodel : { *(.text.rvmodel .text.rvmodel.* .text .text.*) } > ram
  . = ALIGN(0x1000);
  _end = .;
  ASSERT(_end <= ORIGIN(ram)+LENGTH(ram), "ACT ELF exceeds RAM")
}
