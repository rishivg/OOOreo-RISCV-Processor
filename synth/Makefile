SHELL=/bin/bash -o pipefail
.SHELLFLAGS += -e

export DESIGN_TOP = cpu

.PHONY: synth
synth:
	@mkdir -p reports outputs work/src
	@rm -rf work/src/* work/pkg_headers
	@echo "Copying sources..."
	@mkdir -p work/src/hdl work/src/pkg
	@cp -r ../hdl/* work/src/hdl/
	@cp -r ../pkg/* work/src/pkg/
	@mkdir -p work/src/sram
	@if [ -d "../sram/output" ]; then cp -r ../sram/output/* work/src/sram/; fi
	@echo "Splitting packages into headers..."
	@python3 split_pkg.py
	@echo "Converting imports to includes (moving to top)..."
	@python3 convert_imports.py
	@if command -v yosys >/dev/null 2>&1; then \
		echo "Found Yosys, generating synthesis script..."; \
		echo "# Generated synthesis script" > synthesis.ys; \
		find work/src/hdl -name '*.sv' | sort | while read f; do echo "read_verilog -sv -Iwork/pkg_headers $$f" >> synthesis.ys; done; \
		find work/src/sram -name '*.v' | while read f; do echo "read_verilog $$f" >> synthesis.ys; done; \
		echo "prep -top $(DESIGN_TOP)" >> synthesis.ys; \
		echo "hierarchy -check" >> synthesis.ys; \
		echo "synth -top $(DESIGN_TOP)" >> synthesis.ys; \
		echo "stat -tech cmos" >> synthesis.ys; \
		echo "write_verilog outputs/synth.v" >> synthesis.ys; \
		echo "tee -o reports/area.rpt stat -tech cmos" >> synthesis.ys; \
		yosys -s synthesis.ys | tee synthesis.log; \
	else \
		echo "Error: Yosys not found in PATH. Please install Yosys for open-source synthesis."; \
		exit 1; \
	fi

# Open-source PPA + PD4 flow (sv2v -> yosys -> OpenROAD P&R -> STA). Needs Docker
# (openroad/orfs image). Reuses an existing netlist_pnr.v unless --remap is passed.
.PHONY: ppa ppa-remap
ppa:
	opensource/pnr/ppa.sh
ppa-remap:
	opensource/pnr/ppa.sh --remap

.PHONY: clean
clean:
	rm -rf reports outputs work synthesis.log synthesis.ys
