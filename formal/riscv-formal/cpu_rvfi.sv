// Formal RVFI exposure shim for the SpinalHDL OOOreo core.
//
// rvfi_wrapper.sv assumes a `cpu_rvfi` module that presents flat per-channel
// retirement taps `rvfi_ch_*[NRET]` (option (a) in that file's header). That is
// trivial now that the SpinalHDL `cpu` exposes its whole retirement record as a
// single `rvfi_flat` debug bus at its boundary (the same record the sim TB
// hvl/verilator_spinal/top_tb_spinal.sv drives the riscv-formal monitor from).
//
// This wrapper instantiates the generated `cpu` (../../hdl/gen/cpu.v) and unpacks
// rvfi_flat into the per-channel arrays. NRET defaults to the core's ID_WIDTH
// (2-wide commit). gen_rtl_flat.sh sv2v-flattens this + pkg/types.sv into plain
// Verilog and concatenates it with the core for riscv-formal's yosys flow.
module cpu_rvfi
import cpu_params::*, rvfi_types::*;
#(parameter int NRET = ID_WIDTH)
(
    input  logic        clk,
    input  logic        rst,
    // bmem boundary -- riscv-formal drives the inputs (anyseq)
    output logic [31:0] bmem_addr,
    output logic        bmem_read,
    output logic        bmem_write,
    output logic [63:0] bmem_wdata,
    input  logic        bmem_ready,
    input  logic [31:0] bmem_raddr,
    input  logic [63:0] bmem_rdata,
    input  logic        bmem_rvalid,
    // flattened per-channel retirement taps consumed by rvfi_wrapper.sv
    output logic        rvfi_ch_valid     [NRET],
    output logic [63:0] rvfi_ch_order     [NRET],
    output logic [31:0] rvfi_ch_insn      [NRET],
    output logic [4:0]  rvfi_ch_rs1_addr  [NRET],
    output logic [4:0]  rvfi_ch_rs2_addr  [NRET],
    output logic [31:0] rvfi_ch_rs1_rdata [NRET],
    output logic [31:0] rvfi_ch_rs2_rdata [NRET],
    output logic [4:0]  rvfi_ch_rd_addr   [NRET],
    output logic [31:0] rvfi_ch_rd_wdata  [NRET],
    output logic [31:0] rvfi_ch_pc_rdata  [NRET],
    output logic [31:0] rvfi_ch_pc_wdata  [NRET],
    output logic [31:0] rvfi_ch_mem_addr  [NRET],
    output logic [3:0]  rvfi_ch_mem_rmask [NRET],
    output logic [3:0]  rvfi_ch_mem_wmask [NRET],
    output logic [31:0] rvfi_ch_mem_rdata [NRET],
    output logic [31:0] rvfi_ch_mem_wdata [NRET]
);
    localparam int RVFIW = $bits(rvfi_dbg_t);

    logic [ID_WIDTH*RVFIW-1:0] rvfi_flat;

    cpu dut (
        .clk(clk), .rst(rst),
        .bmem_addr(bmem_addr), .bmem_read(bmem_read), .bmem_write(bmem_write),
        .bmem_wdata(bmem_wdata), .bmem_ready(bmem_ready),
        .bmem_raddr(bmem_raddr), .bmem_rdata(bmem_rdata), .bmem_rvalid(bmem_rvalid),
        .rvfi_flat(rvfi_flat)
    );

    always_comb begin
        for (int c = 0; c < NRET; c++) begin
            rvfi_ch_valid[c]     = 1'b0;
            rvfi_ch_order[c]     = '0;  rvfi_ch_insn[c]      = '0;
            rvfi_ch_rs1_addr[c]  = '0;  rvfi_ch_rs2_addr[c]  = '0;
            rvfi_ch_rs1_rdata[c] = '0;  rvfi_ch_rs2_rdata[c] = '0;
            rvfi_ch_rd_addr[c]   = '0;  rvfi_ch_rd_wdata[c]  = '0;
            rvfi_ch_pc_rdata[c]  = '0;  rvfi_ch_pc_wdata[c]  = '0;
            rvfi_ch_mem_addr[c]  = '0;  rvfi_ch_mem_rmask[c] = '0;  rvfi_ch_mem_wmask[c] = '0;
            rvfi_ch_mem_rdata[c] = '0;  rvfi_ch_mem_wdata[c] = '0;
        end
        for (int c = 0; (c < ID_WIDTH) && (c < NRET); c++) begin
            automatic rvfi_dbg_t r = rvfi_flat[c*RVFIW +: RVFIW];
            rvfi_ch_valid[c]     = r.commit;
            rvfi_ch_order[c]     = r.order;     rvfi_ch_insn[c]      = r.inst;
            rvfi_ch_rs1_addr[c]  = r.rs1_addr;  rvfi_ch_rs2_addr[c]  = r.rs2_addr;
            rvfi_ch_rs1_rdata[c] = r.rs1_rdata; rvfi_ch_rs2_rdata[c] = r.rs2_rdata;
            rvfi_ch_rd_addr[c]   = r.rd_addr;   rvfi_ch_rd_wdata[c]  = r.rd_wdata;
            rvfi_ch_pc_rdata[c]  = r.pc_rdata;  rvfi_ch_pc_wdata[c]  = r.pc_wdata;
            rvfi_ch_mem_addr[c]  = r.mem_addr;  rvfi_ch_mem_rmask[c] = r.mem_rmask;  rvfi_ch_mem_wmask[c] = r.mem_wmask;
            rvfi_ch_mem_rdata[c] = r.mem_rdata; rvfi_ch_mem_wdata[c] = r.mem_wdata;
        end
    end
endmodule
