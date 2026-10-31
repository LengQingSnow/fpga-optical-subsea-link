set script_dir [file dirname [file normalize [info script]]]
set project_root [file normalize [file join $script_dir ..]]
open_project [file join $project_root AX7101_3TX_1RX_PRBS31.xpr]
source [file join $script_dir create_memory_subsystem.tcl]
close_project
