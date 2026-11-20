package ooo

import spinal.core._
import spinal.core.sim._
import ooo.frontend.Icache
import org.scalatest.funsuite.AnyFunSuite

class IcacheAccessSim extends AnyFunSuite {
  for (mode <- 0 to 7) test(s"instruction refills, cold boot and warm reset layout=$mode") {
    val packed = mode > 0
    val banked = mode >= 2
    val validSpec = mode >= 3
    val laneSpec = mode >= 4
    val published = mode >= 5
    TestSimulation.config.addRtl("../sram/output/icache_data_bank/icache_data_bank.v")
      .addRtl("../sram/output/icache_pd_bank/icache_pd_bank.v")
      .addRtl("../sram/output/icache_tag_array/icache_tag_array.v")
      .compile(new Icache(CpuProfiles.named("mcu-efficient").copy(frontendLengthPredecode=packed,frontendBankSpeculation=banked,frontendPayloadSpeculation=banked,frontendValidSpeculation=validSpec,frontendLaneValidity=laneSpec,frontendPublishedValidity=published,frontendInvertedTag=mode==6,frontendPcOneHot=mode==7,frontendCacheAddressOneHot=mode==7,rvfi=packed))).doSim { d =>
      d.io.flatten.filter(_.isInput).foreach {
        case b: Bool => b #= false
        case b: Bits => b #= 0
        case u: UInt => u #= 0
        case _ =>
      }
      def setAddress(addr: Long): Unit = {
        d.io.ufp_addr #= addr
        if(validSpec) {
          val set=(addr>>5)&63;val selected=((addr>>9)&7).toInt
          val candidates=(0 until 8).map { i =>
            val value=if(i==selected) set else (set+11*i+1)&63
            BigInt(value) << (6*i)
          }.reduce(_|_)
          d.io.set_candidates #= candidates;d.io.set_select #= 1<<selected
        }
      }
      setAddress(0)
      val mask=(BigInt(1)<<32)-1
      val image=scala.collection.mutable.Map[Long,BigInt]()
      def word(addr: Long): BigInt = image.getOrElse(addr,(BigInt(0x13)|((BigInt(addr>>2)&2047)<<20))&mask)
      var cycles=0;var response: Option[(Long,Int)]=None
      def tick(): Unit = {
        d.io.clk #= false;d.io.dfp_ready #= (cycles%7>=2);d.io.dfp_rvalid #= false
        response match {
          case Some((addr,0)) =>
            d.io.dfp_rvalid #= true;d.io.dfp_raddr #= addr
            d.io.dfp_rdata #= (0 until 8).map(i=>word(addr+4*i)<<(32*i)).reduce(_|_)
          case _ =>
        }
        sleep(2)
        if(d.io.dfp_read.toBoolean && d.io.dfp_ready.toBoolean) {
          assert(response.isEmpty);response=Some((d.io.dfp_addr.toLong,3+cycles%3))
        } else response=response match {
          case Some((_,0)) => None
          case Some((addr,n)) => Some((addr,n-1))
          case None => None
        }
        assert(!d.io.dfp_write.toBoolean)
        if(laneSpec) {
          val set=((d.io.ufp_addr.toLong>>5)&63).toInt
          d.io.request_initialized #= d.io.initialized_bitmap.toBigInt.testBit(set)
          sleep(1)
        }
        d.io.clk #= true;sleep(2);d.io.clk #= false;sleep(2);cycles+=1
      }
      def reset(edges: Int): Unit = {
        d.io.ufp_read #= false;d.io.ufp_read_early #= false;d.io.rst #= true
        for(_<-0 until edges) tick()
        d.io.rst #= false;tick()
      }
      def fetches(addresses: Seq[Long]): Unit = {
        val pending=scala.collection.mutable.Queue[Long]()
        var sent=0;var done=0;var limit=0
        while(done<addresses.size && limit<addresses.size*100+100) {
          val offer=sent<addresses.size && (pending.isEmpty || d.io.ufp_resp.toBoolean)
          d.io.ufp_read #= offer;d.io.ufp_read_early #= offer
          if(offer) setAddress(addresses(sent))
          sleep(1)
          if(d.io.ufp_resp.toBoolean) {
            assert(pending.nonEmpty)
            val addr=pending.dequeue()
            val expected=(0 until 4).map(i=>word(addr+4*i)<<(32*i)).reduce(_|_)
            assert(d.io.ufp_rdata.toBigInt==expected,s"instruction block mismatch at $addr, cycle $cycles")
            val select=d.io.ufp_pd_sel.toBigInt
            assert(select!=0 && (select&(select-1))==0,"exactly one initialized way must match")
            done+=1
          }
          if(offer) { pending.enqueue(addresses(sent));sent+=1 }
          tick();limit+=1
        }
        assert(done==addresses.size && pending.isEmpty)
        d.io.ufp_read #= false;d.io.ufp_read_early #= false;for(_<-0 until 5) tick()
      }
      reset(2)
      fetches(Seq(0L,16L))
      val base=0xaaaaa000L
      fetches(for(set<-0 until 64;line<-0 until 8;block<-0 until 2) yield base+2048*line+32*set+16*block)
      val random=new scala.util.Random(355)
      fetches((0 until 400).map(_=>base+2048*random.nextInt(8)+32*random.nextInt(64)+16*random.nextInt(2)))
      for(edges<-Seq(2,3,4,1)) {
        fetches(Seq(base,base+16))
        for(i<-0 until 8) image(base+4*i)=BigInt(0x13)|((BigInt(37*edges+i)&2047)<<20)
        reset(edges);fetches(Seq(base,base+16))
      }
      fetches(Seq(base,base+16))
      for(i<-0 until 8) image(base+4*i)=BigInt(0x13)|((BigInt(123+i)&2047)<<20)
      d.io.invalidate #= true;d.io.kill #= true;tick()
      d.io.invalidate #= false;d.io.kill #= false
      fetches(Seq(base,base+16))
    }
  }
}
