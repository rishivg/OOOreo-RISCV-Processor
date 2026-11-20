.PHONY: lint lint-verilator lint-icarus lint-yosys clean
lint:
	python3 run_lint.py all
lint-verilator lint-icarus lint-yosys:
	python3 run_lint.py $(patsubst lint-%,%,$@)
clean:
	rm -rf reports obj_dir output
