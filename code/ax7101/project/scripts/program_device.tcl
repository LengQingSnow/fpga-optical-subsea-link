set script_dir [file dirname [file normalize [info script]]]
set project_root [file normalize [file join $script_dir ..]]
set bit_file [file join $project_root bitstream ax7101_dual_dataset_udp.bit]
set probes_file [file join $project_root bitstream ax7101_dual_dataset_udp.ltx]

if {![file exists $bit_file]} {
    error "Bitstream not found: $bit_file"
}

open_hw_manager
connect_hw_server -allow_non_jtag
set targets [get_hw_targets -quiet]
if {[llength $targets] == 0} {
    error "No hardware target found"
}
set target [lindex $targets 0]
set_property PARAM.FREQUENCY 1000000 $target
open_hw_target $target
set devices [get_hw_devices -quiet xc7a100t*]
if {[llength $devices] == 0} {
    error "No XC7A100T device found on the hardware target"
}

set device [lindex $devices 0]
current_hw_device $device
refresh_hw_device -update_hw_probes false $device
set_property PROGRAM.FILE $bit_file $device
if {[file exists $probes_file]} {
    set_property PROBES.FILE $probes_file $device
    set_property FULL_PROBES.FILE $probes_file $device
}
program_hw_devices $device
refresh_hw_device $device
puts "PROGRAMMED_DEVICE=[get_property PART $device]"
puts "PROGRAMMED_BIT=$bit_file"
close_hw_manager
