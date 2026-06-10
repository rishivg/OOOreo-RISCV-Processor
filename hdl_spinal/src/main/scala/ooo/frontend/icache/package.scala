package ooo.frontend

/** ooo.frontend.icache -- port of hdl/frontend/icache/
  *
  * Icache (8KB, 64 sets x 4 way x 32B, epoch/generation valid bit) + IcacheCtrl
  * (PASS_THRU/WB/ALLOCATE FSM). The data/tag arrays stay as the existing SV
  * SRAM blackboxes (sram/output/icache_*); the SpinalHDL wrapper instantiates
  * them as BlackBox so the synth + fakeram macro flow is unchanged.
  */
package object icache
