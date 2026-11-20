package ooo

import spinal.core.sim._
import ooo.memory.LruArray
import org.scalatest.funsuite.AnyFunSuite

class LruArrayWriteSim extends AnyFunSuite {
  for {
    (addressWidth, dataWidth) <- Seq((1, 1), (2, 3), (4, 3), (6, 3), (4, 7))
    readCache <- Seq(false, true)
  } test(s"PLRU delayed writes, held reads and forwarding: address=$addressWidth data=$dataWidth cached=$readCache") {
    TestSimulation.config.compile(new LruArray(addressWidth, dataWidth, readCache)).doSim { dut =>
      dut.io.clk0 #= false
      dut.io.rst0 #= true
      dut.io.csb0 #= true
      dut.io.csb1 #= true
      dut.io.web1 #= true
      dut.io.addr0 #= 0
      dut.io.addr1 #= 0
      dut.io.din1 #= 0

      def edge(): Unit = {
        dut.io.clk0 #= false; sleep(2)
        dut.io.clk0 #= true; sleep(2)
        dut.io.clk0 #= false; sleep(2)
      }
      edge(); edge()
      dut.io.rst0 #= false
      val dataMask = (1 << dataWidth) - 1
      val array = scala.collection.mutable.Map[Int, Int]()
      var readAddress = 0
      var writeAddress = 0
      var writeData = 0
      var writeHeld = false
      var commands = 0

      def step(read: Boolean, readRow: Int, writeCommand: Boolean, writeRow: Int,
               data: Int, readCommand: Boolean = false): Unit = {
        dut.io.csb0 #= !read
        dut.io.addr0 #= readRow
        dut.io.csb1 #= !(writeCommand || readCommand)
        dut.io.web1 #= !writeCommand
        dut.io.addr1 #= writeRow
        dut.io.din1 #= data
        if (writeHeld) array(writeAddress) = writeData
        if (read) readAddress = readRow
        if (writeCommand || readCommand) {
          writeHeld = writeCommand
          writeAddress = writeRow
          writeData = data
        }
        if (writeCommand) commands += 1
        edge()
        val expected = if (writeHeld && readAddress == writeAddress) writeData else array(readAddress)
        assert(dut.io.dout0.toInt == expected, s"PLRU read/forward at row $readAddress")
      }

      for (row <- 0 until (1 << addressWidth)) step(true, row, true, row, (row * 5 + 3) & dataMask)
      step(true, 0, false, 0, 0)
      val random = new scala.util.Random(802 + addressWidth)
      for (cycle <- 0 until 2200) {
        val readRow = random.nextInt(1 << addressWidth)
        val write = cycle % 17 == 0 || cycle % 29 >= 26
        val writeRow = if (cycle % 2 == 0) readRow else random.nextInt(1 << addressWidth)
        step(cycle % 5 != 0, readRow, write, writeRow, random.nextInt(1 << dataWidth),
          readCommand = !write && cycle % 11 == 0)
      }
      assert(commands > 100)
    }
  }
}
