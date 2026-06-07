// Commit/control-flow interfaces: control buffer <-> ROB (branch resolve),
// control buffer -> branch predictor feedback. Split out of backend_itf.sv.

interface cb_rob_itf();
import cpu_params::*;

    logic   [ROB_IDX-1:0]   rob_id;
    logic                   miss_predict;
    logic   [31:0]          target_address;
    logic                   ready;
    logic                   dequeue;

    modport cb (
        output              rob_id,
        output              miss_predict,
        output              target_address,
        output              ready,
        input               dequeue
    );

    modport rob (
        input              rob_id,
        input              miss_predict,
        input              target_address,
        input              ready,
        output             dequeue
    );
endinterface

interface cb_bp_itf();
import cpu_params::*;

    logic                   update_en;
    logic   [31:0]          pc;
    logic   [3:0]           fu_opcode;
    logic                   branch_taken;
    logic   [31:0]          target_address;
    logic   [GHR_LEN-1:0]   ghr;        // history snapshot used when this branch was predicted
    logic                   is_call;    // committed branch pushes a return address (RAS)
    logic                   is_ret;     // committed branch pops a return address (RAS)
    logic                   is_compressed; // RVC: return address = pc+2 (else pc+4)

    modport cb (
        output              update_en,
        output              pc,
        output              fu_opcode,
        output              branch_taken,
        output              target_address,
        output              ghr,
        output              is_call,
        output              is_ret,
        output              is_compressed
    );

    modport bp (
        input               update_en,
        input               pc,
        input               fu_opcode,
        input               branch_taken,
        input               target_address,
        input               ghr,
        input               is_call,
        input               is_ret,
        input               is_compressed
    );

endinterface
