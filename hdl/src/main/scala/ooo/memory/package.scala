package ooo

/** ooo.memory -- port of hdl/memory/
  *
  * LsuTop, MemRs (+ FuAgu, single addr-gen/cyc), LoadQueue (spec-load issue +
  * AGU-address bypass + violation detect), StoreQueue (store-to-load forwarding),
  * StoreBuf, LsuAdapter, and dcache/ (Dcache, DcacheCtrl, HitDetection -- arrays
  * stay as the SV SRAM blackboxes). Blocking D$ today; MSHRs are a roadmap item.
  */
package object memory
