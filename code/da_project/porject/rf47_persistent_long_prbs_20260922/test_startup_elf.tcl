set root [file dirname [file normalize [info script]]]
connect -url tcp:127.0.0.1:3121
configparams force-mem-access 1
targets -set -nocase -filter {name =~ "*Cortex-A53 #0*"}
proc reg {index} {return [expr {[lindex [mrd -force -value [expr {0x80010000+4*$index}] 1] 0] & 0xffffffff}]}
if {[reg 196]!=0x5052424c || [reg 197]!=262144} {error "Not verified long PRBS firmware"}
stop
rst -processor
dow [file join $root rf47_init_long_prbs.elf]
con
after 20000
foreach i {0 1 3 6 7 9 10 11 12 13 14 15 16 17 47 64 65 66 196 197} {puts [format "STARTUP_REG %d %08X" $i [reg $i]]}
if {[reg 3]!=1 || [reg 7]!=1 || [reg 6]!=0 || [reg 65]!=3 || [reg 66]!=3} {error "Startup verification failed"}
set expected {54 65 61 59 20 24 3 4}
for {set i 0} {$i<8} {incr i} {if {[reg [expr {10+$i}]]!=[lindex $expected $i]} {error "Delay mismatch"}}
puts "STARTUP_ELF_VERIFIED"
configparams force-mem-access 0
disconnect
exit
