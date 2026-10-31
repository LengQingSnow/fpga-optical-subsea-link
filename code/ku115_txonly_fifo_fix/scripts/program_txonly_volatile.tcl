if {$argc != 2} {
    error "Usage: program_txonly_volatile.tcl <bit_file> <ltx_file>"
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

set ku115_device ""
set ku115_target ""
foreach target [get_hw_targets] {
    if {[catch {open_hw_target $target} open_error]} {
        puts "SKIP_TARGET $target $open_error"
        continue
    }

    foreach device [get_hw_devices] {
        set part [get_property PART $device]
        puts "FOUND_DEVICE target=$target device=$device part=$part"
        if {[string match "xcku115*" $part]} {
            set ku115_device $device
            set ku115_target $target
            break
        }
    }

    if {$ku115_device ne ""} {
        break
    }
    close_hw_target $target
}

if {$ku115_device eq ""} {
    close_hw_manager
    error "No xcku115 device found on any connected JTAG target"
}

current_hw_target $ku115_target
current_hw_device $ku115_device
refresh_hw_device -update_hw_probes false $ku115_device
set_property PROGRAM.FILE $bit_file $ku115_device
set_property PROBES.FILE $ltx_file $ku115_device
set_property FULL_PROBES.FILE $ltx_file $ku115_device
program_hw_devices $ku115_device
refresh_hw_device $ku115_device

puts "PROGRAMMED_TARGET $ku115_target"
puts "PROGRAMMED_DEVICE $ku115_device"
puts "PROGRAMMED_PART [get_property PART $ku115_device]"
puts "PROGRAMMED_BIT $bit_file"
puts "PROGRAMMED_ILA_COUNT [llength [get_hw_ilas -of_objects $ku115_device]]"

close_hw_manager
exit
