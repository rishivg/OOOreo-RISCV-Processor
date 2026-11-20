SHELL := /bin/bash
.SHELLFLAGS := -euo pipefail -c
PYTHON ?= python3
OUT ?= $(CURDIR)/generated
export OPENRAM_HOME ?= $(OPENRAM)/compiler
export OPENRAM_TECH ?= $(OPENRAM)/technology

.PHONY: all configs clean
configs:
	$(PYTHON) sram.py --out "$(OUT)"
all: configs
	@test -n "$(OPENRAM)" || { echo "Set OPENRAM to an installed OpenRAM checkout" >&2; exit 2; }
	for config in "$(OUT)"/*/*.py; do $(PYTHON) "$(OPENRAM)/sram_compiler.py" "$$config"; done
clean:
	rm -rf "$(OUT)"
