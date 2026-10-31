set script_dir [file dirname [file normalize [info script]]]
set project_root [file normalize [file join $script_dir ..]]
set project_file [file join $project_root AX7101_3TX_1RX_PRBS31.xpr]

open_project $project_file
puts "SYNTH_STATUS=[get_property STATUS [get_runs synth_1]]"
puts "IMPL_STATUS=[get_property STATUS [get_runs impl_1]]"

if {[get_property PROGRESS [get_runs impl_1]] == "100%"} {
    open_run impl_1
    set setup_path [get_timing_paths -delay_type max -max_paths 1 -nworst 1]
    set hold_path [get_timing_paths -delay_type min -max_paths 1 -nworst 1]
    puts "WNS_NS=[get_property SLACK [lindex $setup_path 0]]"
    puts "WHS_NS=[get_property SLACK [lindex $hold_path 0]]"
    report_route_status
}
close_project
