// Functional model for the fixed I0/S0 BUFGCTRL configuration used by Cpu.
// Hardware implementation uses the Xilinx primitive, not this simulation model.
module BUFGCTRL #(
    parameter INIT_OUT = 0,
    parameter PRESELECT_I0 = "FALSE",
    parameter PRESELECT_I1 = "FALSE"
) (
    input I0, I1, S0, S1, CE0, CE1, IGNORE0, IGNORE1,
    output O
);
    reg enabled = 1'b1;
    // Transparent low-phase storage preserves an active clock's full high phase.
    /* verilator lint_off LATCH */
    always @* if (!I0) enabled = CE0 && S0;
    /* verilator lint_on LATCH */
    assign O = I0 && enabled;
endmodule
