package ooo

import spinal.core._
import spinal.core.sim._
import ooo.common.TaggedSlots
import org.scalatest.funsuite.AnyFunSuite

class TaggedSlotsHarness(depth: Int) extends Component {
  val io = new Bundle {
    val clk = in Bool(); val rst = in Bool(); val flush = in Bool()
    val dispatch = in Bool(); val key = in Bits(8 bits); val query = in Bits(8 bits)
    val capture = in Bits(depth bits); val release = in Bits(depth bits)
    val ready = out Bool(); val allocated = out Bool()
    val allocation = out Bits(depth bits); val valid = out Bits(depth bits)
    val captured = out Bits(depth bits); val matches = out Bits(depth bits)
  }
  val cd = ClockDomain(io.clk,io.rst,config=ClockDomainConfig(resetKind=SYNC,resetActiveLevel=HIGH))
  new ClockingArea(cd) {
    val slots = new TaggedSlots(depth,8)
    slots.dispatch := io.dispatch; slots.dispatchKey := io.key; slots.flush := io.flush
    slots.capture := io.capture; slots.release := io.release
    io.ready := slots.ready; io.allocated := slots.allocateFire; io.allocation := slots.allocation
    io.valid := slots.valid.asBits; io.captured := slots.captured.asBits & slots.valid.asBits
    io.matches := slots.matching(io.query)
  }
}

class TaggedSlotsSim extends AnyFunSuite {
  for (depth <- Seq(1,2,3,8,17,33)) test(s"tagged captures depth=$depth: full backpressure, release, capture and flush") {
    TestSimulation.config.compile(new TaggedSlotsHarness(depth)).doSim { d =>
      d.io.clk #= false; d.io.rst #= true; d.io.flush #= false; d.io.dispatch #= false
      d.io.key #= 0; d.io.query #= 0; d.io.capture #= 0; d.io.release #= 0
      def tick(): Unit = { d.io.clk #= false; sleep(2); d.io.clk #= true; sleep(2); d.io.clk #= false; sleep(2) }
      tick(); tick(); d.io.rst #= false
      val model = Array.fill[Option[Int]](depth)(None)
      val captured = Array.fill(depth)(false)
      val random = new scala.util.Random(908+depth)
      def mask(indices: Seq[Int]): BigInt = indices.foldLeft(BigInt(0))(_.setBit(_))
      for (step <- 0 until 400) {
        val free = model.indexWhere(_.isEmpty)
        val dispatch = step < depth+2 || random.nextBoolean()
        val flush = step > depth+2 && random.nextInt(17)==0
        val release = if (step < depth+2) BigInt(0) else BigInt(depth, random)
        val capture = BigInt(depth, random)
        val key = random.nextInt(256)
        d.io.dispatch #= dispatch; d.io.flush #= flush; d.io.release #= release
        d.io.capture #= capture; d.io.key #= key
        val query = model.flatten.headOption.getOrElse(key); d.io.query #= query
        sleep(1)
        assert(d.io.ready.toBoolean == (free >= 0))
        assert(d.io.allocated.toBoolean == (dispatch && free>=0 && !flush))
        assert(d.io.allocation.toBigInt == (if (free >= 0) BigInt(1) << free else BigInt(0)))
        assert(d.io.matches.toBigInt == mask(model.indices.filter(i => model(i).contains(query))))
        val previousValid = model.map(_.isDefined)
        if (dispatch && free>=0 && !flush) { model(free)=Some(key); captured(free)=false }
        for (i <- 0 until depth) {
          if (capture.testBit(i) && previousValid(i)) captured(i)=true
          if (release.testBit(i) || flush) model(i)=None
        }
        tick()
        assert(d.io.valid.toBigInt == mask(model.indices.filter(i => model(i).isDefined)))
        assert(d.io.captured.toBigInt == mask(model.indices.filter(i => model(i).isDefined && captured(i))))
      }
    }
  }
}
