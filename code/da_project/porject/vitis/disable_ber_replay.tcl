set control_base 0x80010000
set control_word65 [expr {$control_base + 4 * 65}]
set status_word66 [expr {$control_base + 4 * 66}]

proc read_word {address} {
    set line [mrd $address 1]
    set token [lindex $line end]
    scan $token %x value
    return $value
}

connect -url tcp:127.0.0.1:3121
configparams force-mem-access 1
targets -set -nocase -filter {name =~ "*Cortex-A53 #0*"}
catch {stop}
mwr $control_word65 0
after 20
set control [read_word $control_word65]
set status [read_word $status_word66]
puts "BER_REF_CONTROL 0x[format %08X $control]"
puts "BER_REF_STATUS 0x[format %08X $status]"
if {($control & 2) != 0 || ($status & 2) != 0} {
    error "BER replay is still active"
}
puts "BER_REF_REPLAY_DISABLED_VERIFIED"
configparams force-mem-access 0
disconnect
exit
