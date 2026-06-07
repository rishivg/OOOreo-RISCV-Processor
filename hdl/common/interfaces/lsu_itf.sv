// LSU interfaces: load/store queues, store buffer, AGU, memory-ordering
// disambiguation + commit. Split out of backend_itf.sv.

interface ls_rob_itf();
import cpu_params::*;

    logic   [ROB_PTR_IDX-1:0]   rob_head;
    logic   [ROB_IDX-1:0]       rob_id;
    logic   [31:0]              addr_dbg;
    logic   [3:0]               rmask_dbg;
    logic   [3:0]               wmask_dbg;
    logic   [31:0]              rdata_dbg;
    logic   [31:0]              wdata_dbg;
    logic                       valid;

    modport lsu (
        input               rob_head,
        output              rob_id,
        output              addr_dbg,
        output              rmask_dbg,
        output              wmask_dbg,
        output              rdata_dbg,
        output              wdata_dbg,
        output              valid
    );

    modport rob (
        output              rob_head,
        input               rob_id,
        input               addr_dbg,
        input               rmask_dbg,
        input               wmask_dbg,
        input               rdata_dbg,
        input               wdata_dbg,
        input               valid
    );

endinterface

interface ldq_stq_itf();
import cpu_params::*;

    logic   [STQ_IDX:0]     stq_tail; // Index from 1, 0 means empty
    logic                   stq_deq;
    logic   [STQ_IDX:0]     ldq_tracker[LDQ_DEPTH];
    logic   [31:0]          ldq_addr[LDQ_DEPTH];
    logic   [3:0]           ldq_rmask[LDQ_DEPTH];
    logic                   has_conflicting_store[LDQ_DEPTH]; // overlapping older store, known OR unknown address
    logic                   known_conflict[LDQ_DEPTH];        // overlapping older store with a KNOWN address
    logic                   unknown_older[LDQ_DEPTH];         // some older store still has an unknown address
    logic                   forward_en[LDQ_DEPTH];          // load can be satisfied by a single fully-covering store
    logic   [31:0]          forward_wdata[LDQ_DEPTH];       // that store's data word

    modport ldq (
        input               stq_tail,
        input               stq_deq,
        output              ldq_tracker,
        output              ldq_addr,
        output              ldq_rmask,
        input               has_conflicting_store,
        input               known_conflict,
        input               unknown_older,
        input               forward_en,
        input               forward_wdata
    );

    modport stq (
        output              stq_tail,
        output              stq_deq,
        input               ldq_tracker,
        input               ldq_addr,
        input               ldq_rmask,
        output              has_conflicting_store,
        output              known_conflict,
        output              unknown_older,
        output              forward_en,
        output              forward_wdata
    );

endinterface

interface ldq_stb_itf();
import cpu_params::*;

    logic   [31:0]          ldq_addr[LDQ_DEPTH];
    logic   [3:0]           ldq_rmask[LDQ_DEPTH];
    logic                   has_conflicting_store[LDQ_DEPTH];

    modport ldq (
        output              ldq_addr,
        output              ldq_rmask,
        input               has_conflicting_store
    );

    modport stb (
        input               ldq_addr,
        input               ldq_rmask,
        output              has_conflicting_store
    );

endinterface

interface ldq_rob_itf();
import cpu_params::*;

    logic   [ROB_IDX-1:0]       rob_id;
    logic   [31:0]              addr_dbg;
    logic   [3:0]               rmask_dbg;
    logic   [31:0]              rdata_dbg;
    logic                       valid;
    logic                       violation;      // speculatively-issued load aliased an older store
    logic   [ROB_IDX-1:0]       violation_rob_id;

    modport ldq (
        output              rob_id,
        output              addr_dbg,
        output              rmask_dbg,
        output              rdata_dbg,
        output              valid,
        output              violation,
        output              violation_rob_id
    );

    modport rob (
        input               rob_id,
        input               addr_dbg,
        input               rmask_dbg,
        input               rdata_dbg,
        input               valid,
        input               violation,
        input               violation_rob_id
    );

endinterface

interface stq_rob_itf();
import cpu_params::*;

    logic   [ROB_IDX-1:0]       rob_id;
    logic   [31:0]              addr_dbg;
    logic   [3:0]               wmask_dbg;
    logic   [31:0]              wdata_dbg;
    logic   [31:0]              rs1_value_dbg;
    logic   [31:0]              rs2_value_dbg;
    logic                       valid;
    logic                       ready;

    modport stq (
        output              rob_id,
        output              addr_dbg,
        output              wmask_dbg,
        output              wdata_dbg,
        output              rs1_value_dbg,
        output              rs2_value_dbg,
        output              valid,
        input               ready
    );

    modport rob (
        input               rob_id,
        input               addr_dbg,
        input               wmask_dbg,
        input               wdata_dbg,
        input               rs1_value_dbg,
        input               rs2_value_dbg,
        input               valid,
        output              ready
    );

endinterface

interface stq_stb_itf();
import cpu_params::*;

    logic                       valid;
    logic                       ready;
    logic   [31:0]              addr;
    logic   [3:0]               wmask;
    logic   [31:0]              wdata;

    modport stq (
        output              valid,
        input               ready,
        output              addr,
        output              wmask,
        output              wdata
    );

    modport stb (
        input               valid,
        output              ready,
        input               addr,
        input               wmask,
        input               wdata
    );

endinterface

interface agu_lsq_itf();
import cpu_params::*;
import lsu_types::*;

    logic                   valid;
    agu_lsq_t               data;

    modport agu (
        output              valid,
        output              data
    );

    modport lsq (
        input               valid,
        input               data
    );

endinterface
