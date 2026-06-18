#!/usr/bin/env python3
import os
from pathlib import Path


def emit_iostandard(lines, port):
    lines.append(f"set_property IOSTANDARD LVCMOS33 [get_ports {port}]")


def main():
    out = Path("build/constraints.expanded.xdc")
    out.parent.mkdir(parents=True, exist_ok=True)
    freq_mhz = float(os.environ.get("FREQ_MHZ", "100"))
    period_ns = 1000.0 / freq_mhz

    lines = [
        (
            "create_clock -add -name sys_clk_pin "
            f"-period {period_ns:.3f} -waveform {{0 {period_ns / 2:.3f}}} [get_ports clk]"
        ),
    ]

    for port in ("clk", "rst", "bmem_ready", "bmem_rvalid", "bmem_read", "bmem_write"):
        emit_iostandard(lines, port)

    for bus, width in (
        ("bmem_addr", 32),
        ("bmem_wdata", 64),
        ("bmem_raddr", 32),
        ("bmem_rdata", 64),
    ):
        for bit in range(width):
            emit_iostandard(lines, f"{bus}[{bit}]")

    out.write_text("\n".join(lines) + "\n")


if __name__ == "__main__":
    main()
