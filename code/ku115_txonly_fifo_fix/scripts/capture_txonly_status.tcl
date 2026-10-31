if {$argc != 2} {
    error "Usage: capture_txonly_status.tcl <ltx_file> <output_dir>"
}

set ltx_file [file normalize [lindex $argv 0]]
set output_dir [file normalize [lindex $argv 1]]
if {![file exists $ltx_file]} {
    error "LTX file not found: $ltx_file"
}
file mkdir $output_dir

proc find_ku115 {} {
    foreach target [get_hw_targets] {
        if {[catch {open_hw_target $target}]} {
            continue
        }
        foreach device [get_hw_devices] {
            if {[string match "xcku115*" [get_property PART $device]]} {
                return [list $target $device]
            }
        }
        close_hw_target $target
    }
    error "No xcku115 device found on any connected JTAG target"
}

proc find_ila_by_cell {device cell_name} {
    foreach candidate [get_hw_ilas -of_objects $device] {
        if {[get_property CELL_NAME $candidate] eq $cell_name} {
            return $candidate
        }
    }
    error "ILA not found: $cell_name"
}

proc capture_ila {ila output_prefix} {
    run_hw_ila -trigger_now $ila
    wait_on_hw_ila $ila
    upload_hw_ila_data $ila
    write_hw_ila_data -force -csv_file $output_prefix \
        [get_hw_ila_data -of_objects $ila]
}

open_hw_manager
connect_hw_server -allow_non_jtag
lassign [find_ku115] target device
current_hw_target $target
current_hw_device $device
set_property PROBES.FILE $ltx_file $device
set_property FULL_PROBES.FILE $ltx_file $device
refresh_hw_device $device

set aggregate_ila [find_ila_by_cell $device aggregate_ila_inst]
set qsfp_ila [find_ila_by_cell $device qsfp_loop_ila_inst]
capture_ila $aggregate_ila [file join $output_dir aggregate_status]
capture_ila $qsfp_ila [file join $output_dir qsfp_status]

puts "CAPTURED_TARGET $target"
puts "CAPTURED_AGGREGATE [file join $output_dir aggregate_status.csv]"
puts "CAPTURED_QSFP [file join $output_dir qsfp_status.csv]"
close_hw_manager
exit
