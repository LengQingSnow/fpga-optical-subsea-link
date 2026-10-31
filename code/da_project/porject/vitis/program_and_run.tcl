set script_dir [file normalize [file dirname [info script]]]
set bit_file [file normalize [file join $script_dir .. vivado output rf47_qsfp_dpqpsk_nrz_8gsps_runtime_cal.bit]]
set elf_file [file normalize [file join $script_dir output rf47_init.elf]]
set psu_init_file [file normalize [file join $script_dir output psu_init.tcl]]

foreach required_file [list $bit_file $elf_file $psu_init_file] {
    if {![file exists $required_file]} {
        error "Required programming file not found: $required_file"
    }
}

connect -url tcp:127.0.0.1:3121
targets -set -nocase -filter {name =~ "*PSU*"}
rst -system
after 2000

targets -set -nocase -filter {name == "PS TAP"}
fpga -file $bit_file
targets -set -nocase -filter {name =~ "*PSU*"}
source $psu_init_file
psu_init
psu_ps_pl_isolation_removal
psu_ps_pl_reset_config

targets -set -nocase -filter {name =~ "*Cortex-A53 #0*"}
rst -processor
dow $elf_file
con

puts "RF47 NRZ runtime-calibration bitstream programmed; MTS initialization application started."
disconnect
exit
