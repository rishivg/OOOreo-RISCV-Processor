package ooo

import spinal.core.sim._
import ooo.execute.FuBr
import org.scalatest.funsuite.AnyFunSuite
import scala.util.Random

class FuBrSim extends AnyFunSuite {
  for (rvfi <- Seq(false, true)) {
  test(s"branch targets, comparisons, links and prediction checking match RV32 reference RVFI=$rvfi") {
    TestSimulation.config.compile(new FuBr(CpuProfiles.named("mcu-efficient").copy(rvfi=rvfi))).doSim { dut =>
      val mask32=(BigInt(1)<<32)-1
      def u(x:BigInt)=x & mask32
      def signed(x:BigInt)=if (u(x).testBit(31)) u(x)-(BigInt(1)<<32) else u(x)
      def tick():Unit={dut.io.clk #= false; sleep(1); dut.io.clk #= true; sleep(1)}
      dut.io.clk #= false; dut.io.rst #= true; dut.io.br_rs_valid #= false; dut.io.fu_br_reg_in #= 0
      tick(); tick(); dut.io.rst #= false
      val random=new Random(20261012)
      val ops=Seq(0,1,4,5,6,7,8,9,15,2)
      val corners=Seq[BigInt](0,1,2,BigInt("7fffffff",16),BigInt("80000000",16),mask32)
      def run(op:Int,a:BigInt,b:BigInt,pc:BigInt,imm:BigInt,compressed:Boolean,wrongDirection:Boolean,wrongTarget:Boolean,rd:Int=19,phy:Int=37):Unit={
        val taken=op match {
          case 0=>a==b; case 1=>a!=b
          case 4=>signed(a)<signed(b); case 5=>signed(a)>=signed(b)
          case 6=>a<b; case 7=>a>=b
          case 8|9=>true; case _=>false
        }
        val seq=u(pc+(if(compressed)2 else 4))
        val target=if(!taken)seq else if(op==9)u(a+imm)&(mask32-1) else u(pc+imm)
        val predictedDirection=if(wrongDirection)!taken else taken
        val predictedTarget=if(wrongTarget)target^1 else target
        val bits=predictedTarget | (BigInt(if(predictedDirection)1 else 0)<<32) |
          (BigInt(if(compressed)1 else 0)<<33) | (b<<34) | (a<<66) | (u(imm)<<98) |
          (u(pc)<<130) | (BigInt(op)<<162) | (BigInt(phy)<<166) | (BigInt(rd)<<172) | (BigInt(23)<<177)
        dut.io.fu_br_reg_in #= bits; dut.io.br_rs_valid #= true
        tick(); tick()
        assert(dut.io.cdb_valid.toBoolean)
        assert(dut.io.br_cdb_valid.toBoolean==(op!=15))
        assert(dut.io.br_cdb_branch_taken.toBoolean==taken, s"direction op=$op a=$a b=$b")
        assert(dut.io.br_cdb_target_address.toBigInt==target, s"target op=$op pc=$pc imm=$imm")
        assert(dut.io.br_cdb_miss_predict.toBoolean==(wrongDirection||wrongTarget), s"prediction op=$op")
        if(rd!=0) assert(dut.io.cdb_rd_value.toBigInt==(if(op==15)u(pc+imm)else seq), s"link op=$op")
        assert(dut.io.cdb_rd_phy.toInt==phy && dut.io.cdb_rd_arch.toInt==rd && dut.io.cdb_rob_id.toInt==23)
      }
      for(op<-ops;a<-corners;b<-corners;c<-Seq(false,true);direction<-Seq(false,true);target<-Seq(false,true))
        run(op,a,b,BigInt("fffffff0",16),BigInt(32),c,direction,target)
      for(_<-0 until 3000)
        run(ops(random.nextInt(ops.length)),BigInt(32,random),BigInt(32,random),BigInt(32,random),BigInt(32,random),random.nextBoolean(),random.nextBoolean(),random.nextBoolean())
      // An x0 destination still completes and redirects; its writeback data is
      // not architecturally consumed. Mix it with live destinations to test reuse.
      for(op<-ops;rd<-Seq(0,19);c<-Seq(false,true))
        run(op,BigInt("80000000",16),BigInt(1),BigInt("fffffff0",16),BigInt(32),c,false,false,rd,if(rd==0)0 else 37)
      dut.io.br_rs_valid #= false; tick(); tick()
      assert(!dut.io.cdb_valid.toBoolean && !dut.io.br_cdb_valid.toBoolean)
    }
  }
  }
}
