package ooo

import spinal.core._
import spinal.core.sim._
import ooo.memory.Dcache
import org.scalatest.funsuite.AnyFunSuite

class DcacheAccessSim extends AnyFunSuite {
  for (allBanks <- Seq(false, true); mergedTag <- Seq(false, true); cachedLru <- Seq(false, true))
    test(s"masked stores, evictions and reset with all-bank reads=$allBanks, merged tag=$mergedTag, cached PLRU=$cachedLru") {
    TestSimulation.config.addRtl("../sram/output/dcache_data_bank/dcache_data_bank.v")
      .addRtl("../sram/output/dcache_tag_array/dcache_tag_array.v")
      .compile(new Dcache(CpuProfiles.named("mcu-efficient").copy(
        dcacheReadAllBanks=allBanks, dcacheMergedTag=mergedTag, dcacheLruReadCache=cachedLru))).doSim { d =>
      d.io.flatten.filter(_.isInput).foreach {
        case b: Bool => b #= false
        case b: Bits => b #= 0
        case u: UInt => u #= 0
        case _ =>
      }
      val mask=(BigInt(1)<<32)-1
      val backing=scala.collection.mutable.Map[Long,BigInt]()
      val architectural=scala.collection.mutable.Map[Long,BigInt]()
      def initial(addr: Long): BigInt = (BigInt("13579bdf",16)^BigInt(addr))&mask
      def memory(addr: Long): BigInt = backing.getOrElse(addr,initial(addr))
      def expected(addr: Long): BigInt = architectural.getOrElse(addr,initial(addr))
      var cycles=0
      var response: Option[(Long,Int)]=None
      def busTick(): Unit = {
        d.io.clk #= false
        d.io.dfp_ready #= (cycles%9>=2)
        d.io.dfp_rvalid #= false
        response match {
          case Some((addr,0)) =>
            d.io.dfp_rvalid #= true; d.io.dfp_raddr #= addr
            d.io.dfp_rdata #= (0 until 8).map(i=>memory(addr+4*i)<<(32*i)).reduce(_|_)
          case _ =>
        }
        sleep(2)
        if(d.io.dfp_write.toBoolean && d.io.dfp_ready.toBoolean) {
          val addr=d.io.dfp_addr.toLong; val data=d.io.dfp_wdata.toBigInt
          for(i<-0 until 8) {
            val word=(data>>(32*i))&mask
            assert(word==expected(addr+4*i),s"dirty writeback mismatch at ${addr+4*i}")
            backing(addr+4*i)=word
          }
        }
        if(d.io.dfp_read.toBoolean && d.io.dfp_ready.toBoolean) {
          assert(response.isEmpty,"cache must not issue overlapping line reads")
          response=Some((d.io.dfp_addr.toLong,2+cycles%4))
        } else response=response match {
          case Some((_,0)) => None
          case Some((addr,n)) => Some((addr,n-1))
          case None => None
        }
        d.io.clk #= true; sleep(2); d.io.clk #= false; sleep(2); cycles+=1
      }
      def clear(): Unit = {
        d.io.ufp_req_early #= (allBanks && cycles%3==0)
        d.io.ufp_rmask #= 0; d.io.ufp_wmask #= 0
        // Exercise speculative reads without accepting a cache transaction.
        if (allBanks) {
          val addr=0x02000000L+4*(cycles%128)
          d.io.ufp_addr #= addr; d.io.ufp_hi0 #= addr>>16; d.io.ufp_hi1 #= addr>>16
          d.io.ufp_c16 #= false; d.io.ufp_word_oh #= BigInt(1)<<((addr>>2)&7).toInt
        }
      }
      def reset(edges: Int): Unit = {
        clear(); d.io.rst #= true
        for(_<-0 until edges) busTick()
        d.io.rst #= false; busTick()
      }
      case class Op(addr: Long,write: Int=0,data: BigInt=BigInt(0))
      def transactions(ops: Seq[Op]): Unit = {
        val pending=scala.collection.mutable.Queue[Op]()
        var sent=0; var completed=0; var limit=0
        while(completed<ops.size && limit<ops.size*100+100) {
          val offer=sent<ops.size && !d.io.dbg_stall.toBoolean
          clear()
          if(offer) {
            val op=ops(sent);d.io.ufp_addr #= op.addr
            val carry=(sent&1)!=0
            val high0=((op.addr>>16)-(if(carry)1 else 0))&65535
            d.io.ufp_hi0 #= high0; d.io.ufp_hi1 #= (high0+1)&65535; d.io.ufp_c16 #= carry
            d.io.ufp_word_oh #= BigInt(1)<<((op.addr>>2)&7).toInt
            d.io.ufp_req_early #= true; d.io.ufp_wdata #= op.data
            if(op.write==0) d.io.ufp_rmask #= 15 else d.io.ufp_wmask #= op.write
          }
          sleep(1)
          if(d.io.ufp_resp.toBoolean) {
            assert(pending.nonEmpty,"response must belong to an accepted request")
            val op=pending.dequeue()
            if(op.write==0) assert(d.io.ufp_rdata.toBigInt==expected(op.addr),s"read mismatch at ${op.addr}, cycle $cycles")
            else {
              var value=expected(op.addr)
              for(b<-0 until 4) if((op.write&(1<<b))!=0) {
                val byteMask=BigInt(255)<<(8*b)
                value=(value&(mask^byteMask))|(op.data&byteMask)
              }
              architectural(op.addr)=value
            }
            completed+=1
          }
          if(offer) { pending.enqueue(ops(sent));sent+=1 }
          busTick();limit+=1
        }
        assert(completed==ops.size && pending.isEmpty)
        clear();for(_<-0 until 6) busTick()
      }
      reset(1)
      val base=0xaaaaa000L
      transactions(for(set<-0 until 16;line<-0 until 8) yield Op(base+512*line+32*set))
      val random=new scala.util.Random(194)
      transactions((0 until 250).map { n =>
        val addr=base+512*random.nextInt(8)+32*random.nextInt(16)+4*random.nextInt(8)
        if(n%3==0) Op(addr,1+random.nextInt(15),BigInt(32,random)) else Op(addr)
      })
      transactions(for(set<-0 until 16;line<-0 until 8;word<-0 until 8) yield Op(base+512*line+32*set+4*word))
      // All cached dirty words must reach backing memory before completion.
      transactions(for(set<-0 until 16;line<-0 until 4;word<-0 until 8) yield
        Op(base+512*line+32*set+4*word,15,BigInt(32,random)))
      clear(); d.io.flush_request #= true
      var flushCycles=0
      while(!d.io.flush_done.toBoolean && flushCycles<5000) { busTick();flushCycles+=1 }
      assert(d.io.flush_done.toBoolean,"cache flush must complete under backpressure")
      for((addr,value)<-architectural) assert(memory(addr)==value,s"maintenance lost dirty data at $addr")
      for(_<-0 until 4) { busTick();assert(d.io.flush_done.toBoolean) }
      d.io.flush_request #= false;for(_<-0 until 3) busTick()
      // Model an external DMA write only after CPU maintenance has completed.
      val dma=base+32*7+4*3;val dmaValue=BigInt("ab12cd34",16)
      backing(dma)=dmaValue;architectural(dma)=dmaValue
      transactions(Seq(Op(dma)))
      // A clean cached line must refetch after reset, independently of the
      // reset pulse length. The backing image may change while reset is held.
      val reboot=base+0x10000
      transactions(Seq(Op(reboot)))
      val fresh=BigInt("cafef00d",16); backing(reboot)=fresh;architectural(reboot)=fresh
      reset(2)
      transactions(Seq(Op(reboot)))
    }
  }
}
