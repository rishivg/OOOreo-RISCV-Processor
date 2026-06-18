package ooo

/** ooo.common -- port of hdl/common/
  *
  * Shared infrastructure:
  *   - interfaces/ : the SV `*_itf` interfaces -> SpinalHDL Bundles/IMasterSlave
  *     (cacheline, frontend_fifo, fifo_backend, cb_bp, execute, lsu, commit, rename)
  *   - cache/      : lru_array, valid_array, plru_update
  *   - clock_gate, one_hot_mux, skid_buffer, bmem_arbiter, dmem_arbiter, cache_adapter
  *
  * SpinalHDL note: most SV `interface` + `modport` pairs become a `Bundle` with
  * `IMasterSlave` (master/slave views) instead of explicit modports.
  */
package object common
