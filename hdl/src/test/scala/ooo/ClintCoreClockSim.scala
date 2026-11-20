package ooo

import spinal.core._
import spinal.core.sim._
import ooo.memory.Clint
import org.scalatest.funsuite.AnyFunSuite

class ClintCoreClockHarness(retimed: Boolean, decoded: Boolean) extends Component {
  val io = new Bundle {
    val clk, rst, enable, valid = in Bool()
    val addr = in Bits(16 bits)
    val rmask, wmask = in Bits(4 bits)
    val wdata = in Bits(32 bits)
    val referenceData, clientData = out Bits(32 bits)
    val mismatch = out Bool()
  }
  val cfg=CpuProfiles.named("mcu")
  val reference=new Clint(cfg,decoded,decoded,retimed)
  val client=new Clint(cfg,decoded,decoded,retimed,clientClockedRead=true)
  reference.setDefinitionName("clint_reference")
  client.setDefinitionName("clint_client")
  client.io.read_clk := io.clk && io.enable
  for (c <- Seq(reference,client)) {
    c.io.clk := io.clk; c.io.rst := io.rst
    c.io.req_valid := io.valid; c.io.req_addr := io.addr
    c.io.req_rmask := io.rmask; c.io.req_wmask := io.wmask; c.io.req_wdata := io.wdata
    if (decoded) {
      val select=Clint.registerSelect(B(cfg.clintHi16,16 bits) ## io.addr)
      val read=io.valid && io.rmask.orR
      val write=io.valid && io.wmask.orR
      c.io.read_sel := select & B(Clint.offsets.size bits,default -> read)
      c.io.write_sel := select & B(Clint.offsets.size bits,default -> write)
      c.io.read_fire := read
      c.io.request_fire := read || write
    }
  }
  io.referenceData := reference.io.rdata; io.clientData := client.io.rdata
  io.mismatch := (reference.io.resp =/= client.io.resp) ||
    (reference.io.mtime =/= client.io.mtime) || (reference.io.irq_timer =/= client.io.irq_timer) ||
    (reference.io.irq_soft =/= client.io.irq_soft)
}

class ClintCoreClockSim extends AnyFunSuite {
  for (retimed <- Seq(false,true); decoded <- Seq(false,true))
    test(s"CLINT requester clock preserves reads and live timer/IRQs through sleep, retimed=$retimed decoded=$decoded") {
      TestSimulation.config.compile(new ClintCoreClockHarness(retimed,decoded)).doSim { d =>
        val random=new scala.util.Random(600)
        d.io.clk #= false; d.io.rst #= true; d.io.enable #= true; d.io.valid #= false
        d.io.addr #= 0; d.io.rmask #= 0; d.io.wmask #= 0; d.io.wdata #= 0
        var haveRead=false
        def tick(): Unit = {
          d.io.clk #= false; sleep(2); d.io.clk #= true; sleep(2)
          assert(!d.io.mismatch.toBoolean)
          if (haveRead) assert(d.io.referenceData.toBigInt==d.io.clientData.toBigInt)
          d.io.clk #= false; sleep(2)
        }
        tick();tick()
        var previousRequest=false; var sleepLeft=0
        for (i <- 0 until 6000) {
          if (!previousRequest && sleepLeft==0 && random.nextInt(20)==0) sleepLeft=1+random.nextInt(40)
          val enabled=sleepLeft==0
          val valid=enabled && random.nextInt(4)!=0
          val read=if (random.nextBoolean()) 15 else 0
          val write=if (random.nextInt(3)==0) random.nextInt(16) else 0
          val addr=(Clint.offsets :+ 0x1234)(random.nextInt(6))+random.nextInt(4)
          d.io.enable #= enabled; d.io.valid #= valid; d.io.addr #= addr
          d.io.rmask #= read; d.io.wmask #= write; d.io.wdata #= BigInt(32,random)
          d.io.rst #= (i%127==0)
          if (valid && read!=0) haveRead=true
          tick()
          previousRequest=valid && (read!=0 || write!=0)
          if (sleepLeft>0) sleepLeft-=1
        }
      }
    }
}
