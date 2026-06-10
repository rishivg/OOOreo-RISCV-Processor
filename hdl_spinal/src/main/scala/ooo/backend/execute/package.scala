package ooo.backend

/** ooo.backend.execute -- port of hdl/backend/execute/
  *
  * Prf (64-entry physical regfile, comb read + bypass), IntRs (compacting int
  * reservation station, 2 fast-bypass ALU outputs) + FuAlu + IssueArbiter,
  * IntmRs (mul/div RS) + FuMul (parallel, MUL_LATENCY=2) + FuDiv (DW_div_seq
  * blackbox). Wakeup CAM + select is prototyped in the IssueQueue spike.
  */
package object execute
