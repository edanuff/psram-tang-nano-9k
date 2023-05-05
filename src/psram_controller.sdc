//Copyright (C)2014-2023 GOWIN Semiconductor Corporation.
//All rights reserved.
//File Title: Timing Constraints file
//GOWIN Version: 1.9.8.09 Education
//Created Time: 2023-05-04 16:59:13
create_clock -name clk_sys -period 37.037 -waveform {0 18.518} [get_ports {sys_clk}]
create_generated_clock -name clk_pll_mem -source [get_ports {sys_clk}] -master_clock clk_sys -divide_by 2 -multiply_by 4 [get_nets {clk}]
set_multicycle_path -from [get_clocks {clk_pll_mem}] -to [get_clocks {clk_sys}]  -setup -end 2
set_multicycle_path -from [get_clocks {clk_pll_mem}] -to [get_clocks {clk_sys}]  -hold -end 1
