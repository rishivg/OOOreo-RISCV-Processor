# OpenROAD floorplan -> global place -> repair_design -> detailed place -> STA.
# Purpose: get TRUSTWORTHY timing/power by giving the netlist real physical
# parasitics + buffering. The raw yosys+abc netlist (no buffers) reports garbage
# WNS (-50us) because global control nets fan out to thousands of flops on one
# gate; repair_design fixes that once the design is placed.
#
# Run from synth/opensource/ :
#   docker run --rm -e ECE411_CLOCK_PERIOD_PS=2000 -v "$PWD/../..":/w -w /w \
#     openroad/orfs:latest \
#     /OpenROAD-flow-scripts/tools/install/OpenROAD/bin/openroad -no_init -exit \
#     synth/opensource/pnr/run_pnr.tcl
set PLAT /OpenROAD-flow-scripts/flow/platforms/nangate45
set SITE FreePDK45_38x28_10R_NP_162NW_34O
set DIR  synth/opensource/pnr

# ---------- liberty ----------
read_liberty $PLAT/lib/NangateOpenCellLibrary_typical.lib
read_liberty $PLAT/lib/fakeram45_128x256.lib
read_liberty $PLAT/lib/fakeram45_32x32.lib
read_liberty $PLAT/lib/fakeram45_64x32.lib
read_liberty $DIR/div_fake.lib

# ---------- lef ----------
read_lef $PLAT/lef/NangateOpenCellLibrary.tech.lef
read_lef $PLAT/lef/NangateOpenCellLibrary.macro.mod.lef
read_lef $PLAT/lef/fakeram45_128x256.lef
read_lef $PLAT/lef/fakeram45_32x32.lef
read_lef $PLAT/lef/fakeram45_64x32.lef
read_lef $DIR/div_fake.lef

# ---------- design ----------
read_verilog $DIR/netlist_pnr.v
link_design cpu

# ---------- constraints ----------
set period_ps 1000
if { [info exists ::env(ECE411_CLOCK_PERIOD_PS)] } { set period_ps $::env(ECE411_CLOCK_PERIOD_PS) }
set period_ns [expr {$period_ps / 1000.0}]
create_clock -name clk -period $period_ns [get_ports clk]
set_input_delay  0.2 -clock clk [all_inputs]
set_output_delay 0.1 -clock clk [all_outputs]
puts "INFO: clock period = $period_ns ns ([expr {1000.0/$period_ns}] MHz target)"

# ---------- floorplan ----------
# Die/core size and placement density are env-overridable so the floorplan can
# be tightened (shorter wires -> less repair buffering -> higher Fmax + smaller
# area) without editing this file. Defaults reproduce the original loose 1600um
# / density-0.6 run exactly.
set die_um  1600.0
set dens    0.6
# Treat an unset OR empty env var as "use default" (ppa.sh may pass empty knobs).
if { [info exists ::env(PNR_DIE_UM)]  && $::env(PNR_DIE_UM)  ne "" } { set die_um [expr {double($::env(PNR_DIE_UM))}] }
if { [info exists ::env(PNR_DENSITY)] && $::env(PNR_DENSITY) ne "" } { set dens   [expr {double($::env(PNR_DENSITY))}] }
set core_lo 20.0
set core_hi [expr {$die_um - 20.0}]
puts "INFO: die ${die_um}x${die_um} um, core ${core_lo}..${core_hi}, place density $dens"
initialize_floorplan -die_area [list 0 0 $die_um $die_um] \
                     -core_area [list $core_lo $core_lo $core_hi $core_hi] -site $SITE
make_tracks

# ---------- manual macro placement (shelf packer) ----------
# Pack all BLOCK macros into a strip on the left of the core; stdcells fill the
# rest. Deterministic + non-overlapping; not connectivity-optimal but valid.
set block [ord::get_db_block]
set dbu [$block getDbUnitsPerMicron]
proc um {block v} { return [expr {round($v * [$block getDbUnitsPerMicron])}] }

set macros {}
foreach inst [$block getInsts] {
  if { [[$inst getMaster] getType] == "BLOCK" } { lappend macros $inst }
}
puts "INFO: [llength $macros] macros to place"

set gap     [um $block 10.0]
set x0       [um $block 30.0]
set y0       [um $block 30.0]
set strip_w [um $block 690.0] ;# region width for macros
set cx $x0
set cy $y0
set shelf_h 0
foreach inst $macros {
  set m [$inst getMaster]
  set w [$m getWidth]; set h [$m getHeight]
  if { $cx + $w > $x0 + $strip_w } {           ;# wrap to next shelf
    set cx $x0
    set cy [expr {$cy + $shelf_h + $gap}]
    set shelf_h 0
  }
  place_macro -macro_name [$inst getName] \
    -location [list [expr {$cx/double($dbu)}] [expr {$cy/double($dbu)}]] -orientation R0
  $inst setPlacementStatus FIRM ;# keep global placement from moving it
  set cx [expr {$cx + $w + $gap}]
  if { $h > $shelf_h } { set shelf_h $h }
}
puts "INFO: macros placed; top shelf reaches y=[expr {($cy+$shelf_h)/double($dbu)}] um"

# ---------- IO pins ----------
place_pins -hor_layers metal5 -ver_layers metal6

# ---------- wire RC ----------
source $PLAT/setRC.tcl

# ---------- global placement ----------
global_placement -density $dens -pad_left 1 -pad_right 1
estimate_parasitics -placement

puts "\n===== timing BEFORE repair_design (unbuffered) ====="
report_worst_slack -max

# ---------- buffering / resize ----------
set_dont_use {TAPCELL_X1 FILLCELL_X1 AOI211_X1 OAI211_X1}
repair_design
detailed_placement
estimate_parasitics -placement

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
}

# ---------- reports ----------
puts "\n===== timing AFTER repair_design ====="
report_worst_slack -max
report_tns
report_wns
puts "\n===== critical paths ====="
report_checks -path_delay max -group_count 8 -slack_max 1e30 \
  -fields {capacitance slew fanout input_pins} -format full_clock
puts "\n===== power ====="
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
