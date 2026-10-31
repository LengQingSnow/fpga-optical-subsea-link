set control_base 0x80010000

connect -url tcp:127.0.0.1:3121
configparams force-mem-access 1
targets -set -nocase -filter {name =~ "*Cortex-A53 #0*"}
catch {stop}

puts "SDR_INFO"
puts [mrd $control_base 1]
puts "MTIME_START"
puts [mrd [expr {$control_base + 4}] 1]
puts "MMCM_LOCKED"
puts [mrd [expr {$control_base + 12}] 1]
puts "RF_MODE"
puts [mrd [expr {$control_base + 24}] 1]
puts "CONFIG_DONE"
puts [mrd [expr {$control_base + 28}] 1]
puts "RUNTIME_STATUS"
puts [mrd [expr {$control_base + 36}] 1]
for {set lane 0} {$lane < 8} {incr lane} {
    puts "TX${lane}_DELAY"
    puts [mrd [expr {$control_base + 40 + 4 * $lane}] 1]
}
puts "DELAY_COMMIT_TOGGLE"
puts [mrd [expr {$control_base + 72}] 1]
puts "FW_VERSION"
puts [mrd [expr {$control_base + 256}] 1]
for {set tile 0} {$tile < 4} {incr tile} {
    set tile_base [expr {0x80040000 + 0x4000 + 0x4000 * $tile}]
    puts "DAC_TILE${tile}_CURRENT_STATE"
    puts [mrd [expr {$tile_base + 0x0C}] 1]
    puts "DAC_TILE${tile}_STATUS"
    puts [mrd [expr {$tile_base + 0x228}] 1]
    foreach block {0 2} {
        set block_base [expr {0x80040000 + 0x6000 + 0x4000 * $tile + 0x400 * $block}]
        puts "DAC_TILE${tile}_BLOCK${block}_CLK_ENABLE"
        puts [mrd $block_base 1]
        puts "DAC_TILE${tile}_BLOCK${block}_FIFO_ISR"
        puts [mrd [expr {$block_base + 0x14}] 1]
        puts "DAC_TILE${tile}_BLOCK${block}_FIFO_IMR"
        puts [mrd [expr {$block_base + 0x18}] 1]
    }
}

con
configparams force-mem-access 0
disconnect
exit
