package ooo.frontend.bpred

import spinal.core._
import ooo.CpuConfig

/** History fold and bank routing for a single early fetch outcome. */
class TageReadChoice(cfg:CpuConfig,length:Int,width:Int,historyWidth:Int) extends Component {
  setDefinitionName(s"tage_read_choice_$length")
  addAttribute("keep_hierarchy","yes")
  val io=new Bundle {
    val fold,recovery,pc_a,pc_b=in Bits(width bits)
    val fetch_fold=if (cfg.tageHistoryStateCofactors) in Bits(width bits) else null
    val history=in Bits(historyWidth bits)
    val valid,taken=in Bits(cfg.ifWidth bits)
    val flush=in Bool()
    val address_0,address_1=out Bits(width-1 bits)
    val bank=out Bool()
  }
  noIoPrefix()
  var fold:Bits=io.fold
  var history:Bits=io.history
  if (!cfg.tageHistoryStateCofactors) for (slot <- 0 until cfg.ifWidth) {
    fold=Mux(io.valid(slot),HistoryFold.step(fold,length,io.taken(slot),history(length-1)),fold)
    history=Mux(io.valid(slot),history(historyWidth-2 downto 0) ## io.taken(slot),history)
  }
  val selected=Mux(io.flush,io.recovery,if (cfg.tageHistoryStateCofactors) io.fetch_fold else fold)
  val a=io.pc_a ^ selected
  val b=io.pc_b ^ selected
  io.bank:=a(0)
  io.address_0:=Mux(a(0),b(width-1 downto 1),a(width-1 downto 1))
  io.address_1:=Mux(a(0),a(width-1 downto 1),b(width-1 downto 1))
}
