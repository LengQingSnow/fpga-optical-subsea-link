set control_base 0x80010000

proc read_word {address} {
    set raw_text [mrd -force $address]
    set hex_value [string range $raw_text end-8 end]
    return [expr "0x$hex_value"]
}

connect -url tcp:127.0.0.1:3121
configparams force-mem-access 1
targets -set -nocase -filter {name =~ "*Cortex-A53 #0*"}
set mask [expr {[read_word [expr {$control_base + 4 * 47}]] & 0xf}]
set commit [expr {[read_word [expr {$control_base + 4 * 48}]] & 1}]
puts [format "PREEQ_MASK 0x%X" $mask]
puts "PREEQ_COMMIT_TOGGLE $commit"
for {set component 0} {$component < 4} {incr component} {
    set values {}
    for {set tap 0} {$tap < 7} {incr tap} {
        set index [expr {$component * 7 + $tap}]
        set word_index [expr {19 + $index}]
        set value [expr {[read_word [expr {$control_base + 4 * $word_index}]] & 0xffff}]
        if {$value >= 32768} {
            set value [expr {$value - 65536}]
        }
        lappend values $value
    }
    puts "COMPONENT${component}_Q15 $values"
}
configparams force-mem-access 0
disconnect
exit
