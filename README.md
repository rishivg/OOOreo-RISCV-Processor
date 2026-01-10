# OOOreo Processor

![OOOreo CI](https://github.com/rishivg/OOOreo-RV32IM-Processor/actions/workflows/ci.yml/badge.svg)

**OOOreo** is a superscalar, out-of-order RISC-V processor core implementing the RV32IM instruction set. It is designed for learning and exploring advanced microarchitectural concepts like Tomasulo's algorithm, speculative execution, and branch prediction.

## Project Structure
*   **`hdl/`**: SystemVerilog source code for the processor core.
*   **`hvl/`**: Verification logic and testbench components.
*   **`sim/`**: Verilator simulation environment.
*   **`fpga/`**: FPGA implementation tools (F4PGA/Vivado).
*   **`sw/`**: Software stack (drivers, apps, BSP).
*   **`formal/`**: Formal verification properties.

## Getting Started

### 1. Install Dependencies
```bash
./scripts/install_toolchain.sh
```

### 2. Run CI Pipeline Locally
```bash
./scripts/run_ci.sh all
```

### 3. Run Simulation Manually
```bash
cd sim
make run_verilator_top_tb PROG=../testcode/coremark_im.elf
```
