package ooo.frontend.bpred

import spinal.core._
import ooo.CpuConfig

/** Original history transition evaluated for one early fetch outcome. */
class TageHistoryChoice(cfg:CpuConfig,lengths:Seq[Int],indexWidth:Int,tagWidth:Int,historyWidth:Int) extends Component {
  setDefinitionName("tage_history_choice")
  addAttribute("keep_hierarchy","yes")
  val io=new Bundle {
    val history=in Bits(historyWidth bits)
    val fidx=in Bits(lengths.length*indexWidth bits)
    val ftag=in Bits(lengths.length*tagWidth bits)
    val valid,taken=in Bits(cfg.ifWidth bits)
    val next_history=out Bits(historyWidth bits)
    val next_fidx=out Bits(lengths.length*indexWidth bits)
    val next_ftag=out Bits(lengths.length*tagWidth bits)
  }
  noIoPrefix()
  var history:Bits=io.history
  val index=Array.tabulate(lengths.length)(t=>io.fidx(t*indexWidth,indexWidth bits))
  val tag=Array.tabulate(lengths.length)(t=>io.ftag(t*tagWidth,tagWidth bits))
  for (slot <- 0 until cfg.ifWidth) {
    for (t <- lengths.indices) {
      index(t)=Mux(io.valid(slot),HistoryFold.step(index(t),lengths(t),io.taken(slot),history(lengths(t)-1)),index(t))
      tag(t)=Mux(io.valid(slot),HistoryFold.step(tag(t),lengths(t),io.taken(slot),history(lengths(t)-1)),tag(t))
    }
    history=Mux(io.valid(slot),history(historyWidth-2 downto 0) ## io.taken(slot),history)
  }
  io.next_history:=history
  io.next_fidx:=Vec(index.toSeq).asBits
  io.next_ftag:=Vec(tag.toSeq).asBits
}
