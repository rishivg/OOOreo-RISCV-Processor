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
# right-sized cache fakerams (hand-scaled to the actual geometry; the stock 128x256/
# 32x32 macros over-provisioned the I$ 64-set / D$ 16-set arrays ~2-8x). See fakeram/.
read_liberty $DIR/fakeram/fakeram45_64x256.lib   ;# I$ data (64 sets)
read_liberty $DIR/fakeram/fakeram45_16x256.lib   ;# D$ data (16 sets)
read_liberty $DIR/fakeram/fakeram45_16x32.lib    ;# D$ tag  (16 sets)
read_liberty $PLAT/lib/fakeram45_64x32.lib       ;# I$ tag  (64 sets, already right-sized)
read_liberty $DIR/div_fake.lib

# ---------- lef ----------
read_lef $PLAT/lef/NangateOpenCellLibrary.tech.lef
read_lef $PLAT/lef/NangateOpenCellLibrary.macro.mod.lef
read_lef $DIR/fakeram/fakeram45_64x256.lef
read_lef $DIR/fakeram/fakeram45_16x256.lef
read_lef $DIR/fakeram/fakeram45_16x32.lef
read_lef $PLAT/lef/fakeram45_64x32.lef
read_lef $DIR/div_fake.lef

# ---------- design ----------
# PNR_NETLIST overrides the netlist path so an alternate (e.g. baseline) netlist
# can be floorplanned for calibration without overwriting netlist_pnr.v.
set NETLIST $DIR/netlist_pnr.v
if { [info exists ::env(PNR_NETLIST)] && $::env(PNR_NETLIST) ne "" } { set NETLIST $::env(PNR_NETLIST) }
read_verilog $NETLIST
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
# area) without editing this file. Default die retuned 1600->1300 / density
# 0.6->0.72 after TAGE_DEPTH 1024->256 shrank the design ~31% (1600um left it at
# 34% util -> sparse placement inflated wire delay; 1300um restores ~55% util,
# matching the density the pre-shrink baseline ran at). Retuned 1300->1250 after
# the PHT 4096->1024 shrink cut another ~7.7% area (1300um dropped util to 50%;
# 1250um restores ~54%, matching the baseline util for an apples-to-apples Fmax).
set die_um  1250.0
set dens    0.72
# Treat an unset OR empty env var as "use default" (ppa.sh may pass empty knobs).
if { [info exists ::env(PNR_DIE_UM)]  && $::env(PNR_DIE_UM)  ne "" } { set die_um [expr {double($::env(PNR_DIE_UM))}] }
if { [info exists ::env(PNR_DENSITY)] && $::env(PNR_DENSITY) ne "" } { set dens   [expr {double($::env(PNR_DENSITY))}] }
set core_lo 20.0
set core_hi [expr {$die_um - 20.0}]
puts "INFO: die ${die_um}x${die_um} um, core ${core_lo}..${core_hi}, place density $dens"
initialize_floorplan -die_area [list 0 0 $die_um $die_um] \
                     -core_area [list $core_lo $core_lo $core_hi $core_hi] -site $SITE
make_tracks

# ---------- manual macro placement (per-cache clustering) ----------
# Cluster each cache's macros into its own compact block instead of packing all 17
# macros into one shared strip by area. The earlier area-packer scattered the 8
# I-cache macros across a ~565x460um region interleaved with the D-cache, so the
# fetch-address net (one driver -> all 8 I-cache macros) ran half a millimeter and
# the worst path was an 11ns repeater chain (80% of the 13.76ns critical path was
# long-wire buffering, only ~2.5ns was logic). Clustering keeps that net short;
# global_placement then pulls each cache's logic adjacent to its own cluster.
# Sorting insts by name groups a cache's ways (data+tag adjacent) contiguously.
set block [ord::get_db_block]
set dbu [$block getDbUnitsPerMicron]
proc um {block v} { return [expr {round($v * [$block getDbUnitsPerMicron])}] }

# classify BLOCK macros by hierarchy, name-sorted so ways pack data-then-tag
set ic {} ; set dc {} ; set ot {}
set pairs {}
foreach inst [$block getInsts] {
  if { [[$inst getMaster] getType] == "BLOCK" } { lappend pairs [list [$inst getName] $inst] }
}
foreach p [lsort -index 0 $pairs] {
  set inst [lindex $p 1]; set nm [lindex $p 0]
  if { [string match *icache* $nm] }      { lappend ic $inst
  } elseif { [string match *dcache* $nm] } { lappend dc $inst
  } else                                   { lappend ot $inst }
}
puts "INFO: macros -> icache [llength $ic], dcache [llength $dc], other [llength $ot]"

# shelf-pack one group into a region whose lower-left is (x0,y0), width strip_w
proc pack_group {block dbu macros x0 y0 strip_w gap} {
  set cx $x0 ; set cy $y0 ; set shelf_h 0
  foreach inst $macros {
    set m [$inst getMaster]
    set w [$m getWidth] ; set h [$m getHeight]
    if { $cx + $w > $x0 + $strip_w } { set cx $x0 ; set cy [expr {$cy + $shelf_h + $gap}] ; set shelf_h 0 }
    place_macro -macro_name [$inst getName] \
      -location [list [expr {$cx/double($dbu)}] [expr {$cy/double($dbu)}]] -orientation R0
    $inst setPlacementStatus FIRM
    set cx [expr {$cx + $w + $gap}]
    if { $h > $shelf_h } { set shelf_h $h }
  }
}

set gap [um $block 8.0]
set sw  [um $block 400.0]    ;# ~2 data macros wide -> each cache packs 2 ways/shelf
pack_group $block $dbu $ic [um $block 30.0]  [um $block 30.0]  $sw $gap   ;# I-cache: lower-left
pack_group $block $dbu $dc [um $block 470.0] [um $block 30.0]  $sw $gap   ;# D-cache: to its right
pack_group $block $dbu $ot [um $block 30.0]  [um $block 560.0] $sw $gap   ;# divider etc.
puts "INFO: macros placed (clustered per cache)"

# NOTE: an LSU std-cell fence (dbRegion+dbGroup over memRs/ldq/stq/arb/dc to shorten
# the AGU-0-stage load-loop nets) was tried and REJECTED: a loose region is silently
# ignored by gpl (only the Top-level region initializes), and a region tight enough
# to bind collides with the oversized fakeram macros -- the region inflates fixed
# area 286k->831k um2 and gpl aborts at 103% utilization (GPL-0301). The load-loop
# wire buffering is a symptom of the macro-dominated floorplan, not LSU scatter a
# std-cell fence can fix. The real Fmax lever for that path is re-pipelining the AGU.

# ---------- IO pins ----------
place_pins -hor_layers metal5 -ver_layers metal6

# ---------- wire RC ----------
source $PLAT/setRC.tcl

# ---------- global placement ----------
# The full-core worst path is the wire-dominated AGU-0-stage load-to-use loop (~85%
# of the path is inter-module net delay). Two env-gated levers attack the wires:
#   PNR_TIMING_DRIVEN=1 -> gpl re-weights critical-path nets (the load loop) so it
#       pulls those modules together instead of pure-wirelength placement.
#   PNR_ROUTABILITY=1   -> gpl spreads to relieve congestion (can help or hurt timing).
# Die size / density (PNR_DIE_UM / PNR_DENSITY above) tighten the whole floorplan so
# every net is shorter. Defaults reproduce the prior wirelength-driven run.
set gp_opts [list -density $dens -pad_left 1 -pad_right 1]
# Timing-driven global placement is ON by default: it re-weights the critical-path
# (load-loop) nets so gpl shortens them instead of pure-wirelength packing. Measured
# +31.9% Fmax (137.55 -> 181.49 MHz @ die1250/0.72) for +5.3% area / +6% power, 0 IPC.
# A die/density sweep confirmed 1250 is the peak (1200/1150 worse: higher util ->
# congestion; 1300/1350 worse: longer wires). Set PNR_TIMING_DRIVEN=0 to disable.
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
