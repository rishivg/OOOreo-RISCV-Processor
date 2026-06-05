SHELL=/bin/bash -o pipefail
.SHELLFLAGS += -e

PKG_SRCS  := $(PWD)/../pkg/types.sv
HDL_SRCS  := $(shell find $(PWD)/../hdl -name '*.sv')
COMM_HVL  := $(shell find $(PWD)/../hvl/common                -name '*.sv' -o -name '*.v' -o -name '*.o' )
VER_HVL   := $(COMM_HVL) $(shell find $(PWD)/../hvl/verilator -name '*.sv' -o -name '*.v' -o -name '*.o' -o -name '*.cpp')
SRAM_SRCS := $(shell find $(PWD)/../sram/output -name '*.v')
HDRS      := $(shell find $(PWD)/../hvl -name '*.svh') $(PWD)/../hvl/common/rvfi_reference.json
DW_IP     := $(shell python3 $(PWD)/../bin/get_options.py dw_ip)
VER_SRCS  := $(PKG_SRCS) $(HDL_SRCS) $(VER_HVL) $(SRAM_SRCS) $(DW_IP)

TIMEOUT   ?= 10000000

ECE411_NO_FLOAT = $(shell python3 $(PWD)/../bin/get_options.py no_float)

COMMON_FLAGS = +incdir+$(PWD)/../hvl/common  $(ECE411_NO_FLOAT) +define+DW_SUPPRESS_WARN +incdir+$(DW)/sim_ver
VER_FLAGS    = $(COMMON_FLAGS) +incdir+$(PWD)/../hvl/verilator -Wall --timescale 1ps/1ps -Mdir build -O1 -CFLAGS "-O1" --x-assign fast --x-initial fast --noassert --cc --exe ../verilator_warn.vlt --trace-fst --trace-structs --trace-max-array 1048576 --trace-max-width 1048576 +define+ECE411_VERILATOR

verilator/build/Vtop_tb: $(VER_SRCS) $(HDRS)
	mkdir -p verilator/build
	python3 check_sus.py
	python3 ../bin/rvfi_reference.py 8 $(ECE411_NO_FLOAT)
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
PERF_DIR  := perf
# program label defaults to the ELF basename without extension
PERF_NAME ?= $(basename $(notdir $(PROG)))
PERIOD_PS  = $(shell python3 $(PWD)/../bin/get_options.py clock)

# Run one program and capture its perf JSON: make perf PROG=/abs/path/foo.elf
.PHONY: perf
perf: verilator/build/Vtop_tb
	@$(MAKE) run_verilator_top_tb PROG="$(PROG)"
	@mkdir -p $(PERF_DIR)
	@python3 ../bin/parse_perf.py verilator/simulation.log \
		--program $(PERF_NAME) --period-ps $(PERIOD_PS) -o $(PERF_DIR)/$(PERF_NAME).json

# Gate all captured perf JSONs against the committed baseline (exit 1 on regression).
.PHONY: perf-check
perf-check:
	@python3 ../bin/check_perf.py --baseline perf_baseline.json $(PERF_DIR)/*.json

# Re-baseline after an intentional, reviewed change.
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
	rm -rf verilator
	rm -f *.log

clean:
	rm -rf bin verilator spike
