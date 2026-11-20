# Xilinx 7-series flow

Defaults: `CPU_PROFILE=mcu-efficient CPU_TARGET=fpga RVFI=0`. Requires Java/sbt,
Python 3.10+, Yosys with ABC9/Xilinx support, and nextpnr-xilinx plus a chip database
for placement/routing. Run from the repository root:

```sh
make -C fpga gen
make -C fpga synth
NEXTPNR=/path/to/nextpnr-xilinx CHIPDB=/path/to/xc7a200tfbg676-3.bin \
  FREQ_MHZ=20 make -C fpga pnr
```

`OUT` isolates experiments (default `fpga/build/default/`). Runs record configuration,
source hashes, RTL, netlist and reports; synthesis/PnR reject changed inputs.
`bin/rtl_sources.py` selects bindings. See [RTL configuration](../hdl/README.md)
for resource and ISA options.

| Override | FPGA default | Purpose |
| --- | --- | --- |
| `PRF_LUTRAM` | `1` | Banked distributed-memory register file |
| `PRF_BINARY_READ` | `1` | Binary mux for a flop register file |
| `PRF_READ_SHARING` | `7` | Memory=1, multiply/divide=2, branch=4 |
| `FPGA_NATIVE_ADD` | `1` | Native carry arithmetic |
| `FPGA_SHARED_SHIFT` | `1` | Shared left/right shifter |
| `STQ_AGE_LUT` | `1` | Store-queue age lookup |
| `DIV_CYCLES` | `12` | Divider latency, 3–33 cycles |

The target selects DSP-sized Karatsuba products, native memories and a BUFGCTRL
sleep gate. `CPU_MULTIPLIER`, `CPU_DIVIDER`, `CPU_MEMORY` and `CPU_CLOCK_GATE`
overrides are validated; FPGA synthesis rejects the simulation-only divider.
`CPU_TARGET=asic` restores ASIC defaults.

PnR defaults are 20 MHz, seed 2 and 3 threads (`FREQ_MHZ`, `PNR_SEED`,
`PNR_THREADS`); `PNR_EXTRA_ARGS` passes tool options. `ABC_MFS_CONFLICTS=5000`
controls SAT refinement. `FAST_MAP=1` omits refinement and cannot accompany a
changed budget; mapping verification remains enabled.

The feedback harness screens implementations. Board use needs a shell, pin
constraints and route/function checks; stock tools may need packing/routing fixes.
See [binding checks](../docs/verification.md#fpga-bindings) and
[physical implementation](../synth/implementation/README.md).
