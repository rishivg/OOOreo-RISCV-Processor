# Generate and run riscv-formal checks for OOOreo.
# Prereqs: ./fetch.sh (riscv-formal checkout) + sby/yosys/solver on PATH
# (oss-cad-suite). Also requires the flattened core RTL with rvfi exposure
# (see ../gen_rtl_flat.sh and the header of rvfi_wrapper.sv).
SHELL := /bin/bash
RVF   := checkout

.PHONY: all genchecks run clean
all: run

../build/cpu_rvfi_flat.v:
	../gen_rtl_flat.sh        # sv2v-flatten cpu + rvfi exposure -> this file

genchecks: ../build/cpu_rvfi_flat.v
	@test -d $(RVF) || { echo "run ./fetch.sh first"; exit 1; }
	python3 $(RVF)/checks/genchecks.py

run: genchecks
	$(MAKE) -C checks

clean:
	rm -rf checks
