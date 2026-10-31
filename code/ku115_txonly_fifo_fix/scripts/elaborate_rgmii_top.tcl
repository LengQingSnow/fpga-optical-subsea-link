set script_dir [file dirname [file normalize [info script]]]
set root_dir [file dirname $script_dir]

open_project [file join $root_dir Sender_KU115.xpr]
set_property top top [get_filesets sources_1]

set known_source_files [get_files -quiet -of_objects [get_filesets sources_1]]
foreach source_file [glob -nocomplain [file join $root_dir src *.v]] {
    if {[lsearch -exact $known_source_files [file normalize $source_file]] < 0} {
        add_files -norecurse $source_file
    }
}
update_compile_order -fileset sources_1

synth_design -rtl -rtl_skip_mlo -name rgmii_rtl -top top

# Vivado replaces PLLE3_BASE with PLLE3_ADV during RTL elaboration. Accept
# either name so this structural check also works before/after transformation.
set pll_cells [get_cells -hierarchical -filter {
    REF_NAME == PLLE3_BASE || REF_NAME == PLLE3_ADV
}]
set idelay_cells [get_cells -hierarchical -filter {REF_NAME == IDELAYE3}]
set tx_clocks [get_clocks -quiet {rgmii1_txc_io rgmii2_txc_io rgmii3_txc_io rgmii4_txc_io}]

puts "RGMII_PLL_COUNT=[llength $pll_cells]"
puts "RGMII_IDELAY_COUNT=[llength $idelay_cells]"
puts "RGMII_TX_CLOCK_COUNT=[llength $tx_clocks]"

if {[llength $pll_cells] != 4} {
    error "Expected four RGMII PLLE3 cells, found [llength $pll_cells]"
}
if {[llength $idelay_cells] != 20} {
    error "Expected 20 RGMII IDELAYE3 cells, found [llength $idelay_cells]"
}
if {[llength $tx_clocks] != 4} {
    error "Expected four RGMII TX generated clocks, found [llength $tx_clocks]"
}

# check_timing is intentionally deferred to the post-synthesis/implementation
# release check. Vivado does not support it on a synth_design -rtl netlist.
puts "RGMII_ELABORATION_PASS"
close_design
close_project
