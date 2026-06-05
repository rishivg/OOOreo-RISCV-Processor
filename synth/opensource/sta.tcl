# OpenSTA: timing + power on the Nangate45-mapped netlist.
# Run inside the openroad image: sta sta.tcl
# CLOCK_PS is passed via env (defaults to 1000 ps = 1 GHz target).

set period_ps [expr {[info exists ::env(ECE411_CLOCK_PERIOD_PS)] ? $::env(ECE411_CLOCK_PERIOD_PS) : 1000}]
set period_ns [expr {$period_ps / 1000.0}]

read_liberty nangate45.lib
# SRAM macros + DW divider are black boxes (no liberty); read stubs so link resolves.
read_verilog sram_bb.v
read_verilog netlist.v
link_design cpu

create_clock -name clk -period $period_ns [get_ports clk]
foreach p [all_inputs] {
    if {[get_full_name $p] ne "clk"} { set_input_delay 0.2 -clock clk $p }
}
set_output_delay 0.1 -clock clk [all_outputs]

puts "==== WNS / TNS (target period ${period_ns} ns) ===="
report_wns
report_tns

puts "==== Worst setup paths (reg-to-reg core logic) ===="
report_checks -path_delay max -group_count 5 -slack_max 1e30 -fields {slew cap input_pins nets fanout} -digits 4

puts "==== Power ===="
report_power -digits 4

puts "==== Design area ===="
report_design_area
