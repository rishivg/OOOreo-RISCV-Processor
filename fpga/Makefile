# F4PGA / Open Source FPGA Toolchain
# Tools required: 
# - sv2v (SystemVerilog to Verilog converter)
# - yosys (Synthesis)
# - nextpnr-xilinx (Place and Route)
# - openfpgaloader (Bitstream loading - optional)

# Project Configuration
TOP_MODULE := cpu
PART       := xc7z020
BUILD_DIR  := build
SCRIPTS_DIR := scripts

# Sources handling
# Find all SystemVerilog files, excluding headers inside hvl or testcode if any
PKG_SRCS   := $(shell find ../pkg -name '*.sv')
HDL_SRCS   := $(shell find ../hdl -name '*.sv')
SRAM_SRCS  := $(shell find ../sram/output -name '*.v')

# Combined source list for sv2v
ALL_SRCS   := $(PKG_SRCS) $(HDL_SRCS) $(SRAM_SRCS)

# Tools
SV2V       := ./tools/sv2v-Linux/sv2v

.PHONY: all sv2v synth pnr clean

all: bitstream

# -----------------------------------------------------------------------------
# 1. Transpilation (SystemVerilog -> Verilog 2005)
# -----------------------------------------------------------------------------
sv2v: $(BUILD_DIR)/$(TOP_MODULE).v

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(BUILD_DIR)/$(TOP_MODULE).v: $(ALL_SRCS) | $(BUILD_DIR)
	@echo "[FLOW] Converting SystemVerilog to Verilog using sv2v..."
	# -I includes directories for Headers
	# We transpile everything into a single Verilog file for Yosys
	$(SV2V) -I../pkg -I../hdl --top=$(TOP_MODULE) $(ALL_SRCS) > $@

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
