set script_dir [file dirname [file normalize [info script]]]
set project_root [file normalize [file join $script_dir ..]]
set project_name AX7101_DUAL_DATASET_UDP
set project_file [file join $project_root ${project_name}.xpr]
set report_dir [file join $project_root reports implementation]
set bit_dir [file join $project_root bitstream]

if {![file exists $project_file]} {
    error "Project does not exist: $project_file"
}

file mkdir $report_dir
file mkdir $bit_dir
set build_jobs 2
set_param general.maxThreads $build_jobs

open_project $project_file
set synth_run [get_runs synth_1]
set stale_incremental_files [get_files -quiet -all \
    *utils_1/imports/synth_1/ax7101_dataset_top.dcp]
if {[llength $stale_incremental_files] != 0} {
    remove_files $stale_incremental_files
}
set_property AUTO_INCREMENTAL_CHECKPOINT 0 $synth_run
set_property INCREMENTAL_CHECKPOINT {} $synth_run
reset_run synth_1

set ooc_runs [get_runs -filter {IS_SYNTHESIS && NAME != "synth_1"}]
set ooc_runs_to_launch [list]
foreach run $ooc_runs {
    set run_status [get_property STATUS $run]
    if {![string match "*Complete*" $run_status]} {
        reset_run $run
        lappend ooc_runs_to_launch $run
    }
}
if {[llength $ooc_runs_to_launch] != 0} {
    launch_runs $ooc_runs_to_launch -jobs $build_jobs
}
if {[llength $ooc_runs] != 0} {
    foreach run $ooc_runs {
        if {![string match "*Complete*" [get_property STATUS $run]]} {
            wait_on_run $run
        }
        set run_status [get_property STATUS $run]
        puts "OOC_STATUS_[get_property NAME $run]=$run_status"
        if {![string match "*Complete*" $run_status]} {
            error "OOC synthesis failed for [get_property NAME $run]: $run_status"
        }
    }
}

launch_runs synth_1 -jobs $build_jobs
wait_on_run synth_1

set synth_status [get_property STATUS [get_runs synth_1]]
puts "SYNTH_STATUS=$synth_status"
if {![string match "*Complete*" $synth_status]} {
    error "Synthesis did not complete successfully: $synth_status"
}

launch_runs impl_1 -to_step write_bitstream -jobs $build_jobs
wait_on_run impl_1

set impl_status [get_property STATUS [get_runs impl_1]]
puts "IMPL_STATUS=$impl_status"
if {![string match "*Complete*" $impl_status]} {
    error "Implementation did not complete successfully: $impl_status"
}

open_run impl_1

report_timing_summary -delay_type min_max -report_unconstrained \
    -max_paths 50 -file [file join $report_dir timing_summary.rpt]
report_route_status -file [file join $report_dir route_status.rpt]
report_drc -file [file join $report_dir drc.rpt]
report_utilization -hierarchical -file [file join $report_dir utilization.rpt]
report_clock_interaction -delay_type min_max \
    -file [file join $report_dir clock_interaction.rpt]
check_timing -verbose -file [file join $report_dir check_timing.rpt]
report_cdc -details -file [file join $report_dir cdc.rpt]

set setup_paths [get_timing_paths -delay_type max -max_paths 1 -nworst 1]
set hold_paths [get_timing_paths -delay_type min -max_paths 1 -nworst 1]
if {[llength $setup_paths] == 0 || [llength $hold_paths] == 0} {
    error "Unable to obtain routed setup/hold timing paths"
}
set wns [get_property SLACK [lindex $setup_paths 0]]
set whs [get_property SLACK [lindex $hold_paths 0]]
puts "WNS_NS=$wns"
puts "WHS_NS=$whs"
if {$wns < 0.0 || $whs < 0.0} {
    error "Routed timing failed: WNS=$wns ns WHS=$whs ns"
}

set bit_file [file join $bit_dir ${project_name}.bit]
set probes_file [file join $bit_dir ${project_name}.ltx]
set checkpoint_file [file join $bit_dir ${project_name}_routed.dcp]
write_bitstream -force $bit_file
write_debug_probes -force $probes_file
write_checkpoint -force $checkpoint_file

puts "BIT_FILE=$bit_file"
puts "PROBES_FILE=$probes_file"
puts "CHECKPOINT_FILE=$checkpoint_file"
close_project
