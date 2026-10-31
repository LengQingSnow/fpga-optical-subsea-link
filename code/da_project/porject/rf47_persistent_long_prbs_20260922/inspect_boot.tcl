connect -url tcp:127.0.0.1:3121
puts [targets]
targets -set -nocase -filter {name =~ "*PSU*"}
configparams force-mem-access 1
foreach addr {0xff5e0200 0xff5e0204 0xffd80044 0xffca0010} {
 puts [format "BOOT_DIAG %08X" $addr]
 puts [mrd -force $addr 1]
}
puts [mrd -force 0x80010000 20]
configparams force-mem-access 0
disconnect
exit
