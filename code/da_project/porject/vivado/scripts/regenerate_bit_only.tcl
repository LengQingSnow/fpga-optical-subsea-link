set script_dir [file normalize [file dirname [info script]]]
set root_dir [file normalize [file join $script_dir ..]]
set project_file [file join $root_dir project rf47_qsfp_dpqpsk_rrc_8gsps_runtime_cal.xpr]
set output_dir [file join $root_dir output]
set artifact_name rf47_qsfp_dpqpsk_nrz_8gsps_runtime_cal

open_project $project_file
set impl_run [get_runs impl_1]
puts "IMPL_STATUS=[get_property STATUS $impl_run]"
puts "IMPL_NEEDS_REFRESH=[get_property NEEDS_REFRESH $impl_run]"
if {![string match "*Complete*" [get_property STATUS $impl_run]]} {
    error "impl_1 is not complete; refusing to launch implementation"
}

open_run impl_1
file mkdir $output_dir
write_bitstream -force -bin_file [file join $output_dir ${artifact_name}.bit]
write_hw_platform -fixed -include_bit -force \
    -file [file join $output_dir ${artifact_name}.xsa]

puts "BITSTREAM=[file join $output_dir ${artifact_name}.bit]"
puts "HARDWARE_PLATFORM=[file join $output_dir ${artifact_name}.xsa]"
close_project
exit
