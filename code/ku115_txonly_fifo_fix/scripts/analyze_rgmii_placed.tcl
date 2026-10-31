set script_dir [file dirname [file normalize [info script]]]
set root_dir [file dirname $script_dir]
set checkpoint [file join $root_dir Sender_KU115.runs impl_1 top_placed.dcp]
set report_name rgmii_stage1
if {$argc >= 1} {
    set checkpoint [file normalize [lindex $argv 0]]
}
if {$argc >= 2} {
    set report_name [lindex $argv 1]
}
set report_dir [file join $root_dir reports $report_name]
file mkdir $report_dir

open_checkpoint $checkpoint
report_clocks -file [file join $report_dir clocks.rpt]
report_clock_networks -file [file join $report_dir clock_networks.rpt]

set placement_file [open [file join $report_dir clock_placement.rpt] w]
puts $placement_file "RGMII clock resource placement"
foreach cell [lsort [get_cells -hierarchical -filter {
    NAME =~ rgmii*_phase_inst/* || NAME =~ rgmii*_rxc_bufg_inst
}]] {
    set loc [get_property -quiet LOC $cell]
    set bel [get_property -quiet BEL $cell]
    set ref [get_property -quiet REF_NAME $cell]
    set region ""
    if {$loc ne ""} {
        set sites [get_sites -quiet $loc]
        if {[llength $sites] > 0} {
            set regions [get_clock_regions -quiet -of_objects $sites]
            if {[llength $regions] > 0} {
                set region [get_property NAME [lindex $regions 0]]
            }
        }
    }
    puts $placement_file [format "%-70s ref=%-12s loc=%-20s bel=%-16s region=%s" \
        $cell $ref $loc $bel $region]
}
close $placement_file

set summary_file [open [file join $report_dir timing_slack_summary.rpt] w]
for {set port 1} {$port <= 4} {incr port} {
    set rx_ports [get_ports [list rgmii${port}_rxd[*] rgmii${port}_rxctl]]
    set setup_paths [get_timing_paths -quiet -from $rx_ports -delay_type max \
        -max_paths 20 -nworst 2]
    set hold_paths [get_timing_paths -quiet -from $rx_ports -delay_type min \
        -max_paths 20 -nworst 2]

    report_timing -from $rx_ports -delay_type max -max_paths 20 -nworst 2 \
        -path_type full_clock_expanded -input_pins \
        -file [file join $report_dir rgmii${port}_rx_setup.rpt]
    report_timing -from $rx_ports -delay_type min -max_paths 20 -nworst 2 \
        -path_type full_clock_expanded -input_pins \
        -file [file join $report_dir rgmii${port}_rx_hold.rpt]

    set setup_slack "NO_PATH"
    set hold_slack "NO_PATH"
    if {[llength $setup_paths] > 0} {
        set setup_slack [get_property SLACK [lindex $setup_paths 0]]
    }
    if {[llength $hold_paths] > 0} {
        set hold_slack [get_property SLACK [lindex $hold_paths 0]]
    }
    puts $summary_file "PORT${port} SETUP_WNS=$setup_slack HOLD_WHS=$hold_slack SETUP_PATHS=[llength $setup_paths] HOLD_PATHS=[llength $hold_paths]"
}
close $summary_file

report_timing -delay_type max -max_paths 20 -nworst 1 \
    -path_type full_clock_expanded \
    -file [file join $report_dir overall_setup.rpt]
report_timing -delay_type min -max_paths 20 -nworst 1 \
    -path_type full_clock_expanded \
    -file [file join $report_dir overall_hold.rpt]

puts "RGMII_PLACED_ANALYSIS_PASS"
close_design
