if {$argc != 3} {
    error "Usage: load_dataset_jtag.tcl <plan_file> <bit_file> <ltx_file>"
}

set plan_file [file normalize [lindex $argv 0]]
set bit_file [file normalize [lindex $argv 1]]
set ltx_file [file normalize [lindex $argv 2]]
set skip_program [expr {
    [info exists ::env(AX7101_SKIP_PROGRAM)] &&
    $::env(AX7101_SKIP_PROGRAM) eq "1"
}]

foreach required [list $plan_file $bit_file] {
    if {![file exists $required]} {
        error "Required file does not exist: $required"
    }
}

proc normalize_axi_data {value} {
    set compact [string map [list "0x" "" "0X" ""] $value]
    regsub -all {[^0-9A-Fa-f]} $compact "" compact
    return [string toupper $compact]
}

open_hw_manager
connect_hw_server
set targets [get_hw_targets -quiet]
if {[llength $targets] == 0} {
    error "No hardware target found"
}

set target ""
set device ""
foreach candidate_target $targets {
    set_property PARAM.FREQUENCY 1000000 $candidate_target
    if {[catch {open_hw_target $candidate_target} open_error]} {
        puts "SKIP_TARGET target=$candidate_target error=$open_error"
        continue
    }
    foreach candidate_device [get_hw_devices -quiet] {
        set part [get_property PART $candidate_device]
        puts "FOUND_DEVICE target=$candidate_target device=$candidate_device part=$part"
        if {[string match "xc7a100t*" $part]} {
            set target $candidate_target
            set device $candidate_device
            break
        }
    }
    if {$device ne ""} {
        break
    }
    close_hw_target $candidate_target
}
if {$device eq ""} {
    close_hw_manager
    error "No XC7A100T device found on any connected JTAG target"
}

current_hw_target $target
current_hw_device $device
if {[file exists $ltx_file]} {
    set_property PROBES.FILE $ltx_file $device
    set_property FULL_PROBES.FILE $ltx_file $device
}
if {!$skip_program} {
    set_property PROGRAM.FILE $bit_file $device
    program_hw_devices $device
    after 5000
} else {
    puts "FPGA_PROGRAM_SKIPPED=1"
    after 10000
}
refresh_hw_device -update_hw_probes false $device

set axes [get_hw_axis -quiet -of_objects $device]
if {[llength $axes] == 0} {
    error "No JTAG-to-AXI hardware master was found after programming"
}
set axi [lindex $axes 0]
puts "HW_AXI_MASTER=$axi"

set input [open $plan_file r]
fconfigure $input -encoding ascii -translation lf
if {[gets $input header] < 0 || $header ne "AX7101_JTAG_AXI_PLAN_V1"} {
    close $input
    error "Invalid JTAG AXI plan header"
}

set operation_count 0
set write_count 0
set read_count 0
while {[gets $input line] >= 0} {
    if {$line eq ""} {
        continue
    }
    set fields [split $line "|"]
    if {[llength $fields] != 5} {
        close $input
        error "Malformed plan line [expr {$operation_count + 2}]"
    }
    lassign $fields opcode label address beats expected_words
    incr operation_count
    set transaction_name [format "dataset_%06d" $operation_count]

    if {$opcode eq "W"} {
        create_hw_axi_txn $transaction_name $axi \
            -type write -address $address -len $beats \
            -data $expected_words -burst INCR
        run_hw_axi [get_hw_axi_txns $transaction_name]
        incr write_count
    } elseif {$opcode eq "R"} {
        create_hw_axi_txn $transaction_name $axi \
            -type read -address $address -len $beats -burst INCR
        set transaction [get_hw_axi_txns $transaction_name]
        run_hw_axi $transaction
        set actual [normalize_axi_data [get_property DATA $transaction]]
        # Vivado reports a burst read as one wide value with the final beat
        # at the most-significant (left) side.  Write data is supplied as an
        # address-ordered word list, so reverse only the beat order here.
        set expected [normalize_axi_data \
            [join [lreverse [split $expected_words " "]] " "]]
        if {$actual ne $expected} {
            close $input
            error "Readback mismatch label=$label address=0x$address"
        }
        incr read_count
    } else {
        close $input
        error "Unsupported plan opcode '$opcode'"
    }

    delete_hw_axi_txn [get_hw_axi_txns $transaction_name]
    if {($operation_count % 256) == 0} {
        puts "JTAG_PROGRESS operations=$operation_count label=$label"
        flush stdout
    }
}
close $input

puts "JTAG_LOAD_OK operations=$operation_count writes=$write_count reads=$read_count"
close_hw_manager
