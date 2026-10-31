if {[llength $argv] != 29} {
    error "Usage: xsct set_preeq_profile.tcl enable_mask c0_t0 ... c3_t6"
}

set enable_mask [expr {[lindex $argv 0]}]
if {$enable_mask < 0 || $enable_mask > 15} {
    error "Enable mask must be in the range 0..15"
}

set coefficients {}
foreach raw_value [lrange $argv 1 end] {
    set value [expr {$raw_value}]
    if {$value < -32768 || $value > 32767} {
        error "Each Q15 coefficient must be in the range -32768..32767"
    }
    lappend coefficients $value
}

set control_base 0x80010000
set start_addr [expr {$control_base + 4}]
set mask_addr [expr {$control_base + 4 * 47}]
set commit_addr [expr {$control_base + 4 * 48}]

connect -url tcp:127.0.0.1:3121
configparams force-mem-access 1
targets -set -nocase -filter {name =~ "*Cortex-A53 #0*"}
catch {stop}
mwr $start_addr 0
after 20
for {set index 0} {$index < 28} {incr index} {
    set signed_value [lindex $coefficients $index]
    set register_value [expr {$signed_value & 0xffff}]
    set word_index [expr {19 + $index}]
    mwr [expr {$control_base + 4 * $word_index}] $register_value
}
mwr $mask_addr $enable_mask
mwr $commit_addr 1
after 30
mwr $start_addr 1
con

puts [format "PREEQ_MASK 0x%X" $enable_mask]
for {set component 0} {$component < 4} {incr component} {
    set first [expr {$component * 7}]
    puts "COMPONENT${component}_Q15 [lrange $coefficients $first [expr {$first + 6}]]"
}
puts "TAP_SPACING_UI 0.5"
puts "TAP_DELAYS_UI 0.0 0.5 1.0 1.5 2.0 2.5 3.0"
puts "TAP_OFFSETS_FROM_CENTER_UI -1.5 -1.0 -0.5 0.0 0.5 1.0 1.5"
configparams force-mem-access 0
disconnect
exit
