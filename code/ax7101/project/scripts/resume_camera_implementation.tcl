set script_dir [file dirname [file normalize [info script]]]
set project_root [file normalize [file join $script_dir ..]]
set project_name AX7101_DUAL_DATASET_UDP
set report_dir [file join $project_root reports implementation]
set bit_dir [file join $project_root bitstream]
file mkdir $report_dir
file mkdir $bit_dir

open_project [file join $project_root ${project_name}.xpr]
set_param general.maxThreads 2
reset_run impl_1
launch_runs impl_1 -to_step write_bitstream -jobs 2
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
report_utilization -hierarchical \
    -file [file join $report_dir utilization.rpt]
report_clock_interaction -delay_type min_max \
    -file [file join $report_dir clock_interaction.rpt]
check_timing -verbose -file [file join $report_dir check_timing.rpt]
report_cdc -details -file [file join $report_dir cdc.rpt]

set setup_paths [get_timing_paths -delay_type max -max_paths 1 -nworst 1]
set hold_paths [get_timing_paths -delay_type min -max_paths 1 -nworst 1]
set wns [get_property SLACK [lindex $setup_paths 0]]
set whs [get_property SLACK [lindex $hold_paths 0]]
puts "WNS_NS=$wns"
puts "WHS_NS=$whs"
if {$wns < 0.0 || $whs < 0.0} {
    error "Routed timing failed: WNS=$wns ns WHS=$whs ns"
}

set bit_file [file join $bit_dir AX7101_DUAL_CAMERA_VGA_UDP.bit]
set probes_file [file join $bit_dir AX7101_DUAL_CAMERA_VGA_UDP.ltx]
set checkpoint_file [file join $bit_dir \
    AX7101_DUAL_CAMERA_VGA_UDP_routed.dcp]
write_bitstream -force $bit_file
write_debug_probes -force $probes_file
write_checkpoint -force $checkpoint_file
puts "BIT_FILE=$bit_file"
puts "PROBES_FILE=$probes_file"
puts "CHECKPOINT_FILE=$checkpoint_file"
close_project
