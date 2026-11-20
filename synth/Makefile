SHELL := /bin/bash
.SHELLFLAGS := -euo pipefail -c
YOSYS ?= yosys

.PHONY: synth ppa ppa-remap clean
synth:
	mkdir -p reports outputs work
	python3 ../bin/generate_rtl.py "$(CURDIR)/work/rtl"
	python3 -c 'import sys; sys.path.insert(0,"../bin"); from rtl_sources import sources; import json; print("\n".join("read_verilog -sv "+json.dumps(str(p)) for p in sources("work/rtl")))' > work/synthesis.ys
	printf '%s\n' 'synth -top cpu' 'check -assert' 'stat -tech cmos' 'write_verilog outputs/synth.v' >> work/synthesis.ys
	$(YOSYS) -s work/synthesis.ys 2>&1 | tee reports/synthesis.log
ppa:
	opensource/pnr/ppa.sh
ppa-remap:
	opensource/pnr/ppa.sh --remap
clean:
	rm -rf reports outputs work
