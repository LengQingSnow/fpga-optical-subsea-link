set script_dir [file normalize [file dirname [info script]]]
set root_dir [file normalize [file join $script_dir ..]]
set project_dir [file join $root_dir project]
set project_name rf47_prbs31_rrc_8gsps
set output_dir [file join $root_dir output]
set report_dir [file join $root_dir reports final]

file mkdir $output_dir
file mkdir $report_dir

open_project [file join $project_dir ${project_name}.xpr]
set_property STEPS.WRITE_BITSTREAM.ARGS.BIN_FILE true [get_runs impl_1]

reset_run synth_1
launch_runs synth_1 -jobs 1
wait_on_run synth_1
set synth_status [get_property STATUS [get_runs synth_1]]
puts "SYNTH_STATUS $synth_status"
if {![string match "*Complete*" $synth_status]} {
    error "Synthesis failed: $synth_status"
}

open_run synth_1
report_utilization -file [file join $report_dir post_synth_utilization.rpt]
report_timing_summary -file [file join $report_dir post_synth_timing_summary.rpt]

launch_runs impl_1 -to_step write_bitstream -jobs 1
wait_on_run impl_1
set impl_status [get_property STATUS [get_runs impl_1]]
puts "IMPL_STATUS $impl_status"
if {![string match "*Complete*" $impl_status]} {
    error "Implementation failed: $impl_status"
}

open_run impl_1
report_drc -file [file join $report_dir post_route_drc.rpt]
report_utilization -file [file join $report_dir post_route_utilization.rpt]
report_timing_summary -max_paths 20 -report_unconstrained \
    -file [file join $report_dir post_route_timing_summary.rpt]
report_clock_utilization -file [file join $report_dir clock_utilization.rpt]
report_cdc -details -file [file join $report_dir cdc.rpt]
write_checkpoint -force [file join $output_dir ${project_name}_routed.dcp]

set run_dir [get_property DIRECTORY [get_runs impl_1]]
set run_bit [file join $run_dir rf47_prbs_rrc_top.bit]
set run_bin [file join $run_dir rf47_prbs_rrc_top.bin]
if {![file exists $run_bit]} {
    error "Bitstream not found: $run_bit"
}
file copy -force $run_bit [file join $output_dir ${project_name}.bit]
if {[file exists $run_bin]} {
    file copy -force $run_bin [file join $output_dir ${project_name}.bin]
}

write_hw_platform -fixed -include_bit -force \
    -file [file join $output_dir ${project_name}.xsa]

puts "BITSTREAM [file join $output_dir ${project_name}.bit]"
puts "HARDWARE_PLATFORM [file join $output_dir ${project_name}.xsa]"
exit
