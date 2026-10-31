set script_dir [file dirname [file normalize [info script]]]
set root_dir [file dirname $script_dir]

set capture_prefix large_stream
if {$argc >= 1} {
    set capture_prefix [lindex $argv 0]
}
set program_device 1
if {$argc >= 2} {
    set program_device [lindex $argv 1]
}
set bit_basename Sender_KU115_qsfp1tx_qsfp2rx_large_stream
if {$argc >= 3} {
    set bit_basename [lindex $argv 2]
}
set settle_ms 1000
if {$argc >= 4} {
    set settle_ms [lindex $argv 3]
}

set bit_file [file join $root_dir bit_archive ${bit_basename}.bit]
set ltx_file [file join $root_dir bit_archive ${bit_basename}.ltx]
file mkdir [file join $root_dir hardware]

if {$program_device && ![file exists $bit_file]} {
    error "BIT file not found: $bit_file"
}
if {![file exists $ltx_file]} {
    error "LTX file not found: $ltx_file"
}

proc find_ila_by_cell {device cell_name} {
    foreach candidate [get_hw_ilas -of_objects $device] {
        if {[get_property CELL_NAME $candidate] eq $cell_name} {
            return $candidate
        }
    }
    error "ILA not found: $cell_name"
}

proc capture_ila_csv {ila output_prefix} {
    run_hw_ila -trigger_now $ila
    wait_on_hw_ila $ila
    upload_hw_ila_data $ila
    write_hw_ila_data -force -csv_file $output_prefix \
        [get_hw_ila_data -of_objects $ila]
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
set_property PROBES.FILE $ltx_file $device
set_property FULL_PROBES.FILE $ltx_file $device

if {$program_device} {
    set_property PROGRAM.FILE $bit_file $device
    program_hw_devices $device
}

refresh_hw_device $device
after $settle_ms

set aggregate_ila [find_ila_by_cell $device aggregate_ila_inst]
set qsfp_ila [find_ila_by_cell $device qsfp_loop_ila_inst]

capture_ila_csv $aggregate_ila \
    [file join $root_dir hardware ${capture_prefix}_aggregate]
capture_ila_csv $qsfp_ila \
    [file join $root_dir hardware ${capture_prefix}_qsfp]

puts "Captured aggregate statistics and QSFP loopback ILAs with prefix: $capture_prefix"
close_hw_manager

