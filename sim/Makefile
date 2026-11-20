SHELL := /bin/bash
.SHELLFLAGS := -euo pipefail -c
ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST)))/..)
BUILD_DIR ?= $(ROOT)/sim/verilator/build
CPU_GEN ?= ooo.Generate
JOBS ?= 4
TRACE ?= 0
TIMEOUT ?= 10000000
PERF_REFERENCE ?= $(ROOT)/sim/perf-reference.json
PERF_NAME ?= $(basename $(notdir $(PROG)))
PERIOD_PS := $(shell python3 $(ROOT)/bin/get_options.py clock)
BINARY := $(abspath $(BUILD_DIR))/Vtop_tb
MEMORY_DIR ?= $(BUILD_DIR)/memory
RUN_DIR := $(abspath $(BUILD_DIR))/run
FORCE_BUILD ?= 0

.PHONY: gen build run run-only perf perf-check perf-update spike interactive_spike clean

gen:
	RVFI=1 python3 $(ROOT)/bin/generate_rtl.py "$(BUILD_DIR)/rtl" --generator "$(CPU_GEN)" $(if $(filter 1,$(FORCE_BUILD)),--force,)

build:
	python3 $(ROOT)/sim/build.py --build-dir "$(BUILD_DIR)" --generator "$(CPU_GEN)" --jobs $(JOBS) \
		$(if $(filter 1,$(TRACE)),--trace,) $(if $(filter 1,$(FORCE_BUILD)),--force,)

run: build
	$(MAKE) run-only

run-only:
	@test -x "$(BINARY)" || { echo "Run make build first" >&2; exit 2; }
	@test -n "$(PROG)" || { echo "Set PROG to an ELF or assembly file" >&2; exit 2; }
	python3 $(ROOT)/bin/generate_memory_file.py -32 "$(abspath $(PROG))" --output-dir "$(MEMORY_DIR)"
	mkdir -p "$(RUN_DIR)" "$(RUN_DIR)/../spike"
	cd "$(RUN_DIR)" && "$(BINARY)" \
		+OOOREO_TIMEOUT=$(TIMEOUT) +OOOREO_CLOCK_PERIOD_PS=$(PERIOD_PS) \
		+OOOREO_BRAM_0_ON_X=$(shell python3 $(ROOT)/bin/get_options.py bmem_x) \
		+OOOREO_MEMLST="$(abspath $(MEMORY_DIR))/memory_32.lst" +OOOREO_NO_DUMP_ALL=1 \
		$(SIM_ARGS) 2>&1 | tee simulation.log

perf: run
	mkdir -p $(ROOT)/sim/perf
	python3 $(ROOT)/bin/parse_perf.py "$(RUN_DIR)/simulation.log" \
		--program $(PERF_NAME) --period-ps $(PERIOD_PS) -o $(ROOT)/sim/perf/$(PERF_NAME).json

perf-check:
	python3 $(ROOT)/bin/check_perf.py --reference "$(PERF_REFERENCE)" $(ROOT)/sim/perf/*.json

perf-update:
	python3 $(ROOT)/bin/check_perf.py --reference "$(PERF_REFERENCE)" --update $(ROOT)/sim/perf/*.json

spike interactive_spike:
	@test -n "$(ELF)" || { echo "Set ELF to a bare-metal program" >&2; exit 2; }
	mkdir -p $(ROOT)/sim/spike
	spike $(if $(filter interactive_spike,$@),-d,) --isa=$(shell python3 $(ROOT)/bin/get_options.py arch) \
		-m0xaaaaa000:0x55556000 --log-commits "$(ELF)"

clean:
	rm -rf $(ROOT)/sim/verilator $(ROOT)/sim/verilator_power $(ROOT)/sim/bin $(ROOT)/sim/spike
