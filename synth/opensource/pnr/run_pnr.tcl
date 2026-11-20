set PLAT /OpenROAD-flow-scripts/flow/platforms/nangate45
set SITE FreePDK45_38x28_10R_NP_162NW_34O
set DIR  synth/opensource/pnr

# Load the cell library and active screening macros. Parent fixtures stay on disk
# for fixture generation; unused geometries do not need to be loaded into OpenROAD.
set MEMORIES {
  fakeram45_16x32
  fakeram45_64x128
  fakeram45_1r1w_32x96
  fakeram45_1r1w_64x32
  fakeram45_1r1w_16x240
}
read_liberty $PLAT/lib/NangateOpenCellLibrary_typical.lib
read_liberty $PLAT/lib/fakeram45_64x32.lib
foreach macro $MEMORIES { read_liberty $DIR/fakeram/$macro.lib }
read_liberty $DIR/div_fake.lib

read_lef $PLAT/lef/NangateOpenCellLibrary.tech.lef
read_lef $PLAT/lef/NangateOpenCellLibrary.macro.mod.lef
read_lef $PLAT/lef/fakeram45_64x32.lef
foreach macro $MEMORIES { read_lef $DIR/fakeram/$macro.lef }
read_lef $DIR/div_fake.lef

# ---------- design ----------
# PNR_NETLIST selects a netlist without overwriting netlist_pnr.v.
set NETLIST $DIR/netlist_pnr.v
if { [info exists ::env(PNR_NETLIST)] && $::env(PNR_NETLIST) ne "" } { set NETLIST $::env(PNR_NETLIST) }
read_verilog $NETLIST
link_design cpu

# ---------- constraints ----------
set period_ps 1000
if { [info exists ::env(OOOREO_CLOCK_PERIOD_PS)] } { set period_ps $::env(OOOREO_CLOCK_PERIOD_PS) }
set period_ns [expr {$period_ps / 1000.0}]
create_clock -name clk -period $period_ns [get_ports clk]
set_input_delay  0.2 -clock clk [all_inputs]
set_output_delay 0.1 -clock clk [all_outputs]
puts "INFO: clock period = $period_ns ns ([expr {1000.0/$period_ns}] MHz target)"

set die_um  980.0
set dens    0.86
# Treat an unset OR empty env var as "use default" (ppa.sh may pass empty knobs).
if { [info exists ::env(PNR_DIE_UM)]  && $::env(PNR_DIE_UM)  ne "" } { set die_um [expr {double($::env(PNR_DIE_UM))}] }
if { [info exists ::env(PNR_DENSITY)] && $::env(PNR_DENSITY) ne "" } { set dens   [expr {double($::env(PNR_DENSITY))}] }
set core_lo 20.0
set core_hi [expr {$die_um - 20.0}]
puts "INFO: die ${die_um}x${die_um} um, core ${core_lo}..${core_hi}, place density $dens"
initialize_floorplan -die_area [list 0 0 $die_um $die_um] \
                     -core_area [list $core_lo $core_lo $core_hi $core_hi] -site $SITE
make_tracks

set block [ord::get_db_block]
set dbu [$block getDbUnitsPerMicron]
proc um {block v} { return [expr {round($v * [$block getDbUnitsPerMicron])}] }

set split_ictag [expr {![info exists ::env(PNR_SPLIT_ICTAG)] || $::env(PNR_SPLIT_ICTAG) != 0}]
set ic {} ; set ict {} ; set ico {} ; set dc {} ; set pr {} ; set ot {}
set pairs {}
foreach inst [$block getInsts] {
  if { [[$inst getMaster] getType] == "BLOCK" } { lappend pairs [list [$inst getName] $inst] }
}
foreach p [lsort -index 0 $pairs] {
  set inst [lindex $p 1]; set nm [lindex $p 0]
  if { $split_ictag && [string match *icacheOffsetBank* $nm] } { lappend ico $inst
  } elseif { $split_ictag && ([string match *icacheTagArray* $nm] || [string match *icachePdBank* $nm]) } { lappend ict $inst
  } elseif { [string match *icache* $nm] }      { lappend ic $inst
  } elseif { [string match *dcache* $nm] } { lappend dc $inst
  } elseif { [string match *tage* $nm] || [string match *ubtb* $nm] || [string match *bim* $nm] } { lappend pr $inst
  } else                                   { lappend ot $inst }
}
puts "INFO: macros -> icache [llength $ic], ictag [llength $ict], offsets [llength $ico], dcache [llength $dc], pred [llength $pr], other [llength $ot]"

proc pack_group {block dbu macros x0 y0 strip_w gap {orient R0}} {
  set cx $x0 ; set cy $y0 ; set shelf_h 0
  foreach inst $macros {
    set m [$inst getMaster]
    set w [$m getWidth] ; set h [$m getHeight]
    if { $cx + $w > $x0 + $strip_w } { set cx $x0 ; set cy [expr {$cy + $shelf_h + $gap}] ; set shelf_h 0 }
    place_macro -macro_name [$inst getName] \
      -location [list [expr {$cx/double($dbu)}] [expr {$cy/double($dbu)}]] -orientation $orient
    $inst setPlacementStatus FIRM
    set cx [expr {$cx + $w + $gap}]
    if { $h > $shelf_h } { set shelf_h $h }
  }
}

# Mirror west-column macro pins toward the core; PNR_MACRO_MY=0 selects R0.
set fe_orient MY
if { [info exists ::env(PNR_MACRO_MY)] && $::env(PNR_MACRO_MY) == 0 } { set fe_orient R0 }
puts "INFO: west-column macro orientation: $fe_orient"

set gap [um $block 8.0]
set sw  [um $block 400.0]    ;# ~2 data macros wide -> each cache packs 2 ways/shelf
pack_group $block $dbu $ic [um $block 30.0]  [um $block 30.0]  $sw $gap $fe_orient  ;# I-cache: lower-left
set pred_y 440.0
if { [info exists ::env(PNR_PRED_Y)] && $::env(PNR_PRED_Y) != "" } { set pred_y [expr {double($::env(PNR_PRED_Y))}] }
set ict_y 330.0
if { [info exists ::env(PNR_ICT_Y)] && $::env(PNR_ICT_Y) != "" } { set ict_y [expr {double($::env(PNR_ICT_Y))}] }
set prt {}; set prb {}; set pru {}
foreach i $pr { set nm [$i getName]
  if { [string match *bimBank* $nm] }       { lappend prb $i } \
  elseif { [string match *tageBank* $nm] }  { lappend prt $i } \
  else                                      { lappend pru $i } }
set pr [concat $prt $prb $pru]
pack_group $block $dbu $pr [um $block 30.0]  [um $block $pred_y] $sw $gap $fe_orient  ;# predictors: above I-cache
# Additional offset banks fit in the existing gap above the data macros.
if { [llength $ico] > 0 } {
  pack_group $block $dbu $ico [um $block 30.0] [um $block 265.0] $sw $gap $fe_orient
}
# Place split I-cache tags and predecode between the data and predictor shelves.
if { [llength $ict] > 0 } {
  pack_group $block $dbu $ict [um $block 30.0] [um $block $ict_y] $sw $gap $fe_orient
  puts "INFO: I\$ tag+pd mini-shelf placed at (30,$ict_y) beside the predictor shelf (y0=$pred_y)"
}
# Optional dense D-cache grid: place tags first and reduce the shelf gap to 2 um.
set dc_gap $gap
if { [info exists ::env(PNR_DC_GRID)] && $::env(PNR_DC_GRID) == 1 } {
  set dctag {} ; set dcdat {}
  foreach i $dc { if { [string match *dcacheTagArray* [$i getName]] } { lappend dctag $i } else { lappend dcdat $i } }
  set dc [concat $dctag $dcdat]
  set dc_gap [um $block 2.0]
  puts "INFO: D\$ dense grid: gap 2um, tag macros packed first (nearest LSU)"
}
pack_group $block $dbu $dc [um $block 470.0] [um $block 30.0]  $sw $dc_gap  ;# D-cache: to its right
pack_group $block $dbu $ot [um $block 470.0] [um $block 560.0] $sw $gap   ;# divider etc.: out of the way
puts "INFO: macros placed (I-cache + predictors clustered, D-cache, divider)"

# ---------- IO pins ----------
place_pins -hor_layers metal5 -ver_layers metal6

# ---------- wire RC ----------
source $PLAT/setRC.tcl

set gp_opts [list -density $dens -pad_left 1 -pad_right 1]
# Weight timing-critical nets during placement; PNR_TIMING_DRIVEN=0 disables this.
if { !([info exists ::env(PNR_TIMING_DRIVEN)] && $::env(PNR_TIMING_DRIVEN) == 0) } {
  lappend gp_opts -timing_driven
  puts "INFO: timing-driven global placement enabled"
}
if { [info exists ::env(PNR_ROUTABILITY)] && $::env(PNR_ROUTABILITY) == 1 } {
  lappend gp_opts -routability_driven
  puts "INFO: routability-driven global placement enabled"
}
global_placement {*}$gp_opts
estimate_parasitics -placement

puts "\n===== timing BEFORE repair_design (unbuffered) ====="
report_worst_slack -max

# ---------- buffering / resize ----------
set_dont_use {TAPCELL_X1 FILLCELL_X1 AOI211_X1 OAI211_X1}
repair_design
detailed_placement
estimate_parasitics -placement

if { ![info exists ::env(PNR_REPAIR_TIMING)] || $::env(PNR_REPAIR_TIMING) != 0 } {
  puts "\n===== running repair_timing -setup ====="
  repair_timing -setup
  detailed_placement
  estimate_parasitics -placement
  puts "\n===== timing AFTER repair_timing ====="
  report_worst_slack -max
}

# ---------- clock-tree synthesis (env-gated) ----------
# Off by default (ideal clock = fastest/optimistic). PNR_CTS=1 builds a real
# clock tree + propagates it so reported setup timing includes skew/insertion
# delay -- a more honest Fmax. Buffers come from the Nangate45 platform.
if { [info exists ::env(PNR_CTS)] && $::env(PNR_CTS) == 1 } {
  puts "INFO: running clock_tree_synthesis (propagated clock)"
  clock_tree_synthesis -buf_list {CLKBUF_X1 CLKBUF_X2 CLKBUF_X3} \
                       -root_buf CLKBUF_X3 -sink_clustering_enable
  set_propagated_clock [all_clocks]
  detailed_placement
  estimate_parasitics -placement
  repair_design
  detailed_placement
  estimate_parasitics -placement
  if { ![info exists ::env(PNR_CTS_RT)] || $::env(PNR_CTS_RT) != 0 } {
    puts "\n===== timing AFTER CTS, BEFORE post-CTS repair_timing ====="
    report_worst_slack -max
    puts "\n===== running post-CTS repair_timing -setup ====="
    repair_timing -setup
    detailed_placement
    estimate_parasitics -placement
  }
  # report_clock_skew may not exist in every orfs build -- never let it abort the run
  puts "\n===== clock tree ====="
  catch { report_clock_skew }
}

# ---------- reports ----------
puts "\n===== timing AFTER repair_design ====="
report_worst_slack -max
report_tns
report_wns
puts "\n===== critical paths ====="
# PNR_RPT_COUNT widens the endpoint group count for wall analysis (default 8).
set rpt_count 8
if { [info exists ::env(PNR_RPT_COUNT)] && $::env(PNR_RPT_COUNT) ne "" } { set rpt_count $::env(PNR_RPT_COUNT) }
report_checks -path_delay max -group_count $rpt_count -slack_max 1e30 \
  -fields {capacitance slew fanout input_pins} -format full_clock
# PNR_RPT_WALLS=1 adds per-subsystem worst paths (wall-margin analysis): the top
# group_count paths usually all belong to ONE wall, hiding how far behind the
# other co-critical loops (FE fetch, predictors, int-RS wakeup) sit.
if { [info exists ::env(PNR_RPT_WALLS)] && $::env(PNR_RPT_WALLS) == 1 } {
  foreach {tag pat} {
    icacheTag  frontend/if1Stage/icache/icacheTagArray*/u_ram
    tageBank   frontend/tage/tageBank*/u_ram
    ubtbBank   frontend/ubtb/ubtbBankRam*/u_ram
    bimBank    frontend/tage/bimBank*/u_ram
    intRs      backend/intRs*/rsEntry*/entry_reg*
    prf        backend/prf/*
    rename     backend/rename/*
    dcacheData backend/lsuTop/dc/dcacheDataArray*/u_ram
    dcacheTag  backend/lsuTop/dc/dcacheTagArray*/u_ram
  } {
    puts "\n===== wall: $tag ====="
    set insts [get_cells -quiet $pat]
    if { [llength $insts] == 0 } { puts "  (no cells match $pat)"; continue }
    report_checks -path_delay max -group_count 2 -slack_max 1e30 -from $insts
  }
}
puts "\n===== power ====="
# Activity-annotated power (SAIF flow): if a VCD is supplied, annotate real
# switching activity from the Verilator CoreMark run so dynamic power reflects
# actual toggle rates (esp. clock-gated / way-predicted SRAM macros) instead of
# OpenROAD's default switching assumption. OOOREO_VCD_SCOPE is the VCD hierarchy
# path to the `cpu` instance (e.g. top_tb.dut). Env-gated -> default flow unchanged.
if { [info exists ::env(OOOREO_VCD)] && $::env(OOOREO_VCD) ne "" } {
  set vcd_scope "TOP/top_tb/dut"   ;# verified format: TOP + '/' separators
  if { [info exists ::env(OOOREO_VCD_SCOPE)] && $::env(OOOREO_VCD_SCOPE) ne "" } {
    set vcd_scope $::env(OOOREO_VCD_SCOPE)
  }
  puts "INFO: read_vcd -scope $vcd_scope $::env(OOOREO_VCD)"
  read_vcd -scope $vcd_scope $::env(OOOREO_VCD)
}
report_power
puts "\n===== area ====="
report_design_area
# The placed netlist (75MB) + DEF (96MB) are exploration artifacts not consumed
# by the PPA parse. Skip them by default to save I/O on every sweep; set
# PNR_WRITE_DEF=1 to emit them (and PNR_OUT to redirect for parallel variants).
set OUT $DIR
if { [info exists ::env(PNR_OUT)] && $::env(PNR_OUT) ne "" } { set OUT $::env(PNR_OUT) }
if { [info exists ::env(PNR_WRITE_DEF)] && $::env(PNR_WRITE_DEF) == 1 } {
  write_verilog $OUT/netlist_buffered.v
  write_def     $OUT/cpu_placed.def
}
puts "DONE"
exit
