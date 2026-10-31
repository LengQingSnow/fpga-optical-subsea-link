proc normalize_axi_data {value} {
    set compact [string map [list "0x" "" "0X" ""] $value]
    regsub -all {[^0-9A-Fa-f]} $compact "" compact
    return [string toupper $compact]
}

open_hw_manager
connect_hw_server
set target [lindex [get_hw_targets -quiet] 0]
set_property PARAM.FREQUENCY 1000000 $target
open_hw_target $target

set device [lindex [get_hw_devices -quiet xc7a100t*] 0]
current_hw_device $device
refresh_hw_device -update_hw_probes false $device
set axi [lindex [get_hw_axis -quiet -of_objects $device] 0]
if {$axi eq ""} {
    error "No JTAG AXI master found"
}

set base_address 0x03000000
set test_word 0123456789ABCDEF
foreach beats {1 4 8 16 32} {
    set words {}
    for {set index 0} {$index < $beats} {incr index} {
        lappend words $test_word
    }
    set address [format %08X \
        [expr {$base_address + (($beats - 1) * 0x1000)}]]
    create_hw_axi_txn ddr_write_$beats $axi -type write \
        -address $address -len $beats -data $words -burst INCR
    set write_txn [get_hw_axi_txns ddr_write_$beats]
    run_hw_axi $write_txn
    puts "DDR_WRITE_PROPERTIES beats=$beats"
    report_property $write_txn

    create_hw_axi_txn ddr_read_$beats $axi -type read \
        -address $address -len $beats -burst INCR
    set read_txn [get_hw_axi_txns ddr_read_$beats]
    run_hw_axi $read_txn
    puts "DDR_READ_PROPERTIES beats=$beats"
    report_property $read_txn
    set actual [normalize_axi_data [get_property DATA $read_txn]]
    set expected [string repeat $test_word $beats]
    if {$actual ne $expected} {
        error "DDR_JTAG_AXI_FAIL beats=$beats actual=$actual"
    }
    puts "DDR_JTAG_AXI_PASS beats=$beats address=0x$address"
    delete_hw_axi_txn [get_hw_axi_txns ddr_write_$beats]
    delete_hw_axi_txn [get_hw_axi_txns ddr_read_$beats]
}

close_hw_manager
