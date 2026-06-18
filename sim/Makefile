SHELL=/bin/bash -o pipefail
.SHELLFLAGS += -e

# ---------------------------------------------------------------------------
# Verilator sim of the SpinalHDL OOOreo core.
#
# The core is generated from the SpinalHDL project in ../hdl (`sbt runMain
# ooo.Generate` -> ../hdl/gen/cpu.v, plain Verilog). The RVFI monitor is driven
# from the cpu's `rvfi_flat` debug output via the dedicated testbench
# hvl/verilator_spinal/top_tb_spinal.sv (no SV-hierarchy taps). The only external
# modules are vendor/IP: the SRAM macros (../sram/output) + DW_div_seq
# (../hvl/common/dw_mock.sv). See ../sim/build_spinal.sh for the all-in-one script.
# ---------------------------------------------------------------------------

CPU_GEN   ?= ooo.Generate
CPU_V     := $(PWD)/../hdl/gen/cpu.v

PKG_SRCS  := $(PWD)/../pkg/types.sv
# hvl/common (RVFI monitor, mem model, dw_mock) -- perf_monitor.sv is gone (it
# tapped the old SV hierarchy; the SpinalHDL TB drives RVFI from rvfi_flat).
COMM_HVL  := $(shell find $(PWD)/../hvl/common -name '*.sv' -o -name '*.v' -o -name '*.o')
TB_SRC    := $(PWD)/../hvl/verilator_spinal/top_tb_spinal.sv
HARNESS   := $(shell find $(PWD)/../hvl/verilator -name '*.cpp')
SRAM_SRCS := $(shell find $(PWD)/../sram/output -name '*.v')
DW_IP     := $(shell python3 $(PWD)/../bin/get_options.py dw_ip)
VER_SRCS  := $(PKG_SRCS) $(CPU_V) $(COMM_HVL) $(TB_SRC) $(HARNESS) $(SRAM_SRCS) $(DW_IP)

TIMEOUT   ?= 10000000

ECE411_NO_FLOAT = $(shell python3 $(PWD)/../bin/get_options.py no_float)

COMMON_FLAGS = +incdir+$(PWD)/../hvl/common  $(ECE411_NO_FLOAT) +define+DW_SUPPRESS_WARN
VER_FLAGS    = $(COMMON_FLAGS) +incdir+$(PWD)/../hvl/verilator -Wall -Wno-fatal --timescale 1ps/1ps \
               -Mdir build -O1 -CFLAGS "-O1" --x-assign fast --x-initial fast --noassert --cc --exe \
               ../verilator_warn.vlt +define+ECE411_VERILATOR

# Regenerate the SpinalHDL core (always -- sbt is incremental and cheap).
.PHONY: gen
gen:
	@cd ../hdl && sbt -batch "runMain $(CPU_GEN)"

verilator/build/Vtop_tb: gen $(COMM_HVL) $(TB_SRC) $(HARNESS) $(SRAM_SRCS)
	mkdir -p verilator/build
	cd verilator ;\
	verilator $(VER_FLAGS) $(VER_SRCS) --top-module top_tb |& tee build/compile.log
	cd verilator/build ;\
	$(MAKE) --jobs=$(shell echo $(shell nproc)-2 | bc) -f Vtop_tb.mk |& tee -a compile.log

.PHONY: run_verilator_top_tb
run_verilator_top_tb: verilator/build/Vtop_tb $(PROG)
	find ./verilator -maxdepth 1 -type f -delete
	python3 ../bin/generate_memory_file.py -32 $(PROG)
	cd verilator && ./build/Vtop_tb \
		+TIMEOUT_ECE411=$(TIMEOUT) \
		+CLOCK_PERIOD_PS_ECE411=$(shell python3 $(PWD)/../bin/get_options.py clock) \
		+BRAM_0_ON_X_ECE411=$(shell python3 $(PWD)/../bin/get_options.py bmem_x) \
		+MEMLST_ECE411="$(PWD)/bin/memory_32.lst" \
		+NO_DUMP_ALL_ECE411=1 \
		|& tee simulation.log

# ---- performance capture + regression gate (see bin/parse_perf.py, check_perf.py) ----
# NOTE: the detailed micro-arch counters came from the old perf_monitor.sv (SV
# hierarchy taps, removed with the SV core). parse_perf.py still captures Segment
# IPC / cycles from the TB output; re-instrumenting the fine-grained counters
# against the SpinalHDL hierarchy is future work.
PERF_DIR  := perf
PERF_NAME ?= $(basename $(notdir $(PROG)))
PERIOD_PS  = $(shell python3 $(PWD)/../bin/get_options.py clock)

.PHONY: perf
perf: verilator/build/Vtop_tb
	@$(MAKE) run_verilator_top_tb PROG="$(PROG)"
	@mkdir -p $(PERF_DIR)
	@python3 ../bin/parse_perf.py verilator/simulation.log \
		--program $(PERF_NAME) --period-ps $(PERIOD_PS) -o $(PERF_DIR)/$(PERF_NAME).json

.PHONY: perf-check
perf-check:
	@python3 ../bin/check_perf.py --baseline perf_baseline.json $(PERF_DIR)/*.json

.PHONY: perf-update
perf-update:
	@python3 ../bin/check_perf.py --baseline perf_baseline.json --update $(PERF_DIR)/*.json

.PHONY: spike
spike: $(ELF)
	mkdir -p spike
	spike --isa=$(shell python3 $(PWD)/../bin/get_options.py arch) -m0xaaaaa000:0x55556000 --log-commits $(ELF) |& tail -n +6 > spike/spike.log

.PHONY: interactive_spike
interactive_spike: $(ELF)
	spike --isa=$(shell python3 $(PWD)/../bin/get_options.py arch) -m0xaaaaa000:0x55556000 --log-commits -d $(ELF)

.PHONY: clean
clean:
	rm -rf verilator spike
	rm -f *.log
