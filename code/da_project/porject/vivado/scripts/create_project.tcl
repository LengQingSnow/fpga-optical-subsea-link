set script_dir [file normalize [file dirname [info script]]]
set root_dir [file normalize [file join $script_dir ..]]
set ref_dir [file normalize [file join $root_dir .. .. doc rfevm_rf_adaloop rfevm_rf_adaloop]]
set project_dir [file join $root_dir project]
set project_name rf47_qsfp_dpqpsk_rrc_8gsps_runtime_cal
set part_name xczu47dr-ffve1156-2-i
set stale_vendor_gen_dir [file normalize [file join $root_dir .. .. rfevm_rf_adaloop.gen]]

# Vivado records the reference project's generated-IP location inside each XCI.
# Remove only the cache created by earlier runs so stale output cannot lock RFDC.
file delete -force $stale_vendor_gen_dir

file mkdir [file join $root_dir bd]
file mkdir [file join $root_dir vendor]
set ref_bd_dir [file join $ref_dir rfevm_rf_adaloop.srcs sources_1 bd system]
set local_bd_dir [file join $root_dir bd system]
file delete -force $local_bd_dir
file copy -force $ref_bd_dir $local_bd_dir
file delete -force [file join $root_dir bd system.bd]

# The vendor BD stores its old absolute-generation relationship in JSON metadata.
# Redirect only that generated-output field into this standalone project.
set bd_path [file join $local_bd_dir system.bd]
set bd_file [open $bd_path r]
set bd_text [read $bd_file]
close $bd_file
set new_gen_dir [string map {\\ /} [file join $project_dir ${project_name}.gen sources_1 bd system]]
set bd_text [regsub {"gen_directory": "[^"]+"} $bd_text \
    "\"gen_directory\": \"$new_gen_dir\""]
set bd_file [open $bd_path w]
puts -nonewline $bd_file $bd_text
close $bd_file
foreach source_file {up_axi.v} {
    file copy -force \
        [file join $ref_dir rfevm_rf_adaloop.srcs sources_1 new $source_file] \
        [file join $root_dir vendor $source_file]
}
if {![file exists [file join $root_dir vendor user_control.v]]} {
    file copy -force \
        [file join $ref_dir rfevm_rf_adaloop.srcs sources_1 new user_control.v] \
        [file join $root_dir vendor user_control.v]
}

create_project -force $project_name $project_dir -part $part_name
file mkdir $new_gen_dir
set_property target_language Verilog [current_project]
set_property simulator_language Mixed [current_project]
set_property default_lib xil_defaultlib [current_project]

set ip_root [file join $root_dir generated_ip]
file delete -force $ip_root
file mkdir $ip_root

create_ip -name aurora_64b66b -vendor xilinx.com -library ip -version 12.0 \
    -module_name aurora_rx_rf47 -dir $ip_root
set_property -dict [list \
    CONFIG.CHANNEL_ENABLE {X0Y4 X0Y5 X0Y6 X0Y7} \
    CONFIG.C_AURORA_LANES {4} \
    CONFIG.C_LINE_RATE {10.3125} \
    CONFIG.C_REFCLK_FREQUENCY {156.25} \
    CONFIG.C_REFCLK_SOURCE {MGTREFCLK1_of_Quad_X0Y1} \
    CONFIG.C_START_LANE {X0Y4} \
    CONFIG.C_START_QUAD {Quad_X0Y1} \
    CONFIG.C_INIT_CLK {100.0} \
    CONFIG.C_USER_K {false} \
    CONFIG.SupportLevel {1} \
    CONFIG.crc_mode {false} \
    CONFIG.dataflow_config {RX-only_Simplex} \
    CONFIG.flow_mode {None} \
    CONFIG.interface_mode {Framing} \
] [get_ips aurora_rx_rf47]

create_ip -name ila -vendor xilinx.com -library ip -version 6.2 \
    -module_name ila_rf47_qsfp_rx -dir $ip_root
set_property -dict [list \
    CONFIG.C_DATA_DEPTH {1024} \
    CONFIG.C_NUM_OF_PROBES {8} \
    CONFIG.C_PROBE0_WIDTH {6} \
    CONFIG.C_PROBE1_WIDTH {8} \
    CONFIG.C_PROBE2_WIDTH {32} \
    CONFIG.C_PROBE3_WIDTH {32} \
    CONFIG.C_PROBE4_WIDTH {32} \
    CONFIG.C_PROBE5_WIDTH {256} \
    CONFIG.C_PROBE6_WIDTH {256} \
    CONFIG.C_PROBE7_WIDTH {4} \
] [get_ips ila_rf47_qsfp_rx]

generate_target all [get_ips aurora_rx_rf47]
generate_target all [get_ips ila_rf47_qsfp_rx]
foreach ip_name {aurora_rx_rf47 ila_rf47_qsfp_rx} {
    create_ip_run [get_ips $ip_name]
}

add_files -norecurse [file join $root_dir vendor up_axi.v]
add_files -norecurse [file join $root_dir vendor user_control.v]
foreach rtl_file [glob -nocomplain [file join $root_dir rtl *.sv]] {
    add_files -norecurse $rtl_file
}
add_files -fileset constrs_1 -norecurse [file join $root_dir constraints rf47_board.xdc]
add_files -norecurse $bd_path

update_compile_order -fileset sources_1
open_bd_design [get_files system.bd]
set rfdc [get_bd_cells usp_rf_data_converter_0]

# Gen3 Mode 4 (DUC bypass) is required to reach 8 GSPS with 1x interpolation.
set active_dacs {00 02 10 12 20 22 30 32}
set dac_props {}
foreach slice $active_dacs {
    lappend dac_props CONFIG.DAC_Mode${slice} 3
    lappend dac_props CONFIG.DAC_Data_Type${slice} 0
    lappend dac_props CONFIG.DAC_Data_Width${slice} 16
    lappend dac_props CONFIG.DAC_Interpolation_Mode${slice} 1
    lappend dac_props CONFIG.DAC_Invsinc_Ctrl${slice} true
    lappend dac_props CONFIG.DAC_Mixer_Type${slice} 1
    lappend dac_props CONFIG.DAC_Mixer_Mode${slice} 2
}
foreach tile {0 1 2 3} {
    lappend dac_props CONFIG.DAC${tile}_Sampling_Rate 8.000
    lappend dac_props CONFIG.DAC${tile}_Outclk_Freq 500.000
}
foreach {name value} [list \
    CONFIG.DAC0_Clock_Source 4 \
    CONFIG.DAC0_PLL_Enable true \
    CONFIG.DAC0_Refclk_Freq 200.000 \
    CONFIG.DAC1_Refclk_Freq 8000.000 \
    CONFIG.DAC2_PLL_Enable true \
    CONFIG.DAC2_Refclk_Freq 200.000 \
    CONFIG.DAC3_Refclk_Freq 8000.000] {
    lappend dac_props $name $value
}
set_property -dict $dac_props $rfdc

set_property -dict [list \
    CONFIG.DAC0_Multi_Tile_Sync true \
    CONFIG.DAC1_Multi_Tile_Sync true \
    CONFIG.DAC2_Multi_Tile_Sync true \
    CONFIG.DAC3_Multi_Tile_Sync true] $rfdc

set adc_props {}
foreach tile {0 1 2 3} {
    foreach slice {0 1 2 3} {
        lappend adc_props CONFIG.ADC_Slice${tile}${slice}_Enable false
    }
}
set_property -dict $adc_props $rfdc

# Recreate AXIS boundary ports so Vivado propagates the new 256-bit widths.
foreach name {s00_axis s02_axis s10_axis s12_axis s20_axis s22_axis s30_axis s32_axis} {
    set old_port [get_bd_intf_ports -quiet $name]
    if {[llength $old_port]} {
        delete_bd_objs $old_port
    }
    set ext_port [create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 $name]
    set_property -dict [list \
        CONFIG.FREQ_HZ 500000000 \
        CONFIG.HAS_TKEEP 0 \
        CONFIG.HAS_TLAST 0 \
        CONFIG.HAS_TREADY 1 \
        CONFIG.HAS_TSTRB 0 \
        CONFIG.TDATA_NUM_BYTES 32 \
        CONFIG.TDEST_WIDTH 0 \
        CONFIG.TID_WIDTH 0 \
        CONFIG.TUSER_WIDTH 0] $ext_port
    connect_bd_intf_net $ext_port [get_bd_intf_pins $rfdc/$name]
}

# ADCs are disabled; remove boundary objects left by the reference design.
foreach name {adc1_clk vin0_01 vin0_23 vin1_01 vin1_23 vin2_01 vin2_23 vin3_01 vin3_23} {
    set port [get_bd_intf_ports -quiet $name]
    if {[llength $port]} { delete_bd_objs $port }
}
foreach name {m00_axis m01_axis m02_axis m03_axis m10_axis m11_axis m12_axis m13_axis m20_axis m21_axis m22_axis m23_axis m30_axis m31_axis m32_axis m33_axis} {
    set port [get_bd_intf_ports -quiet $name]
    if {[llength $port]} { delete_bd_objs $port }
}
foreach name {user_sysref_adc_0} {
    set port [get_bd_ports -quiet $name]
    if {[llength $port]} { delete_bd_objs $port }
}

# Mode 4 exposes the second board RF-DAC reference-clock input.
if {![llength [get_bd_intf_ports -quiet dac0_clk]]} {
    set ext_port [create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:diff_clock_rtl:1.0 dac0_clk]
    set_property CONFIG.FREQ_HZ 200000000 $ext_port
    connect_bd_intf_net $ext_port [get_bd_intf_pins $rfdc/dac0_clk]
}
set_property CONFIG.FREQ_HZ 200000000 [get_bd_intf_ports dac0_clk]
set_property CONFIG.FREQ_HZ 200000000 [get_bd_intf_ports dac2_clk]

# The MTS AXIS clock must come from the board PL clock, not an RFDC output clock.
set old_clk_net [get_bd_nets -quiet clk_wiz_0_clk_out1]
foreach pin_name {s0_axis_aclk s1_axis_aclk s2_axis_aclk s3_axis_aclk} {
    set pin [get_bd_pins $rfdc/$pin_name]
    if {[llength [get_bd_nets -quiet -of_objects $pin]]} {
        disconnect_bd_net [get_bd_nets -of_objects $pin] $pin
    }
}
if {[llength [get_bd_ports -quiet data_clk]]} {
    delete_bd_objs [get_bd_ports data_clk]
}

# The external 500 MHz PL clock replaces the reference clock wizard. Keep only
# the control-register and RFDC AXI slaves, mapped onto M00 and M01.
foreach net_name {ps8_0_axi_periph_M00_AXI ps8_0_axi_periph_M01_AXI ps8_0_axi_periph_M02_AXI} {
    set intf_net [get_bd_intf_nets -quiet $net_name]
    if {[llength $intf_net]} { delete_bd_objs $intf_net }
}
set clk_wiz_seg [get_bd_addr_segs -quiet zynq_ultra_ps_e_0/Data/SEG_clk_wiz_0_Reg]
if {[llength $clk_wiz_seg]} { delete_bd_objs $clk_wiz_seg }
set clk_wiz [get_bd_cells -quiet clk_wiz_0]
if {[llength $clk_wiz]} { delete_bd_objs $clk_wiz }
foreach net_name {clk_wiz_0_clk_out1 clk_wiz_0_locked} {
    set stale_net [get_bd_nets -quiet $net_name]
    if {[llength $stale_net]} { delete_bd_objs $stale_net }
}
set axi_periph [get_bd_cells ps8_0_axi_periph]
set_property CONFIG.NUM_MI 2 $axi_periph
connect_bd_intf_net [get_bd_intf_pins $axi_periph/M00_AXI] [get_bd_intf_pins up_axi_0/up_axi]
connect_bd_intf_net [get_bd_intf_pins $axi_periph/M01_AXI] [get_bd_intf_pins $rfdc/s_axi]

set axis_clk [create_bd_port -dir I -type clk -freq_hz 500000000 axis_clk]
connect_bd_net $axis_clk \
    [get_bd_pins $rfdc/s0_axis_aclk] \
    [get_bd_pins $rfdc/s1_axis_aclk] \
    [get_bd_pins $rfdc/s2_axis_aclk] \
    [get_bd_pins $rfdc/s3_axis_aclk]

set reset_cell [get_bd_cells rst_rf_clk]
set reset_clk_pin [get_bd_pins $reset_cell/slowest_sync_clk]
if {[llength [get_bd_nets -quiet -of_objects $reset_clk_pin]]} {
    disconnect_bd_net [get_bd_nets -of_objects $reset_clk_pin] $reset_clk_pin
}
connect_bd_net $axis_clk $reset_clk_pin

set lock_pin [get_bd_pins $reset_cell/dcm_locked]
if {[llength [get_bd_nets -quiet -of_objects $lock_pin]]} {
    disconnect_bd_net [get_bd_nets -of_objects $lock_pin] $lock_pin
}
set axis_locked [create_bd_port -dir I axis_locked]
connect_bd_net $axis_locked $lock_pin

set axis_resetn [create_bd_port -dir O -type rst axis_resetn]
set_property CONFIG.POLARITY ACTIVE_LOW $axis_resetn
connect_bd_net [get_bd_pins $reset_cell/peripheral_aresetn] $axis_resetn

set old_sysref [get_bd_ports -quiet user_sysref_dac_0]
if {[llength $old_sysref]} { delete_bd_objs $old_sysref }
foreach net [get_bd_nets -quiet user_sysref_dac*] { delete_bd_objs $net }
foreach net [get_bd_nets -quiet user_sysref_adc*] { delete_bd_objs $net }
set user_sysref [create_bd_port -dir I user_sysref_dac]
connect_bd_net $user_sysref [get_bd_pins $rfdc/user_sysref_dac]

set ps_fclk_freq [get_property CONFIG.FREQ_HZ [get_bd_pins zynq_ultra_ps_e_0/pl_clk0]]
set_property CONFIG.FREQ_HZ $ps_fclk_freq [get_bd_ports fclk_100m]

validate_bd_design
save_bd_design
generate_target all [get_files system.bd]
set wrapper [make_wrapper -files [get_files system.bd] -top]
add_files -norecurse $wrapper

set top_file [file join $root_dir rtl rf47_qsfp_dpqpsk_top.sv]
if {[file exists $top_file]} {
    set_property top rf47_qsfp_dpqpsk_top [get_filesets sources_1]
}
update_compile_order -fileset sources_1
puts "PROJECT_CREATED [file join $project_dir ${project_name}.xpr]"
puts "RFDC_MODE [get_property CONFIG.DAC_Mode00 $rfdc]"
puts "RFDC_SAMPLE_GSPS [get_property CONFIG.DAC0_Sampling_Rate $rfdc]"
puts "RFDC_INTERPOLATION [get_property CONFIG.DAC_Interpolation_Mode00 $rfdc]"
puts "RFDC_WORDS [get_property CONFIG.DAC_Data_Width00 $rfdc]"
puts "RFDC_AXIS_MHZ [get_property CONFIG.DAC0_Fabric_Freq $rfdc]"
exit
