set script_dir [file dirname [file normalize [info script]]]
set root_dir [file dirname $script_dir]
set report_dir [file join $root_dir reports]
file mkdir $report_dir
set archive_basename Sender_KU115_qsfp1tx_qsfp2rx_continuous_lane64
if {$argc >= 1} {
    set archive_basename [lindex $argv 0]
}
set release_report_dir [file join $report_dir $archive_basename]
file mkdir $release_report_dir

open_project [file join $root_dir Sender_KU115.xpr]
set_property top top [get_filesets sources_1]
set known_source_files [get_files -quiet -of_objects [get_filesets sources_1]]
foreach source_file [glob -nocomplain [file join $root_dir src *.v]] {
    if {[lsearch -exact $known_source_files [file normalize $source_file]] < 0} {
        add_files -norecurse $source_file
    }
}
update_compile_order -fileset sources_1

set ooc_runs {}
foreach ip_name {aurora_tx_qsfp1 aurora_rx_qsfp2 ila_qsfp_loop ila_aggregate_stats} {
    set run_name ${ip_name}_synth_1
    if {[llength [get_runs -quiet $run_name]] == 0} {
        create_ip_run [get_ips $ip_name]
    }
    reset_run [get_runs $run_name]
    lappend ooc_runs [get_runs $run_name]
}
launch_runs $ooc_runs -jobs 8
foreach ooc_run $ooc_runs {
    wait_on_run $ooc_run
    if {[get_property STATUS $ooc_run] ne "synth_design Complete!"} {
        error "IP synthesis failed for [get_property NAME $ooc_run]: [get_property STATUS $ooc_run]"
    }
}

# A changed clocking-wizard configuration is not safe to stitch into the old
# synthesis checkpoint in Vivado 2021.2.  Build releases from the current RTL
# and IP products; the RGMII clock resources remain fixed by ethernet.xdc.
set_property AUTO_INCREMENTAL_CHECKPOINT 0 [get_runs synth_1]
reset_property INCREMENTAL_CHECKPOINT [get_runs synth_1]
if {[get_property INCREMENTAL_CHECKPOINT [get_runs synth_1]] ne ""} {
    error "synth_1 still has an incremental checkpoint configured"
}
reset_run synth_1
launch_runs synth_1 -jobs 8
wait_on_run synth_1
if {[get_property STATUS [get_runs synth_1]] ne "synth_design Complete!"} {
    error "Synthesis failed: [get_property STATUS [get_runs synth_1]]"
}

launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_run impl_1
if {[get_property STATUS [get_runs impl_1]] ne "write_bitstream Complete!"} {
    error "Implementation failed: [get_property STATUS [get_runs impl_1]]"
}

open_run impl_1
report_route_status -file [file join $report_dir route_status.rpt]
report_drc -file [file join $report_dir drc.rpt]
report_timing_summary -delay_type min_max -report_unconstrained -check_timing_verbose \
    -file [file join $report_dir timing_summary.rpt]
report_clock_interaction -file [file join $report_dir clock_interaction.rpt]
report_cdc -details -file [file join $report_dir cdc.rpt]
check_timing -verbose -file [file join $report_dir check_timing.rpt]
report_bus_skew -file [file join $report_dir bus_skew.rpt]
report_utilization -file [file join $report_dir utilization.rpt]

set feedback_bufgs [get_cells -hierarchical -filter {
    NAME =~ rgmii*_phase_inst/feedback_bufg_inst
}]
if {[llength $feedback_bufgs] != 4} {
    error "Expected four preserved RGMII feedback BUFGs, found [llength $feedback_bufgs]"
}

set rgmii_summary [open [file join $release_report_dir rgmii_timing_summary.rpt] w]
for {set port 1} {$port <= 4} {incr port} {
    set rx_ports [get_ports [list rgmii${port}_rxd[*] rgmii${port}_rxctl]]
    set setup_paths [get_timing_paths -quiet -from $rx_ports -delay_type max \
        -max_paths 20 -nworst 2]
    set hold_paths [get_timing_paths -quiet -from $rx_ports -delay_type min \
        -max_paths 20 -nworst 2]
    if {[llength $setup_paths] == 0 || [llength $hold_paths] == 0} {
        error "RGMII port $port has missing setup or hold timing paths"
    }

    set setup_slack [get_property SLACK [lindex $setup_paths 0]]
    set hold_slack [get_property SLACK [lindex $hold_paths 0]]
    puts $rgmii_summary "PORT${port} SETUP_WNS=$setup_slack HOLD_WHS=$hold_slack"

    report_timing -from $rx_ports -delay_type max -max_paths 20 -nworst 2 \
        -path_type full_clock_expanded -input_pins \
        -file [file join $release_report_dir rgmii${port}_rx_setup.rpt]
    report_timing -from $rx_ports -delay_type min -max_paths 20 -nworst 2 \
        -path_type full_clock_expanded -input_pins \
        -file [file join $release_report_dir rgmii${port}_rx_hold.rpt]

    if {$setup_slack < 0.0 || $hold_slack < 0.0} {
        error "RGMII port $port timing failed: setup=$setup_slack hold=$hold_slack"
    }
}
close $rgmii_summary

set placement_file [open [file join $release_report_dir rgmii_clock_placement.rpt] w]
foreach cell [lsort [get_cells -hierarchical -filter {
    NAME =~ rgmii*_phase_inst/* || NAME =~ rgmii*_rxc_bufg_inst
}]] {
    set loc [get_property -quiet LOC $cell]
    set ref [get_property -quiet REF_NAME $cell]
    if {$loc ne ""} {
        puts $placement_file "$cell REF_NAME=$ref LOC=$loc"
    }
}
close $placement_file

set failing_setup [get_timing_paths -quiet -delay_type max -slack_lesser_than 0 -max_paths 1]
set failing_hold [get_timing_paths -quiet -delay_type min -slack_lesser_than 0 -max_paths 1]
if {[llength $failing_setup] > 0 || [llength $failing_hold] > 0} {
    error "Timing failed: setup_paths=[llength $failing_setup], hold_paths=[llength $failing_hold]"
}

foreach report_name {
    route_status.rpt drc.rpt timing_summary.rpt clock_interaction.rpt
    cdc.rpt check_timing.rpt bus_skew.rpt utilization.rpt
} {
    file copy -force [file join $report_dir $report_name] \
        [file join $release_report_dir $report_name]
}

set checkpoint_dir [file join $root_dir checkpoints]
file mkdir $checkpoint_dir
write_checkpoint -force [file join $checkpoint_dir ${archive_basename}_routed.dcp]

set bit_src [file join $root_dir Sender_KU115.runs impl_1 top.bit]
set ltx_src [file join $root_dir Sender_KU115.runs impl_1 top.ltx]
file copy -force $bit_src [file join $root_dir bit_archive ${archive_basename}.bit]
if {[file exists $ltx_src]} {
    file copy -force $ltx_src [file join $root_dir bit_archive ${archive_basename}.ltx]
}
close_project
