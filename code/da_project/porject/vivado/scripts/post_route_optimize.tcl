if {[llength $argv] != 3} {
    error "Usage: post_route_optimize.tcl <input_dcp> <candidate_dir> <report_dir>"
}

set input_dcp [file normalize [lindex $argv 0]]
set candidate_dir [file normalize [lindex $argv 1]]
set report_dir [file normalize [lindex $argv 2]]
set design_name rf47_qsfp_dpqpsk_nrz_8gsps_runtime_cal

if {![file exists $input_dcp]} {
    error "Input checkpoint not found: $input_dcp"
}

file mkdir $candidate_dir
file mkdir $report_dir
open_checkpoint $input_dcp
set candidate_base [file join $candidate_dir $design_name]

set initial_setup [get_property SLACK [lindex \
    [get_timing_paths -delay_type max -max_paths 1 -nworst 1] 0]]
set initial_hold [get_property SLACK [lindex \
    [get_timing_paths -delay_type min -max_paths 1 -nworst 1] 0]]
puts "INITIAL_SETUP_WNS $initial_setup"
puts "INITIAL_HOLD_WHS $initial_hold"

phys_opt_design -directive AggressiveExplore
route_design -directive AggressiveExplore

set pass1_setup [get_property SLACK [lindex \
    [get_timing_paths -delay_type max -max_paths 1 -nworst 1] 0]]
set pass1_hold [get_property SLACK [lindex \
    [get_timing_paths -delay_type min -max_paths 1 -nworst 1] 0]]
puts "PASS1_SETUP_WNS $pass1_setup"
puts "PASS1_HOLD_WHS $pass1_hold"
write_checkpoint -force ${candidate_base}_pass1.dcp

if {$pass1_setup < 0.0 || $pass1_hold < 0.0} {
    phys_opt_design -directive AggressiveExplore
    route_design -directive NoTimingRelaxation
    set pass2_setup [get_property SLACK [lindex \
        [get_timing_paths -delay_type max -max_paths 1 -nworst 1] 0]]
    set pass2_hold [get_property SLACK [lindex \
        [get_timing_paths -delay_type min -max_paths 1 -nworst 1] 0]]
    puts "PASS2_SETUP_WNS $pass2_setup"
    puts "PASS2_HOLD_WHS $pass2_hold"
    write_checkpoint -force ${candidate_base}_pass2.dcp
}

report_drc -file [file join $report_dir post_route_opt_drc.rpt]
report_route_status -file [file join $report_dir post_route_opt_route_status.rpt]
report_timing_summary -max_paths 20 -report_unconstrained \
    -file [file join $report_dir post_route_opt_timing_summary.rpt]
report_bus_skew -warn_on_violation \
    -file [file join $report_dir post_route_opt_bus_skew.rpt]

set setup_wns [get_property SLACK [lindex \
    [get_timing_paths -delay_type max -max_paths 1 -nworst 1] 0]]
set hold_whs [get_property SLACK [lindex \
    [get_timing_paths -delay_type min -max_paths 1 -nworst 1] 0]]
puts "FINAL_SETUP_WNS $setup_wns"
puts "FINAL_HOLD_WHS $hold_whs"
if {$setup_wns < 0.0 || $hold_whs < 0.0} {
    error "Post-route timing closure failed: setup WNS=$setup_wns ns, hold WHS=$hold_whs ns"
}

write_checkpoint -force ${candidate_base}_routed.dcp
write_debug_probes -force ${candidate_base}.ltx
write_bitstream -force -bin_file ${candidate_base}.bit
write_hw_platform -fixed -include_bit -force -file ${candidate_base}.xsa

puts "CANDIDATE_BIT ${candidate_base}.bit"
puts "CANDIDATE_DCP ${candidate_base}_routed.dcp"
puts "CANDIDATE_XSA ${candidate_base}.xsa"
exit
