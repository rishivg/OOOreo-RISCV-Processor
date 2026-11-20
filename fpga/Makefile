# Every experiment owns its generated RTL, resolved configuration and reports.
OUT ?= $(CURDIR)/build/default
PYTHON ?= python3
.PHONY: all gen synth pnr
all: synth
gen:
	$(PYTHON) scripts/flow.py prepare --out '$(OUT)'
synth: gen
	$(PYTHON) scripts/flow.py synth --out '$(OUT)'
pnr: synth
	$(PYTHON) scripts/flow.py pnr --out '$(OUT)'
