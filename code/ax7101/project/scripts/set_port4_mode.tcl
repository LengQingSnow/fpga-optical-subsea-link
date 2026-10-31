set script_dir [file dirname [file normalize [info script]]]
set project_root [file normalize [file join $script_dir ..]]
set probes_file [file join $project_root bitstream ax7101_dual_dataset_udp.ltx]

set requested_mode rx
if {[llength $argv] >= 1} {
    set requested_mode [string tolower [lindex $argv 0]]
}
if {[llength $argv] >= 2} {
    # Vivado's batch wrapper can change the working directory; accept an
    # explicit probe path so migrated workspaces with bracketed names work.
    set probes_file [lindex $argv 1]
}

if {$requested_mode ni {rx prbs}} {
    error {Usage: set_port4_mode.tcl rx|prbs}
}

open_hw_manager
connect_hw_server -allow_non_jtag
set targets [get_hw_targets -quiet]
if {[llength $targets] == 0} {
    error "No hardware target found"
}

set target ""
set device ""
foreach candidate_target $targets {
    if {[catch {open_hw_target $candidate_target}]} {
        continue
    }
    set candidate_devices [get_hw_devices -quiet xc7a100t*]
    if {[llength $candidate_devices] != 0} {
        set target $candidate_target
        set device [lindex $candidate_devices 0]
        break
    }
    close_hw_target $candidate_target
}

if {$device eq ""} {
    error "No XC7A100T device found on any connected JTAG target"
}

set_property PARAM.FREQUENCY 1000000 $target
current_hw_target $target
current_hw_device $device
if {![file exists $probes_file]} {
    error "Debug probes file does not exist: $probes_file"
}
set_property PROBES.FILE $probes_file $device
set_property FULL_PROBES.FILE $probes_file $device
refresh_hw_device $device

set vios [get_hw_vios -quiet -of_objects $device]
if {[llength $vios] != 1} {
    error "Expected one VIO core, found [llength $vios]"
}

set vio [lindex $vios 0]
set request_probe [lindex [get_hw_probes -quiet -of_objects $vio \
    *port4_tx_mode_request*] 0]
set active_probe [lindex [get_hw_probes -quiet -of_objects $vio \
    *port4_tx_mode_active*] 0]
set count_probe [lindex [get_hw_probes -quiet -of_objects $vio \
    *port4_prbs_frame_count*] 0]

if {$request_probe eq "" || $active_probe eq "" || $count_probe eq ""} {
    error "Unexpected port 4 VIO probe configuration"
}

set request_value [expr {$requested_mode eq "prbs" ? 1 : 0}]
set_property OUTPUT_VALUE $request_value $request_probe
commit_hw_vio $vio
after 100
refresh_hw_vio $vio

puts "PORT4_REQUESTED_MODE=$requested_mode"
foreach probe [list $active_probe $count_probe] {
    puts "[get_property NAME $probe]=[get_property INPUT_VALUE $probe]"
}

close_hw_manager
