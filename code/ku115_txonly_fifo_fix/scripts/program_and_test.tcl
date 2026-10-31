set script_dir [file dirname [file normalize [info script]]]
set root_dir [file dirname $script_dir]
set capture_prefix qsfp_loopback_lane64
if {$argc >= 1} {
    set capture_prefix [lindex $argv 0]
}
set program_device 1
if {$argc >= 2} {
    set program_device [lindex $argv 1]
}
set bit_basename Sender_KU115_qsfp1tx_qsfp2rx_continuous_lane64
if {$argc >= 3} {
    set bit_basename [lindex $argv 2]
}
set bit_file [file join $root_dir bit_archive ${bit_basename}.bit]
set ltx_file [file join $root_dir bit_archive ${bit_basename}.ltx]

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
if {[file exists $ltx_file]} {
    set_property PROBES.FILE $ltx_file $device
    set_property FULL_PROBES.FILE $ltx_file $device
}
if {$program_device} {
    program_hw_devices $device
}
refresh_hw_device $device

set ila [lindex [get_hw_ilas -of_objects $device -filter {CELL_NAME == "qsfp_loop_ila_inst"}] 0]
if {$ila eq ""} {
    error "QSFP loopback ILA not found"
}

for {set capture_index 1} {$capture_index <= 2} {incr capture_index} {
    run_hw_ila -trigger_now $ila
    wait_on_hw_ila $ila
    upload_hw_ila_data $ila
    write_hw_ila_data -force \
        -csv_file [file join $root_dir hardware ${capture_prefix}_${capture_index}] \
        [get_hw_ila_data -of_objects $ila]
    after 1000
}
close_hw_manager
