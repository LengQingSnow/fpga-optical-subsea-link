# Read-only RF47 replay snapshot, based on the validated 20260916_0918 reader.
# Register map: da_project/porject/vivado/vendor/user_control.v.
# No processor stop, register write, capture arm, reset, or replay change.
proc rf47_read_word {address} {
    set line [mrd $address 1]
    set token [lindex $line end]
    if {![regexp {^(?:0x)?[0-9A-Fa-f]{8}$} $token] ||
        [scan $token %x value] != 1} {
        error "Invalid register read: $line"
    }
    return [expr {$value & 0xffffffff}]
}

proc rf47_read_registers {} {
    set result {}
    foreach {label offset} {RF_MODE 6 BER_CONTROL 65 BER_STATUS 66 BER_COUNT 67} {
        dict set result $label [rf47_read_word [expr {0x80010000 + 4*$offset}]]
    }
    if {[dict get $result RF_MODE] != 0} {
        error "RF_MODE must be 0 for the QSFP data route"
    }
    # Bit 1 enables replay; bit 0 is the capture toggle and may be 0 or 1.
    if {([dict get $result BER_CONTROL] & 2) != 2} {
        error "RF47 replay is disabled; no capture has been armed by this reader"
    }
    if {([dict get $result BER_STATUS] & 3) != 3} {
        error "RF47 reference is not ready and active"
    }
    if {[dict get $result BER_COUNT] != 64} {
        error "RF47 reference must contain 64 words"
    }
    return $result
}

set connected 0
set forced_access 0
set failed [catch {
    connect -url tcp:127.0.0.1:3121
    set connected 1
    configparams force-mem-access 1
    set forced_access 1
    targets -set -nocase -filter {name =~ "*Cortex-A53 #0*"}
    set before [rf47_read_registers]
    # Read the contiguous window in one transaction; -value preserves word order.
    set dwords [mrd -value -size w 0x80010110 128]
    if {[llength $dwords] != 128} {
        error "RF47 reference read must return exactly 128 dwords"
    }
    foreach value $dwords {
        if {![string is wideinteger -strict $value] || $value < 0 || $value > 0xffffffff} {
            error "Invalid unsigned 32-bit RF47 reference value: $value"
        }
    }
    set after [rf47_read_registers]
    foreach label {RF_MODE BER_CONTROL BER_STATUS BER_COUNT} {
        if {[dict get $before $label] != [dict get $after $label]} {
            error "RF47 $label changed during the reference read"
        }
    }
    puts "RF47_REFERENCE_BEGIN 1"
    foreach label {RF_MODE BER_CONTROL BER_STATUS BER_COUNT} {
        puts [format "%s 0x%08X" $label [dict get $before $label]]
    }
    for {set k 0} {$k < 128} {incr k} {
        puts [format "BER_REF_DWORD %d 0x%08X" $k [lindex $dwords $k]]
    }
    puts "RF47_REFERENCE_END 1"
} message]
if {$forced_access} {catch {configparams force-mem-access 0}}
if {$connected} {catch {disconnect}}
if {$failed} {
    puts stderr "RF47_REFERENCE_ERROR $message"
    exit 1
}
exit 0
