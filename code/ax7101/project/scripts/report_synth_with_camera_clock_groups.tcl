set script_dir [file dirname [file normalize [info script]]]
set project_root [file normalize [file join $script_dir ..]]

open_project [file join $project_root AX7101_DUAL_DATASET_UDP.xpr]
open_run synth_1

set_clock_groups -asynchronous \
    -group [get_clocks cmos1_pixel_clk] \
    -group [get_clocks cmos2_pixel_clk] \
    -group [get_clocks e1_rx_clk] \
    -group [get_clocks e2_rx_clk] \
    -group [get_clocks e3_rx_clk] \
    -group [get_clocks e4_rx_clk]

set report_dir [file join $project_root reports synthesis]
report_timing_summary -delay_type min_max -report_unconstrained \
    -max_paths 100 -file [file join $report_dir timing_summary_clock_groups.rpt]
report_timing -delay_type max -max_paths 100 -nworst 10 \
    -file [file join $report_dir setup_paths_clock_groups.rpt]

set setup_path [get_timing_paths -delay_type max -max_paths 1 -nworst 1]
puts "CONSTRAINED_SYNTH_WNS_NS=[get_property SLACK [lindex $setup_path 0]]"
close_project
