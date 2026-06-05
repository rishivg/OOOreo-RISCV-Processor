# Formal verification driver (SymbiYosys).
#
# Tools (none are vendored): sby + yosys + an SMT solver (boolector/yices).
# The reproducible way to get all of them is the YosysHQ oss-cad-suite:
#   https://github.com/YosysHQ/oss-cad-suite-build/releases
# then `source <oss-cad-suite>/environment` so sby/yosys/boolector are on PATH.
#
# Targets:
#   make fifo        - prove the sync_fifo properties (no interfaces; works today)
#   make free_list   - prove free_list invariants (sv2v-flattened; see fv/)
#   make all         - module-level proofs above
#   make riscv-formal- ISA-level RVFI proofs (see riscv-formal/, needs checkout)
SHELL := /bin/bash
SV2V  ?= sv2v
PKG   := ../pkg/types.sv
ITF   := ../hdl/common/interfaces/backend_itf.sv

.PHONY: all fifo free_list riscv-formal clean
all: fifo free_list

# --- working example: self-contained module, read directly by yosys ---
fifo:
	sby -f sby/sync_fifo.sby

# --- interface module: sv2v-flatten into a single module, then prove ---
# free_list uses SV interfaces, which open-yosys cannot read; sv2v inlines the
# fv/ wrapper + free_list into one flat module.
# CAVEAT (verified): sv2v 0.0.13.1 STRIPS concurrent assertions during conversion
# (the inline `fl_no_overflow` and fv/ asserts do not survive the flatten), so
# this target currently elaborates the module but proves nothing until the
# assertions are preserved. Paths to fix, in order of preference:
#   - newer sv2v with SVA pass-through, or sv2v --top + a yosys `read_verilog
#     -sv` of a separate property file bound post-flatten;
#   - or express the invariant in fv/ as a tiny FSM-checkable form sv2v keeps.
# The `fifo` target needs none of this (yosys reads its SVA natively) and is the
# working tier-1 example today.
build/free_list_flat.v: fv/free_list_fv.sv ../hdl/backend/rename/free_list.sv $(ITF) $(PKG)
	@mkdir -p build
	$(SV2V) --top=free_list_fv $(PKG) $(ITF) ../hdl/backend/rename/free_list.sv fv/free_list_fv.sv > $@

free_list: build/free_list_flat.v
	sby -f sby/free_list.sby

riscv-formal:
	$(MAKE) -C riscv-formal

clean:
	rm -rf build sby/sync_fifo sby/free_list riscv-formal/checks
