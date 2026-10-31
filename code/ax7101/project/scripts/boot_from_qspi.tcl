open_hw_manager
connect_hw_server

set targets [get_hw_targets -quiet]
if {[llength $targets] == 0} {
    error "No hardware target found"
}
set target [lindex $targets 0]
set_property PARAM.FREQUENCY 3000000 $target
open_hw_target $target

set devices [get_hw_devices -quiet xc7a100t*]
if {[llength $devices] == 0} {
    error "No XC7A100T device found"
}
set device [lindex $devices 0]
current_hw_device $device
boot_hw_device $device
after 15000
refresh_hw_device -update_hw_probes false $device
puts "QSPI_BOOT_DONE=[get_property REGISTER.IR_STATUS $device]"
close_hw_manager
