if {[llength $argv] != 8} {
    error "Usage: xsct set_lane_delays.tcl tx0 tx1 tx2 tx3 tx4 tx5 tx6 tx7"
}

set delay_codes {}
foreach raw_code $argv {
    set code [expr {$raw_code}]
    if {$code < 0 || $code > 127} {
        error "Each delay code must be in the range 0..127"
    }
    lappend delay_codes $code
}

set control_base 0x80010000
set first_delay_addr [expr {$control_base + 40}]
set commit_addr [expr {$control_base + 72}]

connect -url tcp:127.0.0.1:3121
configparams force-mem-access 1
targets -set -nocase -filter {name =~ "*Cortex-A53 #0*"}
catch {stop}
# Runtime delay commits are atomic in the PL. Keep the DAC stream running so
# the asynchronous gearboxes retain their read phase during calibration.
for {set lane 0} {$lane < 8} {incr lane} {
    mwr [expr {$first_delay_addr + 4 * $lane}] [lindex $delay_codes $lane]
}
mwr $commit_addr 1
# Repeat the same atomic commit. The AXI register is a toggle, so a second
# write republishes identical data and protects interactive calibration from
# a missed CDC event without pausing or draining the DAC stream.
after 50
mwr $commit_addr 1
after 50
con

for {set lane 0} {$lane < 8} {incr lane} {
    set code [lindex $delay_codes $lane]
    set integer_delay [expr {($code >> 5) & 3}]
    set fractional_delay [expr {$code & 31}]
    set nominal_ps [expr {125.0 * $integer_delay + 125.0 * $fractional_delay / 32.0}]
    puts [format "TX%d code=%d integer=%d fraction=%d nominal_ps=%.5f" \
        $lane $code $integer_delay $fractional_delay $nominal_ps]
}
configparams force-mem-access 0
disconnect
exit
