connect -url tcp:127.0.0.1:3121
puts [targets]
targets -set -nocase -filter {name =~ "*PSU*"}
configparams force-mem-access 1
# program_flash leaves the alternate boot selector in JTAG (0x100).
# Select QSPI32 for this reset; no BIT/ELF download is performed.
mwr -force 0xff5e0200 0x2100
puts "RESET_ONLY_QSPI_BOOT_NO_DOWNLOAD"
rst -system
after 30000
targets -set -nocase -filter {name =~ "*Cortex-A53 #0*"}
configparams force-mem-access 1
proc reg {index} {return [expr {[lindex [mrd -force -value [expr {0x80010000+4*$index}] 1] 0] & 0xffffffff}]}
puts "BOOT_MODE_USER"
puts [mrd -force 0xff5e0200 2]
foreach i {0 1 3 6 7 9 10 11 12 13 14 15 16 17 47 64 65 66 196 197} {puts [format "FLASH_BOOT_REG %d %08X" $i [reg $i]]}
if {[reg 0]!=0x52463437 || [reg 196]!=0x5052424c || [reg 197]!=262144} {error "Flash firmware signature mismatch"}
if {[reg 1]!=1 || [reg 3]!=1 || [reg 7]!=1 || [reg 6]!=0 || [reg 65]!=3 || [reg 66]!=3 || [reg 47]!=0} {error "Flash startup state mismatch"}
set expected {54 65 61 59 20 24 3 4}
for {set i 0} {$i<8} {incr i} {if {[reg [expr {10+$i}]]!=[lindex $expected $i]} {error "Delay mismatch"}}
puts "QSPI_BOOT_LONG_PRBS_VERIFIED"
configparams force-mem-access 0
disconnect
exit
