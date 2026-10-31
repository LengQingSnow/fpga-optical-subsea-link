set script_dir [file dirname [file normalize [info script]]]
set project_root [file normalize [file join $script_dir ..]]
set project_file [file join $project_root AX7101_DUAL_DATASET_UDP.xpr]
set report_dir [file join $project_root reports synthesis]

file mkdir $report_dir
set_param general.maxThreads 2

open_project $project_file
reset_run synth_1

set ooc_runs [get_runs -filter {IS_SYNTHESIS && NAME != "synth_1"}]
set pending_ooc [list]
foreach run $ooc_runs {
    if {![string match "*Complete*" [get_property STATUS $run]]} {
        reset_run $run
        lappend pending_ooc $run
    }
}
if {[llength $pending_ooc] != 0} {
    launch_runs $pending_ooc -jobs 2
}
foreach run $ooc_runs {
    if {![string match "*Complete*" [get_property STATUS $run]]} {
        wait_on_run $run
    }
}

launch_runs synth_1 -jobs 2
wait_on_run synth_1
set synth_status [get_property STATUS [get_runs synth_1]]
puts "SYNTH_STATUS=$synth_status"
if {![string match "*Complete*" $synth_status]} {
    error "Synthesis failed: $synth_status"
}

open_run synth_1
report_timing_summary -delay_type min_max -report_unconstrained \
    -max_paths 100 -file [file join $report_dir timing_summary.rpt]
report_timing -delay_type max -max_paths 100 -nworst 10 \
    -file [file join $report_dir setup_paths.rpt]
report_clock_interaction -delay_type min_max \
    -file [file join $report_dir clock_interaction.rpt]
report_cdc -details -file [file join $report_dir cdc.rpt]
report_utilization -hierarchical \
    -file [file join $report_dir utilization.rpt]

set setup_path [get_timing_paths -delay_type max -max_paths 1 -nworst 1]
puts "SYNTH_WNS_NS=[get_property SLACK [lindex $setup_path 0]]"
close_project
