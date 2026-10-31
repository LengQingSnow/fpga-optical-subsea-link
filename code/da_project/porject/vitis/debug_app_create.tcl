set script_dir [file normalize [file dirname [info script]]]
set ws [file join $script_dir debug_workspace]
file delete -force $ws
file mkdir $ws
set xsa [file normalize [file join $script_dir .. vivado output rf47_qsfp_dpqpsk_nrz_8gsps_runtime_cal.xsa]]
setws $ws
puts "WS=$ws"
puts "XSA=$xsa"
puts "PLATFORM_CREATE=[catch {platform create -name rf47_platform -hw $xsa -proc psu_cortexa53_0 -os standalone} msg] $msg"
puts "PLATFORM_LIST=[platform list]"
puts "PLATFORM_GENERATE=[catch {platform generate} msg] $msg"
puts "APP_CREATE=[catch {app create -name rf47_init -platform rf47_platform -domain standalone_domain -template {Hello World}} msg] $msg"
puts "APP_LIST=[app list]"
puts "APP_DIRS=[glob -nocomplain -directory $ws *]"
exit
