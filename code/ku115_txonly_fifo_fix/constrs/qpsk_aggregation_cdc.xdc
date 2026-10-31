# The four aggregate inputs are independent RGMII clock domains.  Only the
# first stage of each Gray-pointer synchronizer is asynchronous; the second
# stage remains timed in its destination clock domain.
set qpsk_async_clocks [get_clocks -quiet -include_generated_clocks \
    clk_out1_clk_wiz_qpsk]
set rgmii_async_clocks [get_clocks -quiet -include_generated_clocks \
    {rgmii1_rxc rgmii2_rxc rgmii3_rxc rgmii4_rxc}]

set_clock_groups -asynchronous \
    -group $qpsk_async_clocks \
    -group $rgmii_async_clocks

set_false_path -to [get_pins -hier -filter {NAME =~ *aggregate_inst/*fifo*/fifo/rd_gray_sync1_reg*/D}]
set_false_path -to [get_pins -hier -filter {NAME =~ *aggregate_inst/*fifo*/fifo/wr_gray_sync1_reg*/D}]
