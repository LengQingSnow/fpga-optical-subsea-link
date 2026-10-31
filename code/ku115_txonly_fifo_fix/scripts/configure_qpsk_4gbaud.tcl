set script_dir [file dirname [file normalize [info script]]]
set root_dir [file dirname $script_dir]

open_project [file join $root_dir Sender_KU115.xpr]
set qpsk_clock_ip [get_ips -quiet clk_wiz_qpsk]
if {[llength $qpsk_clock_ip] != 1} {
    error "Expected one clk_wiz_qpsk IP, found [llength $qpsk_clock_ip]"
}

set_property CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {125.000} $qpsk_clock_ip
generate_target all $qpsk_clock_ip
export_ip_user_files -of_objects $qpsk_clock_ip -no_script -sync -force -quiet

set actual_frequency [get_property CONFIG.CLKOUT1_REQUESTED_OUT_FREQ $qpsk_clock_ip]
if {[expr {abs(double($actual_frequency) - 125.0)}] > 0.0001} {
    error "clk_wiz_qpsk requested frequency is $actual_frequency MHz, expected 125.000 MHz"
}
puts "QPSK_CLOCK_CONFIGURED_MHZ=$actual_frequency"
close_project
