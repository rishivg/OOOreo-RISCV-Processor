package ooo.frontend

import spinal.core._
import ooo.{CpuConfig, PrioSelect}

/** One combinational fetch outcome; direction selection follows this boundary. */
class FetchControlChoice(cfg: CpuConfig) extends Component {
  setDefinitionName("fetch_control_choice")
  addAttribute("keep_hierarchy", "yes")
  val io=new Bundle {
    val valid,ctrl,taken,initialized=in Bits(cfg.ifWidth bits)
    val targets=in Bits(cfg.ifWidth*32 bits)
    val span,reset,flush=in Bool()
    val sequential,following,redirect=in Bits(32 bits)
    val reset_initialized,redirect_initialized,sequential_initialized,following_initialized=in Bool()
    val branch_valid,branch_taken=out Bits(cfg.ifWidth bits)
    val next_pc,predictor_pc=out Bits(32 bits)
    val request_initialized=out Bool()
  }
  noIoPrefix()
  val (en,oh,target)=PrioSelect((0 until cfg.ifWidth).map(i=>io.valid(i)&&io.ctrl(i)&&io.taken(i)),
    (0 until cfg.ifWidth).map(i=>io.targets(i*32,32 bits)))
  var below:Bool=False
  for (slot <- 0 until cfg.ifWidth) {
    io.branch_valid(slot):=io.valid(slot) && !below && io.ctrl(slot)
    io.branch_taken(slot):=io.ctrl(slot) && io.taken(slot)
    below=below || oh(slot)
  }
  val span=io.span && !en
  io.next_pc:=Mux(io.reset,B(0xaaaaa000L,32 bits),Mux(io.flush,io.redirect,
    Mux(en,target,Mux(span,io.following,io.sequential))))
  // A spanning instruction uses its original block for predictor SRAM reads.
  io.predictor_pc:=Mux(span && !io.flush,io.sequential,
    Mux(io.reset,B(cfg.resetPc,32 bits),Mux(io.flush,io.redirect,Mux(en,target,io.sequential))))
  val targetInitialized=ooo.OhSel(Vec(oh).asBits,
    (0 until cfg.ifWidth).map(i=>io.initialized(i).asBits))(0)
  io.request_initialized:=Mux(io.reset,io.reset_initialized,Mux(io.flush,io.redirect_initialized,
    Mux(en,targetInitialized,Mux(span,io.following_initialized,io.sequential_initialized))))
}
