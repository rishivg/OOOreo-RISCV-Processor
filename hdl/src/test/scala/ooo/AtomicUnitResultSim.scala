package ooo

import spinal.core._
import spinal.core.sim._
import ooo.memory.AtomicUnit
import org.scalatest.funsuite.AnyFunSuite

class AtomicUnitResultSim extends AnyFunSuite {
  for(rvfi<-Seq(false,true))test(s"atomic results, delayed cache responses and LR/SC reservation: rvfi=$rvfi") {
    val cfg=CpuProfiles.named("mcu-efficient").copy(rvfi=rvfi)
    TestSimulation.config.compile(new AtomicUnit(cfg)).doSim { d =>
      d.io.flatten.filter(_.isInput).foreach {
        case b:Bool=>b #= false
        case b:Bits=>b #= 0
        case _=>
      }
      d.io.stb_empty #= true
      val mask=(BigInt(1)<<32)-1
      val memory=scala.collection.mutable.Map[Long,BigInt]()
      def mem(a:Long)=memory.getOrElse(a,BigInt("80000001",16)^BigInt(a&65535))
      def signed(x:BigInt)=if(x.testBit(31))x-(BigInt(1)<<32) else x
      def update(op:Int,a:BigInt,b:BigInt):BigInt=(op match {
        case 2=>b;case 3=>a+b;case 4=>a^b;case 5=>a&b;case 6=>a|b
        case 7=>if(signed(a)<signed(b))a else b
        case 8=>if(signed(a)>signed(b))a else b
        case 9=>if(a<b)a else b;case 10=>if(a>b)a else b
      })&mask
      var cycle=0;var pending:Option[(Int,BigInt)]=None
      var reads=0;var writes=0
      def tick():Unit={
        d.io.clk #= false
        d.io.cache_ready #= (pending.isEmpty && cycle%7>=2)
        d.io.cache_resp #= false
        pending match {case Some((0,value))=>d.io.cache_resp #= true;d.io.cache_rdata #= value;case _=>}
        sleep(2)
        if(d.io.cache_valid.toBoolean && d.io.cache_ready.toBoolean) {
          val a=d.io.cache_addr.toLong
          assert(d.io.cache_rmask.toInt==15 || d.io.cache_wmask.toInt==15)
          val old=mem(a)
          if(d.io.cache_wmask.toInt==15){memory(a)=d.io.cache_wdata.toBigInt;writes+=1}else reads+=1
          pending=Some((2+cycle%4,old))
        } else pending=pending match {case Some((0,_))=>None;case Some((n,v))=>Some((n-1,v));case None=>None}
        d.io.clk #= true;sleep(2);d.io.clk #= false;sleep(2);cycle+=1
      }
      d.io.rst #= true;tick();tick();d.io.rst #= false
      var reservation:Option[Long]=None
      val random=new scala.util.Random(415)
      val base=0xaaaaa400L
      var serial=0
      def execute(op:Int,address:Long,value:BigInt):Unit={
        val id=serial%(cfg.robDepth*cfg.idWidth);val rd=1+serial%31;val phy=1+serial%(cfg.prfDepth-1)
        assert(d.io.disp_ready.toBoolean)
        d.io.disp_valid #= true;d.io.disp_rob_id #= id;d.io.disp_amo_op #= op;d.io.disp_rd_arch #= rd;d.io.disp_rd_phy #= phy
        tick();d.io.disp_valid #= false
        d.io.agu_valid #= true;d.io.agu_data #= (BigInt(id)<<132)|(BigInt(address)<<100)|value
        d.io.agu_hi0 #= address>>16;d.io.agu_hi1 #= ((address>>16)+1)&65535;d.io.agu_c16 #= false
        tick();d.io.agu_valid #= false;tick()
        val old=mem(address)
        val success=reservation.contains(address)
        val result=if(op==1){reservation=None;if(success)BigInt(0)else BigInt(1)}else old
        val expectedMemory=if(op==0){reservation=Some(address);old}else if(op==1){if(success)value else old}else update(op,old,value)
        val beforeReads=reads;val beforeWrites=writes
        d.io.go #= true;d.io.go_rob_id #= id
        var wait=0
        while(!d.io.cdb_valid.toBoolean && wait<120){tick();wait+=1}
        assert(d.io.cdb_valid.toBoolean,s"atomic timeout opcode $op")
        assert(d.io.cdb_rd_value.toBigInt==result,s"atomic old/SC result opcode $op")
        assert(d.io.cdb_rob_id.toInt==id && d.io.cdb_rd_arch.toInt==rd && d.io.cdb_rd_phy.toInt==phy)
        assert(d.io.cdb_rs1_dbg.toBigInt==address && d.io.cdb_rs2_dbg.toBigInt==value)
        assert(mem(address)==expectedMemory,s"atomic stored value opcode $op")
        assert(reads-beforeReads==(if(op==1)0 else 1))
        assert(writes-beforeWrites==(if(op==0 || (op==1 && !success))0 else 1))
        tick();d.io.go #= false;tick();tick();serial+=1
      }
      val corners = Seq[BigInt](0, 1, mask, mask - 1, BigInt(1) << 31, (BigInt(1) << 31) - 1)
      for (op <- 7 to 10; a <- corners; b <- corners) {
        execute(2, base, a)
        execute(op, base, b)
      }
      for(i<-0 until 240) {
        val a=base+4*random.nextInt(8)
        val value=if(i%7==0)mask else if(i%11==0)BigInt(1)<<31 else BigInt(32,random)
        execute(2+i%9,a,value)
        if(i%8==0){execute(0,a,0);execute(1,a,value);execute(1,a,value^1)}
        if(i%13==0){
          execute(0,a,0)
          d.io.st_commit_valid #= true;d.io.st_commit_addr #= a;tick();d.io.st_commit_valid #= false;reservation=None
          execute(1,a,value)
        }
        if(i%19==0){execute(0,a,0);execute(1,a^4,value)}
      }
    }
  }
}
