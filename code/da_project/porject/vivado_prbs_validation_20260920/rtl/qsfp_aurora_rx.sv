`timescale 1ns/1ps

module qsfp_aurora_rx (
    input  logic         init_clk,
    input  logic         reset_request,
    input  logic         qsfp_refclk_p,
    input  logic         qsfp_refclk_n,
    input  wire [0:3]    qsfp_rxp,
    input  wire [0:3]    qsfp_rxn,
    output logic [255:0] rx_tdata,
    output logic [31:0]  rx_tkeep,
    output logic         rx_tvalid,
    output logic         rx_tlast,
    output logic [255:0] raw_tdata,
    output logic         user_clk,
    output logic         channel_up,
    output wire [0:3]    lane_up,
    output logic         hard_err,
    output logic         soft_err,
    output logic         reset_ready
);
    logic pma_init;
    logic reset_pb;
    wire [0:255] rx_tdata_ip;
    wire [0:31] rx_tkeep_ip;
    logic [255:0] rx_tdata_mapped;
    logic [31:0] rx_tkeep_mapped;
    logic rx_tvalid_ip;
    logic rx_tlast_ip;

    generate
        for (genvar bit_index = 0; bit_index < 256; bit_index++) begin : g_axis_data_map
            assign rx_tdata_mapped[255-bit_index] = rx_tdata_ip[bit_index];
        end
        for (genvar keep_index = 0; keep_index < 32; keep_index++) begin : g_axis_keep_map
            assign rx_tkeep_mapped[31-keep_index] = rx_tkeep_ip[keep_index];
        end
    endgenerate

    assign raw_tdata = rx_tdata_mapped;

    qsfp_axis_rx_normalizer normalizer_i (
        .aurora_tdata(rx_tdata_mapped),
        .aurora_tkeep(rx_tkeep_mapped),
        .aurora_tvalid(rx_tvalid_ip),
        .aurora_tlast(rx_tlast_ip),
        .normalized_tdata(rx_tdata),
        .normalized_tkeep(rx_tkeep),
        .normalized_tvalid(rx_tvalid),
        .normalized_tlast(rx_tlast)
    );

    aurora_reset_sequence reset_sequence_i (
        .init_clk(init_clk),
        .reset_request(reset_request),
        .pma_init(pma_init),
        .reset_pb(reset_pb),
        .ready(reset_ready)
    );

    aurora_rx_rf47 rx_core_i (
        .rxp(qsfp_rxp),
        .rxn(qsfp_rxn),
        .reset_pb(reset_pb),
        .power_down(1'b0),
        .pma_init(pma_init),
        .rx_hard_err(hard_err),
        .rx_soft_err(soft_err),
        .rx_channel_up(channel_up),
        .rx_lane_up(lane_up),
        .m_axi_rx_tdata(rx_tdata_ip),
        .m_axi_rx_tkeep(rx_tkeep_ip),
        .m_axi_rx_tlast(rx_tlast_ip),
        .m_axi_rx_tvalid(rx_tvalid_ip),
        .gt_refclk1_p(qsfp_refclk_p),
        .gt_refclk1_n(qsfp_refclk_n),
        .user_clk_out(user_clk),
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

