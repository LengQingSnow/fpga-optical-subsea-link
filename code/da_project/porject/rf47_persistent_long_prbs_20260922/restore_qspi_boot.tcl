connect -url tcp:127.0.0.1:3121
puts [targets]
if {[catch {targets -set -nocase -filter {name == "PSU"}}]} {
 targets -set 4
}
configparams force-mem-access 1
puts [mrd -force 0xff5e0200 2]
mwr -force 0xff5e0200 0x2100
puts [mrd -force 0xff5e0200 1]
rst -system
after 2000
puts [targets]
targets -set -nocase -filter {name =~ "*Cortex-A53 #0*"}
catch {con} result
puts "CON_RESULT $result"
after 20000
puts [targets]
puts [mrd -force 0x80010000 20]
configparams force-mem-access 0
disconnect
exit
