package ooo

import spinal.core._
import spinal.core.sim._
import ooo.memory.StoreQueue
import org.scalatest.funsuite.AnyFunSuite

class StoreQueueLifetimeSim extends AnyFunSuite {
  for (depth <- Seq(4, 8); lookup <- Seq(false, true)) {
    test(s"store queue depth $depth lookup=$lookup forwarding, stale IDs, wrap and flush") {
      val cfg = CpuProfiles.named("mcu-efficient").copy(stqDepth = depth, storeAgeLookup = lookup)
      TestSimulation.config.compile(new StoreQueue(cfg)).doSim { d =>
        d.io.flatten.filter(_.isInput).foreach {
          case b: Bool => b #= false
          case b: Bits => b #= 0
          case _ =>
        }
        def tick(): Unit = { d.io.clk #= false; sleep(2); d.io.clk #= true; sleep(2); d.io.clk #= false; sleep(2) }
        d.io.rst #= true; tick(); tick(); d.io.rst #= false
        case class Entry(id: Int, var resolved: Boolean = false, var address: BigInt = BigInt(0),
                         var mask: Int = 0, var data: BigInt = BigInt(0))
        val queue = scala.collection.mutable.ArrayBuffer[Entry]()
        val random = new scala.util.Random(1292 + depth)
        val trackerWidth = cfg.stqIdx + 1
        def pack(values: Seq[BigInt], width: Int): BigInt = values.zipWithIndex.foldLeft(BigInt(0)) {
          case (v, (x, i)) => v | (x << (i * width))
        }
        var serial = 0; var retired = 0; var stale = 0; var forwarded = 0; var unknown = 0
        for (cycle <- 0 until 5000) {
          val reset = cycle % 823 == 822; val flush = cycle % 257 == 256
          val incoming = random.nextInt(4) != 0
          var nextId = serial % 64
          while (queue.exists(_.id == nextId)) nextId = (nextId + 1) % 64
          val completion: Option[Int] = if (queue.nonEmpty && random.nextInt(3) != 0)
            Some(queue(random.nextInt(queue.size)).id)
            else if (random.nextBoolean()) Some((0 until 64).find(id => !queue.exists(_.id == id)).get) else None
          val address = BigInt(0x2000 + random.nextInt(8) * 4 + random.nextInt(4))
          val mask = 1 + random.nextInt(15); val data = BigInt(32, random)
          val robReady = random.nextInt(3) != 0; val stbReady = random.nextInt(3) != 0
          val trackers = Seq.fill(cfg.ldqDepth)(random.nextInt(queue.size + 1))
          val addresses = Seq.fill(cfg.ldqDepth)(if (queue.nonEmpty && random.nextBoolean())
            queue(random.nextInt(queue.size)).address else BigInt(0x2000 + random.nextInt(8) * 4))
          val masks = Seq.fill(cfg.ldqDepth)(1 + random.nextInt(15))
          d.io.rst #= reset; d.io.backend_flush #= flush
          d.io.from_ds_valid #= incoming; d.io.from_ds_uop_rob_id #= nextId; d.io.from_ds_uop_fu_opcode #= 10
          d.io.from_agu_valid #= completion.isDefined
          d.io.from_agu_data #= (BigInt(completion.getOrElse(0)) << 132) | (address << 100) | (data << 68) | (BigInt(mask) << 64)
          d.io.to_rob_ready #= robReady; d.io.to_stb_ready #= stbReady
          d.io.ldq_tracker_flat #= pack(trackers.map(BigInt(_)), trackerWidth)
          d.io.ldq_addr_flat #= pack(addresses, 32); d.io.ldq_rmask_flat #= pack(masks.map(BigInt(_)), 4)
          sleep(1)
          val want = queue.headOption.exists(_.resolved)
          assert(d.io.from_ds_ready.toBoolean == (queue.size < depth))
          assert(d.io.stq_tail.toInt == queue.size)
          assert(d.io.to_stb_valid.toBoolean == (want && robReady))
          assert(d.io.to_rob_valid.toBoolean == (want && stbReady))
          assert(d.io.stq_deq.toBoolean == (want && robReady && stbReady))
          if (want) {
            val head = queue.head
            assert(d.io.to_rob_rob_id.toInt == head.id)
            assert(d.io.to_stb_addr.toBigInt == ((head.address >> 2) << 2))
            assert(d.io.to_stb_wmask.toInt == head.mask && d.io.to_stb_wdata.toBigInt == head.data)
          }
          for (i <- 0 until cfg.ldqDepth) {
            val older = queue.take(trackers(i))
            val unresolved = older.exists(e => !e.resolved)
            val overlaps = older.filter(e => e.resolved && (e.address >> 2) == (addresses(i) >> 2) && (e.mask & masks(i)) != 0)
            val forward = !unresolved && overlaps.size == 1 && (overlaps.head.mask & masks(i)) == masks(i)
            assert(d.io.known_conflict.toBigInt.testBit(i) == overlaps.nonEmpty)
            assert(d.io.unknown_older.toBigInt.testBit(i) == unresolved)
            if (trackers(i) > 0) assert(d.io.has_conflicting_store.toBigInt.testBit(i) == (unresolved || overlaps.nonEmpty))
            assert(d.io.forward_en.toBigInt.testBit(i) == forward)
            if (forward) {
              assert(((d.io.forward_wdata_flat.toBigInt >> (i * 32)) & ((BigInt(1) << 32) - 1)) == overlaps.head.data)
              forwarded += 1
            }
            if (unresolved) unknown += 1
          }
          val accept = incoming && queue.size < depth
          completion.foreach { id => queue.find(_.id == id) match {
            case Some(e) => e.resolved = true; e.address = address; e.mask = mask; e.data = data
            case None => stale += 1
          }}
          if (want && robReady && stbReady) { queue.remove(0); retired += 1 }
          if (accept) { queue += Entry(nextId); serial += 1 }
          tick()
          if (reset || flush) queue.clear()
        }
        assert(retired > 500 && stale > 300 && forwarded > 100 && unknown > 500)
      }
    }
  }
}
