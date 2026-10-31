set script_dir [file dirname [file normalize [info script]]]
set project_root [file normalize [file join $script_dir ..]]
set checkpoint [file join $project_root \
    AX7101_DUAL_DATASET_UDP.runs impl_1 ax7101_dataset_top_placed.dcp]
set report_file [file join $project_root reports placed_timing_debug.rpt]

open_checkpoint $checkpoint
report_timing -delay_type max -max_paths 20 -nworst 20 \
    -path_type full -file $report_file
puts "PLACED_TIMING_REPORT=$report_file"
