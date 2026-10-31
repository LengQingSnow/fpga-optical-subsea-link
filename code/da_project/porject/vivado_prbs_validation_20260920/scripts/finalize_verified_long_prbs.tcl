set root [file normalize [file join [file dirname [info script]] ..]]
set checkpoint [file join $root project rf47_qsfp_dpqpsk_rrc_8gsps_runtime_cal.runs impl_1 rf47_qsfp_dpqpsk_top_routed.dcp]
set report [file join $root reports verified_long_prbs]
set output [file join $root output rf47_prbs31_fragment262144_nrz_validation]
file mkdir $report
open_checkpoint $checkpoint
source [file join $root constraints verified_analog_pins.xdc]
report_io -file [file join $report pins.rpt]
report_drc -file [file join $report drc.rpt]
set bad [get_drc_violations -quiet -filter {SEVERITY == Error || SEVERITY == "Critical Warning"}]
if {[llength $bad]} {error "Unresolved DRC: $bad"}
report_timing_summary -max_paths 10 -report_unconstrained -file [file join $report timing.rpt]
set setup [get_property SLACK [lindex [get_timing_paths -delay_type max -max_paths 1] 0]]
set hold [get_property SLACK [lindex [get_timing_paths -delay_type min -max_paths 1] 0]]
puts "VERIFIED_SETUP_WNS $setup"
puts "VERIFIED_HOLD_WHS $hold"
if {$setup<0 || $hold<0} {error "Timing failed"}
report_route_status -file [file join $report route.rpt]
write_checkpoint -force ${output}_routed.dcp
write_debug_probes -force ${output}.ltx
write_bitstream -force -bin_file ${output}.bit
puts "VERIFIED_LONG_PRBS_BIT ${output}.bit"
exit
