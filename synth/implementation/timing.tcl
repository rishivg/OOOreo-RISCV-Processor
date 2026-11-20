set root [file dirname [file normalize [info script]]]
set models [file join $root models]
foreach library [lsort [glob $models/*.lib]] { read_liberty $library }
foreach lef [concat [list $models/NangateOpenCellLibrary.tech.lef] \
    [list $models/NangateOpenCellLibrary.macro.mod.lef] \
    [lsort [glob $models/fakeram*.lef]] [list $models/div_fake.lef]] {
  read_lef $lef
}
read_db $::env(LAYOUT_DB)
read_sdc $root/constraints.sdc
source $models/setRC.tcl
set_propagated_clock [all_clocks]
estimate_parasitics -placement
puts SETUP
report_worst_slack -max -digits 9
puts HOLD
report_worst_slack -min -digits 9
puts ELECTRICAL
report_check_types -max_slew -max_capacitance -max_fanout -violators -digits 9
puts ELECTRICAL_END
puts CLOCK
report_check_types -min_pulse_width -min_period -clock_gating_setup -clock_gating_hold -violators -digits 9
puts CLOCK_END
report_tns -digits 9
report_design_area
check_placement -verbose
set_power_activity -global -activity 0.1 -duty 0.5 -clock clk
report_power -digits 9
exit
