`timescale 1ns / 1ps

module top
    (
        input           sys_clk_p,
        input           sys_clk_n,
        input           rst_n,

        output          e1_mdc,
        inout           e1_mdio,
        output          e1_reset,
        output [3:0]    rgmii1_txd,
        output          rgmii1_txctl,
        output          rgmii1_txc,
        input  [3:0]    rgmii1_rxd,
        input           rgmii1_rxctl,
        input           rgmii1_rxc,

        output          e2_mdc,
        inout           e2_mdio,
        output          e2_reset,
        output [3:0]    rgmii2_txd,
        output          rgmii2_txctl,
        output          rgmii2_txc,
        input  [3:0]    rgmii2_rxd,
        input           rgmii2_rxctl,
        input           rgmii2_rxc,

        output          e3_mdc,
        inout           e3_mdio,
        output          e3_reset,
        output [3:0]    rgmii3_txd,
        output          rgmii3_txctl,
        output          rgmii3_txc,
        input  [3:0]    rgmii3_rxd,
        input           rgmii3_rxctl,
        input           rgmii3_rxc,

        output          e4_mdc,
        inout           e4_mdio,
        output          e4_reset,
        output [3:0]    rgmii4_txd,
        output          rgmii4_txctl,
        output          rgmii4_txc,
        input  [3:0]    rgmii4_rxd,
        input           rgmii4_rxctl,
        input           rgmii4_rxc,

        input           qsfp1_refclk_p,
        input           qsfp1_refclk_n,
        output [0:3]    qsfp1_txp,
        output [0:3]    qsfp1_txn,
        input           qsfp2_refclk_p,
        input           qsfp2_refclk_n,
        input  [0:3]    qsfp2_rxp,
        input  [0:3]    qsfp2_rxn,

        output          fan
    );

wire key_low;
wire sys_clk;
wire locked;
wire ref_200M;
wire rdy;
wire eth_rst_n;
wire eth_sys_rst_n;
wire qpsk_clk;
wire qpsk_locked;
wire qpsk_rst_n;
(* KEEP = "true" *) wire rgmii1_rxc_bufg;
(* KEEP = "true" *) wire rgmii2_rxc_bufg;
  (* KEEP = "true" *) wire rgmii3_rxc_bufg;
  (* KEEP = "true" *) wire rgmii4_rxc_bufg;
  (* KEEP = "true" *) wire rgmii1_rxc_phase;
  (* KEEP = "true" *) wire rgmii2_rxc_phase;
  (* KEEP = "true" *) wire rgmii3_rxc_phase;
  (* KEEP = "true" *) wire rgmii4_rxc_phase;
  wire rgmii1_phase_locked;
  wire rgmii2_phase_locked;
  wire rgmii3_phase_locked;
  wire rgmii4_phase_locked;
  wire eth1_rst_n;
  wire eth2_rst_n;
  wire eth3_rst_n;
  wire eth4_rst_n;
wire eth1_aggregate_clk;
wire eth2_aggregate_clk;
wire eth3_aggregate_clk;
wire eth4_aggregate_clk;
wire [7:0] eth1_aggregate_data;
wire [7:0] eth2_aggregate_data;
wire [7:0] eth3_aggregate_data;
wire [7:0] eth4_aggregate_data;
wire eth1_aggregate_valid;
wire eth2_aggregate_valid;
wire eth3_aggregate_valid;
wire eth4_aggregate_valid;
wire eth1_aggregate_ready;
wire eth2_aggregate_ready;
wire eth3_aggregate_ready;
wire eth4_aggregate_ready;
wire [23:0] eth1_aggregate_packet_data;
wire [23:0] eth2_aggregate_packet_data;
wire [23:0] eth3_aggregate_packet_data;
wire [23:0] eth4_aggregate_packet_data;
wire eth1_aggregate_packet_valid;
wire eth2_aggregate_packet_valid;
wire eth3_aggregate_packet_valid;
wire eth4_aggregate_packet_valid;
wire [31:0] aggregate_packet_count0;
wire [31:0] aggregate_packet_count1;
wire [31:0] aggregate_packet_count2;
wire [31:0] aggregate_packet_count3;
wire [31:0] aggregate_byte_count0;
wire [31:0] aggregate_byte_count1;
wire [31:0] aggregate_byte_count2;
wire [31:0] aggregate_byte_count3;
wire [3:0] aggregate_payload_overflow;
wire [3:0] aggregate_descriptor_overflow;
wire [31:0] eth1_rx_mac_good_count;
wire [31:0] eth1_rx_mac_crc_error_count;
wire [31:0] eth1_rx_ip_checksum_error_count;
wire [31:0] eth1_rx_udp_checksum_error_count;
wire [31:0] eth1_rx_udp_packet_commit_count;
wire [31:0] eth1_rx_udp_buffer_overflow_count;
wire [31:0] eth2_rx_mac_good_count;
wire [31:0] eth2_rx_mac_crc_error_count;
wire [31:0] eth2_rx_ip_checksum_error_count;
wire [31:0] eth2_rx_udp_checksum_error_count;
wire [31:0] eth2_rx_udp_packet_commit_count;
wire [31:0] eth2_rx_udp_buffer_overflow_count;
wire [31:0] eth3_rx_mac_good_count;
wire [31:0] eth3_rx_mac_crc_error_count;
wire [31:0] eth3_rx_ip_checksum_error_count;
wire [31:0] eth3_rx_udp_checksum_error_count;
wire [31:0] eth3_rx_udp_packet_commit_count;
wire [31:0] eth3_rx_udp_buffer_overflow_count;
wire [31:0] eth4_rx_mac_good_count;
wire [31:0] eth4_rx_mac_crc_error_count;
wire [31:0] eth4_rx_ip_checksum_error_count;
wire [31:0] eth4_rx_udp_checksum_error_count;
wire [31:0] eth4_rx_udp_packet_commit_count;
wire [31:0] eth4_rx_udp_buffer_overflow_count;
wire [191:0] eth1_rx_debug_counts_qpsk;
wire [191:0] eth2_rx_debug_counts_qpsk;
wire [191:0] eth3_rx_debug_counts_qpsk;
wire [191:0] eth4_rx_debug_counts_qpsk;
wire [127:0] rx_mac_good_counts_qpsk;
wire [127:0] rx_mac_crc_error_counts_qpsk;
wire [127:0] rx_ip_checksum_error_counts_qpsk;
wire [127:0] rx_udp_checksum_error_counts_qpsk;
wire [127:0] rx_udp_packet_commit_counts_qpsk;
wire [127:0] rx_udp_buffer_overflow_counts_qpsk;
(* KEEP = "true", DONT_TOUCH = "true", MARK_DEBUG = "true" *) wire [127:0] qpsk_bits;
(* KEEP = "true", DONT_TOUCH = "true", MARK_DEBUG = "true" *) wire qpsk_valid;
(* KEEP = "true", DONT_TOUCH = "true", MARK_DEBUG = "true" *) wire qpsk_frame_start;
(* KEEP = "true", DONT_TOUCH = "true", MARK_DEBUG = "true" *) wire qpsk_frame_end;
wire [255:0] qsfp_tx_tdata;
wire [31:0] qsfp_tx_tkeep;
wire qsfp_tx_tvalid;
wire qsfp_tx_tready;
wire qsfp_tx_tlast;
wire qsfp_tx_user_clk;
wire qsfp_tx_channel_up;
wire [0:3] qsfp_tx_lane_up;
wire qsfp_tx_hard_err;
wire qsfp_tx_soft_err;
wire [255:0] qsfp_rx_tdata;
wire [31:0] qsfp_rx_tkeep;
wire qsfp_rx_tvalid;
wire qsfp_rx_tlast;
wire qsfp_rx_user_clk;
wire qsfp_rx_channel_up;
wire [0:3] qsfp_rx_lane_up;
wire qsfp_rx_hard_err;
wire qsfp_rx_soft_err;
wire aurora_reset_ready;
wire qsfp_bridge_overflow;
wire qsfp_bridge_frame_error;
wire [31:0] qsfp_tx_frame_count;
wire [31:0] qsfp_rx_frame_count;
wire [31:0] qsfp_data_error_count;
wire [31:0] qsfp_half_swap_error_count;
wire [31:0] qsfp_boundary_error_count;
wire [31:0] qsfp_underflow_count;
wire [31:0] qsfp_idle_frame_count;
wire [31:0] qsfp_data_frame_count;
wire qsfp_reference_overflow;
wire qsfp_header_error;
wire [255:0] qsfp_expected_data;
wire qsfp_expected_tlast;
wire qsfp_expected_valid;
wire qsfp_link_ready_qpsk;
wire qsfp_link_ready_tx;
wire qsfp_link_ready_rx;
reg qsfp_tx_up_qpsk_d0;
reg qsfp_tx_up_qpsk_d1;
reg qsfp_rx_up_qpsk_d0;
reg qsfp_rx_up_qpsk_d1;
reg qsfp_rx_up_tx_d0;
reg qsfp_rx_up_tx_d1;
reg qsfp_tx_up_rx_d0;
reg qsfp_tx_up_rx_d1;
wire aurora_ready_tx_sync_n;
wire aurora_ready_rx_sync_n;
reg qsfp_bridge_overflow_rx_d0;
reg qsfp_bridge_overflow_rx_d1;
reg qsfp_bridge_frame_error_rx_d0;
reg qsfp_bridge_frame_error_rx_d1;
reg qsfp_tx_error_sticky;
reg qsfp_tx_error_rx_d0;
reg qsfp_tx_error_rx_d1;
reg qsfp_rx_error_sticky;

reg reset_delay;
reg reset_delay_d0;
reg reset_delay_d1;

reg reset_ctrl;
reg reset_ctrl_d0;
reg reset_ctrl_d1;

wire phy_reset_n;

assign fan = 1'b0;

// Hold the Ethernet ports in reset until the clocking and IDELAY resources are ready.
assign eth_rst_n = locked & rdy;
assign qpsk_rst_n = eth_rst_n & qpsk_locked;
assign qsfp_link_ready_qpsk = qsfp_tx_up_qpsk_d1;
assign qsfp_link_ready_tx = aurora_ready_tx_sync_n & qsfp_tx_channel_up;
assign qsfp_link_ready_rx = aurora_ready_rx_sync_n & qsfp_rx_channel_up & qsfp_tx_up_rx_d1;

assign e1_reset = phy_reset_n;
assign e2_reset = phy_reset_n;
assign e3_reset = phy_reset_n;
assign e4_reset = phy_reset_n;

(* DONT_TOUCH = "true" *)
BUFGCE #(
    .CE_TYPE("SYNC"),
    .IS_CE_INVERTED(1'b0),
    .IS_I_INVERTED(1'b0),
    .SIM_DEVICE("ULTRASCALE")
) rgmii1_rxc_bufg_inst (
    .I(rgmii1_rxc),
    .CE(1'b1),
    .O(rgmii1_rxc_bufg)
);

(* DONT_TOUCH = "true" *)
BUFGCE #(
    .CE_TYPE("SYNC"),
    .IS_CE_INVERTED(1'b0),
    .IS_I_INVERTED(1'b0),
    .SIM_DEVICE("ULTRASCALE")
) rgmii2_rxc_bufg_inst (
    .I(rgmii2_rxc),
    .CE(1'b1),
    .O(rgmii2_rxc_bufg)
);

(* DONT_TOUCH = "true" *)
BUFGCE #(
    .CE_TYPE("SYNC"),
    .IS_CE_INVERTED(1'b0),
    .IS_I_INVERTED(1'b0),
    .SIM_DEVICE("ULTRASCALE")
) rgmii3_rxc_bufg_inst (
    .I(rgmii3_rxc),
    .CE(1'b1),
    .O(rgmii3_rxc_bufg)
);

(* DONT_TOUCH = "true" *)
BUFGCE #(
    .CE_TYPE("SYNC"),
    .IS_CE_INVERTED(1'b0),
    .IS_I_INVERTED(1'b0),
    .SIM_DEVICE("ULTRASCALE")
) rgmii4_rxc_bufg_inst (
    .I(rgmii4_rxc),
    .CE(1'b1),
    .O(rgmii4_rxc_bufg)
);

rgmii_rx_clock_phase #(
    .CLKOUT_PHASE_DEGREES(-90.0)
) rgmii1_phase_inst (
    .clk_in(rgmii1_rxc_bufg),
    .reset(!locked),
    .clk_out(rgmii1_rxc_phase),
    .locked(rgmii1_phase_locked)
);

rgmii_rx_clock_phase #(
    .CLKOUT_PHASE_DEGREES(-90.0)
) rgmii2_phase_inst (
    .clk_in(rgmii2_rxc_bufg),
    .reset(!locked),
    .clk_out(rgmii2_rxc_phase),
    .locked(rgmii2_phase_locked)
);

rgmii_rx_clock_phase #(
    .CLKOUT_PHASE_DEGREES(-90.0)
) rgmii3_phase_inst (
    .clk_in(rgmii3_rxc_bufg),
    .reset(!locked),
    .clk_out(rgmii3_rxc_phase),
    .locked(rgmii3_phase_locked)
);

rgmii_rx_clock_phase #(
    .CLKOUT_PHASE_DEGREES(-90.0)
) rgmii4_phase_inst (
    .clk_in(rgmii4_rxc_bufg),
    .reset(!locked),
    .clk_out(rgmii4_rxc_phase),
    .locked(rgmii4_phase_locked)
);

async_reset_sync eth1_reset_sync_inst (
    .clk(rgmii1_rxc_phase),
    .async_reset_n(eth_rst_n & rgmii1_phase_locked),
    .sync_reset_n(eth1_rst_n)
);

async_reset_sync eth2_reset_sync_inst (
    .clk(rgmii2_rxc_phase),
    .async_reset_n(eth_rst_n & rgmii2_phase_locked),
    .sync_reset_n(eth2_rst_n)
);

async_reset_sync eth3_reset_sync_inst (
    .clk(rgmii3_rxc_phase),
    .async_reset_n(eth_rst_n & rgmii3_phase_locked),
    .sync_reset_n(eth3_rst_n)
);

async_reset_sync eth4_reset_sync_inst (
    .clk(rgmii4_rxc_phase),
    .async_reset_n(eth_rst_n & rgmii4_phase_locked),
    .sync_reset_n(eth4_rst_n)
);

async_reset_sync eth_sys_reset_sync_inst (
    .clk(sys_clk),
    .async_reset_n(eth_rst_n),
    .sync_reset_n(eth_sys_rst_n)
);

phy_reset_controller #(
    .HOLD_CYCLES(1_000_000),
    .COUNTER_WIDTH(20)
) phy_reset_ctrl_inst (
    .clk(sys_clk),
    .reset_request(key_low || !rst_n),
    .clock_ready(locked),
    .phy_reset_n(phy_reset_n)
);

clk_wiz_0 pll_inst
   (
    .clk_out1(sys_clk),
    .clk_out2(ref_200M),
    .reset(key_low),
    .locked(locked),
    .clk_in1_p(sys_clk_p),
    .clk_in1_n(sys_clk_n)
   );

clk_wiz_qpsk qpsk_clock_inst
   (
    .clk_out1(qpsk_clk),
    .reset(key_low),
    .locked(qpsk_locked),
    .clk_in1(sys_clk)
   );

always @ (posedge ref_200M) begin
    if (locked == 1'b0) begin
        reset_delay    <= 1'b1;
        reset_delay_d0 <= 1'b1;
        reset_delay_d1 <= 1'b1;
    end
    else begin
        reset_delay    <= 1'b0;
        reset_delay_d0 <= reset_delay;
        reset_delay_d1 <= reset_delay_d0;
    end
end

always @ (posedge ref_200M) begin
    if (locked == 1'b0) begin
        reset_ctrl    <= 1'b1;
        reset_ctrl_d0 <= 1'b1;
        reset_ctrl_d1 <= 1'b1;
    end
    else begin
        reset_ctrl    <= reset_delay_d1;
        reset_ctrl_d0 <= reset_ctrl;
        reset_ctrl_d1 <= reset_ctrl_d0;
    end
end

(* IODELAY_GROUP = "rgmii_idelay_group" *)
IDELAYCTRL #(
   .SIM_DEVICE("ULTRASCALE")
) IDELAYCTRL_inst (
  .RDY(rdy),
  .REFCLK(ref_200M),
  .RST(reset_ctrl_d1)
);

ethernet_test #(
    .LOCAL_MAC_ADDR(48'h00_0a_35_01_fe_c1),
    .LOCAL_IP_ADDR (32'hc0a80011),
    .DEST_IP_ADDR  (32'hc0a80003),
    .RXD0_DELAY_PS (1000),
    .RXD1_DELAY_PS (1000),
    .RXD2_DELAY_PS (1000),
    .RXD3_DELAY_PS (1000),
    .RX_CTL_DELAY_PS(1000)
) eth1 (
    .rst_n       (eth1_rst_n),
    .sys_rst_n   (eth_sys_rst_n),
    .sys_clk     (sys_clk),
    .led         (),
    .e_mdc       (e1_mdc),
    .e_mdio      (e1_mdio),
    .rgmii_txd   (rgmii1_txd),
    .rgmii_txctl (rgmii1_txctl),
    .rgmii_txc   (rgmii1_txc),
    .rgmii_rxd   (rgmii1_rxd),
    .rgmii_rxctl (rgmii1_rxctl),
    .rgmii_rxc   (rgmii1_rxc_phase),
    .aggregate_clk   (eth1_aggregate_clk),
    .aggregate_data  (eth1_aggregate_data),
    .aggregate_valid (eth1_aggregate_valid),
    .aggregate_ready (eth1_aggregate_ready),
    .aggregate_packet_data  (eth1_aggregate_packet_data),
    .aggregate_packet_valid (eth1_aggregate_packet_valid),
    .rx_mac_good_count           (eth1_rx_mac_good_count),
    .rx_mac_crc_error_count      (eth1_rx_mac_crc_error_count),
    .rx_ip_checksum_error_count  (eth1_rx_ip_checksum_error_count),
    .rx_udp_checksum_error_count (eth1_rx_udp_checksum_error_count),
    .rx_udp_packet_commit_count  (eth1_rx_udp_packet_commit_count),
    .rx_udp_buffer_overflow_count(eth1_rx_udp_buffer_overflow_count)
);

ethernet_test #(
    .LOCAL_MAC_ADDR(48'h00_0a_35_01_fe_c2),
    .LOCAL_IP_ADDR (32'hc0a80012),
    .DEST_IP_ADDR  (32'hc0a80003),
    .RXD0_DELAY_PS (1000),
    .RXD1_DELAY_PS (1000),
    .RXD2_DELAY_PS (1000),
    .RXD3_DELAY_PS (1000),
    .RX_CTL_DELAY_PS(1000)
) eth2 (
    .rst_n       (eth2_rst_n),
    .sys_rst_n   (eth_sys_rst_n),
    .sys_clk     (sys_clk),
    .led         (),
    .e_mdc       (e2_mdc),
    .e_mdio      (e2_mdio),
    .rgmii_txd   (rgmii2_txd),
    .rgmii_txctl (rgmii2_txctl),
    .rgmii_txc   (rgmii2_txc),
    .rgmii_rxd   (rgmii2_rxd),
    .rgmii_rxctl (rgmii2_rxctl),
    .rgmii_rxc   (rgmii2_rxc_phase),
    .aggregate_clk   (eth2_aggregate_clk),
    .aggregate_data  (eth2_aggregate_data),
    .aggregate_valid (eth2_aggregate_valid),
    .aggregate_ready (eth2_aggregate_ready),
    .aggregate_packet_data  (eth2_aggregate_packet_data),
    .aggregate_packet_valid (eth2_aggregate_packet_valid),
    .rx_mac_good_count           (eth2_rx_mac_good_count),
    .rx_mac_crc_error_count      (eth2_rx_mac_crc_error_count),
    .rx_ip_checksum_error_count  (eth2_rx_ip_checksum_error_count),
    .rx_udp_checksum_error_count (eth2_rx_udp_checksum_error_count),
    .rx_udp_packet_commit_count  (eth2_rx_udp_packet_commit_count),
    .rx_udp_buffer_overflow_count(eth2_rx_udp_buffer_overflow_count)
);

ethernet_test #(
    .LOCAL_MAC_ADDR(48'h00_0a_35_01_fe_c3),
    .LOCAL_IP_ADDR (32'hc0a80013),
    .DEST_IP_ADDR  (32'hc0a80003),
    .RXD0_DELAY_PS (1000),
    .RXD1_DELAY_PS (1000),
    .RXD2_DELAY_PS (1000),
    .RXD3_DELAY_PS (1000),
    .RX_CTL_DELAY_PS(1000)
) eth3 (
    .rst_n       (eth3_rst_n),
    .sys_rst_n   (eth_sys_rst_n),
    .sys_clk     (sys_clk),
    .led         (),
    .e_mdc       (e3_mdc),
    .e_mdio      (e3_mdio),
    .rgmii_txd   (rgmii3_txd),
    .rgmii_txctl (rgmii3_txctl),
    .rgmii_txc   (rgmii3_txc),
    .rgmii_rxd   (rgmii3_rxd),
    .rgmii_rxctl (rgmii3_rxctl),
    .rgmii_rxc   (rgmii3_rxc_phase),
    .aggregate_clk   (eth3_aggregate_clk),
    .aggregate_data  (eth3_aggregate_data),
    .aggregate_valid (eth3_aggregate_valid),
    .aggregate_ready (eth3_aggregate_ready),
    .aggregate_packet_data  (eth3_aggregate_packet_data),
    .aggregate_packet_valid (eth3_aggregate_packet_valid),
    .rx_mac_good_count           (eth3_rx_mac_good_count),
    .rx_mac_crc_error_count      (eth3_rx_mac_crc_error_count),
    .rx_ip_checksum_error_count  (eth3_rx_ip_checksum_error_count),
    .rx_udp_checksum_error_count (eth3_rx_udp_checksum_error_count),
    .rx_udp_packet_commit_count  (eth3_rx_udp_packet_commit_count),
    .rx_udp_buffer_overflow_count(eth3_rx_udp_buffer_overflow_count)
);

ethernet_test #(
    .LOCAL_MAC_ADDR(48'h00_0a_35_01_fe_c4),
    .LOCAL_IP_ADDR (32'hc0a80014),
    .DEST_IP_ADDR  (32'hc0a80003),
    .RXD0_DELAY_PS (1000),
    .RXD1_DELAY_PS (1000),
    .RXD2_DELAY_PS (1000),
    .RXD3_DELAY_PS (1000),
    .RX_CTL_DELAY_PS(1000)
) eth4 (
    .rst_n       (eth4_rst_n),
    .sys_rst_n   (eth_sys_rst_n),
    .sys_clk     (sys_clk),
    .led         (),
    .e_mdc       (e4_mdc),
    .e_mdio      (e4_mdio),
    .rgmii_txd   (rgmii4_txd),
    .rgmii_txctl (rgmii4_txctl),
    .rgmii_txc   (rgmii4_txc),
    .rgmii_rxd   (rgmii4_rxd),
    .rgmii_rxctl (rgmii4_rxctl),
    .rgmii_rxc   (rgmii4_rxc_phase),
    .aggregate_clk   (eth4_aggregate_clk),
    .aggregate_data  (eth4_aggregate_data),
    .aggregate_valid (eth4_aggregate_valid),
    .aggregate_ready (eth4_aggregate_ready),
    .aggregate_packet_data  (eth4_aggregate_packet_data),
    .aggregate_packet_valid (eth4_aggregate_packet_valid),
    .rx_mac_good_count           (eth4_rx_mac_good_count),
    .rx_mac_crc_error_count      (eth4_rx_mac_crc_error_count),
    .rx_ip_checksum_error_count  (eth4_rx_ip_checksum_error_count),
    .rx_udp_checksum_error_count (eth4_rx_udp_checksum_error_count),
    .rx_udp_packet_commit_count  (eth4_rx_udp_packet_commit_count),
    .rx_udp_buffer_overflow_count(eth4_rx_udp_buffer_overflow_count)
);

debug_counter_cdc #(.COUNTER_COUNT(6)) eth1_rx_counter_cdc_inst (
    .src_clk(rgmii1_rxc_phase),
    .src_rst_n(eth1_rst_n),
    .src_counts({eth1_rx_udp_buffer_overflow_count,
                 eth1_rx_udp_packet_commit_count,
                 eth1_rx_udp_checksum_error_count,
                 eth1_rx_ip_checksum_error_count,
                 eth1_rx_mac_crc_error_count,
                 eth1_rx_mac_good_count}),
    .dest_clk(qpsk_clk),
    .dest_rst_n(qpsk_rst_n),
    .dest_counts(eth1_rx_debug_counts_qpsk)
);

debug_counter_cdc #(.COUNTER_COUNT(6)) eth2_rx_counter_cdc_inst (
    .src_clk(rgmii2_rxc_phase),
    .src_rst_n(eth2_rst_n),
    .src_counts({eth2_rx_udp_buffer_overflow_count,
                 eth2_rx_udp_packet_commit_count,
                 eth2_rx_udp_checksum_error_count,
                 eth2_rx_ip_checksum_error_count,
                 eth2_rx_mac_crc_error_count,
                 eth2_rx_mac_good_count}),
    .dest_clk(qpsk_clk),
    .dest_rst_n(qpsk_rst_n),
    .dest_counts(eth2_rx_debug_counts_qpsk)
);

debug_counter_cdc #(.COUNTER_COUNT(6)) eth3_rx_counter_cdc_inst (
    .src_clk(rgmii3_rxc_phase),
    .src_rst_n(eth3_rst_n),
    .src_counts({eth3_rx_udp_buffer_overflow_count,
                 eth3_rx_udp_packet_commit_count,
                 eth3_rx_udp_checksum_error_count,
                 eth3_rx_ip_checksum_error_count,
                 eth3_rx_mac_crc_error_count,
                 eth3_rx_mac_good_count}),
    .dest_clk(qpsk_clk),
    .dest_rst_n(qpsk_rst_n),
    .dest_counts(eth3_rx_debug_counts_qpsk)
);

debug_counter_cdc #(.COUNTER_COUNT(6)) eth4_rx_counter_cdc_inst (
    .src_clk(rgmii4_rxc_phase),
    .src_rst_n(eth4_rst_n),
    .src_counts({eth4_rx_udp_buffer_overflow_count,
                 eth4_rx_udp_packet_commit_count,
                 eth4_rx_udp_checksum_error_count,
                 eth4_rx_ip_checksum_error_count,
                 eth4_rx_mac_crc_error_count,
                 eth4_rx_mac_good_count}),
    .dest_clk(qpsk_clk),
    .dest_rst_n(qpsk_rst_n),
    .dest_counts(eth4_rx_debug_counts_qpsk)
);

assign rx_mac_good_counts_qpsk =
    {eth4_rx_debug_counts_qpsk[31:0], eth3_rx_debug_counts_qpsk[31:0],
     eth2_rx_debug_counts_qpsk[31:0], eth1_rx_debug_counts_qpsk[31:0]};
assign rx_mac_crc_error_counts_qpsk =
    {eth4_rx_debug_counts_qpsk[63:32], eth3_rx_debug_counts_qpsk[63:32],
     eth2_rx_debug_counts_qpsk[63:32], eth1_rx_debug_counts_qpsk[63:32]};
assign rx_ip_checksum_error_counts_qpsk =
    {eth4_rx_debug_counts_qpsk[95:64], eth3_rx_debug_counts_qpsk[95:64],
     eth2_rx_debug_counts_qpsk[95:64], eth1_rx_debug_counts_qpsk[95:64]};
assign rx_udp_checksum_error_counts_qpsk =
    {eth4_rx_debug_counts_qpsk[127:96], eth3_rx_debug_counts_qpsk[127:96],
     eth2_rx_debug_counts_qpsk[127:96], eth1_rx_debug_counts_qpsk[127:96]};
assign rx_udp_packet_commit_counts_qpsk =
    {eth4_rx_debug_counts_qpsk[159:128], eth3_rx_debug_counts_qpsk[159:128],
     eth2_rx_debug_counts_qpsk[159:128], eth1_rx_debug_counts_qpsk[159:128]};
assign rx_udp_buffer_overflow_counts_qpsk =
    {eth4_rx_debug_counts_qpsk[191:160], eth3_rx_debug_counts_qpsk[191:160],
     eth2_rx_debug_counts_qpsk[191:160], eth1_rx_debug_counts_qpsk[191:160]};

(* KEEP_HIERARCHY = "yes", DONT_TOUCH = "yes" *)
eth_aggregate_4port aggregate_inst
(
    .rst_n      (qpsk_rst_n),
    .agg_clk    (qpsk_clk),
    .in0_clk    (eth1_aggregate_clk),
    .in0_data   (eth1_aggregate_data),
    .in0_valid  (eth1_aggregate_valid),
    .in0_ready  (eth1_aggregate_ready),
    .in0_desc_data  (eth1_aggregate_packet_data),
    .in0_desc_valid (eth1_aggregate_packet_valid),
    .in1_clk    (eth2_aggregate_clk),
    .in1_data   (eth2_aggregate_data),
    .in1_valid  (eth2_aggregate_valid),
    .in1_ready  (eth2_aggregate_ready),
    .in1_desc_data  (eth2_aggregate_packet_data),
    .in1_desc_valid (eth2_aggregate_packet_valid),
    .in2_clk    (eth3_aggregate_clk),
    .in2_data   (eth3_aggregate_data),
    .in2_valid  (eth3_aggregate_valid),
    .in2_ready  (eth3_aggregate_ready),
    .in2_desc_data  (eth3_aggregate_packet_data),
    .in2_desc_valid (eth3_aggregate_packet_valid),
    .in3_clk    (eth4_aggregate_clk),
    .in3_data   (eth4_aggregate_data),
    .in3_valid  (eth4_aggregate_valid),
    .in3_ready  (eth4_aggregate_ready),
    .in3_desc_data  (eth4_aggregate_packet_data),
    .in3_desc_valid (eth4_aggregate_packet_valid),
    .qpsk_bits  (qpsk_bits),
    .qpsk_valid (qpsk_valid),
    .frame_start(qpsk_frame_start),
    .frame_end  (qpsk_frame_end),
    .accepted_packet_count0(aggregate_packet_count0),
    .accepted_packet_count1(aggregate_packet_count1),
    .accepted_packet_count2(aggregate_packet_count2),
    .accepted_packet_count3(aggregate_packet_count3),
    .accepted_byte_count0(aggregate_byte_count0),
    .accepted_byte_count1(aggregate_byte_count1),
    .accepted_byte_count2(aggregate_byte_count2),
    .accepted_byte_count3(aggregate_byte_count3),
    .payload_overflow(aggregate_payload_overflow),
    .descriptor_overflow(aggregate_descriptor_overflow)
);

always @(posedge qpsk_clk or negedge qpsk_rst_n) begin
    if (!qpsk_rst_n) begin
        qsfp_tx_up_qpsk_d0 <= 1'b0;
        qsfp_tx_up_qpsk_d1 <= 1'b0;
        qsfp_rx_up_qpsk_d0 <= 1'b0;
        qsfp_rx_up_qpsk_d1 <= 1'b0;
    end else begin
        qsfp_tx_up_qpsk_d0 <= qsfp_tx_channel_up;
        qsfp_tx_up_qpsk_d1 <= qsfp_tx_up_qpsk_d0;
        qsfp_rx_up_qpsk_d0 <= qsfp_rx_channel_up;
        qsfp_rx_up_qpsk_d1 <= qsfp_rx_up_qpsk_d0;
    end
end

async_reset_sync aurora_ready_tx_sync_inst (
    .clk(qsfp_tx_user_clk),
    .async_reset_n(aurora_reset_ready),
    .sync_reset_n(aurora_ready_tx_sync_n)
);

async_reset_sync aurora_ready_rx_sync_inst (
    .clk(qsfp_rx_user_clk),
    .async_reset_n(aurora_reset_ready),
    .sync_reset_n(aurora_ready_rx_sync_n)
);

always @(posedge qsfp_tx_user_clk) begin
    if (!aurora_ready_tx_sync_n) begin
        qsfp_rx_up_tx_d0 <= 1'b0;
        qsfp_rx_up_tx_d1 <= 1'b0;
    end else begin
        qsfp_rx_up_tx_d0 <= qsfp_rx_channel_up;
        qsfp_rx_up_tx_d1 <= qsfp_rx_up_tx_d0;
    end
end

always @(posedge qsfp_rx_user_clk) begin
    if (!aurora_ready_rx_sync_n) begin
        qsfp_tx_up_rx_d0 <= 1'b0;
        qsfp_tx_up_rx_d1 <= 1'b0;
    end else begin
        qsfp_tx_up_rx_d0 <= qsfp_tx_channel_up;
        qsfp_tx_up_rx_d1 <= qsfp_tx_up_rx_d0;
    end
end

qsfp_axis_tx_bridge qsfp_tx_bridge_inst (
    .source_clk(qpsk_clk),
    .source_rst_n(qpsk_rst_n & qsfp_link_ready_qpsk),
    .link_ready(qsfp_link_ready_qpsk),
    .source_data(qpsk_bits),
    .source_valid(qpsk_valid),
    .source_frame_start(qpsk_frame_start),
    .source_frame_end(qpsk_frame_end),
    .tx_clk(qsfp_tx_user_clk),
    .tx_rst_n(qsfp_link_ready_tx),
    .tx_tdata(qsfp_tx_tdata),
    .tx_tkeep(qsfp_tx_tkeep),
    .tx_tvalid(qsfp_tx_tvalid),
    .tx_tready(qsfp_tx_tready),
    .tx_tlast(qsfp_tx_tlast),
    .overflow_sticky(qsfp_bridge_overflow),
    .source_frame_error_sticky(qsfp_bridge_frame_error)
);

qsfp_aurora_loop qsfp_loop_inst (
    .init_clk(sys_clk),
    .reset_request(!rst_n || !locked || key_low),
    .qsfp1_refclk_p(qsfp1_refclk_p),
    .qsfp1_refclk_n(qsfp1_refclk_n),
    .qsfp1_txp(qsfp1_txp),
    .qsfp1_txn(qsfp1_txn),
    .qsfp2_refclk_p(qsfp2_refclk_p),
    .qsfp2_refclk_n(qsfp2_refclk_n),
    .qsfp2_rxp(qsfp2_rxp),
    .qsfp2_rxn(qsfp2_rxn),
    .tx_tdata(qsfp_tx_tdata),
    .tx_tkeep(qsfp_tx_tkeep),
    .tx_tvalid(qsfp_tx_tvalid),
    .tx_tlast(qsfp_tx_tlast),
    .tx_tready(qsfp_tx_tready),
    .tx_user_clk(qsfp_tx_user_clk),
    .tx_channel_up(qsfp_tx_channel_up),
    .tx_lane_up(qsfp_tx_lane_up),
    .tx_hard_err(qsfp_tx_hard_err),
    .tx_soft_err(qsfp_tx_soft_err),
    .rx_tdata(qsfp_rx_tdata),
    .rx_tkeep(qsfp_rx_tkeep),
    .rx_tvalid(qsfp_rx_tvalid),
    .rx_tlast(qsfp_rx_tlast),
    .rx_user_clk(qsfp_rx_user_clk),
    .rx_channel_up(qsfp_rx_channel_up),
    .rx_lane_up(qsfp_rx_lane_up),
    .rx_hard_err(qsfp_rx_hard_err),
    .rx_soft_err(qsfp_rx_soft_err),
    .reset_ready(aurora_reset_ready)
);

qsfp_loopback_monitor qsfp_monitor_inst (
    .tx_clk(qsfp_tx_user_clk),
    .tx_rst_n(qsfp_link_ready_tx),
    .tx_tdata(qsfp_tx_tdata),
    .tx_tvalid(qsfp_tx_tvalid),
    .tx_tready(qsfp_tx_tready),
    .tx_tlast(qsfp_tx_tlast),
    .rx_clk(qsfp_rx_user_clk),
    .rx_rst_n(qsfp_link_ready_rx),
    .rx_tdata(qsfp_rx_tdata),
    .rx_tkeep(qsfp_rx_tkeep),
    .rx_tvalid(qsfp_rx_tvalid),
    .rx_tlast(qsfp_rx_tlast),
    .tx_frame_count(qsfp_tx_frame_count),
    .rx_frame_count(qsfp_rx_frame_count),
    .data_error_count(qsfp_data_error_count),
    .half_swap_error_count(qsfp_half_swap_error_count),
    .boundary_error_count(qsfp_boundary_error_count),
    .underflow_count(qsfp_underflow_count),
    .idle_frame_count(qsfp_idle_frame_count),
    .data_frame_count(qsfp_data_frame_count),
    .reference_overflow_sticky(qsfp_reference_overflow),
    .header_error_sticky(qsfp_header_error),
    .expected_data_debug(qsfp_expected_data),
    .expected_tlast_debug(qsfp_expected_tlast),
    .expected_valid_debug(qsfp_expected_valid)
);

always @(posedge qsfp_tx_user_clk or negedge qsfp_link_ready_tx) begin
    if (!qsfp_link_ready_tx)
        qsfp_tx_error_sticky <= 1'b0;
    else if (qsfp_tx_hard_err || qsfp_tx_soft_err)
        qsfp_tx_error_sticky <= 1'b1;
end

always @(posedge qsfp_rx_user_clk or negedge qsfp_link_ready_rx) begin
    if (!qsfp_link_ready_rx) begin
        qsfp_rx_error_sticky <= 1'b0;
        qsfp_tx_error_rx_d0 <= 1'b0;
        qsfp_tx_error_rx_d1 <= 1'b0;
        qsfp_bridge_overflow_rx_d0 <= 1'b0;
        qsfp_bridge_overflow_rx_d1 <= 1'b0;
        qsfp_bridge_frame_error_rx_d0 <= 1'b0;
        qsfp_bridge_frame_error_rx_d1 <= 1'b0;
    end else begin
        if (qsfp_rx_hard_err || qsfp_rx_soft_err)
            qsfp_rx_error_sticky <= 1'b1;
        qsfp_tx_error_rx_d0 <= qsfp_tx_error_sticky;
        qsfp_tx_error_rx_d1 <= qsfp_tx_error_rx_d0;
        qsfp_bridge_overflow_rx_d0 <= qsfp_bridge_overflow;
        qsfp_bridge_overflow_rx_d1 <= qsfp_bridge_overflow_rx_d0;
        qsfp_bridge_frame_error_rx_d0 <= qsfp_bridge_frame_error;
        qsfp_bridge_frame_error_rx_d1 <= qsfp_bridge_frame_error_rx_d0;
    end
end

ila_qsfp_loop qsfp_loop_ila_inst (
    .clk(qsfp_rx_user_clk),
    .probe0({qsfp_tx_channel_up, qsfp_rx_channel_up}),
    .probe1({qsfp_reference_overflow, qsfp_header_error,
             qsfp_bridge_overflow_rx_d1, qsfp_bridge_frame_error_rx_d1,
             qsfp_tx_error_rx_d1, qsfp_rx_error_sticky,
             &qsfp_tx_lane_up, &qsfp_rx_lane_up}),
    .probe2(qsfp_tx_frame_count),
    .probe3(qsfp_rx_frame_count),
    .probe4(qsfp_data_error_count),
    .probe5(qsfp_half_swap_error_count),
    .probe6(qsfp_boundary_error_count),
    .probe7(qsfp_underflow_count),
    .probe8(qsfp_idle_frame_count),
    .probe9(qsfp_data_frame_count),
    .probe10(qsfp_rx_tdata),
    .probe11(qsfp_expected_data),
    .probe12({qsfp_rx_tvalid, qsfp_rx_tlast,
              qsfp_expected_valid, qsfp_expected_tlast})
);

ila_aggregate_stats aggregate_ila_inst
(
    .clk    (qpsk_clk),
    .probe0 (qpsk_bits),
    .probe1 ({qpsk_frame_start, qpsk_frame_end, qpsk_valid}),
    .probe2 (aggregate_packet_count0),
    .probe3 (aggregate_packet_count1),
    .probe4 (aggregate_packet_count2),
    .probe5 (aggregate_packet_count3),
    .probe6 (aggregate_byte_count0),
    .probe7 (aggregate_byte_count1),
    .probe8 (aggregate_byte_count2),
    .probe9 (aggregate_byte_count3),
    .probe10({aggregate_descriptor_overflow, aggregate_payload_overflow}),
    .probe11(rx_mac_good_counts_qpsk),
    .probe12(rx_mac_crc_error_counts_qpsk),
    .probe13(rx_ip_checksum_error_counts_qpsk),
    .probe14(rx_udp_checksum_error_counts_qpsk),
    .probe15(rx_udp_packet_commit_counts_qpsk),
    .probe16(rx_udp_buffer_overflow_counts_qpsk)
);

ax_debounce key_u0
(
    .clk            (sys_clk),
    .rst            (1'b0),
    .button_in      (rst_n),
    .button_posedge (),
    .button_negedge (key_low),
    .button_out     ()
);

endmodule
