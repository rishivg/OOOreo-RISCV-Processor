"""Compare FPGA bindings against their behavioral reference models."""

import argparse
import json
from pathlib import Path

from icarus import run_testbench

ROOT = Path(__file__).resolve().parents[2]


def check_memories(out):
    out.mkdir(parents=True, exist_ok=True)
    (out / "results.json").unlink(missing_ok=True)
    cases = [
        ("dcache_data_array", 256, 4, 32),
        ("dcache_data_bank", 32, 4, 4),
        ("icache_data_array", 256, 6, 32),
        ("icache_data_bank", 128, 6, 16),
        ("dcache_tag_array", 24, 4, 1),
        ("dcache_tag_array", 25, 4, 1),
    ]
    results = []
    for name, width, address_width, mask_width in cases:
        directory = out / f"{name}-{width}"
        directory.mkdir(exist_ok=True)
        reference = (
            (ROOT / f"sram/output/{name}/{name}.v")
            .read_text()
            .replace("module " + name + "(", "module reference(")
        )
        (directory / "reference.v").write_text(reference)
        mask = "" if name == "dcache_tag_array" else ",.wmask0(mask)"
        random_data = ("data=$random(seed);" if width < 32
                       else f"for(j=0;j<{width};j=j+32)data[j+:32]=$random(seed);")
        testbench = f"""module tb;
     reg clk=0,cs=1,we=1;reg [{address_width-1}:0] addr=0;reg [{width-1}:0] data=0;reg [{mask_width-1}:0] mask=0;
     wire [{width-1}:0] a,b;integer i,j;integer seed=63421;
     reference #(.DATA_WIDTH({width}),.ADDR_WIDTH({address_width})) refmem(.clk0(clk),.csb0(cs),.web0(we),.addr0(addr),.din0(data),.dout0(a){mask});
     {name} #(.DATA_WIDTH({width}),.ADDR_WIDTH({address_width})) dut(.clk0(clk),.csb0(cs),.web0(we),.addr0(addr),.din0(data),.dout0(b){mask});
     task tick;begin #2;clk=1;#2;clk=0;#2;end endtask
     task check;begin if(a !== b)begin $display("MISMATCH {name} cycle=%0d a=%h b=%h",i,a,b);$fatal;end end endtask
     initial begin
     cs=0;we=1;tick();
     for(i=0;i<{1<<address_width};i=i+1)begin we=0;addr=i;mask='1;data={{ {((width+31)//32)}{{$random(seed)}} }};tick();end
     we=1;tick();tick();
     for(i=0;i<24000;i=i+1)begin
     cs=($random(seed)&7)<3;we=($random(seed)&3)!=0;addr=$random(seed);mask=$random(seed);
     {random_data}
     tick();check();
     end
     $display("PASS {name} 24000 randomized cycles");$finish;
     end
     endmodule"""
        (directory / "tb.v").write_text(testbench)
        try:
            output = run_testbench(directory, [
                directory / "tb.v", directory / "reference.v",
                ROOT / "fpga/rtl/xilinx_mem_wrappers.v",
            ])
        except RuntimeError:
            results.append({"module": name, "width": width, "pass": False, "cycles": 24000})
            (out / "results.json").write_text(json.dumps(results, indent=2))
            raise
        print(output, flush=True)
        results.append({"module": name, "width": width, "pass": True, "cycles": 24000})
    (out / "results.json").write_text(json.dumps(results, indent=2))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", nargs="?", type=Path,
                        default=ROOT / "fpga/build/memory-checks")
    check_memories(parser.parse_args().directory.resolve())
