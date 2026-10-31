connect -url tcp:127.0.0.1:3121
puts [targets]
targets -set -nocase -filter {name =~ "*Cortex-A53 #0*"}
configparams force-mem-access 1
puts "BOOT_MODE_USER"
puts [mrd -force 0xff5e0200 1]
puts "RUNTIME_REGISTERS"
puts [mrd -force 0x80010000 200]
configparams force-mem-access 0
disconnect
exit
