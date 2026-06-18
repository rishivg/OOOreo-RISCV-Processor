package ooo

/** ooo.frontend -- port of hdl/frontend/
  *
  * Houses: If1Stage, FetchAlign, Decompressor, Ftq, Ftb, InstQueue, FrontendTop.
  * Subpackages:
  *   - bpred/  : branch_predictor (Tage, Ubtb, Ras)
  *   - icache/ : Icache, IcacheCtrl (data/tag arrays stay as the SV SRAM blackboxes)
  */
package object frontend
