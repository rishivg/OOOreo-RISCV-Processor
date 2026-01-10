# F4PGA / Open Source FPGA Toolchain

This directory contains the tooling to synthesize and implement the OOOreo processor using the F4PGA (SymbiFlow) open-source toolchain.

## Prerequisites
*   **sv2v**: SystemVerilog to Verilog converter.
*   **Yosys**: Synthesis tool.
*   **nextpnr-xilinx**: Place and Route tool for Xilinx devices.
*   **Project X-Ray / F4PGA Arch Defs**: For bitstream generation.

## Directory Structure
*   `scripts/`: Yosys synthesis scripts (`synth.ys`).
*   `constraints/`: XDC constraint files.
*   `build/`: Build artifacts (transpiled verilog, json netlists, fasm).

## Usage

### 1. Transpile (SystemVerilog -> Verilog)
Converts the complex SystemVerilog codebase into a single F4PGA-compatible Verilog file.
```bash
make sv2v
```

### 2. Synthesis (Yosys)
Runs synthesis and generates a JSON netlist.
```bash
make synth
```

### 3. Place and Route (Nextpnr)
Places the design on the FPGA fabric.
```bash
make pnr
```

## Note on Bitstream
The `make bitstream` target generates a FASM file. Converting FASM to a `.bit` file requires the full F4PGA database environment (fasm2bel), which must be sourced in your shell.
