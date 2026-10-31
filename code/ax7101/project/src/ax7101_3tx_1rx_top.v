`timescale 1ns/1ps

module ax7101_3tx_1rx_top (
    input  wire       sys_clk_p,
    input  wire       sys_clk_n,
    input  wire       rst_n,
    output wire [1:0] led,

    output wire       e1_reset,
    output wire       e1_mdc,
    inout  wire       e1_mdio,
    input  wire       e1_rxc,
    input  wire       e1_rxdv,
    input  wire       e1_rxer,
    input  wire [7:0] e1_rxd,
    input  wire       e1_txc,
    output wire       e1_gtxc,
    output reg        e1_txen,
    output wire       e1_txer,
    output reg  [7:0] e1_txd,

    output wire       e2_reset,
    output wire       e2_mdc,
    inout  wire       e2_mdio,
    input  wire       e2_rxc,
    input  wire       e2_rxdv,
    input  wire       e2_rxer,
    input  wire [7:0] e2_rxd,
    input  wire       e2_txc,
    output wire       e2_gtxc,
    output reg        e2_txen,
    output wire       e2_txer,
    output reg  [7:0] e2_txd,

    output wire       e3_reset,
    output wire       e3_mdc,
    inout  wire       e3_mdio,
    input  wire       e3_rxc,
    input  wire       e3_rxdv,
    input  wire       e3_rxer,
    input  wire [7:0] e3_rxd,
    input  wire       e3_txc,
    output wire       e3_gtxc,
    output reg        e3_txen,
    output wire       e3_txer,
    output reg  [7:0] e3_txd,

    output wire       e4_reset,
    output wire       e4_mdc,
    inout  wire       e4_mdio,
    input  wire       e4_rxc,
    input  wire       e4_rxdv,
    input  wire       e4_rxer,
    input  wire [7:0] e4_rxd,
    input  wire       e4_txc,
    output wire       e4_gtxc,
    output wire       e4_txen,
    output wire       e4_txer,
    output wire [7:0] e4_txd
);

wire sys_clk_200;
wire tx_clk_125;
wire clocks_locked;
wire phy_reset_n;
wire sys_reset_n;
wire tx_reset_n;
wire rx4_reset_n;

wire [1:0] phy_speed_1;
wire [1:0] phy_speed_2;
wire [1:0] phy_speed_3;
wire [1:0] phy_speed_4;
wire phy_link_1;
wire phy_link_2;
wire phy_link_3;
wire phy_link_4;
wire [3:0] phy_led_1;
wire [3:0] phy_led_2;
wire [3:0] phy_led_3;
wire [3:0] phy_led_4;

wire [11:0] phy_status_tx;
wire tx_link_1;
wire tx_link_2;
wire tx_link_3;
wire tx_link_4;
wire [1:0] tx_speed_1;
wire [1:0] tx_speed_2;
wire [1:0] tx_speed_3;
wire [1:0] tx_speed_4;
wire tx_enable_1;
wire tx_enable_2;
wire tx_enable_3;

wire tx_en_1_internal;
wire tx_en_2_internal;
wire tx_en_3_internal;
wire tx_er_1_internal;
wire tx_er_2_internal;
wire tx_er_3_internal;
wire [7:0] tx_data_1_internal;
wire [7:0] tx_data_2_internal;
wire [7:0] tx_data_3_internal;
wire [31:0] tx_sequence_1;
wire [31:0] tx_sequence_2;
wire [31:0] tx_sequence_3;
wire [31:0] tx_frame_count_1;
wire [31:0] tx_frame_count_2;
wire [31:0] tx_frame_count_3;
wire [31:0] tx_sequence_1_system;
wire [31:0] tx_sequence_2_system;
wire [31:0] tx_sequence_3_system;

(* IOB = "TRUE" *) reg [7:0] e4_rxd_iob;
(* IOB = "TRUE" *) reg e4_rxdv_iob;
(* IOB = "TRUE" *) reg e4_rxer_iob;

wire [1:0] rx_current_source;
wire [31:0] rx_good_frames_1;
wire [31:0] rx_good_frames_2;
wire [31:0] rx_good_frames_3;
wire [31:0] rx_fcs_errors_1;
wire [31:0] rx_fcs_errors_2;
wire [31:0] rx_fcs_errors_3;
wire [31:0] rx_sequence_errors_1;
wire [31:0] rx_sequence_errors_2;
wire [31:0] rx_sequence_errors_3;
wire [63:0] rx_bit_errors_1;
wire [63:0] rx_bit_errors_2;
wire [63:0] rx_bit_errors_3;
wire [63:0] rx_bits_checked_1;
wire [63:0] rx_bits_checked_2;
wire [63:0] rx_bits_checked_3;
wire [31:0] rx_malformed_frames;
wire [31:0] rx_gmii_er_frames;
wire rx_stats_toggle;

wire [737:0] rx_stats_source;
wire [737:0] rx_stats_system;
wire rx_stats_update_system;

wire [1:0] stat_current_source;
wire [31:0] stat_good_frames_1;
wire [31:0] stat_good_frames_2;
wire [31:0] stat_good_frames_3;
wire [31:0] stat_fcs_errors_1;
wire [31:0] stat_fcs_errors_2;
wire [31:0] stat_fcs_errors_3;
wire [31:0] stat_sequence_errors_1;
wire [31:0] stat_sequence_errors_2;
wire [31:0] stat_sequence_errors_3;
wire [63:0] stat_bit_errors_1;
wire [63:0] stat_bit_errors_2;
wire [63:0] stat_bit_errors_3;
wire [63:0] stat_bits_checked_1;
wire [63:0] stat_bits_checked_2;
wire [63:0] stat_bits_checked_3;
wire [31:0] stat_malformed_frames;
wire [31:0] stat_gmii_er_frames;

clock_gen_200_to_125 u_clock_gen (
    .sys_clk_p(sys_clk_p),
    .sys_clk_n(sys_clk_n),
    .reset_n(rst_n),
    .sys_clk_200(sys_clk_200),
    .tx_clk_125(tx_clk_125),
    .locked(clocks_locked)
);

phy_reset_controller #(
    .RESET_CYCLES(4_000_000)
) u_phy_reset (
    .clk(sys_clk_200),
    .external_reset_n(rst_n && clocks_locked),
    .phy_reset_n(phy_reset_n)
);

async_reset_sync u_sys_reset_sync (
    .clk(sys_clk_200),
    .async_reset_n(phy_reset_n),
    .sync_reset_n(sys_reset_n)
);

async_reset_sync u_tx_reset_sync (
    .clk(tx_clk_125),
    .async_reset_n(phy_reset_n),
    .sync_reset_n(tx_reset_n)
);

async_reset_sync u_rx4_reset_sync (
    .clk(e4_rxc),
    .async_reset_n(phy_reset_n),
    .sync_reset_n(rx4_reset_n)
);

assign e1_reset = phy_reset_n;
assign e2_reset = phy_reset_n;
assign e3_reset = phy_reset_n;
assign e4_reset = phy_reset_n;

smi_config #(.REF_CLK(200), .MDC_CLK(500)) u_mdio_1 (
    .clk(sys_clk_200),
    .rst_n(sys_reset_n),
    .mdc(e1_mdc),
    .mdio(e1_mdio),
    .speed(phy_speed_1),
    .link(phy_link_1),
    .led(phy_led_1)
);

smi_config #(.REF_CLK(200), .MDC_CLK(500)) u_mdio_2 (
    .clk(sys_clk_200),
    .rst_n(sys_reset_n),
    .mdc(e2_mdc),
    .mdio(e2_mdio),
    .speed(phy_speed_2),
    .link(phy_link_2),
    .led(phy_led_2)
);

smi_config #(.REF_CLK(200), .MDC_CLK(500)) u_mdio_3 (
    .clk(sys_clk_200),
    .rst_n(sys_reset_n),
    .mdc(e3_mdc),
    .mdio(e3_mdio),
    .speed(phy_speed_3),
    .link(phy_link_3),
    .led(phy_led_3)
);

smi_config #(.REF_CLK(200), .MDC_CLK(500)) u_mdio_4 (
    .clk(sys_clk_200),
    .rst_n(sys_reset_n),
    .mdc(e4_mdc),
    .mdio(e4_mdio),
    .speed(phy_speed_4),
    .link(phy_link_4),
    .led(phy_led_4)
);

sync_bits #(.WIDTH(12)) u_status_to_tx (
    .clk(tx_clk_125),
    .rst_n(tx_reset_n),
    .async_data({
        phy_link_4, phy_speed_4,
        phy_link_3, phy_speed_3,
        phy_link_2, phy_speed_2,
        phy_link_1, phy_speed_1
    }),
    .sync_data(phy_status_tx)
);

assign {
    tx_link_4, tx_speed_4,
    tx_link_3, tx_speed_3,
    tx_link_2, tx_speed_2,
    tx_link_1, tx_speed_1
} = phy_status_tx;

assign tx_enable_1 = tx_link_1 && (tx_speed_1 == 2'b10);
assign tx_enable_2 = tx_link_2 && (tx_speed_2 == 2'b10);
assign tx_enable_3 = tx_link_3 && (tx_speed_3 == 2'b10);

gmii_prbs31_tx #(.SOURCE_PORT(1)) u_tx_1 (
    .clk(tx_clk_125),
    .rst_n(tx_reset_n),
    .enable(tx_enable_1),
    .gmii_tx_en(tx_en_1_internal),
    .gmii_tx_er(tx_er_1_internal),
    .gmii_txd(tx_data_1_internal),
    .frame_sequence(tx_sequence_1),
    .frame_count(tx_frame_count_1)
);

gmii_prbs31_tx #(.SOURCE_PORT(2)) u_tx_2 (
    .clk(tx_clk_125),
    .rst_n(tx_reset_n),
    .enable(tx_enable_2),
    .gmii_tx_en(tx_en_2_internal),
    .gmii_tx_er(tx_er_2_internal),
    .gmii_txd(tx_data_2_internal),
    .frame_sequence(tx_sequence_2),
    .frame_count(tx_frame_count_2)
);

gmii_prbs31_tx #(.SOURCE_PORT(3)) u_tx_3 (
    .clk(tx_clk_125),
    .rst_n(tx_reset_n),
    .enable(tx_enable_3),
    .gmii_tx_en(tx_en_3_internal),
    .gmii_tx_er(tx_er_3_internal),
    .gmii_txd(tx_data_3_internal),
    .frame_sequence(tx_sequence_3),
    .frame_count(tx_frame_count_3)
);

gray_counter_cdc #(.WIDTH(32)) u_tx_sequence_cdc_1 (
    .src_clk(tx_clk_125),
    .src_rst_n(tx_reset_n),
    .src_binary(tx_sequence_1),
    .dst_clk(sys_clk_200),
    .dst_rst_n(sys_reset_n),
    .dst_binary(tx_sequence_1_system)
);

gray_counter_cdc #(.WIDTH(32)) u_tx_sequence_cdc_2 (
    .src_clk(tx_clk_125),
    .src_rst_n(tx_reset_n),
    .src_binary(tx_sequence_2),
    .dst_clk(sys_clk_200),
    .dst_rst_n(sys_reset_n),
    .dst_binary(tx_sequence_2_system)
);

gray_counter_cdc #(.WIDTH(32)) u_tx_sequence_cdc_3 (
    .src_clk(tx_clk_125),
    .src_rst_n(tx_reset_n),
    .src_binary(tx_sequence_3),
    .dst_clk(sys_clk_200),
    .dst_rst_n(sys_reset_n),
    .dst_binary(tx_sequence_3_system)
);

always @(posedge tx_clk_125 or negedge tx_reset_n) begin
    if (!tx_reset_n) begin
        e1_txen <= 1'b0;
        e2_txen <= 1'b0;
        e3_txen <= 1'b0;
        e1_txd <= 8'd0;
        e2_txd <= 8'd0;
        e3_txd <= 8'd0;
    end else begin
        e1_txen <= tx_en_1_internal;
        e2_txen <= tx_en_2_internal;
        e3_txen <= tx_en_3_internal;
        e1_txd <= tx_data_1_internal;
        e2_txd <= tx_data_2_internal;
        e3_txd <= tx_data_3_internal;
    end
end

assign e1_txer = tx_er_1_internal;
assign e2_txer = tx_er_2_internal;
assign e3_txer = tx_er_3_internal;
assign e4_txen = 1'b0;
assign e4_txer = 1'b0;
assign e4_txd = 8'd0;

gmii_clock_forward u_gtxc_1 (
    .clk_125(tx_clk_125),
    .reset_n(tx_reset_n),
    .gmii_gtxc(e1_gtxc)
);

gmii_clock_forward u_gtxc_2 (
    .clk_125(tx_clk_125),
    .reset_n(tx_reset_n),
    .gmii_gtxc(e2_gtxc)
);

gmii_clock_forward u_gtxc_3 (
    .clk_125(tx_clk_125),
    .reset_n(tx_reset_n),
    .gmii_gtxc(e3_gtxc)
);

gmii_clock_forward u_gtxc_4 (
    .clk_125(tx_clk_125),
    .reset_n(tx_reset_n),
    .gmii_gtxc(e4_gtxc)
);

always @(posedge e4_rxc) begin
    e4_rxd_iob <= e4_rxd;
    e4_rxdv_iob <= e4_rxdv;
    e4_rxer_iob <= e4_rxer;
end

gmii_prbs31_rx_checker u_rx_checker (
    .rx_clk(e4_rxc),
    .rst_n(rx4_reset_n),
    .gmii_rx_dv(e4_rxdv_iob),
    .gmii_rx_er(e4_rxer_iob),
    .gmii_rxd(e4_rxd_iob),
    .current_source(rx_current_source),
    .good_frames_1(rx_good_frames_1),
    .good_frames_2(rx_good_frames_2),
    .good_frames_3(rx_good_frames_3),
    .fcs_errors_1(rx_fcs_errors_1),
    .fcs_errors_2(rx_fcs_errors_2),
    .fcs_errors_3(rx_fcs_errors_3),
    .sequence_errors_1(rx_sequence_errors_1),
    .sequence_errors_2(rx_sequence_errors_2),
    .sequence_errors_3(rx_sequence_errors_3),
    .bit_errors_1(rx_bit_errors_1),
    .bit_errors_2(rx_bit_errors_2),
    .bit_errors_3(rx_bit_errors_3),
    .bits_checked_1(rx_bits_checked_1),
    .bits_checked_2(rx_bits_checked_2),
    .bits_checked_3(rx_bits_checked_3),
    .malformed_frames(rx_malformed_frames),
    .gmii_rx_er_frames(rx_gmii_er_frames),
    .stats_update_toggle(rx_stats_toggle)
);

assign rx_stats_source = {
    rx_current_source,
    rx_good_frames_1,
    rx_good_frames_2,
    rx_good_frames_3,
    rx_fcs_errors_1,
    rx_fcs_errors_2,
    rx_fcs_errors_3,
    rx_sequence_errors_1,
    rx_sequence_errors_2,
    rx_sequence_errors_3,
    rx_bit_errors_1,
    rx_bit_errors_2,
    rx_bit_errors_3,
    rx_bits_checked_1,
    rx_bits_checked_2,
    rx_bits_checked_3,
    rx_malformed_frames,
    rx_gmii_er_frames
};

stats_snapshot_cdc #(.WIDTH(738)) u_stats_snapshot (
    .src_clk(e4_rxc),
    .src_rst_n(rx4_reset_n),
    .src_data(rx_stats_source),
    .src_toggle(rx_stats_toggle),
    .dst_clk(sys_clk_200),
    .dst_rst_n(sys_reset_n),
    .dst_data(rx_stats_system),
    .dst_update_pulse(rx_stats_update_system)
);

assign {
    stat_current_source,
    stat_good_frames_1,
    stat_good_frames_2,
    stat_good_frames_3,
    stat_fcs_errors_1,
    stat_fcs_errors_2,
    stat_fcs_errors_3,
    stat_sequence_errors_1,
    stat_sequence_errors_2,
    stat_sequence_errors_3,
    stat_bit_errors_1,
    stat_bit_errors_2,
    stat_bit_errors_3,
    stat_bits_checked_1,
    stat_bits_checked_2,
    stat_bits_checked_3,
    stat_malformed_frames,
    stat_gmii_er_frames
} = rx_stats_system;

assign led[0] = phy_link_4 && (phy_speed_4 == 2'b10);
assign led[1] = stat_good_frames_1[15] ^
                stat_good_frames_2[15] ^
                stat_good_frames_3[15];

wire [11:0] ila_phy_status;
assign ila_phy_status = {
    phy_link_4, phy_speed_4,
    phy_link_3, phy_speed_3,
    phy_link_2, phy_speed_2,
    phy_link_1, phy_speed_1
};

ila_ber u_ila_ber (
    .clk(sys_clk_200),
    .probe0(ila_phy_status),
    .probe1(stat_current_source),
    .probe2(stat_good_frames_1),
    .probe3(stat_good_frames_2),
    .probe4(stat_good_frames_3),
    .probe5(stat_fcs_errors_1),
    .probe6(stat_fcs_errors_2),
    .probe7(stat_fcs_errors_3),
    .probe8(stat_sequence_errors_1),
    .probe9(stat_sequence_errors_2),
    .probe10(stat_sequence_errors_3),
    .probe11(stat_bit_errors_1),
    .probe12(stat_bit_errors_2),
    .probe13(stat_bit_errors_3),
    .probe14(stat_bits_checked_1),
    .probe15(stat_bits_checked_2),
    .probe16(stat_bits_checked_3),
    .probe17(stat_malformed_frames),
    .probe18(stat_gmii_er_frames),
    .probe19({
        tx_sequence_3_system,
        tx_sequence_2_system,
        tx_sequence_1_system
    })
);

endmodule
