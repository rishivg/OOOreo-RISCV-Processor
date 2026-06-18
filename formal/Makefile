# Formal verification driver for the SpinalHDL OOOreo core.
#
# Tools (none are vendored): sby + yosys + an SMT solver (boolector/yices), plus a
# riscv-formal checkout (riscv-formal/fetch.sh). The reproducible way to get the
# solver stack is the YosysHQ oss-cad-suite:
#   https://github.com/YosysHQ/oss-cad-suite-build/releases
# then `source <oss-cad-suite>/environment` so sby/yosys/boolector are on PATH.
#
# The core is SpinalHDL -> emits plain Verilog (hdl/gen/cpu.v). gen_rtl_flat.sh
# generates it and combines it with the cpu_rvfi RVFI-exposure shim
# (riscv-formal/cpu_rvfi.sv) into a single flat file the formal flow reads.
#
# Targets:
#   make riscv-formal - ISA-level RVFI proofs of the whole core (riscv-formal/,
#                       needs ./riscv-formal/fetch.sh + a solver)
#   make flat         - just (re)generate build/cpu_rvfi_flat.v
SHELL := /bin/bash

.PHONY: all riscv-formal flat clean
all: riscv-formal

# Flat core + RVFI exposure shim for the formal flow.
flat:
	./gen_rtl_flat.sh

riscv-formal:
	$(MAKE) -C riscv-formal

clean:
	rm -rf build riscv-formal/checks
