"""Compare FPGA bindings against their behavioral reference models."""

import argparse
import json
from pathlib import Path

from icarus import run_testbench

ROOT = Path(__file__).resolve().parents[2]


def check_divider(out):
    out.mkdir(parents=True, exist_ok=True)
    (out / "results.json").unlink(missing_ok=True)
    reference = (
        (ROOT / "hvl/common/dw_mock.sv")
        .read_text()
        .replace("module DW_div_seq", "module divider_reference", 1)
    )
    (out / "reference.sv").write_text(reference)
    results = []
    for width, cycles, signed in [
        (1, 3, 1),
        (8, 3, 0),
        (8, 6, 1),
        (17, 8, 0),
        (32, 9, 0),
        (32, 12, 1),
        (33, 6, 1),
        (33, 8, 1),
        (33, 12, 1),
        (33, 33, 0),
        (33, 3, 1),
    ]:
        name = f"{width}-{cycles}-{signed}"
        directory = out / name
        directory.mkdir(exist_ok=True)
        text = f"""module tb;reg clk=0,rst_n=0,hold=0,start=0;reg [{width-1}:0] a=0,b=0;
    wire done,rdone,z,rz;wire [{width-1}:0] q,r,rq,rr;
    DW_div_seq #(.a_width({width}),.b_width({width}),.num_cyc({cycles}),.tc_mode({signed})) dut(clk,rst_n,hold,start,a,b,done,z,q,r);
    divider_reference #(.a_width({width}),.b_width({width}),.num_cyc({cycles}),.tc_mode({signed})) refdut(clk,rst_n,hold,start,a,b,rdone,rz,rq,rr);
    integer job,enabled;
    task tick;begin #2;clk=1;#2;if(done!==rdone)$fatal(1,"completion mismatch job %0d",job);if(done&&(q!==rq||r!==rr||z!==rz))$fatal(1,"result mismatch job %0d a %h b %h q %h rq %h r %h rr %h",job,a,b,q,rq,r,rr);clk=0;#2;end endtask
    initial begin tick();tick();rst_n=1;
    for(job=0;job<500;job=job+1)begin hold=0;start=1;a={{$random,$random}};b={{$random,$random}};
    case(job)0:begin a=0;b=0;end 1:begin a=1;b=0;end 2:begin a=-1;b=1;end 3:begin a={{1'b1,{{({width}-1){{1'b0}}}}}};b=-1;end endcase
     tick();start=0;enabled=0;while(!done)begin hold=($urandom%4==0);if(!hold)enabled=enabled+1;tick();end
     if(enabled!={cycles})$fatal(1,"latency %0d",enabled);hold=1;repeat(3)tick();hold=0;tick();
     if(job%37==0)begin start=1;tick();start=0;rst_n=0;tick();rst_n=1;end
    end $display("PASS {name}");$finish;end endmodule"""
        (directory / "tb.sv").write_text(text)
        run_testbench(directory, [
            ROOT / "hdl/src/main/verilog/dw_div_seq_iterative.v",
            out / "reference.sv", directory / "tb.sv",
        ])
        results.append({"case": name, "passed": True})
        print("PASS", name, flush=True)
    (out / "results.json").write_text(
        json.dumps({"passed": True, "cases": results}, indent=2) + "\n"
    )


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", nargs="?", type=Path,
                        default=ROOT / "fpga/build/divider-checks")
    check_divider(parser.parse_args().directory.resolve())
