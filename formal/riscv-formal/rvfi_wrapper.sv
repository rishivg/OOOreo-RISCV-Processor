// riscv-formal wrapper for the OOOreo core (2-wide commit => NRET=2).
//
// riscv-formal proves that every instruction the core RETIRES is ISA-legal and
// self-consistent (rvfi_insn checks), and that memory ordering holds (rvfi_mem).
// It reads a flat rvfi_* trace from this wrapper's outputs.
//
// PREREQUISITE (one small RTL exposure, mirroring hvl/common/rvfi_reference.svh):
//   The core exposes its retirement trace only as the internal interface array
//   `cpu.backend_i.rob_i.rvfi_itf[k]` (fields: commit, order, inst, rs1_addr,
//   rs2_addr, rs1_rdata, rs2_rdata, rd_addr, rd_wdata, pc_rdata, pc_wdata,
//   mem_addr, mem_rmask, mem_wmask, mem_rdata, mem_wdata). For formal, those taps
//   must be reachable post-sv2v-flatten. Two options:
//     (a) add real `output rvfi_*` ports to cpu (or a thin cpu_rvfi RTL wrapper)
//         driven from rob_i.rvfi_itf -- recommended, stable; or
//     (b) generate a flattened tap module (like rvfi_reference.svh) and bind it.
//   This wrapper assumes (a): a cpu_rvfi presenting flat per-channel taps
//   `rvfi_ch_*[k]`. Wire it to your chosen exposure before running checks.
//
// MEMORY: riscv-formal leaves the core's bmem_* inputs free (`anyseq`); the
// solver picks DRAM responses and the rvfi_mem channel checks ordering. Note
// the cache hierarchy makes the reachable state deep -- start with shallow
// `depth` and the `insn` checks (per-instruction, cheap) before `mem`/`liveness`.
`default_nettype none
module rvfi_wrapper (
    input  wire        clock,
    input  wire        reset,
    `RVFI_OUTPUTS
);
    localparam NRET = 2;

    // free DRAM-side inputs (riscv-formal drives them)
    (* keep *) `rvformal_rand_reg [31:0] bmem_raddr;
    (* keep *) `rvformal_rand_reg [63:0] bmem_rdata;
    (* keep *) `rvformal_rand_reg        bmem_ready;
    (* keep *) `rvformal_rand_reg        bmem_rvalid;
    (* keep *) wire [31:0] bmem_addr;
    (* keep *) wire        bmem_read, bmem_write;
    (* keep *) wire [63:0] bmem_wdata;

    // DUT: cpu_rvfi == cpu + flat retirement taps rvfi_ch_*[NRET] (see header).
    cpu_rvfi #(.NRET(NRET)) uut (
        .clk(clock), .rst(reset),
        .bmem_addr(bmem_addr), .bmem_read(bmem_read), .bmem_write(bmem_write),
        .bmem_wdata(bmem_wdata), .bmem_ready(bmem_ready),
        .bmem_raddr(bmem_raddr), .bmem_rdata(bmem_rdata), .bmem_rvalid(bmem_rvalid),
        .rvfi_ch_valid(rvfi_ch_valid), .rvfi_ch_order(rvfi_ch_order),
        .rvfi_ch_insn(rvfi_ch_insn), .rvfi_ch_rs1_addr(rvfi_ch_rs1_addr),
        .rvfi_ch_rs2_addr(rvfi_ch_rs2_addr), .rvfi_ch_rs1_rdata(rvfi_ch_rs1_rdata),
        .rvfi_ch_rs2_rdata(rvfi_ch_rs2_rdata), .rvfi_ch_rd_addr(rvfi_ch_rd_addr),
        .rvfi_ch_rd_wdata(rvfi_ch_rd_wdata), .rvfi_ch_pc_rdata(rvfi_ch_pc_rdata),
        .rvfi_ch_pc_wdata(rvfi_ch_pc_wdata), .rvfi_ch_mem_addr(rvfi_ch_mem_addr),
        .rvfi_ch_mem_rmask(rvfi_ch_mem_rmask), .rvfi_ch_mem_wmask(rvfi_ch_mem_wmask),
        .rvfi_ch_mem_rdata(rvfi_ch_mem_rdata), .rvfi_ch_mem_wdata(rvfi_ch_mem_wdata)
    );

    // per-channel taps from cpu_rvfi
    wire             rvfi_ch_valid     [NRET];
    wire [63:0]      rvfi_ch_order     [NRET];
    wire [31:0]      rvfi_ch_insn      [NRET];
    wire [4:0]       rvfi_ch_rs1_addr  [NRET];
    wire [4:0]       rvfi_ch_rs2_addr  [NRET];
    wire [31:0]      rvfi_ch_rs1_rdata [NRET];
    wire [31:0]      rvfi_ch_rs2_rdata [NRET];
    wire [4:0]       rvfi_ch_rd_addr   [NRET];
    wire [31:0]      rvfi_ch_rd_wdata  [NRET];
    wire [31:0]      rvfi_ch_pc_rdata  [NRET];
    wire [31:0]      rvfi_ch_pc_wdata  [NRET];
    wire [31:0]      rvfi_ch_mem_addr  [NRET];
    wire [3:0]       rvfi_ch_mem_rmask [NRET];
    wire [3:0]       rvfi_ch_mem_wmask [NRET];
    wire [31:0]      rvfi_ch_mem_rdata [NRET];
    wire [31:0]      rvfi_ch_mem_wdata [NRET];

    // pack per-channel taps into riscv-formal's flat rvfi_* vectors
    genvar i;
    generate for (i = 0; i < NRET; i = i + 1) begin : pack
        assign rvfi_valid[i]                 = rvfi_ch_valid[i] && !reset;
        assign rvfi_order[i*64 +: 64]        = rvfi_ch_order[i];
        assign rvfi_insn [i*32 +: 32]        = rvfi_ch_insn[i];
        assign rvfi_trap [i]                 = 1'b0;   // core has no traps (no CSR/exceptions modeled)
        assign rvfi_halt [i]                 = 1'b0;
        assign rvfi_intr [i]                 = 1'b0;
        assign rvfi_mode [i*2 +: 2]          = 2'd3;   // machine mode
        assign rvfi_ixl  [i*2 +: 2]          = 2'd1;   // XLEN=32
        assign rvfi_rs1_addr [i*5 +: 5]      = rvfi_ch_rs1_addr[i];
        assign rvfi_rs2_addr [i*5 +: 5]      = rvfi_ch_rs2_addr[i];
        assign rvfi_rs1_rdata[i*32 +: 32]    = rvfi_ch_rs1_rdata[i];
        assign rvfi_rs2_rdata[i*32 +: 32]    = rvfi_ch_rs2_rdata[i];
        assign rvfi_rd_addr  [i*5 +: 5]      = rvfi_ch_rd_addr[i];
        assign rvfi_rd_wdata [i*32 +: 32]    = rvfi_ch_rd_wdata[i];
        assign rvfi_pc_rdata [i*32 +: 32]    = rvfi_ch_pc_rdata[i];
        assign rvfi_pc_wdata [i*32 +: 32]    = rvfi_ch_pc_wdata[i];
        assign rvfi_mem_addr [i*32 +: 32]    = rvfi_ch_mem_addr[i];
        assign rvfi_mem_rmask[i*4  +: 4]     = rvfi_ch_mem_rmask[i];
        assign rvfi_mem_wmask[i*4  +: 4]     = rvfi_ch_mem_wmask[i];
        assign rvfi_mem_rdata[i*32 +: 32]    = rvfi_ch_mem_rdata[i];
        assign rvfi_mem_wdata[i*32 +: 32]    = rvfi_ch_mem_wdata[i];
    end endgenerate
endmodule
`default_nettype wire
