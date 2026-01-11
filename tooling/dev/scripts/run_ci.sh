#!/bin/bash
set -e

# Default settings
LINT_DIR="lint"
SIM_DIR="sim"
FPGA_DIR="fpga"
SW_DIR="sw"

# Helper function for printing
print_header() {
    echo "====================================================================="
    echo "  $1"
    echo "====================================================================="
}

# 1. LINTING
run_lint() {
    print_header "Running Lint (Verilator + Yosys if installed)"
    cd $LINT_DIR
    # Using the 'make lint' target we optimized earlier
    make lint
    cd ..
}

# 2. SIMULATION
run_simulation() {
    TEST_ELF=$1
    if [ -z "$TEST_ELF" ]; then
        echo "Error: run_simulation requires an ELF path argument."
        exit 1
    fi
    print_header "Running Simulation (Verilator)"
    echo "Test Program: $TEST_ELF"
    
    cd $SIM_DIR
    # Build simulator first
    make verilator/build/Vtop_tb
    
    # Run specific test
    # Ensure ELF path is absolute
    case "$TEST_ELF" in
        /*) ABS_ELF="$TEST_ELF" ;;
        *)  ABS_ELF="$(pwd)/../$TEST_ELF" ;;
    esac
    
    make run_verilator_top_tb PROG="$ABS_ELF"
    cd ..
}

# 3. SYNTHESIS CHECK (FPGA)
run_synthesis() {
    print_header "Running FPGA Synthesis (sv2v + Yosys)"
    
    cd $FPGA_DIR
    
    # Check if tools are present (local installation check)
    if [ ! -f "tools/sv2v-Linux/sv2v" ]; then
         echo "[WARN] Local sv2v not found. Attempting to build or download..."
         # Basic download logic if missing (CI fallback)
         mkdir -p tools
         wget -q https://github.com/zachjs/sv2v/releases/download/v0.0.13/sv2v-Linux.zip -O sv2v.zip || true
         if [ -f "sv2v.zip" ]; then unzip -o sv2v.zip -d tools; fi
    fi
    
    make sv2v
    make synth
    cd ..
}

# 4. SOFTWARE BUILD (Placeholder)
run_sw_build() {
    print_header "Building Software"
    if [ -d "$SW_DIR" ]; then
        echo "Software directory exists. (Make target pending)"
        # cd $SW_DIR && make all
    else
        echo "Software directory missing."
    fi
}

# COMMAND DISPATCHER
case "$1" in
    "lint")
        run_lint
        ;;
    "sim")
        run_simulation "$2"
        ;;
    "synth")
        run_synthesis
        ;;
    "all")
        run_lint
        run_synthesis
        # Run a default smoke test for simulation
        if [ -f "testcode/coremark_im.elf" ]; then
            run_simulation "testcode/coremark_im.elf"
        else
            echo "[WARN] Default testcode/coremark_im.elf not found. Skipping Sim."
        fi
        ;;
    *)
        echo "Usage: $0 {lint|sim <elf_path>|synth|all}"
        exit 1
        ;;
esac

echo "---------------------------------------------------------------------"
echo "  CI Task '$1' Completed Successfully."
echo "---------------------------------------------------------------------"
exit 0
