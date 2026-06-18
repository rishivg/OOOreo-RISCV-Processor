package ooo.backend

/** ooo.backend.branch -- port of hdl/backend/branch/
  *
  * BranchTop, BrRs (branch reservation station) + FuBr (resolve + redirect),
  * ControlBuffer (cb_entry: pc/ghr/is_call/is_ret/is_compressed for predictor
  * training + RAS at commit).
  */
package object branch
