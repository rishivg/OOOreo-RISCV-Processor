package ooo.backend

/** ooo.backend.decode -- port of hdl/backend/decode/
  *
  * Decoder (RV32IM(C) -> uop), IdStage (per-slot decode, branch-split invariant,
  * RVFI dbg fields), DsStage (dispatch readiness, RS-type routing).
  */
package object decode
