if {[llength $argv] != 1} {
    error "Usage: xsct set_source_mode.tcl qsfp|square"
}

set requested_mode [string tolower [lindex $argv 0]]
if {$requested_mode eq "qsfp"} {
    set mode_value 0
} elseif {$requested_mode eq "square"} {
    set mode_value 1
} else {
    error "Source mode must be qsfp or square"
}

set control_base 0x80010000
set start_addr [expr {$control_base + 4}]
set mode_addr [expr {$control_base + 24}]

connect -url tcp:127.0.0.1:3121
configparams force-mem-access 1
targets -set -nocase -filter {name =~ "*Cortex-A53 #0*"}
catch {stop}
mwr $start_addr 0
after 20
mwr $mode_addr $mode_value
after 20
mwr $start_addr 1
con
puts "SOURCE_MODE $requested_mode"
configparams force-mem-access 0
disconnect
exit
