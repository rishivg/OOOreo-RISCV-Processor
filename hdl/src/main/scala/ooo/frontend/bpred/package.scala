package ooo.frontend

/** ooo.frontend.bpred -- port of hdl/frontend/branch_predictor/
  *
  * Tage (4 tagged components + bimodal base, spec/commit GHR), Ubtb (micro-BTB,
  * 64-entry assoc), Ras (return address stack, spec/commit). These are pure
  * predictors -> RVFI can't break them, so they're the safest pieces to port and
  * unit-test in SpinalSim against captured prediction traces from the SV core.
  */
package object bpred
