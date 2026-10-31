set script_dir [file dirname [file normalize [info script]]]
set root_dir [file dirname $script_dir]

open_project [file join $root_dir Sender_KU115.xpr]

set aggregate_ila [get_ips ila_aggregate_stats]
if {[llength $aggregate_ila] != 1} {
    error "Expected one ila_aggregate_stats IP, found [llength $aggregate_ila]"
}

set_property -dict [list \
    CONFIG.C_NUM_OF_PROBES {17} \
    CONFIG.C_PROBE11_WIDTH {128} \
    CONFIG.C_PROBE12_WIDTH {128} \
    CONFIG.C_PROBE13_WIDTH {128} \
    CONFIG.C_PROBE14_WIDTH {128} \
    CONFIG.C_PROBE15_WIDTH {128} \
    CONFIG.C_PROBE16_WIDTH {128} \
] $aggregate_ila

generate_target all $aggregate_ila
export_ip_user_files -of_objects $aggregate_ila -no_script -sync -force
report_property $aggregate_ila
close_project
