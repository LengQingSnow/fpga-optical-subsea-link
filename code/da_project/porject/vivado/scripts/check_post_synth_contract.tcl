set script_dir [file normalize [file dirname [info script]]]
set root_dir [file normalize [file join $script_dir ..]]
set project_file [file join $root_dir project rf47_qsfp_dpqpsk_rrc_8gsps_runtime_cal.xpr]
open_project $project_file
open_run synth_1

set control_sync_pins [get_pins -hier -regexp {.*(mtime_start_sync_ff_reg\[0\]|config_done_sync_ff_reg\[0\]|rf_mode_sync_ff_reg\[0\]|datapath_enable_500_sync_ff_reg\[0\]|rx_diag_sync_ff1_reg\[[0-3]\])/D}]
set delay_sync_pins [get_pins -hier -regexp {.*delay_config_cdc_i/(delay_meta_reg\[[0-9]+\]|commit_sync_reg\[0\])/D}]
set reset_clear_pins [get_pins -hier -regexp {.*(reset_250_i|reset_rx_i)/sync_ff_reg\[[0-2]\]/CLR}]

if {[llength $control_sync_pins] != 8} {
    error "Expected eight control/diagnostic CDC first-stage pins, found [llength $control_sync_pins]"
}
if {[llength $delay_sync_pins] != 57} {
    error "Expected 57 bundled-delay CDC first-stage pins, found [llength $delay_sync_pins]"
}
if {[llength $reset_clear_pins] != 6} {
    error "Expected six reset synchronizer clear pins, found [llength $reset_clear_pins]"
}
if {[llength [get_cells -hier -regexp -nocase {.*prbs.*}]] != 0} {
    error "Internal PRBS logic is present in synthesized design"
}

puts "CONTROL_SYNC_PINS [llength $control_sync_pins]"
puts "DELAY_SYNC_PINS [llength $delay_sync_pins]"
puts "RESET_CLEAR_PINS [llength $reset_clear_pins]"
puts "NO_INTERNAL_PRBS 1"
exit
