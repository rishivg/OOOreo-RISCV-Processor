# OOOreo Artix-7 Open FPGA Flow

This flow implements the generated OOOreo Verilog core with open-source FPGA
tools. It does not require sbt or sv2v: `make gen` copies
`../hdl/gen/cpu.v` into `build/cpu.v` and Yosys reads it directly.

## Local Toolchain

The repo copy is set up to use tools installed under `../tools`:

* `../tools/oss-cad-suite/bin/yosys`
* `../tools/nextpnr-xilinx-build/nextpnr-xilinx`
* `../tools/xc7a200tfbg676-3.bin`

`nextpnr-xilinx` was built locally from `gatecat/nextpnr-xilinx` with the
Project X-Ray database submodule. The selected implementation part is
`xc7a200tfbg676-3`. The smaller Artix-7 35T/100T class parts are not realistic
for the current flat synthesized OOOreo netlist.

## Flow

```bash
make gen
make synth
make pnr FREQ_MHZ=100
```

Useful knobs:

```bash
make synth USE_DSP=1   # default, maps multiplier logic to DSP48E1
make synth USE_DSP=0   # fallback, adds synth_xilinx -nodsp
make pnr FREQ_MHZ=50
```

The implementation top is `rtl/cpu_impl_top.v`, a thin wrapper around `cpu`
that exposes the clock/reset and bmem interface while tying off the wide RVFI
debug output internally. Using `cpu` directly keeps `rvfi_flat` live as an
826-bit top-level output and significantly inflates implementation area.

`scripts/gen_xdc.py` expands `constraints/constraints.xdc` into
`build/constraints.expanded.xdc`, with one `IOSTANDARD` assignment per port bit.
This avoids parser limitations in the current `nextpnr-xilinx` XDC frontend.
The generated clock period follows `FREQ_MHZ`.

## Current Results And Caveats

The DSP-mapped synthesis completes cleanly and writes
`build/cpu_impl_top-dsp.json`. Yosys reports 4 DSP48E1s and 44,208 flip-flops.
The cache SRAM behavioral models are only 16 entries deep, so Yosys maps them
to distributed RAM (`RAM32M`/`RAM64M`) instead of BRAM. Current BRAM usage is
therefore 0, not the expected NaxRiscv-like 12 BRAM.

The first `nextpnr-xilinx` implementation attempt on `xc7a200tfbg676-3` packed
and placed the DSP-mapped design, but routing failed on a constant-net arc into
a DSP48E1 `MULTSIGNIN` input:

```text
ERROR: Failed to route arc ... '$PACKER_GND_NET' ... DSP48_X0Y64/MULTSIGNIN.
```

Before that router failure, nextpnr reported 130,741 slice LUTs, 44,208 slice
FFs, 4 DSP48E1s, 0 BRAMs, and a post-placement maximum clock of 3.78 MHz at a
100 MHz target. Treat that frequency as a failed/place-stage timing datapoint,
not a routed Fmax.
