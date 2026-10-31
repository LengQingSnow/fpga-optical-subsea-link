if {$argc < 2} {
    error "Usage: program_rgmii_candidate.tcl <candidate.bit> <matching.ltx>"
}

set bit_file [file normalize [lindex $argv 0]]
set ltx_file [file normalize [lindex $argv 1]]

if {![file exists $bit_file]} {
    error "BIT file not found: $bit_file"
}
if {![file exists $ltx_file]} {
    error "LTX file not found: $ltx_file"
}

open_hw_manager
connect_hw_server -allow_non_jtag
open_hw_target
set device [lindex [get_hw_devices -filter {PART =~ "xcku115*"}] 0]
if {$device eq ""} {
    error "No xcku115 device found"
}

current_hw_device $device
refresh_hw_device -update_hw_probes false $device
set_property PROGRAM.FILE $bit_file $device
set_property PROBES.FILE $ltx_file $device
set_property FULL_PROBES.FILE $ltx_file $device
program_hw_devices $device
refresh_hw_device $device
puts "PROGRAMMED_BIT=$bit_file"
close_hw_manager
