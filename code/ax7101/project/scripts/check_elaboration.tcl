set script_dir [file dirname [file normalize [info script]]]
set project_root [file normalize [file join $script_dir ..]]
open_project [file join $project_root AX7101_DUAL_DATASET_UDP.xpr]
update_compile_order -fileset sources_1
synth_design -rtl -name rtl_1
report_utilization -file [file join $project_root reports camera_elaboration_utilization.rpt]
puts "ELABORATION_PASS"
close_project
