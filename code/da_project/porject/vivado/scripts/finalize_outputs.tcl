set script_dir [file normalize [file dirname [info script]]]
set root_dir [file normalize [file join $script_dir ..]]
set project_name rf47_qsfp_dpqpsk_rrc_8gsps_runtime_cal
set artifact_name rf47_qsfp_dpqpsk_nrz_8gsps_runtime_cal
set project_file [file join $root_dir project ${project_name}.xpr]
set output_dir [file join $root_dir output]
set report_dir [file join $root_dir reports nrz_runtime_cal_final]

file mkdir $output_dir
file mkdir $report_dir
open_project $project_file
open_run impl_1

report_drc -file [file join $report_dir post_route_drc.rpt]
report_utilization -file [file join $report_dir post_route_utilization.rpt]
report_timing_summary -max_paths 20 -report_unconstrained \
    -file [file join $report_dir post_route_timing_summary.rpt]
report_clock_utilization -file [file join $report_dir clock_utilization.rpt]
report_cdc -details -file [file join $report_dir cdc.rpt]
write_checkpoint -force [file join $output_dir ${artifact_name}_routed.dcp]
write_debug_probes -force [file join $output_dir ${artifact_name}.ltx]

set run_dir [get_property DIRECTORY [get_runs impl_1]]
set run_bit [file join $run_dir rf47_qsfp_dpqpsk_top.bit]
set run_bin [file join $run_dir rf47_qsfp_dpqpsk_top.bin]
if {![file exists $run_bit]} {
    error "Bitstream not found: $run_bit"
}
file copy -force $run_bit [file join $output_dir ${artifact_name}.bit]
if {[file exists $run_bin]} {
    file copy -force $run_bin [file join $output_dir ${artifact_name}.bin]
}
write_hw_platform -fixed -include_bit -force \
    -file [file join $output_dir ${artifact_name}.xsa]

puts "BITSTREAM [file join $output_dir ${artifact_name}.bit]"
puts "HARDWARE_PLATFORM [file join $output_dir ${artifact_name}.xsa]"
exit
