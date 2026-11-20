package ooo.common

import spinal.core._

/** Reuse an SRAM's held synchronous read result only for the exact same row.
  * Any write to that row invalidates reuse, including a same-edge read/write:
  * the SRAM read sees the old row and must be refreshed on the next request.
  */
class SynchronousReadReuse(addressWidth: Int, request: Bool, address: Bits,
                           write: Bool, writeAddress: Bits) extends Area {
  val known = RegInit(False)
  val heldAddress = Reg(Bits(addressWidth bits))
  val enable = request && (!known || address =/= heldAddress)
  when(enable) { heldAddress := address; known := True }
  val resultingAddress = Mux(enable,address,heldAddress)
  when(write && writeAddress === resultingAddress) { known := False }
}
