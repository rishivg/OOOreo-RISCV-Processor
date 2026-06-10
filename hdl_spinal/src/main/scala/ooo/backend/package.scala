package ooo

/** ooo.backend -- port of hdl/backend/
  *
  * BackendTop + subpackages mirroring the SV layout:
  *   - decode/  : Decoder, IdStage, DsStage (decode + dispatch)
  *   - rename/  : Rat, Rrf, FreeList, Rob (map table, retirement file, ROB)
  *   - execute/ : Prf, IntRs (+ FuAlu, IssueArbiter), IntmRs (+ FuMul, FuDiv)
  *   - branch/  : BranchTop, BrRs (+ FuBr), ControlBuffer
  */
package object backend
