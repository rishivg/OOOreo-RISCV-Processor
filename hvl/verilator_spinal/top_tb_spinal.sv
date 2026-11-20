// Drive the RVFI monitor from the generated core’s retirement bus.
module top_tb
import cpu_params::*, rvfi_types::*;
(
    input   logic   clk,
    input   logic   rst
);
    localparam RVFIW = $bits(rvfi_dbg_t);

    longint timeout;
    initial begin
        $value$plusargs("OOOREO_TIMEOUT=%d", timeout);
    end

    mem_itf_banked mem_itf(.*);
    dram_w_burst_frfcfs_controller mem(.itf(mem_itf));

    mon_itf #(.CHANNELS(8)) mon_itf(.*);
    monitor #(.CHANNELS(8)) monitor(.itf(mon_itf));

    logic [ID_WIDTH*RVFIW-1:0] rvfi_flat;

    cpu dut(
        .clk(clk), .rst(rst),
        .bmem_addr(mem_itf.addr), .bmem_read(mem_itf.read), .bmem_write(mem_itf.write),
        .bmem_wdata(mem_itf.wdata), .bmem_ready(mem_itf.ready),
        .bmem_raddr(mem_itf.raddr), .bmem_rdata(mem_itf.rdata), .bmem_rvalid(mem_itf.rvalid),
`ifdef OOO_ZICSR
        .irq_ext(1'b0),
`endif
`ifdef OOO_LOWPOWER
        .scan_enable(1'b0), .sleeping(),
`endif
`ifdef OOO_MMIO
        .mmio_req_ready(1'b0), .mmio_resp_valid(1'b0),
        .mmio_resp_error(1'b0), .mmio_resp_rdata(32'b0),
        .mmio_req_valid(), .mmio_addr(), .mmio_wdata(), .mmio_rmask(), .mmio_wmask(),
`endif
        .rvfi_flat(rvfi_flat)
    );

    // ---- drive the RVFI monitor from cpu.rvfi_flat (ID_WIDTH channels used) ----
    always_comb begin
        for (int c = 0; c < 8; c++) begin
            mon_itf.valid[c]     = 1'b0;
            mon_itf.order[c]     = '0;
            mon_itf.inst[c]      = '0;
            mon_itf.rs1_addr[c]  = '0;  mon_itf.rs2_addr[c]  = '0;
            mon_itf.rs1_rdata[c] = '0;  mon_itf.rs2_rdata[c] = '0;
            mon_itf.rd_addr[c]   = '0;  mon_itf.rd_wdata[c]  = '0;
            mon_itf.frd_addr[c]  = '0;  mon_itf.frd_wdata[c] = '0;
            mon_itf.pc_rdata[c]  = '0;  mon_itf.pc_wdata[c]  = '0;
            mon_itf.mem_addr[c]  = '0;  mon_itf.mem_rmask[c] = '0;  mon_itf.mem_wmask[c] = '0;
            mon_itf.mem_rdata[c] = '0;  mon_itf.mem_wdata[c] = '0;
            mon_itf.intr[c]      = 1'b0;
        end
        for (int c = 0; c < ID_WIDTH; c++) begin
            automatic rvfi_dbg_t r = rvfi_flat[c*RVFIW +: RVFIW];
            mon_itf.valid[c]     = r.commit;
            mon_itf.order[c]     = r.order;
            mon_itf.inst[c]      = r.inst;
            mon_itf.rs1_addr[c]  = r.rs1_addr;  mon_itf.rs2_addr[c]  = r.rs2_addr;
            mon_itf.rs1_rdata[c] = r.rs1_rdata; mon_itf.rs2_rdata[c] = r.rs2_rdata;
            mon_itf.rd_addr[c]   = r.rd_addr;   mon_itf.rd_wdata[c]  = r.rd_wdata;
            mon_itf.frd_addr[c]  = r.frd_addr;  mon_itf.frd_wdata[c] = r.frd_wdata;
            mon_itf.pc_rdata[c]  = r.pc_rdata;  mon_itf.pc_wdata[c]  = r.pc_wdata;
            mon_itf.mem_addr[c]  = r.mem_addr;  mon_itf.mem_rmask[c] = r.mem_rmask;  mon_itf.mem_wmask[c] = r.mem_wmask;
            mon_itf.mem_rdata[c] = r.mem_rdata; mon_itf.mem_wdata[c] = r.mem_wdata;
            mon_itf.intr[c]      = r.intr;
        end
    end

    always @(posedge clk) begin
        for (int unsigned i = 0; i < 8; ++i) begin
            if (mon_itf.halt[i]) $finish;
        end
        if (timeout == 0) begin $error("TB Error: Timed out"); $fatal; end
        if (mon_itf.error != 0) $fatal;
        if (mem_itf.error != 0) $fatal;
        timeout <= timeout - 1;
    end

endmodule
