# F4PGA / Open Source FPGA Toolchain
# Tools required:
# - yosys (Synthesis)
# - nextpnr-xilinx (Place and Route)
#
# The OOOreo core is SpinalHDL now and emits Verilog directly, so there is no
# sv2v or sbt step in this flow: ../hdl/gen/cpu.v is copied directly and fed
# to yosys with the SRAM behavioral models and the DW_div_seq divider mock.

# Project Configuration
TOP_MODULE := cpu_impl_top
PART       := xc7a200tfbg676-3
BUILD_DIR  := build
SCRIPTS_DIR := scripts
REPORTS_DIR := reports
CONSTRAINTS := build/constraints.expanded.xdc

YOSYS      := ../tools/oss-cad-suite/bin/yosys
NEXTPNR    := ../tools/nextpnr-xilinx-build/nextpnr-xilinx
CHIPDB     := ../tools/xc7a200tfbg676-3.bin
FREQ_MHZ   ?= 100
USE_DSP    ?= 1

ifeq ($(USE_DSP),0)
SYNTH_DSP_OPT := -nodsp
BUILD_VARIANT := nodsp
else
SYNTH_DSP_OPT :=
BUILD_VARIANT := dsp
endif

SYNTH_SCRIPT := $(BUILD_DIR)/synth-$(BUILD_VARIANT).ys
NETLIST      := $(BUILD_DIR)/$(TOP_MODULE)-$(BUILD_VARIANT).json
ROUTED_JSON  := $(BUILD_DIR)/$(TOP_MODULE)-$(BUILD_VARIANT)_routed.json
FASM         := $(BUILD_DIR)/$(TOP_MODULE)-$(BUILD_VARIANT).fasm
PNR_REPORT   := $(REPORTS_DIR)/nextpnr-$(BUILD_VARIANT)-$(FREQ_MHZ)MHz.json
PNR_LOG      := $(REPORTS_DIR)/nextpnr-$(BUILD_VARIANT)-$(FREQ_MHZ)MHz.log

# Generated core + the external modules it instantiates (SRAM macros + divider).
CPU_V      := ../hdl/gen/cpu.v
WRAPPER_V  := rtl/cpu_impl_top.v
SRAM_SRCS  := $(shell find ../sram/output -name '*.v')
DIV_SRC    := ../hvl/common/dw_mock.sv

.PHONY: all gen synth pnr clean

all: bitstream

# -----------------------------------------------------------------------------
# 1. Core generation (SpinalHDL -> Verilog)
# -----------------------------------------------------------------------------
gen: $(BUILD_DIR)/cpu.v

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(BUILD_DIR)/cpu.v: | $(BUILD_DIR)
	@echo "[FLOW] Copying generated core $(CPU_V) -> $@ ..."
	cp $(CPU_V) $@

# -----------------------------------------------------------------------------
# 2. Synthesis (Yosys)
# -----------------------------------------------------------------------------
synth: $(BUILD_DIR)/$(TOP_MODULE).json

$(SYNTH_SCRIPT): $(SCRIPTS_DIR)/synth.ys | $(BUILD_DIR)
	sed 's/@SYNTH_DSP_OPT@/$(SYNTH_DSP_OPT)/g; s/@BUILD_VARIANT@/$(BUILD_VARIANT)/g' $< > $@

$(NETLIST): $(BUILD_DIR)/cpu.v $(WRAPPER_V) $(SYNTH_SCRIPT)
	@echo "[FLOW] Running Yosys Synthesis..."
	mkdir -p $(REPORTS_DIR)
	$(YOSYS) -l $(REPORTS_DIR)/yosys-$(BUILD_VARIANT).log -s $(SYNTH_SCRIPT)

$(BUILD_DIR)/$(TOP_MODULE).json: $(NETLIST)
	cp $< $@

# -----------------------------------------------------------------------------
# 3. Place and Route (nextpnr-xilinx)
# -----------------------------------------------------------------------------
pnr: $(BUILD_DIR)/$(TOP_MODULE).fasm

$(CONSTRAINTS): constraints/constraints.xdc scripts/gen_xdc.py | $(BUILD_DIR)
	FREQ_MHZ=$(FREQ_MHZ) python3 scripts/gen_xdc.py

$(FASM): $(NETLIST) $(CHIPDB)
	@echo "[FLOW] Running Nextpnr (Place & Route)..."
	mkdir -p $(REPORTS_DIR)
	FREQ_MHZ=$(FREQ_MHZ) python3 scripts/gen_xdc.py
	$(NEXTPNR) --chipdb $(CHIPDB) --xdc $(CONSTRAINTS) --freq $(FREQ_MHZ) \
		--timing-allow-fail --threads $$(nproc) \
		--json $(NETLIST) \
		--write $(ROUTED_JSON) \
		--fasm $@ \
		--report $(PNR_REPORT) \
		--log $(PNR_LOG)

$(BUILD_DIR)/$(TOP_MODULE).fasm: $(FASM)
	cp $< $@

# -----------------------------------------------------------------------------
# 4. Bitstream Generation (Symbiflow/F4PGA specific utility usually needed here)
# -----------------------------------------------------------------------------
# Placeholder: Running fasm2frame or similar usually depends on the specific 
# F4PGA architecture installation (xc7).
bitstream: $(BUILD_DIR)/$(TOP_MODULE).fasm
	@echo "[TODO] Bitstream generation requires the Project X-Ray bitstream tools."
	@echo "Generated FASM: $(BUILD_DIR)/$(TOP_MODULE).fasm"

clean:
	rm -rf $(BUILD_DIR) reports
