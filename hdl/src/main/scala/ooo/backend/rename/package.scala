package ooo.backend

/** ooo.backend.rename -- port of hdl/backend/rename/
  *
  * Rat (arch->phys map + intra-bundle forwarding), FreeList (fixed-set circular
  * buffer of non-arch pregs), Rrf (retirement map), Rob (in-order commit, row-
  * granular + slot-granular recovery, viol/branch flush, RVFI emit).
  *
  * The RenameRob spike (../../spike) is the validated proof-of-concept for the
  * N-wide rename + ROB allocate/commit core of this package.
  */
package object rename
