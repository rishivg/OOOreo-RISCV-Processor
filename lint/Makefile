SHELL=/bin/bash -o pipefail
.SHELLFLAGS += -e

# The core is generated from the SpinalHDL project in ../hdl (run_lint.sh runs
# `sbt runMain ooo.Generate` -> ../hdl/gen/cpu.v before linting). These vars are
# documentation; the actual source list lives in run_lint.sh.
HDL_SRCS  := $(PWD)/../hdl/gen/cpu.v
SRAM_SRCS := $(shell find $(PWD)/../sram/output -name '*.v')
STUB_SRCS := $(PWD)/dw_stubs.v

# Verilator Flags:
# -Wall: Enable all warnings
# --lint-only: Check for syntax/lint errors, don't build
# --top-module cpu: Top level module
FLAGS     := -Wall --lint-only --top-module cpu -Wno-fatal +define+ECE411_VERILATOR ../sim/verilator_warn.vlt

.PHONY: lint
lint:
	./run_lint.sh all

.PHONY: lint-verilator
lint-verilator:
	./run_lint.sh verilator

.PHONY: lint-icarus
lint-icarus:
	./run_lint.sh icarus

.PHONY: lint-yosys
lint-yosys:
	./run_lint.sh yosys

.PHONY: clean
clean:
	rm -rf obj_dir reports/*.stats reports/*.log

