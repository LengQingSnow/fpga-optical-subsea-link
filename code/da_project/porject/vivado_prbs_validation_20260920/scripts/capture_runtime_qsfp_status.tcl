if {$argc != 2} {
    error "Usage: capture_runtime_qsfp_status.tcl <ltx_file> <output_csv>"
}

set ltx_file [file normalize [lindex $argv 0]]
set output_csv [file normalize [lindex $argv 1]]

if {![file exists $ltx_file]} {
    error "LTX file not found: $ltx_file"
}
file mkdir [file dirname $output_csv]

proc find_rf47 {} {
    foreach target [get_hw_targets] {
        if {[catch {open_hw_target $target}]} {
            continue
        }
        foreach device [get_hw_devices] {
            if {[string match "xczu47dr*" [get_property PART $device]]} {
                return [list $target $device]
            }
        }
        close_hw_target $target
    }
    error "No xczu47dr device found on any connected JTAG target"
}

proc find_ila_by_cell {device cell_name} {
    foreach candidate [get_hw_ilas -of_objects $device] {
        if {[get_property CELL_NAME $candidate] eq $cell_name} {
            return $candidate
        }
    }
    error "ILA not found: $cell_name"
}

open_hw_manager
connect_hw_server -allow_non_jtag

lassign [find_rf47] target device
current_hw_target $target
current_hw_device $device
set_property PROBES.FILE $ltx_file $device
set_property FULL_PROBES.FILE $ltx_file $device
refresh_hw_device $device

set ila [find_ila_by_cell $device qsfp_ila_i]
run_hw_ila -trigger_now $ila
wait_on_hw_ila $ila
upload_hw_ila_data $ila
write_hw_ila_data -force -csv_file $output_csv [get_hw_ila_data -of_objects $ila]

puts "CAPTURED_TARGET $target"
puts "CAPTURED_RF47_QSFP $output_csv"

close_hw_manager
exit
