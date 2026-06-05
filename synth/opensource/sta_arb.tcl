read_liberty nangate45.lib
read_verilog arb_new_net.v
link_design issue_arbiter
set_max_delay 5 -from [all_inputs] -to [all_outputs]
report_checks -path_delay max -unconstrained -digits 4 -fields {} -group_count 1
