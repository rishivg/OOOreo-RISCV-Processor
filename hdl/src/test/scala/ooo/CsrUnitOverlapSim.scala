package ooo

import spinal.core._
import spinal.core.sim._
import ooo.csr.CsrUnit
import org.scalatest.funsuite.AnyFunSuite

class CsrUnitOverlapSim extends AnyFunSuite {
  for((rvfi,depth)<-Seq((false,1),(true,1),(false,3))) {
    test(s"CSR operand lifetime with next dispatch during access: rvfi=$rvfi depth=$depth") {
      val cfg=CpuProfiles.named("mcu-efficient").copy(rvfi=rvfi,csrCamDepth=depth)
      TestSimulation.config.compile(new CsrUnit(cfg)).doSim { d =>
        d.io.flatten.filter(_.isInput).foreach {
          case b:Bool=>b #= false
          case b:Bits=>b #= 0
          case u:UInt=>u #= 0
          case _=>
        }
        d.io.memory_idle #= true
        def tick():Unit={d.io.clk #= false;sleep(2);d.io.clk #= true;sleep(2);d.io.clk #= false;sleep(2)}
        d.io.rst #= true;tick();tick();d.io.rst #= false
        val random=new scala.util.Random(807)
        case class Op(id:Int,funct:Int,field:Int,value:BigInt,result:BigInt,rd:Int,phy:Int,adj:Int)
        val ops=(0 until 180).map { i=>Op(i%(cfg.robDepth*cfg.idWidth),Seq(1,2,3,5,6,7)(i%6),random.nextInt(32),BigInt(32,random),BigInt(32,random),1+i%31,1+i%(cfg.prfDepth-1),random.nextInt(3)) }
        def dispatch(op:Op):Unit={
          assert(d.io.disp_ready.toBoolean)
          d.io.disp_valid #= true;d.io.disp_rob_id #= op.id
          d.io.disp_ctrl #= (BigInt(0x340)<<8)|(BigInt(op.field)<<3)|BigInt(op.funct)
          d.io.disp_rd_arch #= op.rd;d.io.disp_rd_phy #= op.phy
        }
        def capture(op:Op):Unit={d.io.agu_valid #= true;d.io.agu_data #= (BigInt(op.id)<<132)|(op.value<<100)}
        dispatch(ops.head);tick();d.io.disp_valid #= false
        capture(ops.head);tick();d.io.agu_valid #= false
        for((op,index)<-ops.zipWithIndex) {
          d.io.go #= true;d.io.go_rob_id #= op.id;d.io.go_older #= op.adj
          d.io.acc_rdata #= op.result
          tick();sleep(1)
          assert(d.io.acc_en.toBoolean)
          assert(d.io.acc_addr.toBigInt==0x340)
          assert(d.io.acc_wdata.toBigInt==(if((op.funct&4)!=0)BigInt(op.field) else op.value))
          assert(d.io.acc_op.toBigInt==op.funct)
          assert(d.io.acc_write.toBoolean==((op.funct&3)==1 || op.field!=0))
          assert(d.io.acc_instret_adj.toInt==op.adj)
          // Reuse the freed CAM slot at the earliest dispatch edge while the
          // previous access consumes its old operand. Capture the next operand
          // on the next edge, while the previous CDB result is visible.
          if(index+1<ops.size)dispatch(ops(index+1))
          tick();d.io.disp_valid #= false;sleep(1)
          assert(d.io.cdb_valid.toBoolean)
          assert(d.io.cdb_rob_id.toInt==op.id && d.io.cdb_rd_arch.toInt==op.rd && d.io.cdb_rd_phy.toInt==op.phy)
          assert(d.io.cdb_rd_value.toBigInt==op.result)
          if(rvfi)assert(d.io.cdb_rs1_dbg.toBigInt==op.value)
          if(index+1<ops.size)capture(ops(index+1))
          tick();d.io.agu_valid #= false;d.io.go #= false
          tick()
        }
      }
    }
  }
}
