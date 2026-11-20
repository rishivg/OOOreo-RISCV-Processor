package ooo.frontend.bpred

import spinal.core._
import ooo.CpuConfig

/** Counter-dependent choices are ready before the tag-hit mask. */
class TagePredCases(cfg: CpuConfig) extends Component {
  setDefinitionName("tage_prediction_cases")
  addAttribute("keep_hierarchy","yes")
  val n=cfg.tageNum;val cw=cfg.tageCtrBits;val uw=cfg.tageUBits
  require(n>0 && n<=4)
  val io=new Bundle {
    val counters=in Bits(n*cw bits);val usefulness=in Bits(n*uw bits)
    val base=in Bool();val use_alt=in Bool();val predictions=out Bits((1<<n) bits)
  }
  noIoPrefix()
  val counters=io.counters.subdivideIn(n slices)
  val usefulness=io.usefulness.subdivideIn(n slices)
  for(mask <- 0 until (1<<n)) {
    val hits=(0 until n).filter(i=>(mask & (1<<i))!=0).reverse
    if(hits.isEmpty) io.predictions(mask):=io.base
    else {
      val provider=hits.head
      val alternate=if(hits.size>1) !counters(hits(1)).msb else io.base
      val weak=(usefulness(provider)===0) &&
        ((counters(provider)===0) || (counters(provider).asSInt===S(-1,cw bits)))
      io.predictions(mask):=Mux(weak && io.use_alt,alternate,!counters(provider).msb)
    }
  }
}
