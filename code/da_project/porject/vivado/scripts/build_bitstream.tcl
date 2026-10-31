set script_dir [file normalize [file dirname [info script]]]
set root_dir [file normalize [file join $script_dir ..]]
set project_dir [file join $root_dir project]
set project_name rf47_qsfp_dpqpsk_rrc_8gsps_runtime_cal
set artifact_name rf47_qsfp_dpqpsk_nrz_8gsps_runtime_cal
set output_dir [file join $root_dir output]
set report_dir [file join $root_dir reports nrz_runtime_cal_final]
set incremental_checkpoint ""

if {[llength $argv] > 0 && [lindex $argv 0] ne ""} {
    set incremental_checkpoint [file normalize [lindex $argv 0]]
    if {![file exists $incremental_checkpoint]} {
        error "Incremental checkpoint not found: $incremental_checkpoint"
    }
}

file mkdir $output_dir
file mkdir $report_dir

open_project [file join $project_dir ${project_name}.xpr]
# The project container retains its legacy name for compatibility, but the
# active pulse-shaping source is now rectangular NRZ with fractional delay.
set nrz_file [file join $root_dir rtl nrz_2sps_parallel32_configurable.sv]
if {[file exists $nrz_file] &&
    ![llength [get_files -quiet $nrz_file]]} {
    add_files -norecurse $nrz_file
    update_compile_order -fileset sources_1
}
# The runtime-calibration project predates the measured TX pre-emphasis RTL.
# Add it explicitly so an existing .xpr cannot silently synthesize the old
# source list after the filter is introduced.
set preemphasis_file [file join $root_dir rtl tx_preemphasis_parallel32.sv]
if {[file exists $preemphasis_file] &&
    ![llength [get_files -quiet $preemphasis_file]]} {
    add_files -norecurse $preemphasis_file
    update_compile_order -fileset sources_1
}
set preemphasis_3tap_file [file join $root_dir rtl tx_preemphasis_3tap_parallel32.sv]
if {[file exists $preemphasis_3tap_file] &&
    ![llength [get_files -quiet $preemphasis_3tap_file]]} {
    add_files -norecurse $preemphasis_3tap_file
    update_compile_order -fileset sources_1
}
foreach stale_preeq_file [get_files -quiet -filter {NAME =~ "*tx_preeq_15tap_parallel32.sv" || NAME =~ "*tx_preeq_9tap_parallel32.sv"}] {
    remove_files $stale_preeq_file
}
set preemphasis_7tap_file [file join $root_dir rtl tx_preeq_7tap_parallel32.sv]
if {[file exists $preemphasis_7tap_file] &&
    ![llength [get_files -quiet $preemphasis_7tap_file]]} {
    add_files -norecurse $preemphasis_7tap_file
    update_compile_order -fileset sources_1
}
set preeq_cdc_file [file join $root_dir rtl preeq_config_cdc.sv]
if {[file exists $preeq_cdc_file] &&
    ![llength [get_files -quiet $preeq_cdc_file]]} {
    add_files -norecurse $preeq_cdc_file
    update_compile_order -fileset sources_1
}
set ber_reference_file [file join $root_dir rtl ber_reference_replay.sv]
if {[file exists $ber_reference_file] &&
    ![llength [get_files -quiet $ber_reference_file]]} {
    add_files -norecurse $ber_reference_file
    update_compile_order -fileset sources_1
}
set idle_rate_matcher_file [file join $root_dir rtl aggregate_idle_frame_dropper.sv]
if {[file exists $idle_rate_matcher_file] &&
    ![llength [get_files -quiet $idle_rate_matcher_file]]} {
    add_files -norecurse $idle_rate_matcher_file
    update_compile_order -fileset sources_1
}
set_property STEPS.WRITE_BITSTREAM.ARGS.BIN_FILE true [get_runs impl_1]

# The imported vendor project can retain an auto-incremental synthesis DCP
# under a stale absolute path. Vivado 2021.2 may crash while mimicking that
# obsolete skeleton, so synthesis is always clean; implementation reuse is
# controlled separately by the optional routed checkpoint argument.
reset_property INCREMENTAL_CHECKPOINT [get_runs synth_1]
set_property AUTO_INCREMENTAL_CHECKPOINT 0 [get_runs synth_1]
foreach utility_dcp [get_files -quiet -of_objects [get_filesets utils_1] \
        -filter {FILE_TYPE == "Design Checkpoint"}] {
    set normalized_dcp [file normalize $utility_dcp]
    if {[string first [string tolower $root_dir] \
            [string tolower $normalized_dcp]] != 0} {
        puts "REMOVE_STALE_SYNTH_DCP $normalized_dcp"
        remove_files $utility_dcp
    }
}

foreach ip_name {aurora_rx_rf47 ila_rf47_qsfp_rx} {
    set ip_run [get_runs -quiet ${ip_name}_synth_1]
    if {[llength $ip_run]} {
        if {![string match "*Complete*" [get_property STATUS $ip_run]]} {
            reset_run $ip_run
            launch_runs $ip_run -jobs 1
            wait_on_run $ip_run
            if {![string match "*Complete*" [get_property STATUS $ip_run]]} {
                error "IP synthesis failed: $ip_name"
            }
        } else {
            puts "IP_SYNTH_REUSED $ip_name"
        }
    }
}

set synth_status [get_property STATUS [get_runs synth_1]]
set synth_needs_refresh [get_property NEEDS_REFRESH [get_runs synth_1]]
puts "SYNTH_NEEDS_REFRESH $synth_needs_refresh"
if {![string match "*Complete*" $synth_status] || $synth_needs_refresh} {
    reset_run synth_1
    launch_runs synth_1 -jobs 1
    wait_on_run synth_1
    set synth_status [get_property STATUS [get_runs synth_1]]
} else {
    puts "SYNTH_REUSED $synth_status"
}
puts "SYNTH_STATUS $synth_status"
if {![string match "*Complete*" $synth_status]} {
    error "Synthesis failed: $synth_status"
}

open_run synth_1
report_utilization -file [file join $report_dir post_synth_utilization.rpt]
report_timing_summary -file [file join $report_dir post_synth_timing_summary.rpt]
close_design

if {$incremental_checkpoint ne ""} {
    set_property INCREMENTAL_CHECKPOINT $incremental_checkpoint [get_runs impl_1]
    puts "INCREMENTAL_CHECKPOINT $incremental_checkpoint"
} else {
    reset_property INCREMENTAL_CHECKPOINT [get_runs impl_1]
}

reset_run impl_1
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
report_incremental_reuse -file [file join $report_dir incremental_reuse.rpt]
report_bus_skew -warn_on_violation -file [file join $report_dir bus_skew.rpt]
check_timing -verbose -file [file join $report_dir check_timing.rpt]

set setup_path [lindex [get_timing_paths -delay_type max -max_paths 1 -nworst 1] 0]
set hold_path [lindex [get_timing_paths -delay_type min -max_paths 1 -nworst 1] 0]
set setup_wns [get_property SLACK $setup_path]
set hold_whs [get_property SLACK $hold_path]
puts "FINAL_SETUP_WNS $setup_wns"
puts "FINAL_HOLD_WHS $hold_whs"
if {$setup_wns < 0.0 || $hold_whs < 0.0} {
    error "Timing closure failed: setup WNS=$setup_wns ns, hold WHS=$hold_whs ns"
}

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
puts "DEBUG_PROBES [file join $output_dir ${artifact_name}.ltx]"
puts "HARDWARE_PLATFORM [file join $output_dir ${artifact_name}.xsa]"
exit
