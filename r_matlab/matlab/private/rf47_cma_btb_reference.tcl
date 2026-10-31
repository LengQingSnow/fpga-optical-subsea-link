# Read-only audit, never restarts the generator or halts firmware.
if {[catch {
connect -url tcp:127.0.0.1:3121
configparams force-mem-access 1
targets -set -nocase -filter {name =~ "*Cortex-A53 #0*"}
proc reg {index} {
  set values [mrd -force -value [expr {0x80010000+4*$index}] 1]
  return [expr {[lindex $values 0] & 0xffffffff}]
}
if {[reg 196] != 0x5052424c || [reg 197] != 262144} { error "Not the long PRBS test build" }
if {[reg 66] != 3 || ([reg 65]&2)==0} { error "Long PRBS not active" }
foreach index {3 6 7 9 10 11 12 13 14 15 16 17 47 64 65 66 67 196 197 198 199 200 201 202 203} {
  puts [format "LONG_REG %d %08X" $index [reg $index]]
}
set prefix [mrd -force -value 0x80010110 128]
if {[llength $prefix] != 128} { error "Incomplete DA prefix read" }
for {set k 0} {$k<128} {incr k} {
  puts [format "BER_REF_DWORD %d 0x%08X" $k [expr {[lindex $prefix $k] & 0xffffffff}]]
}
disconnect
} problem]} {
  puts stderr "RF47_READ_ONLY_ERROR: $problem"
  catch {disconnect}
  exit 1
}
exit
