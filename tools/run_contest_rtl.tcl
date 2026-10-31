# Offline, isolated generated test project; does not open board projects.
set repo [file normalize [file join [file dirname [info script]] ..]]
set out [file join $repo .release_work contest_rtl]
file mkdir $out
cd $out
create_project contest_rtl [file join $out project] -part xcku115-flva1517-2-e -force
set_property XPM_LIBRARIES {XPM_CDC XPM_MEMORY XPM_FIFO} [current_project]
set src [file join $repo code ku115_txonly_fifo_fix src]
foreach n {frame_byte_bank.v qpsk_frame_aggregator.v eth_aggregate_4port.v async_byte_fifo.v async_reset_sync.v qsfp_axis_tx_bridge.v qsfp_payload_fifo_xpm.v} {
 add_files -norecurse [file join $src $n]
}
set sim [file join $repo code ku115_txonly_fifo_fix sim]
set tests {tb_qpsk_frame_aggregator tb_async_byte_stream_bridge_overflow tb_qsfp_axis_tx_bridge_throughput}
foreach t $tests {add_files -fileset sim_1 -norecurse [file join $sim ${t}.v]}
foreach t $tests {
 puts "CONTEST_TEST_BEGIN $t"
 set_property top $t [get_filesets sim_1]
 set_property xsim.simulate.runtime 0ns [get_filesets sim_1]
 update_compile_order -fileset sim_1
 launch_simulation
 run all
 close_sim
 puts "CONTEST_TEST_END $t"
}
close_project
