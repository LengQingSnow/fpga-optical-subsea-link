set script_dir [file dirname [file normalize [info script]]]
set root_dir [file dirname $script_dir]
set project_name Sender_KU115
set project_file [file join $root_dir ${project_name}.xpr]

create_project -force $project_name $root_dir -part xcku115-flva1517-2-i
set_property target_language Verilog [current_project]
set_property simulator_language Mixed [current_project]
set_property default_lib xil_defaultlib [current_project]

set rtl_files [glob -nocomplain [file join $root_dir src *.v]]
if {[llength $rtl_files] > 0} {
    add_files -norecurse $rtl_files
}

set sim_files [glob -nocomplain [file join $root_dir sim *.v]]
if {[llength $sim_files] > 0} {
    add_files -fileset sim_1 -norecurse $sim_files
}

set xdc_files [glob -nocomplain [file join $root_dir constrs *.xdc]]
if {[llength $xdc_files] > 0} {
    add_files -fileset constrs_1 -norecurse $xdc_files
}

set xci_files [glob -nocomplain [file join $root_dir ip * *.xci]]
if {[llength $xci_files] > 0} {
    add_files -norecurse $xci_files
    foreach xci_file $xci_files {
        set_property generate_synth_checkpoint false [get_files [file normalize $xci_file]]
    }
}

set qpsk_clock_ip [get_ips -quiet clk_wiz_qpsk]
if {[llength $qpsk_clock_ip] != 1} {
    error "Expected one clk_wiz_qpsk IP, found [llength $qpsk_clock_ip]"
}
set_property CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {125.000} $qpsk_clock_ip

set ip_root [file join $root_dir generated_ip]
if {[file exists $ip_root]} {
    file delete -force $ip_root
}
file mkdir $ip_root

create_ip -name aurora_64b66b -vendor xilinx.com -library ip -version 12.0 \
    -module_name aurora_tx_qsfp1 -dir $ip_root
set_property -dict [list \
    CONFIG.CHANNEL_ENABLE {X1Y24 X1Y25 X1Y26 X1Y27} \
    CONFIG.C_AURORA_LANES {4} \
    CONFIG.C_LINE_RATE {10.3125} \
    CONFIG.C_REFCLK_FREQUENCY {156.25} \
    CONFIG.C_REFCLK_SOURCE {MGTREFCLK0_of_Quad_X1Y6} \
    CONFIG.C_START_LANE {X1Y24} \
    CONFIG.C_START_QUAD {Quad_X1Y6} \
    CONFIG.C_INIT_CLK {50.0} \
    CONFIG.C_USER_K {false} \
    CONFIG.SupportLevel {1} \
    CONFIG.crc_mode {false} \
    CONFIG.dataflow_config {TX-only_Simplex} \
    CONFIG.flow_mode {None} \
    CONFIG.interface_mode {Framing} \
] [get_ips aurora_tx_qsfp1]

create_ip -name aurora_64b66b -vendor xilinx.com -library ip -version 12.0 \
    -module_name aurora_rx_qsfp2 -dir $ip_root
set_property -dict [list \
    CONFIG.CHANNEL_ENABLE {X1Y20 X1Y21 X1Y22 X1Y23} \
    CONFIG.C_AURORA_LANES {4} \
    CONFIG.C_LINE_RATE {10.3125} \
    CONFIG.C_REFCLK_FREQUENCY {156.25} \
    CONFIG.C_REFCLK_SOURCE {MGTREFCLK0_of_Quad_X1Y5} \
    CONFIG.C_START_LANE {X1Y20} \
    CONFIG.C_START_QUAD {Quad_X1Y5} \
    CONFIG.C_INIT_CLK {50.0} \
    CONFIG.C_USER_K {false} \
    CONFIG.SupportLevel {1} \
    CONFIG.crc_mode {false} \
    CONFIG.dataflow_config {RX-only_Simplex} \
    CONFIG.flow_mode {None} \
    CONFIG.interface_mode {Framing} \
] [get_ips aurora_rx_qsfp2]

create_ip -name ila -vendor xilinx.com -library ip -version 6.2 \
    -module_name ila_qsfp_loop -dir $ip_root
set_property -dict [list \
    CONFIG.C_DATA_DEPTH {1024} \
    CONFIG.C_NUM_OF_PROBES {13} \
    CONFIG.C_PROBE0_WIDTH {2} \
    CONFIG.C_PROBE1_WIDTH {8} \
    CONFIG.C_PROBE2_WIDTH {32} \
    CONFIG.C_PROBE3_WIDTH {32} \
    CONFIG.C_PROBE4_WIDTH {32} \
    CONFIG.C_PROBE5_WIDTH {32} \
    CONFIG.C_PROBE6_WIDTH {32} \
    CONFIG.C_PROBE7_WIDTH {32} \
    CONFIG.C_PROBE8_WIDTH {32} \
    CONFIG.C_PROBE9_WIDTH {32} \
    CONFIG.C_PROBE10_WIDTH {256} \
    CONFIG.C_PROBE11_WIDTH {256} \
    CONFIG.C_PROBE12_WIDTH {4} \
] [get_ips ila_qsfp_loop]

create_ip -name ila -vendor xilinx.com -library ip -version 6.2 \
    -module_name ila_aggregate_stats -dir $ip_root
set_property -dict [list \
    CONFIG.C_DATA_DEPTH {1024} \
    CONFIG.C_NUM_OF_PROBES {17} \
    CONFIG.C_PROBE0_WIDTH {128} \
    CONFIG.C_PROBE1_WIDTH {3} \
    CONFIG.C_PROBE2_WIDTH {32} \
    CONFIG.C_PROBE3_WIDTH {32} \
    CONFIG.C_PROBE4_WIDTH {32} \
    CONFIG.C_PROBE5_WIDTH {32} \
    CONFIG.C_PROBE6_WIDTH {32} \
    CONFIG.C_PROBE7_WIDTH {32} \
    CONFIG.C_PROBE8_WIDTH {32} \
    CONFIG.C_PROBE9_WIDTH {32} \
    CONFIG.C_PROBE10_WIDTH {8} \
    CONFIG.C_PROBE11_WIDTH {128} \
    CONFIG.C_PROBE12_WIDTH {128} \
    CONFIG.C_PROBE13_WIDTH {128} \
    CONFIG.C_PROBE14_WIDTH {128} \
    CONFIG.C_PROBE15_WIDTH {128} \
    CONFIG.C_PROBE16_WIDTH {128} \
] [get_ips ila_aggregate_stats]

generate_target all [get_ips]
export_ip_user_files -of_objects [get_ips] -no_script -sync -force -quiet

foreach ip_name {aurora_tx_qsfp1 aurora_rx_qsfp2 ila_qsfp_loop ila_aggregate_stats} {
    create_ip_run [get_ips $ip_name]
}

set_property top top [get_filesets sources_1]
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1
report_ip_status -file [file join $root_dir reports ip_status.rpt]
close_project
