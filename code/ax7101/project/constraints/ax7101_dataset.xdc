############## NET - IOSTANDARD ######################
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]
#############SPI Configurate Setting##################
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]
set_property CONFIG_MODE SPIx4 [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 50 [current_design]
############## clock define###########################
create_clock -period 5.000 [get_ports sys_clk_p]
set_property PACKAGE_PIN R4 [get_ports sys_clk_p]
set_property IOSTANDARD DIFF_SSTL15 [get_ports sys_clk_p]
#################reset setting########################
set_property IOSTANDARD LVCMOS15 [get_ports rst_n]
set_property PACKAGE_PIN T6 [get_ports rst_n]
###################MDIO##############################
set_property PACKAGE_PIN L16 [get_ports e1_mdio]
set_property IOSTANDARD LVCMOS33 [get_ports e1_mdio]
set_property PACKAGE_PIN AB22 [get_ports e2_mdio]
set_property IOSTANDARD LVCMOS33 [get_ports e2_mdio]
set_property PACKAGE_PIN V19 [get_ports e3_mdio]
set_property IOSTANDARD LVCMOS33 [get_ports e3_mdio]
set_property PACKAGE_PIN U20 [get_ports e4_mdio]
set_property IOSTANDARD LVCMOS33 [get_ports e4_mdio]
set_property PULLUP true [get_ports e1_mdc]
set_property SLEW SLOW [get_ports e1_mdio]
set_property PULLUP true [get_ports e1_mdio]
set_property PULLUP true [get_ports e2_mdc]
set_property SLEW SLOW [get_ports e2_mdio]
set_property PULLUP true [get_ports e2_mdio]
set_property PULLUP true [get_ports e3_mdc]
set_property SLEW SLOW [get_ports e3_mdio]
set_property PULLUP true [get_ports e3_mdio]
set_property PULLUP true [get_ports e4_mdc]
set_property SLEW SLOW [get_ports e4_mdio]
set_property PULLUP true [get_ports e4_mdio]
#############LED Setting###########################
set_property PACKAGE_PIN E17 [get_ports {led[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[0]}]

set_property PACKAGE_PIN F16 [get_ports {led[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[1]}]
############## ethernet PORT1 RX define############
create_clock -period 8.000 -name e1_rx_clk [get_ports e1_rxc]
set_property IOSTANDARD LVCMOS33 [get_ports e1_rxc]
set_property PACKAGE_PIN K18 [get_ports e1_rxc]

set_property PACKAGE_PIN J17 [get_ports e1_mdc]
set_property IOSTANDARD LVCMOS33 [get_ports e1_mdc]

set_property IOSTANDARD LVCMOS33 [get_ports e1_rxdv]
set_property PACKAGE_PIN M22 [get_ports e1_rxdv]

set_property IOSTANDARD LVCMOS33 [get_ports e1_rxer]
set_property PACKAGE_PIN N18 [get_ports e1_rxer]

set_property IOSTANDARD LVCMOS33 [get_ports {e1_rxd[0]}]
set_property PACKAGE_PIN N22 [get_ports {e1_rxd[0]}]

set_property IOSTANDARD LVCMOS33 [get_ports {e1_rxd[1]}]
set_property PACKAGE_PIN H18 [get_ports {e1_rxd[1]}]

set_property IOSTANDARD LVCMOS33 [get_ports {e1_rxd[2]}]
set_property PACKAGE_PIN H17 [get_ports {e1_rxd[2]}]

set_property IOSTANDARD LVCMOS33 [get_ports {e1_rxd[3]}]
set_property PACKAGE_PIN M21 [get_ports {e1_rxd[3]}]

set_property IOSTANDARD LVCMOS33 [get_ports {e1_rxd[4]}]
set_property PACKAGE_PIN L21 [get_ports {e1_rxd[4]}]

set_property IOSTANDARD LVCMOS33 [get_ports {e1_rxd[5]}]
set_property PACKAGE_PIN N20 [get_ports {e1_rxd[5]}]

set_property IOSTANDARD LVCMOS33 [get_ports {e1_rxd[6]}]
set_property PACKAGE_PIN M20 [get_ports {e1_rxd[6]}]

set_property IOSTANDARD LVCMOS33 [get_ports {e1_rxd[7]}]
set_property PACKAGE_PIN N19 [get_ports {e1_rxd[7]}]
############## ethernet PORT1 TX define##############
set_property IOSTANDARD LVCMOS33 [get_ports e1_txc]
set_property PACKAGE_PIN K21 [get_ports e1_txc]

set_property IOSTANDARD LVCMOS33 [get_ports e1_gtxc]
set_property PACKAGE_PIN G21 [get_ports e1_gtxc]

set_property IOSTANDARD LVCMOS33 [get_ports e1_txen]
set_property PACKAGE_PIN G22 [get_ports e1_txen]

set_property IOSTANDARD LVCMOS33 [get_ports e1_txer]
set_property PACKAGE_PIN K17 [get_ports e1_txer]

set_property IOSTANDARD LVCMOS33 [get_ports {e1_txd[0]}]
set_property PACKAGE_PIN D22 [get_ports {e1_txd[0]}]

set_property IOSTANDARD LVCMOS33 [get_ports {e1_txd[1]}]
set_property PACKAGE_PIN H20 [get_ports {e1_txd[1]}]

set_property IOSTANDARD LVCMOS33 [get_ports {e1_txd[2]}]
set_property PACKAGE_PIN H22 [get_ports {e1_txd[2]}]

set_property IOSTANDARD LVCMOS33 [get_ports {e1_txd[3]}]
set_property PACKAGE_PIN J22 [get_ports {e1_txd[3]}]

set_property IOSTANDARD LVCMOS33 [get_ports {e1_txd[4]}]
set_property PACKAGE_PIN K22 [get_ports {e1_txd[4]}]

set_property IOSTANDARD LVCMOS33 [get_ports {e1_txd[5]}]
set_property PACKAGE_PIN L19 [get_ports {e1_txd[5]}]

set_property IOSTANDARD LVCMOS33 [get_ports {e1_txd[6]}]
set_property PACKAGE_PIN K19 [get_ports {e1_txd[6]}]

set_property IOSTANDARD LVCMOS33 [get_ports {e1_txd[7]}]
set_property PACKAGE_PIN L20 [get_ports {e1_txd[7]}]

set_property IOSTANDARD LVCMOS33 [get_ports e1_reset]
set_property PACKAGE_PIN G20 [get_ports e1_reset]

############## ethernet PORT2 RX define#################
create_clock -period 8.000 -name e2_rx_clk [get_ports e2_rxc]
set_property IOSTANDARD LVCMOS33 [get_ports e2_rxc]
set_property PACKAGE_PIN J20 [get_ports e2_rxc]

set_property PACKAGE_PIN AB21 [get_ports e2_mdc]
set_property IOSTANDARD LVCMOS33 [get_ports e2_mdc]

set_property IOSTANDARD LVCMOS33 [get_ports e2_rxdv]
set_property PACKAGE_PIN L13 [get_ports e2_rxdv]

set_property IOSTANDARD LVCMOS33 [get_ports e2_rxer]
set_property PACKAGE_PIN G13 [get_ports e2_rxer]

set_property IOSTANDARD LVCMOS33 [get_ports {e2_rxd[0]}]
set_property PACKAGE_PIN M13 [get_ports {e2_rxd[0]}]

set_property IOSTANDARD LVCMOS33 [get_ports {e2_rxd[1]}]
set_property PACKAGE_PIN K14 [get_ports {e2_rxd[1]}]

set_property IOSTANDARD LVCMOS33 [get_ports {e2_rxd[2]}]
set_property PACKAGE_PIN K13 [get_ports {e2_rxd[2]}]

set_property IOSTANDARD LVCMOS33 [get_ports {e2_rxd[3]}]
set_property PACKAGE_PIN J14 [get_ports {e2_rxd[3]}]

set_property IOSTANDARD LVCMOS33 [get_ports {e2_rxd[4]}]
set_property PACKAGE_PIN H14 [get_ports {e2_rxd[4]}]

set_property IOSTANDARD LVCMOS33 [get_ports {e2_rxd[5]}]
set_property PACKAGE_PIN H15 [get_ports {e2_rxd[5]}]

set_property IOSTANDARD LVCMOS33 [get_ports {e2_rxd[6]}]
set_property PACKAGE_PIN J15 [get_ports {e2_rxd[6]}]

set_property IOSTANDARD LVCMOS33 [get_ports {e2_rxd[7]}]
set_property PACKAGE_PIN H13 [get_ports {e2_rxd[7]}]
############## ethernet PORT2 TX define##################
set_property IOSTANDARD LVCMOS33 [get_ports e2_txc]
set_property PACKAGE_PIN T14 [get_ports e2_txc]

set_property IOSTANDARD LVCMOS33 [get_ports e2_gtxc]
set_property PACKAGE_PIN M16 [get_ports e2_gtxc]

set_property IOSTANDARD LVCMOS33 [get_ports e2_txen]
set_property PACKAGE_PIN M15 [get_ports e2_txen]

set_property IOSTANDARD LVCMOS33 [get_ports e2_txer]
set_property PACKAGE_PIN T15 [get_ports e2_txer]

set_property IOSTANDARD LVCMOS33 [get_ports {e2_txd[0]}]
set_property PACKAGE_PIN L15 [get_ports {e2_txd[0]}]

set_property IOSTANDARD LVCMOS33 [get_ports {e2_txd[1]}]
set_property PACKAGE_PIN K16 [get_ports {e2_txd[1]}]

set_property IOSTANDARD LVCMOS33 [get_ports {e2_txd[2]}]
set_property PACKAGE_PIN W15 [get_ports {e2_txd[2]}]

set_property IOSTANDARD LVCMOS33 [get_ports {e2_txd[3]}]
set_property PACKAGE_PIN W16 [get_ports {e2_txd[3]}]

set_property IOSTANDARD LVCMOS33 [get_ports {e2_txd[4]}]
set_property PACKAGE_PIN V17 [get_ports {e2_txd[4]}]

set_property IOSTANDARD LVCMOS33 [get_ports {e2_txd[5]}]
set_property PACKAGE_PIN W17 [get_ports {e2_txd[5]}]

set_property IOSTANDARD LVCMOS33 [get_ports {e2_txd[6]}]
set_property PACKAGE_PIN U15 [get_ports {e2_txd[6]}]

set_property IOSTANDARD LVCMOS33 [get_ports {e2_txd[7]}]
set_property PACKAGE_PIN V15 [get_ports {e2_txd[7]}]

set_property IOSTANDARD LVCMOS33 [get_ports e2_reset]
set_property PACKAGE_PIN L14 [get_ports e2_reset]

############## ethernet PORT3 RX define##################
create_clock -period 8.000 -name e3_rx_clk [get_ports e3_rxc]
set_property IOSTANDARD LVCMOS33 [get_ports e3_rxc]
set_property PACKAGE_PIN V13 [get_ports e3_rxc]

set_property PACKAGE_PIN V20 [get_ports e3_mdc]
set_property IOSTANDARD LVCMOS33 [get_ports e3_mdc]

set_property IOSTANDARD LVCMOS33 [get_ports e3_rxdv]
set_property PACKAGE_PIN AA20 [get_ports e3_rxdv]

set_property IOSTANDARD LVCMOS33 [get_ports e3_rxer]
set_property PACKAGE_PIN U21 [get_ports e3_rxer]

set_property IOSTANDARD LVCMOS33 [get_ports {e3_rxd[0]}]
set_property PACKAGE_PIN AB20 [get_ports {e3_rxd[0]}]

set_property IOSTANDARD LVCMOS33 [get_ports {e3_rxd[1]}]
set_property PACKAGE_PIN AA19 [get_ports {e3_rxd[1]}]

set_property IOSTANDARD LVCMOS33 [get_ports {e3_rxd[2]}]
set_property PACKAGE_PIN AA18 [get_ports {e3_rxd[2]}]

set_property IOSTANDARD LVCMOS33 [get_ports {e3_rxd[3]}]
set_property PACKAGE_PIN AB18 [get_ports {e3_rxd[3]}]

set_property IOSTANDARD LVCMOS33 [get_ports {e3_rxd[4]}]
set_property PACKAGE_PIN Y17 [get_ports {e3_rxd[4]}]

set_property IOSTANDARD LVCMOS33 [get_ports {e3_rxd[5]}]
set_property PACKAGE_PIN W22 [get_ports {e3_rxd[5]}]

set_property IOSTANDARD LVCMOS33 [get_ports {e3_rxd[6]}]
set_property PACKAGE_PIN W21 [get_ports {e3_rxd[6]}]

set_property IOSTANDARD LVCMOS33 [get_ports {e3_rxd[7]}]
set_property PACKAGE_PIN T21 [get_ports {e3_rxd[7]}]
############## ethernet PORT3 TX define##################
set_property IOSTANDARD LVCMOS33 [get_ports e3_txc]
set_property PACKAGE_PIN V10 [get_ports e3_txc]

set_property IOSTANDARD LVCMOS33 [get_ports e3_gtxc]
set_property PACKAGE_PIN AA21 [get_ports e3_gtxc]

set_property IOSTANDARD LVCMOS33 [get_ports e3_txen]
set_property PACKAGE_PIN V14 [get_ports e3_txen]

set_property IOSTANDARD LVCMOS33 [get_ports e3_txer]
set_property PACKAGE_PIN AA9 [get_ports e3_txer]

set_property IOSTANDARD LVCMOS33 [get_ports {e3_txd[0]}]
set_property PACKAGE_PIN W11 [get_ports {e3_txd[0]}]

set_property IOSTANDARD LVCMOS33 [get_ports {e3_txd[1]}]
set_property PACKAGE_PIN W12 [get_ports {e3_txd[1]}]

set_property IOSTANDARD LVCMOS33 [get_ports {e3_txd[2]}]
set_property PACKAGE_PIN Y11 [get_ports {e3_txd[2]}]

set_property IOSTANDARD LVCMOS33 [get_ports {e3_txd[3]}]
set_property PACKAGE_PIN Y12 [get_ports {e3_txd[3]}]

set_property IOSTANDARD LVCMOS33 [get_ports {e3_txd[4]}]
set_property PACKAGE_PIN W10 [get_ports {e3_txd[4]}]

set_property IOSTANDARD LVCMOS33 [get_ports {e3_txd[5]}]
set_property PACKAGE_PIN AA11 [get_ports {e3_txd[5]}]

set_property IOSTANDARD LVCMOS33 [get_ports {e3_txd[6]}]
set_property PACKAGE_PIN AA10 [get_ports {e3_txd[6]}]

set_property IOSTANDARD LVCMOS33 [get_ports {e3_txd[7]}]
set_property PACKAGE_PIN AB10 [get_ports {e3_txd[7]}]

set_property IOSTANDARD LVCMOS33 [get_ports e3_reset]
set_property PACKAGE_PIN T20 [get_ports e3_reset]

############## ethernet PORT4 RX define##################
create_clock -period 8.000 -name e4_rx_clk [get_ports e4_rxc]
set_property IOSTANDARD LVCMOS33 [get_ports e4_rxc]
set_property PACKAGE_PIN Y18 [get_ports e4_rxc]

set_property PACKAGE_PIN V18 [get_ports e4_mdc]
set_property IOSTANDARD LVCMOS33 [get_ports e4_mdc]

set_property IOSTANDARD LVCMOS33 [get_ports e4_rxdv]
set_property PACKAGE_PIN W20 [get_ports e4_rxdv]

set_property IOSTANDARD LVCMOS33 [get_ports e4_rxer]
set_property PACKAGE_PIN N13 [get_ports e4_rxer]

set_property IOSTANDARD LVCMOS33 [get_ports {e4_rxd[0]}]
set_property PACKAGE_PIN W19 [get_ports {e4_rxd[0]}]

set_property IOSTANDARD LVCMOS33 [get_ports {e4_rxd[1]}]
set_property PACKAGE_PIN Y19 [get_ports {e4_rxd[1]}]

set_property IOSTANDARD LVCMOS33 [get_ports {e4_rxd[2]}]
set_property PACKAGE_PIN V22 [get_ports {e4_rxd[2]}]

set_property IOSTANDARD LVCMOS33 [get_ports {e4_rxd[3]}]
set_property PACKAGE_PIN U22 [get_ports {e4_rxd[3]}]

set_property IOSTANDARD LVCMOS33 [get_ports {e4_rxd[4]}]
set_property PACKAGE_PIN T18 [get_ports {e4_rxd[4]}]

set_property IOSTANDARD LVCMOS33 [get_ports {e4_rxd[5]}]
set_property PACKAGE_PIN R18 [get_ports {e4_rxd[5]}]

set_property IOSTANDARD LVCMOS33 [get_ports {e4_rxd[6]}]
set_property PACKAGE_PIN R14 [get_ports {e4_rxd[6]}]

set_property IOSTANDARD LVCMOS33 [get_ports {e4_rxd[7]}]
set_property PACKAGE_PIN P14 [get_ports {e4_rxd[7]}]
############## ethernet PORT4 TX define##################
set_property IOSTANDARD LVCMOS33 [get_ports e4_txc]
set_property PACKAGE_PIN U16 [get_ports e4_txc]

set_property IOSTANDARD LVCMOS33 [get_ports e4_gtxc]
set_property PACKAGE_PIN P20 [get_ports e4_gtxc]

set_property IOSTANDARD LVCMOS33 [get_ports e4_txen]
set_property PACKAGE_PIN P16 [get_ports e4_txen]

set_property IOSTANDARD LVCMOS33 [get_ports e4_txer]
set_property PACKAGE_PIN R19 [get_ports e4_txer]

set_property IOSTANDARD LVCMOS33 [get_ports {e4_txd[0]}]
set_property PACKAGE_PIN R17 [get_ports {e4_txd[0]}]

set_property IOSTANDARD LVCMOS33 [get_ports {e4_txd[1]}]
set_property PACKAGE_PIN P15 [get_ports {e4_txd[1]}]

set_property IOSTANDARD LVCMOS33 [get_ports {e4_txd[2]}]
set_property PACKAGE_PIN N17 [get_ports {e4_txd[2]}]

set_property IOSTANDARD LVCMOS33 [get_ports {e4_txd[3]}]
set_property PACKAGE_PIN P17 [get_ports {e4_txd[3]}]

set_property IOSTANDARD LVCMOS33 [get_ports {e4_txd[4]}]
set_property PACKAGE_PIN T16 [get_ports {e4_txd[4]}]

set_property IOSTANDARD LVCMOS33 [get_ports {e4_txd[5]}]
set_property PACKAGE_PIN U17 [get_ports {e4_txd[5]}]

set_property IOSTANDARD LVCMOS33 [get_ports {e4_txd[6]}]
set_property PACKAGE_PIN U18 [get_ports {e4_txd[6]}]

set_property IOSTANDARD LVCMOS33 [get_ports {e4_txd[7]}]
set_property PACKAGE_PIN P19 [get_ports {e4_txd[7]}]

set_property IOSTANDARD LVCMOS33 [get_ports e4_reset]
set_property PACKAGE_PIN R16 [get_ports e4_reset]

############## GMII source-synchronous timing ##################
# The ODDR forwards an inverted 125 MHz clock. TX data is registered on the
# rising edge, then sampled by the PHY on the forwarded clock edge 4 ns later.
create_generated_clock -name e1_tx_clk \
    -source [get_pins u_gtxc_1/u_oddr/C] -divide_by 1 -invert [get_ports e1_gtxc]
create_generated_clock -name e2_tx_clk \
    -source [get_pins u_gtxc_2/u_oddr/C] -divide_by 1 -invert [get_ports e2_gtxc]
create_generated_clock -name e3_tx_clk \
    -source [get_pins u_gtxc_3/u_oddr/C] -divide_by 1 -invert [get_ports e3_gtxc]
create_generated_clock -name e4_tx_clk \
    -source [get_pins u_gtxc_4/u_oddr/C] -divide_by 1 -invert [get_ports e4_gtxc]

# RTL8211E GMII setup/hold budget. The TX clock phase deliberately provides a
# half-cycle center-aligned window. Port 4 RX uses the PHY-supplied RX clock and
# an IOB input register; the checker sees that registered byte one cycle later.
set_output_delay -clock e1_tx_clk -max 2.000 \
    [get_ports {e1_txd[*] e1_txen e1_txer}]
set_output_delay -clock e1_tx_clk -min 0.000 \
    [get_ports {e1_txd[*] e1_txen e1_txer}]
set_output_delay -clock e2_tx_clk -max 2.000 \
    [get_ports {e2_txd[*] e2_txen e2_txer}]
set_output_delay -clock e2_tx_clk -min 0.000 \
    [get_ports {e2_txd[*] e2_txen e2_txer}]
set_output_delay -clock e3_tx_clk -max 2.000 \
    [get_ports {e3_txd[*] e3_txen e3_txer}]
set_output_delay -clock e3_tx_clk -min 0.000 \
    [get_ports {e3_txd[*] e3_txen e3_txer}]
set_output_delay -clock e4_tx_clk -max 2.000 \
    [get_ports {e4_txd[*] e4_txen e4_txer}]
set_output_delay -clock e4_tx_clk -min 0.000 \
    [get_ports {e4_txd[*] e4_txen e4_txer}]

set_input_delay -clock e4_rx_clk -max 2.000 \
    [get_ports {e4_rxd[*] e4_rxdv e4_rxer}]
set_input_delay -clock e4_rx_clk -min 0.000 \
    [get_ports {e4_rxd[*] e4_rxdv e4_rxer}]

# PHY receive clocks are unrelated to the 200/125 MHz FPGA clock family.
set_clock_groups -asynchronous \
    -group [get_clocks -include_generated_clocks sys_clk_p] \
    -group [get_clocks e1_rx_clk] \
    -group [get_clocks e2_rx_clk] \
    -group [get_clocks e3_rx_clk] \
    -group [get_clocks e4_rx_clk]

# External reset and low-speed MDIO inputs are asynchronous to the FPGA clock.
set_false_path -from [get_ports rst_n]
set_false_path -from [get_ports {e1_mdio e2_mdio e3_mdio e4_mdio}]

# These are the first stages of explicit two-flop status synchronizers.
set_false_path -to [get_pins -hier -filter \
    {REF_PIN_NAME == D && NAME =~ *u_status_to_tx/sync_meta_reg*}]
set_false_path -to [get_pins -hier -filter \
    {REF_PIN_NAME == D && NAME =~ *u_descriptor_ready_to_tx/sync_meta_reg*}]
set_false_path -to [get_pins -hier -filter \
    {REF_PIN_NAME == D && NAME =~ *u_descriptor_data_to_tx/sync_meta_reg*}]

# Dual-camera frame control uses level handshakes. Only the first destination
# synchronizer stage and the stable companion metadata are asynchronous.
set_false_path -to [get_pins -hier -filter \
    {REF_PIN_NAME == D && NAME =~ *read_ack_cdc*/level_meta_reg*}]
set_false_path -to [get_pins -hier -filter \
    {REF_PIN_NAME == D && NAME =~ *write_ack_cdc*/level_meta_reg*}]
set_false_path -to [get_pins -hier -filter \
    {REF_PIN_NAME == D && NAME =~ *video_read_ack_cdc_m1/sync_meta_reg*}]
set_false_path -to [get_pins -hier -filter \
    {REF_PIN_NAME == D && NAME =~ *frame_fifo_read_m0/read_req_d0_reg*}]
set_false_path -to [get_pins -hier -filter \
    {REF_PIN_NAME == D && NAME =~ *frame_fifo_read_m0/read_len_d0_reg*}]
set_false_path -to [get_pins -hier -filter \
    {REF_PIN_NAME == D && NAME =~ *frame_fifo_read_m0/read_addr_index_d0_reg*}]
set_false_path -to [get_pins -hier -filter \
    {REF_PIN_NAME == D && NAME =~ *frame_fifo_write_m0/write_req_d0_reg*}]
set_false_path -to [get_pins -hier -filter \
    {REF_PIN_NAME == D && NAME =~ *frame_fifo_write_m0/write_len_d0_reg*}]
set_false_path -to [get_pins -hier -filter \
    {REF_PIN_NAME == D && NAME =~ *frame_fifo_write_m0/write_addr_index_d0_reg*}]

# phy_reset_n asserts asynchronously; each destination domain releases reset
# through its own three-stage synchronizer.
set_false_path -to [get_pins -hier -filter \
    {REF_PIN_NAME == CLR && NAME =~ *reset_sync/sync_pipe_reg*}]
set_false_path -to [get_pins -hier -filter \
    {REF_PIN_NAME == CLR && NAME =~ *reset_pipe_reg*}]

############## Dual OV5640 and VGA ##################
set_property IOSTANDARD LVCMOS33 [get_ports {
    cmos1_scl cmos1_sda cmos1_vsync cmos1_href cmos1_pclk cmos1_rst_n
    cmos1_db[*]
    cmos2_scl cmos2_sda cmos2_vsync cmos2_href cmos2_pclk cmos2_rst_n
    cmos2_db[*]
    vga_out_hs vga_out_vs vga_out_r[*] vga_out_g[*] vga_out_b[*]
}]

set_property PACKAGE_PIN J19 [get_ports cmos1_sda]
set_property PACKAGE_PIN D19 [get_ports cmos1_scl]
set_property PACKAGE_PIN C18 [get_ports cmos1_pclk]
set_property PACKAGE_PIN B18 [get_ports cmos1_href]
set_property PACKAGE_PIN B17 [get_ports cmos1_vsync]
set_property PACKAGE_PIN C17 [get_ports cmos1_rst_n]
set_property PACKAGE_PIN A18 [get_ports {cmos1_db[0]}]
set_property PACKAGE_PIN F18 [get_ports {cmos1_db[1]}]
set_property PACKAGE_PIN C19 [get_ports {cmos1_db[2]}]
set_property PACKAGE_PIN C20 [get_ports {cmos1_db[3]}]
set_property PACKAGE_PIN D20 [get_ports {cmos1_db[4]}]
set_property PACKAGE_PIN E19 [get_ports {cmos1_db[5]}]
set_property PACKAGE_PIN A19 [get_ports {cmos1_db[6]}]
set_property PACKAGE_PIN E18 [get_ports {cmos1_db[7]}]
set_property PACKAGE_PIN G15 [get_ports {cmos1_db[8]}]
set_property PACKAGE_PIN G16 [get_ports {cmos1_db[9]}]

set_property PACKAGE_PIN C22 [get_ports cmos2_sda]
set_property PACKAGE_PIN B20 [get_ports cmos2_scl]
set_property PACKAGE_PIN G17 [get_ports cmos2_pclk]
set_property PACKAGE_PIN J16 [get_ports cmos2_href]
set_property PACKAGE_PIN G18 [get_ports cmos2_vsync]
set_property PACKAGE_PIN M17 [get_ports cmos2_rst_n]
set_property PACKAGE_PIN E21 [get_ports {cmos2_db[0]}]
set_property PACKAGE_PIN D21 [get_ports {cmos2_db[1]}]
set_property PACKAGE_PIN F19 [get_ports {cmos2_db[2]}]
set_property PACKAGE_PIN F21 [get_ports {cmos2_db[3]}]
set_property PACKAGE_PIN A21 [get_ports {cmos2_db[4]}]
set_property PACKAGE_PIN B21 [get_ports {cmos2_db[5]}]
set_property PACKAGE_PIN A20 [get_ports {cmos2_db[6]}]
set_property PACKAGE_PIN F20 [get_ports {cmos2_db[7]}]
set_property PACKAGE_PIN F15 [get_ports {cmos2_db[8]}]
set_property PACKAGE_PIN B22 [get_ports {cmos2_db[9]}]

set_property PACKAGE_PIN C13 [get_ports vga_out_hs]
set_property PACKAGE_PIN B13 [get_ports vga_out_vs]
set_property PACKAGE_PIN AB16 [get_ports {vga_out_r[0]}]
set_property PACKAGE_PIN Y16 [get_ports {vga_out_r[1]}]
set_property PACKAGE_PIN AA16 [get_ports {vga_out_r[2]}]
set_property PACKAGE_PIN Y13 [get_ports {vga_out_r[3]}]
set_property PACKAGE_PIN AB17 [get_ports {vga_out_r[4]}]
set_property PACKAGE_PIN D15 [get_ports {vga_out_g[0]}]
set_property PACKAGE_PIN AB13 [get_ports {vga_out_g[1]}]
set_property PACKAGE_PIN W14 [get_ports {vga_out_g[2]}]
set_property PACKAGE_PIN AA14 [get_ports {vga_out_g[3]}]
set_property PACKAGE_PIN AA13 [get_ports {vga_out_g[4]}]
set_property PACKAGE_PIN AB12 [get_ports {vga_out_g[5]}]
set_property PACKAGE_PIN D14 [get_ports {vga_out_b[0]}]
set_property PACKAGE_PIN E14 [get_ports {vga_out_b[1]}]
set_property PACKAGE_PIN E13 [get_ports {vga_out_b[2]}]
set_property PACKAGE_PIN F13 [get_ports {vga_out_b[3]}]
set_property PACKAGE_PIN F14 [get_ports {vga_out_b[4]}]

create_clock -period 11.904 -name cmos1_pixel_clk [get_ports cmos1_pclk]
create_clock -period 11.904 -name cmos2_pixel_clk [get_ports cmos2_pclk]
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets cmos1_pclk_IBUF]
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets cmos2_pclk_IBUF]

set_clock_groups -asynchronous \
    -group [get_clocks -include_generated_clocks sys_clk_p] \
    -group [get_clocks cmos1_pixel_clk] \
    -group [get_clocks cmos2_pixel_clk]

# The two camera pixel clocks are also unrelated to every PHY receive clock.
# This covers diagnostics that intentionally cross from a camera domain into
# the port-4 ILA through Gray-code synchronizers.
set_clock_groups -asynchronous \
    -group [get_clocks cmos1_pixel_clk] \
    -group [get_clocks cmos2_pixel_clk] \
    -group [get_clocks e1_rx_clk] \
    -group [get_clocks e2_rx_clk] \
    -group [get_clocks e3_rx_clk] \
    -group [get_clocks e4_rx_clk]
