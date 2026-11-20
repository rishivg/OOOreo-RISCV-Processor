#!/usr/bin/env python3
"""Generate isolated, source-identified FPGA experiments without RTL replacement."""

import argparse
import json
import os
import shlex
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "bin"))
from build_cache import digest as sha, file_hashes, tool_identity
from rtl_sources import configuration, sources
from generate_rtl import generate, generator_inputs


def command(args, log):
    with log.open("w") as stream:
        subprocess.run(
            list(map(str, args)),
            cwd=ROOT,
            stdout=stream,
            stderr=subprocess.STDOUT,
            check=True,
        )


def inputs(out):
    return configuration(out), sources(out) + [out / "pnr_harness.v"]


def input_hashes(out):
    _, files = inputs(out)
    paths = files + generator_inputs() + [
        out / "configuration.json", Path(__file__),
        ROOT / "bin/rtl_sources.py", ROOT / "bin/build_cache.py",
    ]
    return {
        str(Path(name).relative_to(ROOT)) if Path(name).is_relative_to(ROOT) else name: checksum
        for name, checksum in file_hashes(paths).items()
    }


def prepare(out):
    env = dict(os.environ)
    env.setdefault("CPU_PROFILE", "mcu-efficient")
    env.setdefault("CPU_TARGET", "fpga")
    env["RVFI"] = "0"
    env["RTL_OUT"] = str(out)
    generate(out, env=env, log=out / "generate.log")
    cfg = configuration(out)
    ports = [
        ".clk(clk)",
        ".rst(rst)",
        ".bmem_addr(addr)",
        ".bmem_read(rd)",
        ".bmem_write(wr)",
        ".bmem_wdata(wdata)",
        ".bmem_ready(state[0])",
        ".bmem_raddr(state)",
        ".bmem_rdata({state,state})",
        ".bmem_rvalid(state[1])",
        ".rvfi_flat()",
    ]
    if cfg["zicsr"]:
        ports += [".irq_ext(state[2])"]
    if cfg["lowPower"]:
        ports += [".scan_enable(1'b0)", ".sleeping(sleeping)"]
    if cfg["mmio"]:
        ports += [
            ".mmio_req_valid(mvalid)",
            ".mmio_req_ready(state[3])",
            ".mmio_addr(maddr)",
            ".mmio_rmask(rmask)",
            ".mmio_wmask(wmask)",
            ".mmio_wdata(mdata)",
            ".mmio_resp_valid(state[4])",
            ".mmio_resp_error(state[5])",
            ".mmio_resp_rdata(state)",
        ]
    wrapper = """// Implementation harness; not a board memory/peripheral controller.
module pnr_harness(input clk,rst);
(* keep="true" *) wire [31:0] addr;(* keep="true" *) wire [63:0] wdata;
(* keep="true" *) wire rd,wr;
(* keep="true" *) reg [31:0] state;
wire sleeping,mvalid;wire [31:0] maddr,mdata;wire [3:0] rmask,wmask;
"""
    if not cfg["mmio"]:
        wrapper += "assign mvalid=0;assign maddr=0;assign mdata=0;assign rmask=0;assign wmask=0;\n"
    if not cfg["lowPower"]:
        wrapper += "assign sleeping=0;\n"
    wrapper += "cpu core(" + ",".join(ports) + ");\n"
    wrapper += "always @(posedge clk) if(rst)state<=32'h35ade128;else state<={state[30:0],state[31]^state[21]^state[1]^state[0]}^addr^wdata[31:0]^wdata[63:32]^maddr^mdata^{20'b0,rmask,wmask,rd,wr,mvalid,sleeping};\nendmodule\n"
    (out / "pnr_harness.v").write_text(wrapper)
    manifest = {
        "schema_version": 1,
        "config": cfg,
        "inputs": input_hashes(out),
        "generated_rtl_sha256": sha(out / "cpu.v"),
    }
    (out / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")


def verify_inputs(out):
    manifest = json.loads((out / "manifest.json").read_text())
    try:
        current = input_hashes(out)
    except FileNotFoundError as error:
        raise SystemExit(f"Input missing since preparation: {error.filename}; run prepare again") from error
    changed = sorted(name for name in current.keys() | manifest["inputs"].keys()
                     if current.get(name) != manifest["inputs"].get(name))
    if changed:
        raise SystemExit(f"Inputs changed since preparation: {', '.join(changed)}; run prepare again")


def quote(path):
    return json.dumps(str(path), ensure_ascii=False)


def synth(out):
    verify_inputs(out)
    cfg, files = inputs(out)
    if cfg["implementation"]["divider"] == "mock":
        raise SystemExit("A simulation divider cannot be used for FPGA area or timing")
    budget = int(os.environ.get("ABC_MFS_CONFLICTS", "5000"))
    fast = os.environ.get("FAST_MAP", "0") == "1"
    if budget <= 0 or fast and budget != 5000:
        raise SystemExit("Invalid ABC budget or incompatible FAST_MAP setting")
    script = "\n".join("read_verilog -sv " + quote(p) for p in files) + "\n"
    script += "scratchpad -set xilinx_dsp.multonly 1\n"
    # ABC9 keeps its final equivalence verification; only SAT refinement effort changes.
    if fast:
        script += 'scratchpad -set abc9.script "+&scorr;&sweep;&dc2;&dch,-f,-r;&if,{W},{D},{R},-v"\n'
    elif budget != 5000:
        script += f'scratchpad -set abc9.script "+&scorr;&sweep;&dc2;&dch,-f,-r;&if,{{W}},{{D}},{{R}},-v;&mfs,-C,{budget}"\n'
    script += "synth_xilinx -top pnr_harness -family xc7 -flatten -abc9 -dff -widemux 8 -noiopad\nopt_clean -purge\ncheck -assert\n"
    script += f'tee -o {quote(out / "statistics.json")} stat -json\nwrite_json {quote(out / "netlist.json")}\n'
    (out / "synth.ys").write_text(script)
    command(
        [
            os.environ.get("YOSYS", "yosys"),
            "-l",
            out / "yosys.log",
            "-s",
            out / "synth.ys",
        ],
        out / "yosys-console.log",
    )
    stats = json.loads((out / "statistics.json").read_text())
    counts = stats["design"]["num_cells_by_type"]
    (out / "area.json").write_text(
        json.dumps(
            {
                "lut": sum(v for k, v in counts.items() if k.startswith("LUT")),
                "ff": sum(v for k, v in counts.items() if k.startswith("FD")),
                "cells": counts,
                "netlist_sha256": sha(out / "netlist.json"),
                "fast_map": fast,
                "abc_mfs_conflicts": budget,
            },
            indent=2,
        )
        + "\n"
    )


def pnr(out):
    verify_inputs(out)
    area = json.loads((out / "area.json").read_text())
    if sha(out / "netlist.json") != area["netlist_sha256"]:
        raise SystemExit("Netlist changed since synthesis")
    freq = float(os.environ.get("FREQ_MHZ", "20"))
    db = Path(os.environ["CHIPDB"]).resolve()
    pnr = os.environ.get("NEXTPNR", "nextpnr-xilinx")
    (out / "constraints.xdc").write_text(
        f"create_clock -name sys_clk -period {1000/freq:.6f} [get_ports clk]\n"
    )
    args = [
        pnr,
        "--chipdb",
        db,
        "--xdc",
        out / "constraints.xdc",
        "--freq",
        str(freq),
        "--seed",
        os.environ.get("PNR_SEED", "2"),
        "--threads",
        os.environ.get("PNR_THREADS", "3"),
        "--json",
        out / "netlist.json",
        "--write",
        out / "routed.json",
        "--fasm",
        out / "design.fasm",
        "--report",
        out / "timing.json",
        "--log",
        out / "nextpnr.log",
    ]
    args += shlex.split(os.environ.get("PNR_EXTRA_ARGS", ""))
    (out / "pnr-request.json").write_text(
        json.dumps(
            {
                "arguments": list(map(str, args)),
                "netlist_sha256": sha(out / "netlist.json"),
                "chipdb_sha256": sha(db),
                "nextpnr_sha256": tool_identity(pnr)["sha256"],
            },
            indent=2,
        )
        + "\n"
    )
    command(args, out / "nextpnr-console.log")


if __name__ == "__main__":
    stages = {"prepare": prepare, "synth": synth, "pnr": pnr}
    p = argparse.ArgumentParser()
    p.add_argument("stage", choices=stages)
    p.add_argument("--out", required=True, type=Path)
    a = p.parse_args()
    out = a.out.resolve()
    out.mkdir(parents=True, exist_ok=True)
    stages[a.stage](out)
