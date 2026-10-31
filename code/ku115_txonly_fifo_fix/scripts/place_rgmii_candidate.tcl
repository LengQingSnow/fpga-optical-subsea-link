set script_dir [file dirname [file normalize [info script]]]
set root_dir [file dirname $script_dir]
set report_dir [file join $root_dir reports rgmii_stage2]
file mkdir $report_dir

open_project [file join $root_dir Sender_KU115.xpr]
set_property top top [get_filesets sources_1]

set known_source_files [get_files -quiet -of_objects [get_filesets sources_1]]
foreach source_file [glob -nocomplain [file join $root_dir src *.v]] {
    if {[lsearch -exact $known_source_files [file normalize $source_file]] < 0} {
        add_files -norecurse $source_file
    }
}
update_compile_order -fileset sources_1

reset_property AUTO_INCREMENTAL_CHECKPOINT [get_runs synth_1]
reset_run synth_1
launch_runs synth_1 -jobs 8
wait_on_run synth_1
if {[get_property STATUS [get_runs synth_1]] ne "synth_design Complete!"} {
    error "Synthesis failed: [get_property STATUS [get_runs synth_1]]"
}

launch_runs impl_1 -to_step place_design -jobs 8
wait_on_run impl_1
set impl_status [get_property STATUS [get_runs impl_1]]
set placed_run_checkpoint [file join $root_dir Sender_KU115.runs impl_1 top_placed.dcp]
if {![file exists $placed_run_checkpoint]} {
    error "Placement failed: $impl_status"
}

open_run impl_1
set feedback_bufgs [get_cells -hierarchical -filter {
    NAME =~ rgmii*_phase_inst/feedback_bufg_inst
}]
puts "RGMII_FEEDBACK_BUFG_COUNT=[llength $feedback_bufgs]"
if {[llength $feedback_bufgs] != 4} {
    error "Expected four preserved RGMII feedback BUFGs, found [llength $feedback_bufgs]"
}

set placed_checkpoint [file join $report_dir rgmii_stage2_placed.dcp]
write_checkpoint -force $placed_checkpoint
report_timing_summary -delay_type min_max -report_unconstrained \
    -check_timing_verbose -file [file join $report_dir timing_summary_placed.rpt]
puts "RGMII_STAGE2_PLACEMENT_PASS checkpoint=$placed_checkpoint"
close_project
