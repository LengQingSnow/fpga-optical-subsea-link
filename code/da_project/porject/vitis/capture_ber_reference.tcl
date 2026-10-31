if {[llength $argv] > 0} {
    error "Usage: xsct capture_ber_reference.tcl"
}

set control_base 0x80010000
set control_word65 [expr {$control_base + 4 * 65}]
set status_word66 [expr {$control_base + 4 * 66}]
set count_word67 [expr {$control_base + 4 * 67}]

proc read_word {address} {
    set line [mrd $address 1]
    set token [lindex $line end]
    if {[scan $token %x value] != 1} {
        error "Cannot parse register readback: $line"
    }
    return [expr {$value & 0xffffffff}]
}

connect -url tcp:127.0.0.1:3121
configparams force-mem-access 1
targets -set -nocase -filter {name =~ "*Cortex-A53 #0*"}
catch {stop}

# Bit 0 arms a fresh capture by toggling the CDC request; bit 1 keeps the
# captured block in cyclic replay while the scope records the waveform.
mwr $control_word65 3
after 20

set ready 0
for {set poll 0} {$poll < 500} {incr poll} {
    set status [read_word $status_word66]
    if {($status & 3) == 3} {
        set ready 1
        break
    }
    after 10
}
if {!$ready} {
    error "BER reference capture timeout; status=$status"
}

set count [read_word $count_word67]
puts "BER_REF_STATUS 0x[format %08X $status]"
puts "BER_REF_WORD_COUNT $count"
if {$count != 64} {
    error "Unexpected BER reference word count: $count"
}
for {set index 0} {$index < 128} {incr index} {
    set value [read_word [expr {$control_base + 4 * (68 + $index)}]]
    puts [format "BER_REF_DWORD %d 0x%08X" $index [expr {$value & 0xffffffff}]]
}

puts "BER_REF_READY 1"
configparams force-mem-access 0
catch {con}
disconnect
exit
