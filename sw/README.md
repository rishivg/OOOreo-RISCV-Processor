# Software & Board Support Package (BSP)

This directory contains the software stack for the OOOreo processor.

## Structure
*   **`apps/`**: Source code for user applications and benchmarks (CoreMark, Dhrystone).
*   **`drivers/`**: Hardware abstraction layer (HAL) drivers for peripherals (UART, Timer).
*   **`lib/`**: Standard library implementations (printf, memset, string).
*   **`linker/`**: Linker scripts defining memory maps for Simulation and FPGA.

## Build Instructions
(To be implemented: Toolchain info `riscv32-unknown-elf-gcc`)

```bash
cd sw
make apps
```
