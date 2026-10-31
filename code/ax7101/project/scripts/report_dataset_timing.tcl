set script_dir [file dirname [file normalize [info script]]]
set project_root [file normalize [file join $script_dir ..]]
set checkpoint_file [file join $project_root bitstream \
    AX7101_DUAL_DATASET_UDP_routed.dcp]
set report_dir [file join $project_root reports implementation]
set detail_file [file join $report_dir dataset_gmii_timing.rpt]
set summary_file [file join $report_dir dataset_gmii_timing_summary.txt]

if {![file exists $checkpoint_file]} {
    error "Routed checkpoint does not exist: $checkpoint_file"
}

proc report_group {summary detail_file name direction ports} {
    if {$direction eq "from"} {
        set setup_paths [get_timing_paths -from $ports \
            -delay_type max -max_paths 1 -nworst 1]
        set hold_paths [get_timing_paths -from $ports \
            -delay_type min -max_paths 1 -nworst 1]
        report_timing -from $ports -delay_type max -max_paths 10 \
            -file $detail_file -append
        report_timing -from $ports -delay_type min -max_paths 10 \
            -file $detail_file -append
    } else {
        set setup_paths [get_timing_paths -to $ports \
            -delay_type max -max_paths 1 -nworst 1]
        set hold_paths [get_timing_paths -to $ports \
            -delay_type min -max_paths 1 -nworst 1]
        report_timing -to $ports -delay_type max -max_paths 10 \
            -file $detail_file -append
        report_timing -to $ports -delay_type min -max_paths 10 \
            -file $detail_file -append
    }

    if {[llength $setup_paths] == 0 || [llength $hold_paths] == 0} {
        error "No complete setup/hold path found for $name"
    }

    set setup_slack [get_property SLACK [lindex $setup_paths 0]]
    set hold_slack [get_property SLACK [lindex $hold_paths 0]]
    set line [format "%-9s setup=%7.3f ns  hold=%7.3f ns" \
        $name $setup_slack $hold_slack]
    puts $summary $line
    puts $line

    if {$setup_slack < 0.0 || $hold_slack < 0.0} {
        error "$name timing failed: setup=$setup_slack hold=$hold_slack"
    }
}

file mkdir $report_dir
open_checkpoint $checkpoint_file

set detail [open $detail_file w]
puts $detail "ax7101 dual-dataset GMII detailed routed timing"
close $detail

set summary [open $summary_file w]
puts $summary "ax7101 dual-dataset GMII routed timing summary"
puts $summary "Positive setup and hold slack are required."
puts $summary ""

report_group $summary $detail_file TX_PORT1 to \
    [get_ports {e1_txd[*] e1_txen e1_txer}]
report_group $summary $detail_file TX_PORT2 to \
    [get_ports {e2_txd[*] e2_txen e2_txer}]
report_group $summary $detail_file TX_PORT3 to \
    [get_ports {e3_txd[*] e3_txen e3_txer}]
report_group $summary $detail_file RX_PORT4 from \
    [get_ports {e4_rxd[*] e4_rxdv e4_rxer}]

close $summary
close_design
