if {$argc < 1} {
    error "usage: vivado -mode batch -source scripts/evaluate_rgmii_phase.tcl -tclargs <phase_degrees>"
}

set phase_degrees [lindex $argv 0]
set input_min_override ""
if {$argc >= 2} {
    set input_min_override [lindex $argv 1]
}
set script_dir [file dirname [file normalize [info script]]]
set root_dir [file dirname $script_dir]
set checkpoint [file join $root_dir Sender_KU115.runs impl_1 top_placed.dcp]
set report_dir [file join $root_dir reports rgmii_phase_eval]
file mkdir $report_dir

open_checkpoint $checkpoint
set pll_cells [get_cells -hierarchical -filter {
    NAME =~ rgmii*_phase_inst/rx_pll_inst
}]
if {[llength $pll_cells] != 4} {
    error "Expected four RGMII PLLs, found [llength $pll_cells]"
}

set_property CLKOUT0_PHASE $phase_degrees $pll_cells
if {$input_min_override ne ""} {
    for {set port 1} {$port <= 4} {incr port} {
        set rx_clock [get_clocks rgmii${port}_rxc]
        set rx_ports [get_ports [list rgmii${port}_rxd[*] rgmii${port}_rxctl]]
        set_input_delay -clock $rx_clock -min $input_min_override $rx_ports
        set_input_delay -clock $rx_clock -clock_fall -min $input_min_override \
            -add_delay $rx_ports
    }
}
update_timing
set report_suffix $phase_degrees
if {$input_min_override ne ""} {
    append report_suffix _min${input_min_override}
}
report_clocks -file [file join $report_dir clocks_${report_suffix}.rpt]

set summary_file [open [file join $report_dir timing_${report_suffix}.rpt] w]
for {set port 1} {$port <= 4} {incr port} {
    set rx_ports [get_ports [list rgmii${port}_rxd[*] rgmii${port}_rxctl]]
    set setup_paths [get_timing_paths -quiet -from $rx_ports -delay_type max \
        -max_paths 20 -nworst 2]
    set hold_paths [get_timing_paths -quiet -from $rx_ports -delay_type min \
        -max_paths 20 -nworst 2]
    set setup_slack [get_property SLACK [lindex $setup_paths 0]]
    set hold_slack [get_property SLACK [lindex $hold_paths 0]]
    puts $summary_file "PORT${port} SETUP_WNS=$setup_slack HOLD_WHS=$hold_slack"
}
close $summary_file

puts "RGMII_PHASE_EVAL_PASS phase=$phase_degrees"
close_design
