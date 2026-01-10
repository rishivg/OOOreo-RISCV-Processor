#!/bin/bash

# Usage: ./run_lint.sh [tool] [top_module]
# tool: all, verilator, icarus, yosys
# top_module: default cpu

TOOL=${1:-all}
TOP_MODULE=${2:-cpu}
EXIT_CODE=0
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Initialize Report JSON
echo "{" > reports/lint_report.json
echo "  \"timestamp\": \"$TIMESTAMP\"," >> reports/lint_report.json
echo "  \"top_module\": \"$TOP_MODULE\"," >> reports/lint_report.json
echo "  \"results\": {" >> reports/lint_report.json

# Define paths and sources
PKG_SRCS="../pkg/types.sv"
HDL_SRCS=$(find ../hdl -name '*.sv')
SRAM_SRCS=$(find ../sram/output -name '*.v')
STUB_SRCS="dw_stubs.v"

# Verilator Flags
# Added --stats for Advanced Reporting (#5)
STATS_FILE="reports/${TOP_MODULE}.stats"
FLAGS="-Wall --lint-only --top-module $TOP_MODULE -Wno-fatal +define+ECE411_VERILATOR ../sim/verilator_warn.vlt --stats --stats-vars"

mkdir -p reports

if [ "$TOOL" = "verilator" ] || [ "$TOOL" = "all" ]; then
    echo "----------------------------------------"
    echo " Starting Verilator Lint for: $TOP_MODULE"
    echo "----------------------------------------"

    # Run Verilator
    if verilator $FLAGS $PKG_SRCS $HDL_SRCS $SRAM_SRCS $STUB_SRCS -I../hdl -I../pkg > "reports/verilator_${TOP_MODULE}.log" 2>&1; then
        # Move the stats file to the reports directory
        STATS_SRC="obj_dir/V${TOP_MODULE}__stats.txt"
        if [ -f "$STATS_SRC" ]; then mv "$STATS_SRC" "$STATS_FILE"; fi
        
        echo ""
        echo "----------------------------------------"
        echo " Verilator Lint Passed Successfully!"
        echo " Stats written to $STATS_FILE"
        echo "----------------------------------------"
        
        # Simple Stats Summary
        if [ -f "$STATS_FILE" ]; then
            echo " Quick Stats:"
            grep "Node count, CELL" "$STATS_FILE" || true
        fi
        
        # Report Update
        echo "    \"verilator\": \"passed\"," >> reports/lint_report.json

    else
        cat "reports/verilator_${TOP_MODULE}.log"
        echo ""
        echo "----------------------------------------"
        echo " Verilator Lint Failed."
        echo "----------------------------------------"
        
        # Report Update
        echo "    \"verilator\": \"failed\"," >> reports/lint_report.json
        EXIT_CODE=1
    fi
fi

# Cross-Verification with Icarus Verilog (#3)
if [ "$TOOL" = "icarus" ] || [ "$TOOL" = "all" ]; then
    if command -v iverilog &> /dev/null; then
        echo ""
        echo "----------------------------------------"
        echo " Starting Icarus Verilog Lint..."
        echo "----------------------------------------"
        # -g2012 for SystemVerilog support
        # -t null means just check syntax, don't build simulation executable
        if iverilog -g2012 -t null -Wall -I../hdl -I../pkg $PKG_SRCS $HDL_SRCS $SRAM_SRCS $STUB_SRCS; then
             echo " Icarus Lint Passed."
             echo "    \"icarus\": \"passed\"," >> reports/lint_report.json
        else
             echo " Icarus Lint Found Issues."
             echo "    \"icarus\": \"failed\"," >> reports/lint_report.json
             if [ "$TOOL" = "icarus" ]; then EXIT_CODE=1; fi
        fi
    else
        echo "" 
        echo " [INFO] Icarus Verilog (iverilog) not found. Skipping usage."
        echo "    \"icarus\": \"skipped\"," >> reports/lint_report.json
    fi
fi

# Yosys Hierarchy Check (#5)
if [ "$TOOL" = "yosys" ] || [ "$TOOL" = "all" ]; then
    if command -v yosys &> /dev/null; then
        echo ""
        echo "----------------------------------------"
        echo " Starting Yosys Hierarchy Check..."
        echo "----------------------------------------"
        
        # Construct Yosys script
        # 1. Read files
        # 2. Check hierarchy
        # 3. Generate Dot graph
        YOSYS_CMD="output/yosys.log"
        mkdir -p output
        
        # Note: We rely on yosys to read the SV source. Yosys support for SV is partial.
        if yosys -p "read_verilog -sv -I../hdl -I../pkg $PKG_SRCS $HDL_SRCS $SRAM_SRCS $STUB_SRCS; hierarchy -check -top $TOP_MODULE; show -format dot -prefix reports/hierarchy_${TOP_MODULE}" > reports/yosys_${TOP_MODULE}.log 2>&1; then
             echo " Yosys Hierarchy Verified."
             echo " Dependency Graph: reports/hierarchy_${TOP_MODULE}.dot"
             echo "    \"yosys\": \"passed\"," >> reports/lint_report.json
        else
             cat reports/yosys_${TOP_MODULE}.log
             echo " Yosys Hierarchy Failed."
             echo "    \"yosys\": \"failed\"," >> reports/lint_report.json
             if [ "$TOOL" = "yosys" ]; then EXIT_CODE=1; fi
        fi
    else
        echo " [INFO] Yosys not found. Skipping."
        echo "    \"yosys\": \"skipped\"," >> reports/lint_report.json
    fi
fi

# Close JSON
# Remove trailing comma if exists (hacky way using sed)
sed -i '$ s/,$//' reports/lint_report.json
echo "  }" >> reports/lint_report.json
echo "}" >> reports/lint_report.json

echo "----------------------------------------"
echo " Report generated: reports/lint_report.json"
exit $EXIT_CODE

