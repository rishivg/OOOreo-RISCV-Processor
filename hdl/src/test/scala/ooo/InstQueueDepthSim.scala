package ooo

import spinal.core._
import spinal.core.sim._
import ooo.frontend.InstQueue
import org.scalatest.funsuite.AnyFunSuite
import scala.collection.mutable.Queue

class InstQueueDecodeProbe(cfg: CpuConfig, depth: Int) extends InstQueue(cfg,depth) {
  val decodedMatches = if (cfg.iqParallelDecode) out Bool() else null
  if (cfg.iqParallelDecode) {
    val width = ooo.backend.decode.DecoderPayload.width(cfg)
    decodedMatches := (0 until cfg.idWidth).map { slot =>
      io.out_decoded_flat(slot * width,width bits) ===
        ooo.backend.decode.DecoderPayload.decode(io.out_inst_flat(slot * 32,32 bits),cfg).asBits
    }.reduce(_ && _)
  }
}

class InstQueueDepthSim extends AnyFunSuite {
  val cases = (for (depth <- Seq(2,4,8); gated <- Seq(false,true); head <- Seq(false,true))
    yield (depth,gated,head,0)) ++ (for (depth <- Seq(2,4,8); mode <- Seq(1,2))
    yield (depth,true,true,mode))
  for ((depth,gated,head,mode) <- cases) test(s"instruction queue depth=$depth gated=$gated head=$head decode=$mode preserves slots, PCs and metadata through stalls and wrap") {
    val cfg = CpuConfig(gateFetchPayload=gated,iqOneHotHead=head,
      iqParallelDecode=mode>0,iqMergedDecodeSelect=mode==2)
    TestSimulation.config.compile(new InstQueueDecodeProbe(cfg,depth)).doSim { d =>
      d.io.flatten.filter(_.isInput).foreach {
        case b: Bool => b #= false
        case b: Bits => b #= 0
        case _ =>
      }
      def tick(): Unit = { d.io.clk #= false; sleep(2); d.io.clk #= true; sleep(2); d.io.clk #= false; sleep(2) }
      d.io.rst #= true; tick(); tick(); d.io.rst #= false
      case class Entry(inst: BigInt,pc: BigInt,compressed: Boolean,prov: Int,taken: Boolean,target: BigInt)
      val expected = Queue[Entry]()
      val random = new scala.util.Random(41+depth)
      var serial = 0
      def pack(values: Seq[BigInt], width: Int): BigInt = values.zipWithIndex.map { case (v,i)=>v << (i*width) }.foldLeft(BigInt(0))(_ | _)
      for (cycle <- 0 until 700) {
        val count = if (cycle < 600) 1+random.nextInt(4) else 0
        val basePc = BigInt(0x1000+serial*16+14)
        val entries = (0 until count).map { i =>
          val pc=basePc+i*2; val compressed=(serial+i)%2==0; val taken=random.nextInt(4)==0
          val target=if (taken) BigInt(0x80010000L)+(serial+i)*32 else pc+(if (compressed) 2 else 4)
          val inst = if (mode>0) BigInt(random.nextLong() & 0xffffffffL)
            else BigInt(((serial+i)&0x7ff) << 20)|BigInt("00000093",16)
          Entry(inst,pc,compressed,(serial+i)&15,taken,target)
        }
        d.io.in_valid #= count>0; d.io.out_ready #= (cycle>=600 || random.nextInt(3)!=0)
        d.io.in_valid_slots #= (1 << count)-1
        d.io.in_inst_flat #= pack(entries.map(_.inst),32)
        d.io.in_inst_raw_flat #= pack(entries.map(_.inst),32)
        d.io.in_pc_flat #= pack(entries.map(_.pc),32)
        d.io.in_is_compressed #= entries.zipWithIndex.filter(_._1.compressed).map(x=>1 << x._2).sum
        d.io.in_predict_taken #= entries.zipWithIndex.filter(_._1.taken).map(x=>1 << x._2).sum
        d.io.in_predict_target_flat #= pack(entries.map(_.target),32)
        d.io.in_prov_flat #= pack(entries.map(e=>BigInt(e.prov)),CpuConfig().bpProvW)
        sleep(1)
        if (mode>0) assert(d.decodedMatches.toBoolean,s"decoded payload mismatch at cycle $cycle")
        if (d.io.out_valid.toBoolean && d.io.out_ready.toBoolean) {
          for (slot <- 0 until 2 if ((d.io.out_valid_slots.toInt >> slot)&1)!=0) {
            assert(expected.nonEmpty,s"unexpected output at cycle $cycle")
            val e=expected.dequeue()
            assert(((d.io.out_inst_flat.toBigInt >> (slot*32))&0xffffffffL)==e.inst)
            assert(((d.io.out_inst_raw_flat.toBigInt >> (slot*32))&0xffffffffL)==e.inst)
            assert(((d.io.out_pc_flat.toBigInt >> (slot*32))&0xffffffffL)==e.pc)
            assert((((d.io.out_is_compressed.toInt >> slot)&1)!=0)==e.compressed)
            assert((((d.io.out_predict_taken.toInt >> slot)&1)!=0)==e.taken)
            assert(((d.io.out_predict_target_flat.toBigInt >> (slot*32))&0xffffffffL)==e.target)
            assert(((d.io.out_prov_flat.toBigInt >> (slot*CpuConfig().bpProvW))&15)==e.prov)
          }
        }
        if (count>0 && d.io.in_ready.toBoolean) { expected ++= entries; serial+=count }
        tick()
      }
      assert(expected.isEmpty,"queued instructions must drain completely")
    }
  }
}
