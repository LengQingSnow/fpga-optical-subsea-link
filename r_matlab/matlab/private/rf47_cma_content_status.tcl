# Read-only: no mode changes, reference arming, resets, or CPU halt.
if {[catch {
connect -url tcp:127.0.0.1:3121
configparams force-mem-access 1
targets -set -nocase -filter {name =~ "*Cortex-A53 #0*"}
foreach index {3 6 7 65 66} {
  set value [lindex [mrd -force -value [expr {0x80010000+4*$index}] 1] 0]
  puts [format "CMA_INFO_REG %d %08X" $index [expr {$value & 0xffffffff}]]
}
configparams force-mem-access 0
disconnect
} problem]} {
  puts stderr "RF47_INFORMATION_READ_ERROR: $problem"
  catch {disconnect}
  exit 1
}
exit 0
