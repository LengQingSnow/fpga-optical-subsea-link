# QSFP1 TX uses Bank 230; QSFP2 RX uses Bank 229.
set_property PACKAGE_PIN P10 [get_ports qsfp1_refclk_p]
set_property PACKAGE_PIN U8 [get_ports qsfp2_refclk_p]

create_clock -name qsfp1_refclk -period 6.400 [get_ports qsfp1_refclk_p]
create_clock -name qsfp2_refclk -period 6.400 [get_ports qsfp2_refclk_p]

# Asynchronous FIFO Gray-pointer synchronizers. Only the first destination
# stage is exempted; the second stage remains timed by its destination clock.
set_false_path -to [get_pins -hier -filter {
    NAME =~ *qsfp_tx_bridge_inst/payload_fifo/rd_gray_sync1_reg*/D ||
    NAME =~ *qsfp_tx_bridge_inst/payload_fifo/wr_gray_sync1_reg*/D ||
    NAME =~ *qsfp_monitor_inst/expected_fifo/rd_gray_sync1_reg*/D ||
    NAME =~ *qsfp_monitor_inst/expected_fifo/wr_gray_sync1_reg*/D
}]

# Single-bit link and sticky-status synchronizers.
set_false_path -to [get_pins -hier -filter {
    NAME =~ *qsfp_tx_up_qpsk_d0_reg/D ||
    NAME =~ *qsfp_rx_up_qpsk_d0_reg/D ||
    NAME =~ *qsfp_rx_up_tx_d0_reg/D ||
    NAME =~ *qsfp_tx_up_rx_d0_reg/D ||
    NAME =~ *qsfp_tx_error_rx_d0_reg/D ||
    NAME =~ *qsfp_bridge_overflow_rx_d0_reg/D ||
    NAME =~ *qsfp_bridge_frame_error_rx_d0_reg/D ||
    NAME =~ *qsfp_monitor_inst/tx_frame_gray_sync1_reg*/D ||
    NAME =~ *qsfp_monitor_inst/reference_overflow_sync1_reg/D
}]

# The reset synchronizers assert asynchronously and release through two clocked
# stages. Recovery/removal timing is intentionally cut only at their CLR pins.
set_false_path -to [get_pins -hier -filter {
    NAME =~ *aurora_ready_tx_sync_inst/sync_ff_reg*/CLR ||
    NAME =~ *aurora_ready_rx_sync_inst/sync_ff_reg*/CLR
}]
