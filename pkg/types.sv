package cpu_params;
    localparam unsigned ID_WIDTH = 2;
endpackage

package rvfi_types;
import cpu_params::*;

    typedef struct packed {
        logic                   commit;
        logic   [63:0]          order;
        logic   [31:0]          inst;
        logic   [4:0]           rs1_addr;
        logic   [4:0]           rs2_addr;
        logic   [31:0]          rs1_rdata;
        logic   [31:0]          rs2_rdata;
        logic   [4:0]           rd_addr;
        logic   [31:0]          rd_wdata;
        logic   [4:0]           frd_addr;
        logic   [31:0]          frd_wdata;
        logic   [31:0]          pc_rdata;
        logic   [31:0]          pc_wdata;
        logic   [31:0]          mem_addr;
        logic   [3:0]           mem_rmask;
        logic   [3:0]           mem_wmask;
        logic   [31:0]          mem_rdata;
        logic   [31:0]          mem_wdata;
        logic                   intr;       // first instruction retired after a trap (rvfi_intr)
    } rvfi_dbg_t;

endpackage
