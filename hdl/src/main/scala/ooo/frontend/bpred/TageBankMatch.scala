package ooo.frontend.bpred

import spinal.core._
import ooo.CpuConfig

/** Decode each physical bank independently, keeping tag comparison before bank selection. */
class TageEntryDecode(cfg: CpuConfig) extends Component {
  setDefinitionName("tage_entry_decode")
  addAttribute("keep_hierarchy", "yes")
  val width = cfg.tageTagBits + cfg.tageCtrBits + cfg.tageUBits
  val io = new Bundle {
    val row = in Bits(width bits)
    val expected = in Bits(cfg.tageTagBits bits)
    val hit, direction, weak_counter = out Bool()
  }
  noIoPrefix()
  val counter = io.row(cfg.tageUBits, cfg.tageCtrBits bits)
  io.hit := io.row(width - 1 downto cfg.tageCtrBits + cfg.tageUBits) === io.expected
  io.direction := !counter.msb
  io.weak_counter := (io.row(cfg.tageUBits - 1 downto 0) === 0) &&
    ((counter === 0) || (counter.asSInt === S(-1, cfg.tageCtrBits bits)))
}

class TageBankMatch(cfg: CpuConfig) extends Component {
  setDefinitionName("tage_bank_match")
  addAttribute("keep_hierarchy", "yes")
  val width = cfg.tageTagBits + cfg.tageCtrBits + cfg.tageUBits
  val io = new Bundle {
    val row_0, row_1 = in Bits(width bits)
    val expected = in Bits(cfg.tageTagBits bits)
    val bank = in Bool()
    val hit, direction, weak_counter = out Bool()
  }
  noIoPrefix()
  val decoded = Seq(io.row_0, io.row_1).map { row =>
    val entry = new TageEntryDecode(cfg)
    entry.io.row := row
    entry.io.expected := io.expected
    entry
  }
  io.hit := Mux(io.bank, decoded(1).io.hit, decoded(0).io.hit)
  io.direction := Mux(io.bank, decoded(1).io.direction, decoded(0).io.direction)
  io.weak_counter := Mux(io.bank, decoded(1).io.weak_counter, decoded(0).io.weak_counter)
}
