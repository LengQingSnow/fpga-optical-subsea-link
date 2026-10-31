set script_dir [file normalize [file dirname [info script]]]
set archive_dir [file normalize [file join $script_dir .. archive same_phase_reference_20260722]]
set bit_file [file join $archive_dir rf47_prbs31_rrc_8gsps.bit]
set elf_file [file join $archive_dir rf47_init.elf]
set psu_init_file [file join $archive_dir psu_init.tcl]

foreach required_file [list $bit_file $elf_file $psu_init_file] {
    if {![file exists $required_file]} {
        error "Required archive file not found: $required_file"
    }
}

connect -url tcp:127.0.0.1:3121
targets -set -nocase -filter {name =~ "*PSU*"}
rst -system
after 2000

fpga -file $bit_file
source $psu_init_file
psu_init
psu_ps_pl_isolation_removal
psu_ps_pl_reset_config

targets -set -nocase -filter {name =~ "*Cortex-A53 #0*"}
rst -processor
dow $elf_file
con

puts "ARCHIVE_PRBS_PROGRAMMED"
disconnect
exit
