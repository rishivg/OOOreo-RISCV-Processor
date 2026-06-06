// Integrated clock gate (latch-based, low-phase transparent).
//
// gclk follows clk only while en was high at the falling edge, so the downstream
// flops see no rising edge on cycles where en is low and their clock-tree /
// register power is saved. The low-phase latch makes the gate transparent
// (bit-identical to the ungated enable-guarded flops) even when en is
// combinational -- a plain clk&en gate is NOT, so do not "simplify" it.
//
// Maps to a Nangate45 CLKGATE (DLL latch + AND) under a DC/ICG flow, which also
// infers such gates automatically from enable-guarded flops. NOTE: the open
// yosys+OpenROAD PPA flow leaves this latch behavioral in the un-flattened
// submodule, which OpenROAD's structural verilog reader cannot parse -- so a
// clock-gated netlist needs the latch flattened/mapped before P&R. Correctness
// (RVFI) is validated on the RTL in Verilator, independent of that.
//
// Correct use: drive en with a guaranteed superset of every write-enable feeding
// the gated register group (OR of all port enables, plus reset).
module clock_gate (
    input  logic clk,
    input  logic en,
    output logic gclk
);
    logic en_latched;
    always_latch
        if (!clk)
            en_latched = en;
    assign gclk = clk & en_latched;
endmodule
