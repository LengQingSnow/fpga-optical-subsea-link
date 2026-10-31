if {$argc != 1} {
    error "usage: vivado -mode batch -source scripts/run_test.tcl -tclargs <testbench>"
}

set testbench [lindex $argv 0]
set script_dir [file dirname [file normalize [info script]]]
set root_dir [file dirname $script_dir]
open_project [file join $root_dir Sender_KU115.xpr]

set known_source_files [get_files -quiet -of_objects [get_filesets sources_1]]
foreach source_file [glob -nocomplain [file join $root_dir src *.v]] {
    if {[lsearch -exact $known_source_files [file normalize $source_file]] < 0} {
        add_files -norecurse $source_file
    }
}
set known_sim_files [get_files -quiet -of_objects [get_filesets sim_1]]
foreach sim_file [glob -nocomplain [file join $root_dir sim *.v]] {
    if {[lsearch -exact $known_sim_files [file normalize $sim_file]] < 0} {
        add_files -fileset sim_1 -norecurse $sim_file
    }
}

set_property top $testbench [get_filesets sim_1]
set_property xsim.simulate.runtime 0ns [get_filesets sim_1]
update_compile_order -fileset sim_1
launch_simulation
run all
close_sim
close_project
