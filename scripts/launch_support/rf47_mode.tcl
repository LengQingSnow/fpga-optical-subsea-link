# Runtime-only controls. Does not program BIT/ELF or modify flash.
proc reg {i} {return [expr {[lindex [mrd -force -value [expr {0x80010000+4*$i}] 1] 0] & 0xffffffff}]}
proc put {i value} {mwr -force [expr {0x80010000+4*$i}] $value}
proc verify {condition message} {if {![uplevel 1 [list expr $condition]]} {error $message}}
proc source_mode {mode} {
    if {[reg 6] != $mode} {put 1 0; after 20; put 6 $mode; after 20; put 1 1; after 500}
    verify {[reg 6]==$mode && [reg 1]==1} "Source/start readback failed"
}
if {[catch {
    set command [lindex $argv 0]
    if {$command ni {check-long square long info delays}} {error "Unknown runtime command"}
    if {$command eq "delays"} {
        if {[llength $argv]!=9} {error "Eight delay codes required"}
        foreach n [lrange $argv 1 end] {if {![string is integer -strict $n] || $n<0 || $n>127} {error "Delay code outside 0..127"}}
    } elseif {[llength $argv]!=1} {error "Unexpected arguments"}
    connect -url tcp:127.0.0.1:3121
    configparams force-mem-access 1
    targets -set -nocase -filter {name =~ "*Cortex-A53 #0*"}
    verify {[reg 0]==0x52463437 && [reg 3]==1 && [reg 7]==1} "RF47 identity/clock/init check failed"
    if {$command in {check-long square long}} {
        verify {[reg 196]==0x5052424c && [reg 197]==262144 && [reg 202]==0x10000009} "Wrong BIT: validated 262144-symbol long-PRBS firmware required. No automatic RF47 programming."
    }
    set before {}
    for {set k 10} {$k<18} {incr k} {lappend before [reg $k]}
    switch -- $command {
        check-long {puts "LONG_FIRMWARE_VERIFIED 262144 symbols/lane"}
        square {
            put 65 0; after 100
            verify {([reg 65]&2)==0 && ([reg 66]&2)==0} "Replay did not stop"
            source_mode 1
            puts "SQUARE_MODE_VERIFIED"
        }
        delays {
            verify {[reg 6]==1 && ([reg 65]&2)==0} "Delay writes require square mode with replay off"
            for {set k 0} {$k<8} {incr k} {put [expr {10+$k}] [lindex $argv [expr {$k+1}]]}
            put 18 1; after 50; put 18 1; after 50
            for {set k 0} {$k<8} {incr k} {
                verify {[reg [expr {10+$k}]]==[lindex $argv [expr {$k+1}]]} "Delay register readback mismatch"
            }
            puts "EIGHT_DELAY_REGISTERS_VERIFIED"
        }
        long {
            put 65 0; after 100
            source_mode 0
            put 65 3
            after 100
            # Word 65 bit 0 is a toggle, not a writable level. The existing
            # MATLAB reader expects toggle=1 as well as replay_enable=1.
            # A second arm may be needed after square-mode calibration.
            if {[reg 65]==2} {put 65 3; after 100}
            set ready 0
            for {set k 0} {$k<500} {incr k} {if {[reg 66]==3} {set ready 1;break};after 10}
            verify {$ready && [reg 65]==3 && [reg 67]==64} "Long PRBS did not become ready"
            puts "LONG_PRBS_VERIFIED period=262144; GUI verifies seed and live DA prefix"
        }
        info {
            put 65 0; after 100
            source_mode 0
            verify {([reg 65]&2)==0 && ([reg 66]&2)==0} "Replay still enabled"
            puts "QSFP_INFORMATION_VERIFIED replay=OFF"
        }
    }
    if {$command ne "delays"} {
        for {set k 0} {$k<8} {incr k} {verify {[reg [expr {10+$k}]]==[lindex $before $k]} "Mode switch changed lane delay"}
    }
    foreach i {1 3 6 7 10 11 12 13 14 15 16 17 65 66} {puts [format "RF47_REG %d %08X" $i [reg $i]]}
    configparams force-mem-access 0
    disconnect
    puts "RF47_STEP_OK $command"
} problem]} {
    puts stderr "RF47_CONTROL_ERROR: $problem"
    catch {configparams force-mem-access 0}
    catch {disconnect}
    exit 1
}
exit 0
