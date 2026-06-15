// Module-swap shim for hdl/backend/decode/id_stage.sv. Feeds the decode_packet_t
// inst/valid to id_stage_spinal, wires the rename control back to id_rat_itf/
// id_fl_itf/id_rob_itf, and assembles the uop_t + rvfi_dbg_t payloads natively from
// the decoder/control outputs + packet fields + RAT/ROB feedback. id_stage_spinal
// re-emits the Decoder (module `decoder`) -> EXTRA_EXCLUDE the SV decoder.sv.
// Used only by sim/build_swap.sh; hdl/ stays pristine.
module id_stage
import cpu_params::*, uop_types::*;
(
    input   logic               clk,
    input   logic               rst,
    fifo_backend_itf.backend    from_fifo,
    output  logic               nxt_valid,
    input   logic               nxt_ready,
    output  logic               uops_valid[ID_WIDTH],
    output  logic   [1:0]       rs_type[ID_WIDTH],
    output  uop_t               uops[ID_WIDTH],
    id_rat_itf.id               to_rat,
    id_fl_itf.id                to_fl,
    id_rob_itf.id               to_rob
);
    logic [ID_WIDTH*32-1:0]      ff_inst_flat;
    logic [ID_WIDTH-1:0]         ff_valid_slots;
    logic [ID_WIDTH*2-1:0]       rs_type_flat, fu_type_flat;
    logic [ID_WIDTH*4-1:0]       fu_opcode_flat;
    logic [ID_WIDTH-1:0]         op1_sel_flat, op2_sel_flat, is_store_flat;
    logic [ID_WIDTH*32-1:0]      imm_flat;
    logic [ID_WIDTH*ARF_IDX-1:0] rd_arch_flat, rs1_arch_flat, rs2_arch_flat;
    logic [ID_WIDTH-1:0]         uv_flat, flv_flat, we_flat;
    logic [ID_WIDTH*PRF_IDX-1:0] rd_phy_flat;

    generate for (genvar i = 0; i < ID_WIDTH; i++) begin
        assign ff_inst_flat[i*32 +: 32] = from_fifo.packet.inst[i];
        assign ff_valid_slots[i]        = from_fifo.packet.valid[i];

        assign uops_valid[i] = uv_flat[i];
        assign rs_type[i]    = rs_type_flat[i*2 +: 2];

        // uop_t assembled natively
        assign uops[i].valid          = uv_flat[i];
        assign uops[i].pc             = from_fifo.packet.pc[i];
        assign uops[i].inst           = from_fifo.packet.inst[i];
        assign uops[i].is_compressed  = from_fifo.packet.is_compressed[i];
        assign uops[i].rs_type        = rs_type_flat[i*2 +: 2];
        assign uops[i].fu_type        = fu_type_flat[i*2 +: 2];
        assign uops[i].fu_opcode      = fu_opcode_flat[i*4 +: 4];
        assign uops[i].op1_sel        = op1_sel_flat[i];
        assign uops[i].op2_sel        = op2_sel_flat[i];
        assign uops[i].imm            = imm_flat[i*32 +: 32];
        assign uops[i].rd_arch        = rd_arch_flat[i*ARF_IDX +: ARF_IDX];
        assign uops[i].rs1_arch       = rs1_arch_flat[i*ARF_IDX +: ARF_IDX];
        assign uops[i].rs2_arch       = rs2_arch_flat[i*ARF_IDX +: ARF_IDX];
        assign uops[i].predict_taken  = from_fifo.packet.predict_taken[i];
        assign uops[i].predict_target = from_fifo.packet.predict_target[i];
        assign uops[i].ghr            = from_fifo.packet.ghr[i];
        assign uops[i].rs1_phy        = to_rat.rs1_phy[i];
        assign uops[i].rs1_valid      = to_rat.rs1_valid[i];
        assign uops[i].rs2_phy        = to_rat.rs2_phy[i];
        assign uops[i].rs2_valid      = to_rat.rs2_valid[i];
        assign uops[i].rd_phy         = rd_phy_flat[i*PRF_IDX +: PRF_IDX];
        assign uops[i].rob_id         = to_rob.rob_id[i];

        // to_rat
        assign to_rat.rs1_arch[i] = rs1_arch_flat[i*ARF_IDX +: ARF_IDX];
        assign to_rat.rs2_arch[i] = rs2_arch_flat[i*ARF_IDX +: ARF_IDX];
        assign to_rat.write_en[i] = we_flat[i];
        assign to_rat.rd_arch[i]  = rd_arch_flat[i*ARF_IDX +: ARF_IDX];
        assign to_rat.rd_phy[i]   = to_fl.free_idx[i];
        // to_fl
        assign to_fl.valid[i] = flv_flat[i];
        // to_rob
        assign to_rob.inst_valid[i] = uv_flat[i];
        assign to_rob.rd_phy[i]     = rd_phy_flat[i*PRF_IDX +: PRF_IDX];
        assign to_rob.rd_arch[i]    = rd_arch_flat[i*ARF_IDX +: ARF_IDX];
        assign to_rob.is_store[i]   = is_store_flat[i];
        // rvfi_dbg (matches SV id_stage)
        assign to_rob.rvfi_dbg[i].order      = 'x;
        assign to_rob.rvfi_dbg[i].inst       = from_fifo.packet.inst_raw[i];
        assign to_rob.rvfi_dbg[i].rs1_addr   = rs1_arch_flat[i*ARF_IDX +: ARF_IDX];
        assign to_rob.rvfi_dbg[i].rs2_addr   = rs2_arch_flat[i*ARF_IDX +: ARF_IDX];
        assign to_rob.rvfi_dbg[i].rs1_rdata  = 'x;
        assign to_rob.rvfi_dbg[i].rs2_rdata  = 'x;
        assign to_rob.rvfi_dbg[i].rd_addr    = rd_arch_flat[i*ARF_IDX +: ARF_IDX];
        assign to_rob.rvfi_dbg[i].rd_wdata   = 'x;
        assign to_rob.rvfi_dbg[i].frd_addr   = 'x;
        assign to_rob.rvfi_dbg[i].frd_wdata  = 'x;
        assign to_rob.rvfi_dbg[i].pc_rdata   = from_fifo.packet.pc[i];
        assign to_rob.rvfi_dbg[i].pc_wdata   = from_fifo.packet.predict_target[i];
        assign to_rob.rvfi_dbg[i].mem_addr   = 'x;
        assign to_rob.rvfi_dbg[i].mem_rmask  = '0;
        assign to_rob.rvfi_dbg[i].mem_wmask  = '0;
        assign to_rob.rvfi_dbg[i].mem_rdata  = 'x;
        assign to_rob.rvfi_dbg[i].mem_wdata  = 'x;
    end endgenerate

    logic [ID_WIDTH*PRF_IDX-1:0] free_idx_flat;
    generate for (genvar i = 0; i < ID_WIDTH; i++) assign free_idx_flat[i*PRF_IDX +: PRF_IDX] = to_fl.free_idx[i]; endgenerate

    id_stage_spinal id_stage_spinal_i (
        .clk(clk), .rst(rst),
        .from_fifo_valid(from_fifo.valid),
        .from_fifo_inst_flat(ff_inst_flat),
        .from_fifo_valid_slots(ff_valid_slots),
        .from_fifo_ready(from_fifo.ready),
        .nxt_valid(nxt_valid), .nxt_ready(nxt_ready),
        .to_fl_ready(to_fl.ready), .to_fl_free_idx_flat(free_idx_flat),
        .to_rob_ready(to_rob.ready),
        .rs_type_flat(rs_type_flat), .fu_type_flat(fu_type_flat), .fu_opcode_flat(fu_opcode_flat),
        .op1_sel(op1_sel_flat), .op2_sel(op2_sel_flat), .imm_flat(imm_flat),
        .rd_arch_flat(rd_arch_flat), .rs1_arch_flat(rs1_arch_flat), .rs2_arch_flat(rs2_arch_flat),
        .is_store(is_store_flat),
        .uops_valid(uv_flat), .uop_rd_phy_flat(rd_phy_flat),
        .to_fl_valid(flv_flat), .to_rat_write_en(we_flat), .to_rob_valid(to_rob.valid)
    );
endmodule
