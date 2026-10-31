set script_dir [file dirname [file normalize [info script]]]
set project_root [file normalize [file join $script_dir ..]]
set probes_file [file join $project_root bitstream AX7101_3TX_1RX_PRBS31.ltx]
set capture_dir [file join $project_root reports hardware]

set test_name port_test
if {[llength $argv] >= 1} {
    set test_name [lindex $argv 0]
}

file mkdir $capture_dir
open_hw_manager
connect_hw_server -allow_non_jtag
open_hw_target

set devices [get_hw_devices -quiet xc7a100t*]
if {[llength $devices] == 0} {
    error "No XC7A100T device found on the hardware target"
}

set device [lindex $devices 0]
current_hw_device $device
set_property PROBES.FILE $probes_file $device
set_property FULL_PROBES.FILE $probes_file $device
refresh_hw_device $device

set ilas [get_hw_ilas -quiet -of_objects $device]
if {[llength $ilas] != 1} {
    error "Expected one ILA core, found [llength $ilas]"
}
set ila [lindex $ilas 0]

proc capture_now {ila output_file} {
    run_hw_ila -trigger_now $ila
    wait_on_hw_ila -timeout 10 $ila
    set data [upload_hw_ila_data $ila]
    write_hw_ila_data -force -csv_file $output_file $data
    puts "CAPTURE_FILE=$output_file"
}

set first_file [file join $capture_dir ${test_name}_first.csv]
set second_file [file join $capture_dir ${test_name}_second.csv]

capture_now $ila $first_file
after 2000
capture_now $ila $second_file

close_hw_manager
