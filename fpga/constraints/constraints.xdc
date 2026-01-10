# Clock Signal (Example for 100MHz clock)
# Replace 'clk' with your top-level clock port name
create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports clk]

# Input/Output Delays (Example placeholders)
# set_input_delay -clock [get_clocks sys_clk_pin] -min -add_delay 0.0 [get_ports rst_n]
# set_input_delay -clock [get_clocks sys_clk_pin] -max -add_delay 2.0 [get_ports rst_n]

# Voltage standards (Example)
# set_property IOSTANDARD LVCMOS33 [get_ports clk]
# set_property IOSTANDARD LVCMOS33 [get_ports rst_n]
