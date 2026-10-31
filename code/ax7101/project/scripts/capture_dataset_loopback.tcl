set script_dir [file dirname [file normalize [info script]]]
set project_root [file normalize [file join $script_dir ..]]
set probes_file [file join $project_root bitstream ax7101_dual_dataset_udp.ltx]
set capture_dir [file join $project_root reports hardware]

set test_name dataset_loopback
set capture_delay_ms 2000
if {[llength $argv] >= 1} {
    set test_name [lindex $argv 0]
}
if {[llength $argv] >= 2} {
    set capture_delay_ms [lindex $argv 1]
}
if {[llength $argv] >= 3} {
    set probes_file [lindex $argv 2]
}
if {[llength $argv] >= 4} {
    set capture_dir [lindex $argv 3]
}

if {![file exists $probes_file]} {
    error "Debug probes file does not exist: $probes_file"
}

proc safe_name {value} {
    return [string map [list "/" "_" "\\" "_" ":" "_"] $value]
}

proc capture_all_ilas {ilas capture_dir test_name phase} {
    foreach ila $ilas {
        run_hw_ila -trigger_now $ila
    }
    foreach ila $ilas {
        wait_on_hw_ila -timeout 10 $ila
        set data [upload_hw_ila_data $ila]
        set ila_name [safe_name [get_property NAME $ila]]
        set output_file [file join $capture_dir \
            ${test_name}_${phase}_${ila_name}.csv]
        write_hw_ila_data -force -csv_file $output_file $data
        puts "CAPTURE_FILE=$output_file"
    }
}

file mkdir $capture_dir
open_hw_manager
connect_hw_server
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
set_property PROBES.FILE $probes_file $device
set_property FULL_PROBES.FILE $probes_file $device
refresh_hw_device $device

set ilas [get_hw_ilas -quiet -of_objects $device]
if {[llength $ilas] != 4} {
    error "Expected four ILA cores, found [llength $ilas]"
}

capture_all_ilas $ilas $capture_dir $test_name first
after $capture_delay_ms
capture_all_ilas $ilas $capture_dir $test_name second

close_hw_manager
