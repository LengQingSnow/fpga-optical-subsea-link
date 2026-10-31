set_property -dict {PACKAGE_PIN E12 IOSTANDARD LVDS_25} [get_ports pl_clk_p]
set_property -dict {PACKAGE_PIN D12 IOSTANDARD LVDS_25} [get_ports pl_clk_n]
set_property -dict {PACKAGE_PIN E14 IOSTANDARD LVDS_25} [get_ports pl_sysref_p]
set_property -dict {PACKAGE_PIN D14 IOSTANDARD LVDS_25} [get_ports pl_sysref_n]

set_property -dict {PACKAGE_PIN C13 IOSTANDARD LVCMOS25} [get_ports lmk_sync]
set_property -dict {PACKAGE_PIN H9 IOSTANDARD LVCMOS33} [get_ports {led[0]}]
set_property -dict {PACKAGE_PIN B11 IOSTANDARD LVCMOS33} [get_ports {led[1]}]
set_property -dict {PACKAGE_PIN B10 IOSTANDARD LVCMOS33} [get_ports {led[2]}]
set_property -dict {PACKAGE_PIN C11 IOSTANDARD LVCMOS33} [get_ports {led[3]}]

create_clock -name pl_clk_200 -period 5.000 [get_ports pl_clk_p]
set_property LOC MMCM_X0Y4 [get_cells axis_mmcm_i]
set_property CLOCK_DEDICATED_ROUTE ANY_CMT_COLUMN [get_nets pl_clk_global]
set_clock_groups -asynchronous \
    -group [get_clocks clk_pl_0] \
    -group [get_clocks -include_generated_clocks pl_clk_200]

set_false_path -from [get_ports pl_sysref_p]
set_false_path -from [get_ports pl_sysref_n]
set_false_path -to [get_ports {led[*]}]
