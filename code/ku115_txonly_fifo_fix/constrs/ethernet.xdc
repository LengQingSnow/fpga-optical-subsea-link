# AXKU115 + FL2121 four-port RGMII Ethernet constraints.
# Current pinout: FL2121 mounted on AXKU115 FMC1.
# If the FL2121 board is moved to FMC2/FMC3/FMC4, replace only the
# PACKAGE_PIN assignments in the Ethernet pin section with the matching
# mapping from support/hardware pin list.

set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]
set_property CONFIG_MODE SPIx4 [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 50 [current_design]
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
set_property BITSTREAM.CONFIG.UNUSEDPIN Pullup [current_design]
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]

# Board clock and reset.
set_property PACKAGE_PIN AK27 [get_ports sys_clk_p]
set_property IOSTANDARD DIFF_HSTL_I_18 [get_ports sys_clk_p]

set_property PACKAGE_PIN AL33 [get_ports rst_n]
set_property IOSTANDARD LVCMOS18 [get_ports rst_n]

set_property PACKAGE_PIN AG27 [get_ports fan]
set_property IOSTANDARD LVCMOS18 [get_ports fan]

# RGMII receive clocks from the four PHYs.
create_clock -period 8.000 -name rgmii1_rxc [get_ports rgmii1_rxc]
create_clock -period 8.000 -name rgmii2_rxc [get_ports rgmii2_rxc]
create_clock -period 8.000 -name rgmii3_rxc [get_ports rgmii3_rxc]
create_clock -period 8.000 -name rgmii4_rxc [get_ports rgmii4_rxc]

# Constrain the explicit RGMII receive clock buffers to the roots used by the
# known-good four-port implementation.
set_property USER_CLOCK_ROOT X2Y1 [get_nets rgmii1_rxc_bufg]
set_property USER_CLOCK_ROOT X2Y1 [get_nets rgmii2_rxc_bufg]
set_property USER_CLOCK_ROOT X0Y1 [get_nets rgmii3_rxc_bufg]
set_property USER_CLOCK_ROOT X0Y1 [get_nets rgmii4_rxc_bufg]
set_property USER_CLOCK_ROOT X2Y1 [get_nets rgmii1_rxc_phase]
set_property USER_CLOCK_ROOT X2Y1 [get_nets rgmii2_rxc_phase]
set_property USER_CLOCK_ROOT X0Y1 [get_nets rgmii3_rxc_phase]
set_property USER_CLOCK_ROOT X0Y1 [get_nets rgmii4_rxc_phase]

# Retain the legal stage-1 clock placement so unrelated logic cannot move the
# RGMII receive clock paths between builds. Feedback BUFG locations are added
# after the first implementation that preserves those cells.
set_property LOC BUFGCE_X1Y34 [get_cells rgmii1_rxc_bufg_inst]
set_property LOC BUFGCE_X1Y35 [get_cells rgmii2_rxc_bufg_inst]
set_property LOC BUFGCE_X0Y26 [get_cells rgmii3_rxc_bufg_inst]
set_property LOC BUFGCE_X0Y24 [get_cells rgmii4_rxc_bufg_inst]

set_property LOC PLLE3_ADV_X1Y3 [get_cells rgmii1_phase_inst/rx_pll_inst]
set_property LOC PLLE3_ADV_X1Y2 [get_cells rgmii2_phase_inst/rx_pll_inst]
set_property LOC PLLE3_ADV_X0Y3 [get_cells rgmii3_phase_inst/rx_pll_inst]
set_property LOC PLLE3_ADV_X0Y2 [get_cells rgmii4_phase_inst/rx_pll_inst]

set_property LOC BUFGCE_X1Y32 [get_cells rgmii1_phase_inst/output_bufg_inst]
set_property LOC BUFGCE_X1Y37 [get_cells rgmii2_phase_inst/output_bufg_inst]
set_property LOC BUFGCE_X0Y27 [get_cells rgmii3_phase_inst/output_bufg_inst]
set_property LOC BUFGCE_X0Y36 [get_cells rgmii4_phase_inst/output_bufg_inst]

set_property LOC BUFGCE_X1Y25 [get_cells rgmii1_phase_inst/feedback_bufg_inst]
set_property LOC BUFGCE_X1Y40 [get_cells rgmii2_phase_inst/feedback_bufg_inst]
set_property LOC BUFGCE_X0Y28 [get_cells rgmii3_phase_inst/feedback_bufg_inst]
set_property LOC BUFGCE_X0Y38 [get_cells rgmii4_phase_inst/feedback_bufg_inst]

# FL2121 straps JL2121 RXDLY and TXDLY high. At the FPGA pins, receive
# data is valid for at least 1 ns before and 1 ns after each RXC edge. Model
# the latest previous transition at -1 ns for setup and the earliest next
# transition at +1 ns for hold on both DDR edges.
set rgmii1_rx_ports [get_ports {rgmii1_rxd[*] rgmii1_rxctl}]
set_input_delay -clock [get_clocks rgmii1_rxc] -max -1.000 $rgmii1_rx_ports
set_input_delay -clock [get_clocks rgmii1_rxc] -min 1.000 $rgmii1_rx_ports
set_input_delay -clock [get_clocks rgmii1_rxc] -clock_fall -max -1.000 -add_delay $rgmii1_rx_ports
set_input_delay -clock [get_clocks rgmii1_rxc] -clock_fall -min 1.000 -add_delay $rgmii1_rx_ports

set rgmii2_rx_ports [get_ports {rgmii2_rxd[*] rgmii2_rxctl}]
set_input_delay -clock [get_clocks rgmii2_rxc] -max -1.000 $rgmii2_rx_ports
set_input_delay -clock [get_clocks rgmii2_rxc] -min 1.000 $rgmii2_rx_ports
set_input_delay -clock [get_clocks rgmii2_rxc] -clock_fall -max -1.000 -add_delay $rgmii2_rx_ports
set_input_delay -clock [get_clocks rgmii2_rxc] -clock_fall -min 1.000 -add_delay $rgmii2_rx_ports

set rgmii3_rx_ports [get_ports {rgmii3_rxd[*] rgmii3_rxctl}]
set_input_delay -clock [get_clocks rgmii3_rxc] -max -1.000 $rgmii3_rx_ports
set_input_delay -clock [get_clocks rgmii3_rxc] -min 1.000 $rgmii3_rx_ports
set_input_delay -clock [get_clocks rgmii3_rxc] -clock_fall -max -1.000 -add_delay $rgmii3_rx_ports
set_input_delay -clock [get_clocks rgmii3_rxc] -clock_fall -min 1.000 -add_delay $rgmii3_rx_ports

set rgmii4_rx_ports [get_ports {rgmii4_rxd[*] rgmii4_rxctl}]
set_input_delay -clock [get_clocks rgmii4_rxc] -max -1.000 $rgmii4_rx_ports
set_input_delay -clock [get_clocks rgmii4_rxc] -min 1.000 $rgmii4_rx_ports
set_input_delay -clock [get_clocks rgmii4_rxc] -clock_fall -max -1.000 -add_delay $rgmii4_rx_ports
set_input_delay -clock [get_clocks rgmii4_rxc] -clock_fall -min 1.000 -add_delay $rgmii4_rx_ports

# TXC and TXD/TX_CTL are edge aligned at the FPGA pins. FL2121 straps JL2121
# TXDLY high, so model the PHY's 2 ns internal TXC delay. The JL2121 delayed
# RGMII receiver requires at least 1 ns setup and 1 ns hold on both DDR edges.
create_generated_clock -name rgmii1_txc_io \
    -source [get_pins eth1/util_gmii_to_rgmii_m0/rgmii_txc_out/C] \
    -edges {1 2 3} -edge_shift {2.000 2.000 2.000} [get_ports rgmii1_txc]
set rgmii1_tx_ports [get_ports {rgmii1_txd[*] rgmii1_txctl}]
set_output_delay -clock [get_clocks rgmii1_txc_io] -max 1.000 $rgmii1_tx_ports
set_output_delay -clock [get_clocks rgmii1_txc_io] -min -1.000 $rgmii1_tx_ports
set_output_delay -clock [get_clocks rgmii1_txc_io] -clock_fall -max 1.000 -add_delay $rgmii1_tx_ports
set_output_delay -clock [get_clocks rgmii1_txc_io] -clock_fall -min -1.000 -add_delay $rgmii1_tx_ports

create_generated_clock -name rgmii2_txc_io \
    -source [get_pins eth2/util_gmii_to_rgmii_m0/rgmii_txc_out/C] \
    -edges {1 2 3} -edge_shift {2.000 2.000 2.000} [get_ports rgmii2_txc]
set rgmii2_tx_ports [get_ports {rgmii2_txd[*] rgmii2_txctl}]
set_output_delay -clock [get_clocks rgmii2_txc_io] -max 1.000 $rgmii2_tx_ports
set_output_delay -clock [get_clocks rgmii2_txc_io] -min -1.000 $rgmii2_tx_ports
set_output_delay -clock [get_clocks rgmii2_txc_io] -clock_fall -max 1.000 -add_delay $rgmii2_tx_ports
set_output_delay -clock [get_clocks rgmii2_txc_io] -clock_fall -min -1.000 -add_delay $rgmii2_tx_ports

create_generated_clock -name rgmii3_txc_io \
    -source [get_pins eth3/util_gmii_to_rgmii_m0/rgmii_txc_out/C] \
    -edges {1 2 3} -edge_shift {2.000 2.000 2.000} [get_ports rgmii3_txc]
set rgmii3_tx_ports [get_ports {rgmii3_txd[*] rgmii3_txctl}]
set_output_delay -clock [get_clocks rgmii3_txc_io] -max 1.000 $rgmii3_tx_ports
set_output_delay -clock [get_clocks rgmii3_txc_io] -min -1.000 $rgmii3_tx_ports
set_output_delay -clock [get_clocks rgmii3_txc_io] -clock_fall -max 1.000 -add_delay $rgmii3_tx_ports
set_output_delay -clock [get_clocks rgmii3_txc_io] -clock_fall -min -1.000 -add_delay $rgmii3_tx_ports

create_generated_clock -name rgmii4_txc_io \
    -source [get_pins eth4/util_gmii_to_rgmii_m0/rgmii_txc_out/C] \
    -edges {1 2 3} -edge_shift {2.000 2.000 2.000} [get_ports rgmii4_txc]
set rgmii4_tx_ports [get_ports {rgmii4_txd[*] rgmii4_txctl}]
set_output_delay -clock [get_clocks rgmii4_txc_io] -max 1.000 $rgmii4_tx_ports
set_output_delay -clock [get_clocks rgmii4_txc_io] -min -1.000 $rgmii4_tx_ports
set_output_delay -clock [get_clocks rgmii4_txc_io] -clock_fall -max 1.000 -add_delay $rgmii4_tx_ports
set_output_delay -clock [get_clocks rgmii4_txc_io] -clock_fall -min -1.000 -add_delay $rgmii4_tx_ports

# Common 1.8 V RGMII IO standards.
set_property IOSTANDARD LVCMOS18 [get_ports {
    e1_mdc e1_mdio e1_reset rgmii1_rxc rgmii1_rxctl rgmii1_txc rgmii1_txctl
    e2_mdc e2_mdio e2_reset rgmii2_rxc rgmii2_rxctl rgmii2_txc rgmii2_txctl
    e3_mdc e3_mdio e3_reset rgmii3_rxc rgmii3_rxctl rgmii3_txc rgmii3_txctl
    e4_mdc e4_mdio e4_reset rgmii4_rxc rgmii4_rxctl rgmii4_txc rgmii4_txctl
}]
set_property IOSTANDARD LVCMOS18 [get_ports {rgmii1_rxd[*]}]
set_property IOSTANDARD LVCMOS18 [get_ports {rgmii1_txd[*]}]
set_property IOSTANDARD LVCMOS18 [get_ports {rgmii2_rxd[*]}]
set_property IOSTANDARD LVCMOS18 [get_ports {rgmii2_txd[*]}]
set_property IOSTANDARD LVCMOS18 [get_ports {rgmii3_rxd[*]}]
set_property IOSTANDARD LVCMOS18 [get_ports {rgmii3_txd[*]}]
set_property IOSTANDARD LVCMOS18 [get_ports {rgmii4_rxd[*]}]
set_property IOSTANDARD LVCMOS18 [get_ports {rgmii4_txd[*]}]

set_property SLEW FAST [get_ports {
    rgmii1_txc rgmii1_txctl
    rgmii2_txc rgmii2_txctl
    rgmii3_txc rgmii3_txctl
    rgmii4_txc rgmii4_txctl
}]
set_property SLEW FAST [get_ports {rgmii1_txd[*]}]
set_property SLEW FAST [get_ports {rgmii2_txd[*]}]
set_property SLEW FAST [get_ports {rgmii3_txd[*]}]
set_property SLEW FAST [get_ports {rgmii4_txd[*]}]

# These RGMII outputs use BITSLICE_0 in bytes that run BISC calibration.
# Ethernet logic is held in reset until IDELAYCTRL RDY asserts, so the
# calibration-time unavailability is acceptable for this design.
set_property UNAVAILABLE_DURING_CALIBRATION TRUE [get_ports rgmii2_txctl]
set_property UNAVAILABLE_DURING_CALIBRATION TRUE [get_ports {rgmii3_txd[1]}]

# Ethernet 1, FL2121 PHY1 on AXKU115 FMC1.
set_property PACKAGE_PIN AL24 [get_ports e1_mdc]
set_property PACKAGE_PIN AJ26 [get_ports e1_mdio]
set_property PACKAGE_PIN AL25 [get_ports e1_reset]
set_property PACKAGE_PIN AM26 [get_ports rgmii1_rxc]
set_property PACKAGE_PIN AN26 [get_ports rgmii1_rxctl]
set_property PACKAGE_PIN AF24 [get_ports {rgmii1_rxd[0]}]
set_property PACKAGE_PIN AG24 [get_ports {rgmii1_rxd[1]}]
set_property PACKAGE_PIN AF25 [get_ports {rgmii1_rxd[2]}]
set_property PACKAGE_PIN AG25 [get_ports {rgmii1_rxd[3]}]
set_property PACKAGE_PIN AJ24 [get_ports rgmii1_txc]
set_property PACKAGE_PIN AV27 [get_ports rgmii1_txctl]
set_property PACKAGE_PIN AH24 [get_ports {rgmii1_txd[0]}]
set_property PACKAGE_PIN AW25 [get_ports {rgmii1_txd[1]}]
set_property PACKAGE_PIN AW26 [get_ports {rgmii1_txd[2]}]
set_property PACKAGE_PIN AV26 [get_ports {rgmii1_txd[3]}]

# Ethernet 2, FL2121 PHY2 on AXKU115 FMC1.
set_property PACKAGE_PIN AR25 [get_ports e2_mdc]
set_property PACKAGE_PIN AU26 [get_ports e2_mdio]
set_property PACKAGE_PIN AR27 [get_ports e2_reset]
set_property PACKAGE_PIN AM27 [get_ports rgmii2_rxc]
set_property PACKAGE_PIN AN27 [get_ports rgmii2_rxctl]
set_property PACKAGE_PIN AH26 [get_ports {rgmii2_rxd[0]}]
set_property PACKAGE_PIN AV28 [get_ports {rgmii2_rxd[1]}]
set_property PACKAGE_PIN AM25 [get_ports {rgmii2_rxd[2]}]
set_property PACKAGE_PIN AW28 [get_ports {rgmii2_rxd[3]}]
set_property PACKAGE_PIN AT28 [get_ports rgmii2_txc]
set_property PACKAGE_PIN AR26 [get_ports rgmii2_txctl]
set_property PACKAGE_PIN AU27 [get_ports {rgmii2_txd[0]}]
set_property PACKAGE_PIN AR28 [get_ports {rgmii2_txd[1]}]
set_property PACKAGE_PIN AN28 [get_ports {rgmii2_txd[2]}]
set_property PACKAGE_PIN AP28 [get_ports {rgmii2_txd[3]}]

# Ethernet 3, FL2121 PHY3 on AXKU115 FMC1.
set_property PACKAGE_PIN AN36 [get_ports e3_mdc]
set_property PACKAGE_PIN AM35 [get_ports e3_mdio]
set_property PACKAGE_PIN AN37 [get_ports e3_reset]
set_property PACKAGE_PIN AP36 [get_ports rgmii3_rxc]
set_property PACKAGE_PIN AR33 [get_ports rgmii3_rxctl]
set_property PACKAGE_PIN AT33 [get_ports {rgmii3_rxd[0]}]
set_property PACKAGE_PIN AT34 [get_ports {rgmii3_rxd[1]}]
set_property PACKAGE_PIN AV33 [get_ports {rgmii3_rxd[2]}]
set_property PACKAGE_PIN AV34 [get_ports {rgmii3_rxd[3]}]
set_property PACKAGE_PIN AU35 [get_ports rgmii3_txc]
set_property PACKAGE_PIN AM34 [get_ports rgmii3_txctl]
set_property PACKAGE_PIN AU34 [get_ports {rgmii3_txd[0]}]
set_property PACKAGE_PIN AW33 [get_ports {rgmii3_txd[1]}]
set_property PACKAGE_PIN AW34 [get_ports {rgmii3_txd[2]}]
set_property PACKAGE_PIN AT35 [get_ports {rgmii3_txd[3]}]

# Ethernet 4, FL2121 PHY4 on AXKU115 FMC1.
set_property PACKAGE_PIN AV36 [get_ports e4_mdc]
set_property PACKAGE_PIN AV38 [get_ports e4_mdio]
set_property PACKAGE_PIN AV39 [get_ports e4_reset]
set_property PACKAGE_PIN AR38 [get_ports rgmii4_rxc]
set_property PACKAGE_PIN AT38 [get_ports rgmii4_rxctl]
set_property PACKAGE_PIN AN34 [get_ports {rgmii4_rxd[0]}]
set_property PACKAGE_PIN AW35 [get_ports {rgmii4_rxd[1]}]
set_property PACKAGE_PIN AP34 [get_ports {rgmii4_rxd[2]}]
set_property PACKAGE_PIN AW36 [get_ports {rgmii4_rxd[3]}]
set_property PACKAGE_PIN AL38 [get_ports rgmii4_txc]
set_property PACKAGE_PIN AU36 [get_ports rgmii4_txctl]
set_property PACKAGE_PIN AM37 [get_ports {rgmii4_txd[0]}]
set_property PACKAGE_PIN AL37 [get_ports {rgmii4_txd[1]}]
set_property PACKAGE_PIN AL34 [get_ports {rgmii4_txd[2]}]
set_property PACKAGE_PIN AL35 [get_ports {rgmii4_txd[3]}]

# The board system clock and PHY RX clocks are asynchronous.
set_false_path -from [get_clocks -of_objects [get_pins pll_inst/inst/mmcme3_adv_inst/CLKOUT0]] -to [get_clocks rgmii1_rxc]
set_false_path -from [get_clocks rgmii1_rxc] -to [get_clocks -of_objects [get_pins pll_inst/inst/mmcme3_adv_inst/CLKOUT0]]
set_false_path -from [get_clocks -of_objects [get_pins pll_inst/inst/mmcme3_adv_inst/CLKOUT0]] -to [get_clocks rgmii2_rxc]
set_false_path -from [get_clocks rgmii2_rxc] -to [get_clocks -of_objects [get_pins pll_inst/inst/mmcme3_adv_inst/CLKOUT0]]
set_false_path -from [get_clocks -of_objects [get_pins pll_inst/inst/mmcme3_adv_inst/CLKOUT0]] -to [get_clocks rgmii3_rxc]
set_false_path -from [get_clocks rgmii3_rxc] -to [get_clocks -of_objects [get_pins pll_inst/inst/mmcme3_adv_inst/CLKOUT0]]
set_false_path -from [get_clocks -of_objects [get_pins pll_inst/inst/mmcme3_adv_inst/CLKOUT0]] -to [get_clocks rgmii4_rxc]
set_false_path -from [get_clocks rgmii4_rxc] -to [get_clocks -of_objects [get_pins pll_inst/inst/mmcme3_adv_inst/CLKOUT0]]
