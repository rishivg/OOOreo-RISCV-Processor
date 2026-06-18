# F4PGA / Open Source FPGA Toolchain
# Tools required:
# - sbt + SpinalHDL (core generation -> ../hdl/gen/cpu.v, plain Verilog)
# - yosys (Synthesis)
# - nextpnr-xilinx (Place and Route)
# - openfpgaloader (Bitstream loading - optional)
#
# The OOOreo core is SpinalHDL now and emits Verilog directly, so there is no
# sv2v step: we generate ../hdl/gen/cpu.v and feed it (plus the SRAM behavioral
# models and the DW_div_seq divider) straight to yosys.

# Project Configuration
TOP_MODULE := cpu
PART       := xc7z020
BUILD_DIR  := build
SCRIPTS_DIR := scripts

# Generated core + the external modules it instantiates (SRAM macros + divider).
CPU_V      := ../hdl/gen/cpu.v
SRAM_SRCS  := $(shell find ../sram/output -name '*.v')
DIV_SRC    := ../hvl/common/dw_mock.sv

.PHONY: all gen synth pnr clean

all: bitstream

# -----------------------------------------------------------------------------
# 1. Core generation (SpinalHDL -> Verilog)
# -----------------------------------------------------------------------------
gen: $(BUILD_DIR)/$(TOP_MODULE).v

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(BUILD_DIR)/$(TOP_MODULE).v: | $(BUILD_DIR)
	@echo "[FLOW] Generating SpinalHDL core -> $(CPU_V) ..."
	cd ../hdl && sbt -batch "runMain ooo.Generate"
	cp $(CPU_V) $@

# -----------------------------------------------------------------------------
# 2. Synthesis (Yosys)
# -----------------------------------------------------------------------------
synth: $(BUILD_DIR)/$(TOP_MODULE).json

$(BUILD_DIR)/$(TOP_MODULE).json: $(BUILD_DIR)/$(TOP_MODULE).v $(SCRIPTS_DIR)/synth.ys
	@echo "[FLOW] Running Yosys Synthesis..."
	mkdir -p reports
	yosys -l reports/yosys.log -s $(SCRIPTS_DIR)/synth.ys

# -----------------------------------------------------------------------------
# 3. Place and Route (nextpnr-xilinx)
# -----------------------------------------------------------------------------
pnr: $(BUILD_DIR)/$(TOP_MODULE).fasm

$(BUILD_DIR)/$(TOP_MODULE).fasm: $(BUILD_DIR)/$(TOP_MODULE).json
	@echo "[FLOW] Running Nextpnr (Place & Route)..."
	# Note: This assumes nextpnr-xilinx is installed and chipdb is available.
	# You may need to add --chipdb <path> if not in default location.
	nextpnr-xilinx --25k --json $(BUILD_DIR)/$(TOP_MODULE).json \
		--write $(BUILD_DIR)/$(TOP_MODULE)_routed.json \
		--fasm $@ \
		--log reports/nextpnr.log

# -----------------------------------------------------------------------------
# 4. Bitstream Generation (Symbiflow/F4PGA specific utility usually needed here)
# -----------------------------------------------------------------------------
# Placeholder: Running fasm2frame or similar usually depends on the specific 
# F4PGA architecture installation (xc7).
bitstream: $(BUILD_DIR)/$(TOP_MODULE).fasm
	@echo "[TODO] Bitstream generation requires fasm2bel/f4pga arch definitions."
	@echo "Generated FASM: $(BUILD_DIR)/$(TOP_MODULE).fasm"

clean:
	rm -rf $(BUILD_DIR) reports
