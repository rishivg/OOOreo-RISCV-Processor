package ooo

import spinal.core._
import spinal.core.sim._
import ooo.execute.ControlBuffer
import org.scalatest.funsuite.AnyFunSuite

class ControlBufferLifetimeSim extends AnyFunSuite {
  test("branch metadata FIFO lifetime, ID reuse, stale completions and reset") {
    val cfg=CpuProfiles.named("mcu-efficient")
    TestSimulation.config.compile(new ControlBuffer(cfg)).doSim { d =>
      d.io.flatten.filter(_.isInput).foreach {
        case b:Bool=>b #= false
        case b:Bits=>b #= 0
        case _=>
      }
      def tick():Unit={d.io.clk #= false;sleep(2);d.io.clk #= true;sleep(2);d.io.clk #= false;sleep(2)}
      d.io.rst #= true;tick();tick();d.io.rst #= false
      case class Entry(id:Int,pc:BigInt,op:Int,kp:Int,prov:BigInt,compressed:Boolean,call:Boolean,
                       var resolved:Boolean=false,var target:BigInt=BigInt(0),var taken:Boolean=false,var miss:Boolean=false)
      val queue=scala.collection.mutable.ArrayBuffer[Entry]()
      val random=new scala.util.Random(124)
      var serial=0;var popped=0;var stale=0
      for(cycle<-0 until 3500) {
        val reset=cycle%193==192
        val incoming=cycle<3300 && random.nextBoolean()
        val branchReady=random.nextInt(4)!=0
        val dequeue=queue.headOption.exists(_.resolved) && (cycle>=3300 || random.nextBoolean())
        var nextId=serial%(cfg.robDepth*cfg.idWidth)
        while(queue.exists(_.id==nextId))nextId=(nextId+1)%(cfg.robDepth*cfg.idWidth)
        val op=if(cycle%23==0)15 else random.nextInt(8)
        val entry=Entry(nextId,BigInt(0x1000+serial*4),op,random.nextInt(cfg.ifWidth),BigInt(cfg.bpProvW,random),random.nextBoolean(),cycle%5==0)
        val cdb:Option[Int]=if(queue.nonEmpty && (cycle>=3300 || random.nextInt(3)!=0))Some(queue(random.nextInt(queue.size)).id)
          else if(cycle%3==0)Some((0 until cfg.robDepth*cfg.idWidth).find(id=> !queue.exists(_.id==id)).get) else None
        val target=BigInt(32,random);val taken=random.nextBoolean();val miss=random.nextBoolean()
        d.io.rst #= reset;d.io.from_ds_valid #= incoming;d.io.branch_ready #= branchReady;d.io.to_rob_dequeue #= dequeue
        d.io.uop_rob_id #= entry.id;d.io.uop_pc #= entry.pc;d.io.uop_fu_opcode #= entry.op
        d.io.uop_kp #= entry.kp;d.io.uop_prov #= entry.prov;d.io.uop_is_compressed #= entry.compressed
        d.io.uop_inst #= (if(entry.call)BigInt("000000ef",16)else BigInt("00000063",16))
        d.io.br_cdb_valid #= cdb.isDefined;d.io.br_cdb_rob_id #= cdb.getOrElse(0).toLong
        d.io.br_cdb_target #= target;d.io.br_cdb_branch_taken #= taken;d.io.br_cdb_miss_predict #= miss
        sleep(1)
        assert(d.io.from_ds_ready.toBoolean==(queue.size<cfg.cbDepth))
        assert(d.io.to_rob_ready.toBoolean==queue.nonEmpty)
        if(queue.nonEmpty) {
          val h=queue.head
          assert(d.io.to_rob_rob_id.toInt==h.id && d.io.to_bp_pc.toBigInt==h.pc)
          assert(d.io.to_bp_fu_opcode.toInt==h.op && d.io.to_bp_kp.toInt==h.kp && d.io.to_bp_prov.toBigInt==h.prov)
          assert(d.io.to_bp_is_compressed.toBoolean==h.compressed && d.io.to_bp_is_call.toBoolean==h.call && !d.io.to_bp_is_ret.toBoolean)
          if(h.resolved){assert(d.io.to_rob_target.toBigInt==h.target && d.io.to_rob_miss_predict.toBoolean==h.miss && d.io.to_bp_branch_taken.toBoolean==h.taken)}
        }
        val accept=incoming && branchReady && op!=15 && queue.size<cfg.cbDepth
        cdb.foreach { id=>queue.find(_.id==id) match {
          case Some(e)=>e.resolved=true;e.target=target;e.taken=taken;e.miss=miss
          case None=>stale+=1
        }}
        if(dequeue){queue.remove(0);popped+=1}
        if(accept){queue+=entry;serial+=1}
        tick()
        if(reset)queue.clear()
      }
      assert(popped>300 && stale>100 && queue.isEmpty)
    }
  }
}
