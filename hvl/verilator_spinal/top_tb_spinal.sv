// Minimal Verilator testbench for the SpinalHDL core (ROADMAP Phase 0).
//
// = hvl/verilator/top_tb.sv MINUS the SV-internal-coupled checkers: the RVFI
// `monitor` + `rvfi_reference.svh` hierarchical taps (dut.backend_i.rob_i.*) and
// `perf_monitor` (also taps dut internals). Those rebind once the SpinalHDL ROB
// is ported (Phase 3) -- SpinalHDL preserves hierarchy names, so a regenerated
// rvfi_reference tap file will point at the SpinalHDL ROB instance.
//
// Purpose: prove gen/cpu.v links with the real memory model across the bmem
// boundary. The stub core never fetches, so this runs to TIMEOUT -- success here
// just means "compiles, links, and simulates without crashing".
module top_tb
(
    input   logic   clk,
    input   logic   rst
);

    longint timeout;
    initial begin
        $value$plusargs("TIMEOUT_ECE411=%d", timeout);
    end

    mem_itf_banked mem_itf(.*);
    dram_w_burst_frfcfs_controller mem(.itf(mem_itf));

    // instantiated but undriven -- keeps the cpp harness' halt/error refs valid
    mon_itf #(.CHANNELS(8)) mon_itf(.*);

    cpu dut(
        .clk            (clk),
        .rst            (rst),

        .bmem_addr  (mem_itf.addr  ),
        .bmem_read  (mem_itf.read  ),
        .bmem_write (mem_itf.write ),
        .bmem_wdata (mem_itf.wdata ),
        .bmem_ready (mem_itf.ready ),
        .bmem_raddr (mem_itf.raddr ),
        .bmem_rdata (mem_itf.rdata ),
        .bmem_rvalid(mem_itf.rvalid)
    );

    always @(posedge clk) begin
        for (int unsigned i = 0; i < 8; ++i) begin
            if (mon_itf.halt[i]) begin
                $finish;
            end
        end
        if (timeout == 0) begin
            $error("TB Error: Timed out");
            $fatal;
        end
        if (mem_itf.error != 0) begin
            $fatal;
        end
        timeout <= timeout - 1;
    end

endmodule
