set script_dir [file dirname [file normalize [info script]]]
set root_dir [file dirname $script_dir]

puts "ARGC=$argc"
puts "ARGV=$argv"

if {$argc < 4} {
    error "Usage: generate_rgmii_idelay_candidates.tcl <routed.dcp> <port 1..4> <delay_csv_ps> <dry_run 0|1>"
}

set checkpoint [file normalize [lindex $argv 0]]
set port [lindex $argv 1]
set dry_run [lindex $argv end]
set delay_values [list]
foreach delay_arg [lrange $argv 2 end-1] {
    foreach delay [split $delay_arg ,] {
        lappend delay_values $delay
    }
}

if {![file exists $checkpoint]} {
    error "Routed checkpoint not found: $checkpoint"
}
if {![string is integer -strict $port] || $port < 1 || $port > 4} {
    error "Port must be an integer from 1 through 4"
}
if {$dry_run ne "0" && $dry_run ne "1"} {
    error "dry_run must be 0 or 1"
}

if {[llength $delay_values] == 0} {
    error "At least one delay value is required"
}
foreach delay $delay_values {
    if {![string is integer -strict $delay] || $delay < 0 || $delay > 1250} {
        error "IDELAY value must be an integer from 0 through 1250 ps: $delay"
    }
}

open_checkpoint $checkpoint

set all_idelay_cells [get_cells -hierarchical -filter {REF_NAME == IDELAYE3}]
set port_idelay_cells [list]
foreach cell $all_idelay_cells {
    if {[string match "eth${port}/*" $cell]} {
        lappend port_idelay_cells $cell
    }
}

puts "TOTAL_IDELAY_CELLS=[llength $all_idelay_cells]"
puts "PORT_IDELAY_CELLS=[llength $port_idelay_cells]"
puts "PORT_IDELAY_CELL_NAMES=[join [lsort $port_idelay_cells] ,]"
puts "PORT_INITIAL_DELAY_VALUES=[join [lsort -unique [get_property DELAY_VALUE $port_idelay_cells]] ,]"
puts "CANDIDATE_VALUES=[join $delay_values ,]"

if {[llength $all_idelay_cells] != 20} {
    error "Expected 20 RGMII IDELAYE3 cells, found [llength $all_idelay_cells]"
}
if {[llength $port_idelay_cells] != 5} {
    error "Expected five IDELAYE3 cells for port $port, found [llength $port_idelay_cells]"
}

if {$dry_run} {
    puts "DRY_RUN_COMPLETE"
    close_design
    exit 0
}

set output_dir [file join $root_dir bit_archive rgmii_calibration]
file mkdir $output_dir
set manifest_path [file join $root_dir reports rgmii_idelay_candidates_manifest.txt]
set manifest [open $manifest_path w]
puts $manifest "SOURCE_CHECKPOINT=$checkpoint"
puts $manifest "PORT=$port"
puts $manifest "PORT_CELLS=[join [lsort $port_idelay_cells] ,]"
puts $manifest "CANDIDATE_VALUES_PS=[join $delay_values ,]"

foreach delay $delay_values {
    set_property DELAY_VALUE $delay $port_idelay_cells
    set delay_tag [format %04d $delay]
    set basename "Sender_KU115_rgmii_port${port}_idelay_${delay_tag}ps"
    set bit_path [file join $output_dir ${basename}.bit]
    write_bitstream -force $bit_path
    puts $manifest "CANDIDATE=$delay,$bit_path"
    puts "GENERATED_CANDIDATE=$delay,$bit_path"
}

close $manifest
puts "MANIFEST=$manifest_path"
puts "GENERATION_COMPLETE"
close_design
