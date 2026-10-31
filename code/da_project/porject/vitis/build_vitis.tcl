set script_dir [file normalize [file dirname [info script]]]
set workspace [file join $script_dir workspace]
set source_dir [file join $script_dir rf47_init src]
set xsa [file normalize [file join $script_dir .. vivado output rf47_qsfp_dpqpsk_nrz_8gsps_runtime_cal.xsa]]

if {![file exists $xsa]} {
    error "Hardware platform not found: $xsa"
}

file delete -force $workspace
file mkdir $workspace
setws $workspace

platform create -name rf47_platform -hw $xsa \
    -proc psu_cortexa53_0 -os standalone
platform generate

app create -name rf47_init -platform rf47_platform \
    -domain standalone_domain -template {Empty Application(C)}
importsources -name rf47_init -path $source_dir
app config -name rf47_init build-config release

set release_dir [file join $workspace rf47_init Release]
set elf [file join $release_dir rf47_init.elf]
set makefile [file join $release_dir makefile]

set app_build_status [catch {app build -name rf47_init} app_build_message]
if {$app_build_status != 0} {
    puts "Vitis app build returned before application link: $app_build_message"
}

if {![file exists $elf]} {
    if {![file exists $makefile]} {
        error "Application makefile not found after app build: $makefile"
    }

    set make_exe [file join $::env(XILINX_VITIS) gnuwin bin make.exe]
    puts [exec $make_exe -C $release_dir all]
}

if {![file exists $elf]} {
    error "Application ELF not found: $elf"
}

set output_dir [file join $script_dir output]
file mkdir $output_dir
file copy -force $elf [file join $output_dir rf47_init.elf]
file copy -force [file join $workspace rf47_platform hw psu_init.tcl] \
    [file join $output_dir psu_init.tcl]
puts "APPLICATION_ELF [file join $output_dir rf47_init.elf]"
exit
