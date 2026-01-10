# Formal Verification

This directory contains property files and configurations for Formal Verification using **SymbiYosys (sby)**.

## Structure
*   **`properties/`**: SystemVerilog Assertion (`.sva`) files containing logical properties (e.g., `rob_props.sva`).
*   **`proofs/`**: Configuration directories for specific verification tasks.
*   **`cpu.sby`**: Top-level SymbiYosys configuration file.

## Prerequisites
*   SymbiYosys (`sby`)
*   Yosys
*   Boolector/Yices (SMT Solvers)

## Usage
```bash
sby -f cpu.sby
```
