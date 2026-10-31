set script_dir [file dirname [file normalize [info script]]]
set project_root [file normalize [file join $script_dir ..]]
set image_name AX7101_DUAL_DATASET_UDP_port4_runtime_mode_verified
if {[llength $argv] >= 1} {
    set image_name [lindex $argv 0]
}
set bit_file [file join $project_root bit_archive \
    ${image_name}.bit]
set probes_file [file join $project_root bit_archive \
    ${image_name}.ltx]
set output_dir [file join $project_root bitstream]
set mcs_file [file join $output_dir ${image_name}.mcs]
set prm_file [file join $output_dir ${image_name}.prm]

if {![file exists $bit_file]} {
    error "Verified bitstream does not exist: $bit_file"
}

file mkdir $output_dir
write_cfgmem -force -format mcs -interface SPIx4 -size 16 \
    -loadbit "up 0x00000000 $bit_file" \
    -file $mcs_file

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
if {[file exists $probes_file]} {
    set_property PROBES.FILE $probes_file $device
    set_property FULL_PROBES.FILE $probes_file $device
}
refresh_hw_device $device

set cfgmem_parts [get_cfgmem_parts -quiet \
    mt25ql128-spi-x1_x2_x4]
if {[llength $cfgmem_parts] == 0} {
    puts "N25Q128_CANDIDATES=$cfgmem_parts"
    error "Vivado N25Q128-compatible configuration-memory part was not found"
}

set cfgmem [create_hw_cfgmem -hw_device $device \
    [lindex $cfgmem_parts 0]]
set_property PROGRAM.ADDRESS_RANGE {use_file} $cfgmem
set_property PROGRAM.FILES [list $mcs_file] $cfgmem
set_property PROGRAM.PRM_FILE $prm_file $cfgmem
set_property PROGRAM.UNUSED_PIN_TERMINATION {pull-none} $cfgmem
set_property PROGRAM.BLANK_CHECK 0 $cfgmem
set_property PROGRAM.ERASE 1 $cfgmem
set_property PROGRAM.CFG_PROGRAM 1 $cfgmem
set_property PROGRAM.VERIFY 1 $cfgmem
set_property PROGRAM.CHECKSUM 0 $cfgmem

startgroup
if {![string equal [get_property PROGRAM.HW_CFGMEM_TYPE $device] \
        [get_property MEM_TYPE [get_property CFGMEM_PART $cfgmem]]]} {
    create_hw_bitstream -hw_device $device \
        [get_property PROGRAM.HW_CFGMEM_BITFILE $device]
    program_hw_devices $device
    refresh_hw_device $device
}
program_hw_cfgmem -hw_cfgmem $cfgmem
endgroup

boot_hw_device $device
after 10000
refresh_hw_device $device

puts "QSPI_MCS_FILE=$mcs_file"
puts "QSPI_PRM_FILE=$prm_file"
puts "QSPI_PART=mt25ql128-spi-x1_x2_x4"
puts "QSPI_PROGRAM_VERIFY=PASS"

close_hw_manager
