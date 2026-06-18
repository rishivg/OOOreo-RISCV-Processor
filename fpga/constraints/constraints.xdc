# Clock Signal (Example for 100MHz clock)
# Replace 'clk' with your top-level clock port name
create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports clk]

# Input/Output Delays (Example placeholders)
# set_input_delay -clock [get_clocks sys_clk_pin] -min -add_delay 0.0 [get_ports rst_n]
# set_input_delay -clock [get_clocks sys_clk_pin] -max -add_delay 2.0 [get_ports rst_n]

# Voltage standards for implementation-only PnR. No package pin LOCs are set;
# nextpnr is free to place these IOs on legal package pins.
set_property IOSTANDARD LVCMOS33 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports rst]
set_property IOSTANDARD LVCMOS33 [get_ports bmem_ready]
set_property IOSTANDARD LVCMOS33 [get_ports bmem_rvalid]
set_property IOSTANDARD LVCMOS33 [get_ports bmem_read]
set_property IOSTANDARD LVCMOS33 [get_ports bmem_write]
set_property IOSTANDARD LVCMOS33 [get_ports {bmem_addr[0] bmem_addr[1] bmem_addr[2] bmem_addr[3] bmem_addr[4] bmem_addr[5] bmem_addr[6] bmem_addr[7] bmem_addr[8] bmem_addr[9] bmem_addr[10] bmem_addr[11] bmem_addr[12] bmem_addr[13] bmem_addr[14] bmem_addr[15] bmem_addr[16] bmem_addr[17] bmem_addr[18] bmem_addr[19] bmem_addr[20] bmem_addr[21] bmem_addr[22] bmem_addr[23] bmem_addr[24] bmem_addr[25] bmem_addr[26] bmem_addr[27] bmem_addr[28] bmem_addr[29] bmem_addr[30] bmem_addr[31]}]
set_property IOSTANDARD LVCMOS33 [get_ports {bmem_wdata[0] bmem_wdata[1] bmem_wdata[2] bmem_wdata[3] bmem_wdata[4] bmem_wdata[5] bmem_wdata[6] bmem_wdata[7] bmem_wdata[8] bmem_wdata[9] bmem_wdata[10] bmem_wdata[11] bmem_wdata[12] bmem_wdata[13] bmem_wdata[14] bmem_wdata[15] bmem_wdata[16] bmem_wdata[17] bmem_wdata[18] bmem_wdata[19] bmem_wdata[20] bmem_wdata[21] bmem_wdata[22] bmem_wdata[23] bmem_wdata[24] bmem_wdata[25] bmem_wdata[26] bmem_wdata[27] bmem_wdata[28] bmem_wdata[29] bmem_wdata[30] bmem_wdata[31] bmem_wdata[32] bmem_wdata[33] bmem_wdata[34] bmem_wdata[35] bmem_wdata[36] bmem_wdata[37] bmem_wdata[38] bmem_wdata[39] bmem_wdata[40] bmem_wdata[41] bmem_wdata[42] bmem_wdata[43] bmem_wdata[44] bmem_wdata[45] bmem_wdata[46] bmem_wdata[47] bmem_wdata[48] bmem_wdata[49] bmem_wdata[50] bmem_wdata[51] bmem_wdata[52] bmem_wdata[53] bmem_wdata[54] bmem_wdata[55] bmem_wdata[56] bmem_wdata[57] bmem_wdata[58] bmem_wdata[59] bmem_wdata[60] bmem_wdata[61] bmem_wdata[62] bmem_wdata[63]}]
set_property IOSTANDARD LVCMOS33 [get_ports {bmem_raddr[0] bmem_raddr[1] bmem_raddr[2] bmem_raddr[3] bmem_raddr[4] bmem_raddr[5] bmem_raddr[6] bmem_raddr[7] bmem_raddr[8] bmem_raddr[9] bmem_raddr[10] bmem_raddr[11] bmem_raddr[12] bmem_raddr[13] bmem_raddr[14] bmem_raddr[15] bmem_raddr[16] bmem_raddr[17] bmem_raddr[18] bmem_raddr[19] bmem_raddr[20] bmem_raddr[21] bmem_raddr[22] bmem_raddr[23] bmem_raddr[24] bmem_raddr[25] bmem_raddr[26] bmem_raddr[27] bmem_raddr[28] bmem_raddr[29] bmem_raddr[30] bmem_raddr[31]}]
set_property IOSTANDARD LVCMOS33 [get_ports {bmem_rdata[0] bmem_rdata[1] bmem_rdata[2] bmem_rdata[3] bmem_rdata[4] bmem_rdata[5] bmem_rdata[6] bmem_rdata[7] bmem_rdata[8] bmem_rdata[9] bmem_rdata[10] bmem_rdata[11] bmem_rdata[12] bmem_rdata[13] bmem_rdata[14] bmem_rdata[15] bmem_rdata[16] bmem_rdata[17] bmem_rdata[18] bmem_rdata[19] bmem_rdata[20] bmem_rdata[21] bmem_rdata[22] bmem_rdata[23] bmem_rdata[24] bmem_rdata[25] bmem_rdata[26] bmem_rdata[27] bmem_rdata[28] bmem_rdata[29] bmem_rdata[30] bmem_rdata[31] bmem_rdata[32] bmem_rdata[33] bmem_rdata[34] bmem_rdata[35] bmem_rdata[36] bmem_rdata[37] bmem_rdata[38] bmem_rdata[39] bmem_rdata[40] bmem_rdata[41] bmem_rdata[42] bmem_rdata[43] bmem_rdata[44] bmem_rdata[45] bmem_rdata[46] bmem_rdata[47] bmem_rdata[48] bmem_rdata[49] bmem_rdata[50] bmem_rdata[51] bmem_rdata[52] bmem_rdata[53] bmem_rdata[54] bmem_rdata[55] bmem_rdata[56] bmem_rdata[57] bmem_rdata[58] bmem_rdata[59] bmem_rdata[60] bmem_rdata[61] bmem_rdata[62] bmem_rdata[63]}]
