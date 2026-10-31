set_property -dict {PACKAGE_PIN E12 IOSTANDARD LVDS_25} [get_ports pl_clk_p]
set_property -dict {PACKAGE_PIN D12 IOSTANDARD LVDS_25} [get_ports pl_clk_n]
set_property PACKAGE_PIN K28 [get_ports qsfp_refclk_p]
set_property -dict {PACKAGE_PIN E14 IOSTANDARD LVDS_25} [get_ports pl_sysref_p]
set_property -dict {PACKAGE_PIN D14 IOSTANDARD LVDS_25} [get_ports pl_sysref_n]

set_property -dict {PACKAGE_PIN C13 IOSTANDARD LVCMOS25} [get_ports lmk_sync]
set_property -dict {PACKAGE_PIN H9 IOSTANDARD LVCMOS33} [get_ports {led[0]}]
set_property -dict {PACKAGE_PIN B11 IOSTANDARD LVCMOS33} [get_ports {led[1]}]
set_property -dict {PACKAGE_PIN B10 IOSTANDARD LVCMOS33} [get_ports {led[2]}]
set_property -dict {PACKAGE_PIN C11 IOSTANDARD LVCMOS33} [get_ports {led[3]}]

create_clock -name pl_clk_200 -period 5.000 [get_ports pl_clk_p]
create_clock -name qsfp_refclk_156p25 -period 6.400 [get_ports qsfp_refclk_p]
set_property LOC MMCM_X0Y4 [get_cells axis_mmcm_i]
set_property CLOCK_DEDICATED_ROUTE ANY_CMT_COLUMN [get_nets pl_clk_global]

# Control flags and diagnostic status cross through explicit two-stage
# synchronizers. Cut only their first destination stage; the second stage stays
# timed in the destination domain.
set_false_path -to [get_pins -hier -regexp {.*(mtime_start_sync_ff_reg\[0\]|config_done_sync_ff_reg\[0\]|rf_mode_sync_ff_reg\[0\]|ber_capture_sync_ff_reg\[0\]|ber_replay_enable_sync_ff_reg\[0\]|ber_reference_ready_sync_ff_reg\[0\]|ber_replay_active_sync_ff_reg\[0\]|datapath_enable_500_sync_ff_reg\[0\]|rx_diag_sync_ff1_reg\[[0-3]\]|runtime_status_sync_ff1_reg\[[0-7]\])/D}]

# The rf_mode control crosses from the AXI clock into the Aurora RX clock.
set_false_path -to [get_pins -hier -regexp {.*rf_mode_rx_sync_ff_reg\[0\]/D}]

# The BER reference RAM is written only during capture and remains immutable
# before reference_ready crosses into the AXI domain. Its readback data is a
# bundled static bus; cut only the memory-cell launch into AXI readback flops.
set ber_ref_mem_cells [get_cells -quiet -hier -regexp {.*ber_reference_i/reference_memory_reg.*}]
set ber_ref_data_pins [get_pins -quiet -hier -regexp {.*control_i/up_rdata_reg\[[0-9]+\]/D}]
if {[llength $ber_ref_mem_cells] && [llength $ber_ref_data_pins]} {
    set_false_path -from $ber_ref_mem_cells -to $ber_ref_data_pins
}

# The delay configuration is a bundled-data CDC. The source snapshot is held
# stable while a four-stage synchronized toggle gives the 56-bit bus time to
# settle through its two-stage synchronizer.
set_false_path -to [get_pins -hier -regexp {.*delay_config_cdc_i/(delay_meta_reg\[[0-9]+\]|commit_sync_reg\[0\])/D}]

# The pre-equalizer payload uses the same bundled-data protocol as the delay
# configuration. Cut the asynchronous input of the first bus/toggle stages.
set_false_path -to [get_pins -hier -regexp {.*preeq_config_cdc_i/(config_meta_reg\[[0-9]+\]|commit_sync_reg\[0\])/D}]

# Reset synchronizers assert asynchronously and release through three clocked
# stages. Recovery/removal checks are cut only on the asynchronous clear pins.
set_false_path -to [get_pins -hier -regexp {.*(reset_250_i|reset_rx_i)/sync_ff_reg\[[0-2]\]/CLR}]

set_false_path -from [get_ports pl_sysref_p]
set_false_path -from [get_ports pl_sysref_n]
set_false_path -to [get_ports {led[*]}]
