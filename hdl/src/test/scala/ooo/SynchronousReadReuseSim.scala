package ooo

import spinal.core._
import spinal.core.sim._
import ooo.common.SynchronousReadReuse
import org.scalatest.funsuite.AnyFunSuite

class SynchronousReadReuseSim extends AnyFunSuite {
  class Harness(aw:Int) extends Component {
    val io=new Bundle {
      val request=in Bool();val address=in Bits(aw bits)
      val write=in Bool();val writeAddress=in Bits(aw bits)
      val writeData=in Bits(32 bits);val writeMask=in Bits(4 bits)
      val baseline=out Bits(32 bits);val optimized=out Bits(32 bits);val readEnable=out Bool()
    }
    val reuse=new SynchronousReadReuse(aw,io.request,io.address,io.write,io.writeAddress)
    val mem=Vec((0 until (1<<aw)).map(i=>RegInit(B(0x91370000L+i,32 bits))))
    val baseline=RegInit(B(0,32 bits));val optimized=RegInit(B(0,32 bits))
    when(io.request){baseline:=mem(io.address.asUInt)}
    when(reuse.enable){optimized:=mem(io.address.asUInt)}
    when(io.write){for(b<-0 until 4)when(io.writeMask(b)){mem(io.writeAddress.asUInt)(8*b,8 bits):=io.writeData(8*b,8 bits)}}
    io.baseline:=baseline;io.optimized:=optimized;io.readEnable:=reuse.enable
  }
  for(aw<-Seq(4,5,6)) {
    test(s"held SRAM row reuse preserves masked writes and read-before-write, aw=$aw") {
      TestSimulation.config.compile(new Harness(aw)).doSim { d =>
        d.io.request #= false;d.io.address #= 0;d.io.write #= false;d.io.writeAddress #= 0;d.io.writeData #= 0;d.io.writeMask #= 0
        d.clockDomain.forkStimulus(10);d.clockDomain.waitSampling(3)
        val random=new scala.util.Random(930+aw)
        var address=0;var opportunities=0;var reads=0
        for(cycle<-0 until 3200) {
          d.clockDomain.waitFallingEdge()
          if(cycle%13==0)address=random.nextInt(1<<aw)
          val request=cycle%7!=0
          val write=cycle%5==0 || cycle%41==0
          val wa=if(cycle%3==0)address else random.nextInt(1<<aw)
          d.io.request #= request;d.io.address #= address
          d.io.write #= write;d.io.writeAddress #= wa;d.io.writeData #= BigInt(32,random);d.io.writeMask #= (1+random.nextInt(15))
          sleep(1)
          if(request)opportunities+=1
          if(d.io.readEnable.toBoolean)reads+=1
          d.clockDomain.waitSampling();sleep(1)
          assert(d.io.baseline.toBigInt==d.io.optimized.toBigInt,s"read mismatch cycle $cycle, request=$request, write=$write address=$address writeAddress=$wa")
        }
        assert(reads<opportunities/2,s"repeated-row requests should avoid redundant reads: $reads/$opportunities")
        // Reset invalidates the held copy and forces the next request to read.
        d.io.request #= false;d.io.write #= false
        d.clockDomain.assertReset();sleep(25);d.clockDomain.deassertReset()
        d.io.request #= true;d.io.address #= address;sleep(1)
        assert(d.io.readEnable.toBoolean)
        d.clockDomain.waitSampling();sleep(1)
        assert(d.io.baseline.toBigInt==d.io.optimized.toBigInt)
      }
    }
  }
}
