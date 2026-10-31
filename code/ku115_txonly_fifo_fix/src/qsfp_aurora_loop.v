`timescale 1ns / 1ps

module qsfp_aurora_loop (
    input              init_clk,
    input              reset_request,

    input              qsfp1_refclk_p,
    input              qsfp1_refclk_n,
    output     [0:3]   qsfp1_txp,
    output     [0:3]   qsfp1_txn,
    input              qsfp2_refclk_p,
    input              qsfp2_refclk_n,
    input      [0:3]   qsfp2_rxp,
    input      [0:3]   qsfp2_rxn,

    input      [255:0] tx_tdata,
    input      [31:0]  tx_tkeep,
    input              tx_tvalid,
    input              tx_tlast,
    output             tx_tready,
    output             tx_user_clk,
    output             tx_channel_up,
    output     [0:3]   tx_lane_up,
    output             tx_hard_err,
    output             tx_soft_err,

    output     [255:0] rx_tdata,
    output     [31:0]  rx_tkeep,
    output             rx_tvalid,
    output             rx_tlast,
    output             rx_user_clk,
    output             rx_channel_up,
    output     [0:3]   rx_lane_up,
    output             rx_hard_err,
    output             rx_soft_err,
    output             reset_ready
);

wire pma_init;
wire reset_pb;
wire [0:255] tx_tdata_ip;
wire [0:31] tx_tkeep_ip;
wire [255:0] tx_tdata_preconditioned;
wire [31:0] tx_tkeep_preconditioned;
wire [0:255] rx_tdata_ip;
wire [0:31] rx_tkeep_ip;
wire [255:0] rx_tdata_mapped;
wire [31:0] rx_tkeep_mapped;
wire rx_tvalid_mapped;
wire rx_tlast_mapped;

qsfp_axis_tx_preconditioner tx_preconditioner (
    .canonical_tdata(tx_tdata),
    .canonical_tkeep(tx_tkeep),
    .aurora_tdata(tx_tdata_preconditioned),
    .aurora_tkeep(tx_tkeep_preconditioned)
);

genvar bit_index;
generate
    for (bit_index = 0; bit_index < 256; bit_index = bit_index + 1) begin : g_axis_data_map
        assign tx_tdata_ip[bit_index] = tx_tdata_preconditioned[255-bit_index];
        assign rx_tdata_mapped[255-bit_index] = rx_tdata_ip[bit_index];
    end
    for (bit_index = 0; bit_index < 32; bit_index = bit_index + 1) begin : g_axis_keep_map
        assign tx_tkeep_ip[bit_index] = tx_tkeep_preconditioned[31-bit_index];
        assign rx_tkeep_mapped[31-bit_index] = rx_tkeep_ip[bit_index];
    end
endgenerate

qsfp_axis_rx_normalizer rx_normalizer (
    .aurora_tdata(rx_tdata_mapped),
    .aurora_tkeep(rx_tkeep_mapped),
    .aurora_tvalid(rx_tvalid_mapped),
    .aurora_tlast(rx_tlast_mapped),
    .normalized_tdata(rx_tdata),
    .normalized_tkeep(rx_tkeep),
    .normalized_tvalid(rx_tvalid),
    .normalized_tlast(rx_tlast)
);

aurora_reset_sequence reset_sequence (
    .init_clk(init_clk),
    .reset_request(reset_request),
    .pma_init(pma_init),
    .reset_pb(reset_pb),
    .ready(reset_ready)
);

aurora_tx_qsfp1 tx_core (
    .reset_pb(reset_pb),
    .power_down(1'b0),
    .pma_init(pma_init),
    .txp(qsfp1_txp),
    .txn(qsfp1_txn),
    .tx_hard_err(tx_hard_err),
    .tx_soft_err(tx_soft_err),
    .tx_channel_up(tx_channel_up),
    .tx_lane_up(tx_lane_up),
    .s_axi_tx_tdata(tx_tdata_ip),
    .s_axi_tx_tkeep(tx_tkeep_ip),
    // The 512-byte application frames already carry sync, length and CRC.
    // Keep Aurora as one continuous byte stream so it cannot repack those
    // boundaries across 256-bit transfers.
    .s_axi_tx_tlast(1'b0),
    .s_axi_tx_tvalid(tx_tvalid),
    .s_axi_tx_tready(tx_tready),
    .gt_refclk1_p(qsfp1_refclk_p),
    .gt_refclk1_n(qsfp1_refclk_n),
    .user_clk_out(tx_user_clk),
    .gt_rxcdrovrden_in(1'b0),
    .init_clk(init_clk),
    .s_axi_awaddr(32'd0), .s_axi_araddr(32'd0),
    .s_axi_wdata(32'd0), .s_axi_wstrb(4'd0),
    .s_axi_awvalid(1'b0), .s_axi_wvalid(1'b0),
    .s_axi_bready(1'b0), .s_axi_arvalid(1'b0), .s_axi_rready(1'b0),
    .s_axi_awaddr_lane1(32'd0), .s_axi_araddr_lane1(32'd0),
    .s_axi_wdata_lane1(32'd0), .s_axi_wstrb_lane1(4'd0),
    .s_axi_awvalid_lane1(1'b0), .s_axi_wvalid_lane1(1'b0),
    .s_axi_bready_lane1(1'b0), .s_axi_arvalid_lane1(1'b0), .s_axi_rready_lane1(1'b0),
    .s_axi_awaddr_lane2(32'd0), .s_axi_araddr_lane2(32'd0),
    .s_axi_wdata_lane2(32'd0), .s_axi_wstrb_lane2(4'd0),
    .s_axi_awvalid_lane2(1'b0), .s_axi_wvalid_lane2(1'b0),
    .s_axi_bready_lane2(1'b0), .s_axi_arvalid_lane2(1'b0), .s_axi_rready_lane2(1'b0),
    .s_axi_awaddr_lane3(32'd0), .s_axi_araddr_lane3(32'd0),
    .s_axi_wdata_lane3(32'd0), .s_axi_wstrb_lane3(4'd0),
    .s_axi_awvalid_lane3(1'b0), .s_axi_wvalid_lane3(1'b0),
    .s_axi_bready_lane3(1'b0), .s_axi_arvalid_lane3(1'b0), .s_axi_rready_lane3(1'b0)
);

aurora_rx_qsfp2 rx_core (
    .rxp(qsfp2_rxp),
    .rxn(qsfp2_rxn),
    .reset_pb(reset_pb),
    .power_down(1'b0),
    .pma_init(pma_init),
    .rx_hard_err(rx_hard_err),
    .rx_soft_err(rx_soft_err),
    .rx_channel_up(rx_channel_up),
    .rx_lane_up(rx_lane_up),
    .m_axi_rx_tdata(rx_tdata_ip),
    .m_axi_rx_tkeep(rx_tkeep_ip),
    .m_axi_rx_tlast(rx_tlast_mapped),
    .m_axi_rx_tvalid(rx_tvalid_mapped),
    .gt_refclk1_p(qsfp2_refclk_p),
    .gt_refclk1_n(qsfp2_refclk_n),
    .user_clk_out(rx_user_clk),
    .gt_rxcdrovrden_in(1'b0),
    .init_clk(init_clk),
    .s_axi_awaddr(32'd0), .s_axi_araddr(32'd0),
    .s_axi_wdata(32'd0), .s_axi_wstrb(4'd0),
    .s_axi_awvalid(1'b0), .s_axi_wvalid(1'b0),
    .s_axi_bready(1'b0), .s_axi_arvalid(1'b0), .s_axi_rready(1'b0),
    .s_axi_awaddr_lane1(32'd0), .s_axi_araddr_lane1(32'd0),
    .s_axi_wdata_lane1(32'd0), .s_axi_wstrb_lane1(4'd0),
    .s_axi_awvalid_lane1(1'b0), .s_axi_wvalid_lane1(1'b0),
    .s_axi_bready_lane1(1'b0), .s_axi_arvalid_lane1(1'b0), .s_axi_rready_lane1(1'b0),
    .s_axi_awaddr_lane2(32'd0), .s_axi_araddr_lane2(32'd0),
    .s_axi_wdata_lane2(32'd0), .s_axi_wstrb_lane2(4'd0),
    .s_axi_awvalid_lane2(1'b0), .s_axi_wvalid_lane2(1'b0),
    .s_axi_bready_lane2(1'b0), .s_axi_arvalid_lane2(1'b0), .s_axi_rready_lane2(1'b0),
    .s_axi_awaddr_lane3(32'd0), .s_axi_araddr_lane3(32'd0),
    .s_axi_wdata_lane3(32'd0), .s_axi_wstrb_lane3(4'd0),
    .s_axi_awvalid_lane3(1'b0), .s_axi_wvalid_lane3(1'b0),
    .s_axi_bready_lane3(1'b0), .s_axi_arvalid_lane3(1'b0), .s_axi_rready_lane3(1'b0)
);

endmodule
