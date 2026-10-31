`timescale 1ns/1ps

module tb_camera_udp_tx_rx_loopback;

reg clk = 1'b0;
reg rst_n = 1'b0;
reg meta_valid = 1'b0;
reg data_valid = 1'b0;
reg [7:0] data = 8'd0;
reg data_last = 1'b0;
wire meta_ready;
wire data_ready;
wire gmii_tx_en;
wire gmii_tx_er;
wire [7:0] gmii_txd;
wire [31:0] camera2_good_packets;
wire [31:0] camera2_header_errors;
wire [31:0] camera2_fcs_errors;
wire [31:0] camera2_ip_errors;
wire [31:0] camera2_udp_errors;
wire [31:0] malformed_frames;
integer byte_index;

always #4 clk = ~clk;

dataset_udp_tx #(
    .SOURCE_MAC(48'h000A3502FEC3),
    .SOURCE_IP(32'hC0A80067),
    .DEST_IP(32'hC0A80014),
    .SOURCE_PORT_ID(8'd3),
    .STATIC_DEST_MAC(48'h000A3501FEC4),
    .USE_STATIC_DEST_MAC(1)
) tx (
    .clk(clk), .rst_n(rst_n), .enable(1'b1), .link_up(1'b1),
    .clear_arp_cache(1'b0),
    .packet_meta_valid(meta_valid), .packet_meta_ready(meta_ready),
    .packet_type(8'd3), .packet_flags(8'h01), .packet_cycle(32'd17),
    .packet_object_id(16'd2), .packet_valid_length(16'd1368),
    .packet_sequence(32'd123), .packet_object_offset(32'd0),
    .packet_object_length(32'd614400), .packet_object_crc32(32'd0),
    .packet_data_valid(data_valid), .packet_data_ready(data_ready),
    .packet_data(data), .packet_data_last(data_last),
    .gmii_rx_dv(1'b0), .gmii_rx_er(1'b0), .gmii_rxd(8'd0),
    .gmii_tx_en(gmii_tx_en), .gmii_tx_er(gmii_tx_er),
    .gmii_txd(gmii_txd), .arp_resolved(), .resolved_mac(),
    .packet_sent(), .arp_request_count(), .udp_packet_count(),
    .input_error_count()
);

camera_udp_rx_checker rx (
    .rx_clk(clk), .rst_n(rst_n), .gmii_rx_dv(gmii_tx_en),
    .gmii_rx_er(gmii_tx_er), .gmii_rxd(gmii_txd), .current_source(),
    .camera1_good_frames(), .camera1_good_objects(), .camera1_fcs_errors(),
    .camera1_ip_checksum_errors(), .camera1_udp_checksum_errors(),
    .camera1_header_errors(), .camera1_sequence_errors(),
    .camera1_offset_errors(), .camera1_object_crc_errors(),
    .camera2_good_frames(camera2_good_packets), .camera2_good_objects(),
    .camera2_fcs_errors(camera2_fcs_errors),
    .camera2_ip_checksum_errors(camera2_ip_errors),
    .camera2_udp_checksum_errors(camera2_udp_errors),
    .camera2_header_errors(camera2_header_errors),
    .camera2_sequence_errors(), .camera2_offset_errors(),
    .camera2_object_crc_errors(), .malformed_frames(malformed_frames),
    .gmii_rx_er_frames(), .stats_update_toggle()
);

initial begin
    repeat (8) @(posedge clk);
    rst_n = 1'b1;
    repeat (4) @(posedge clk);
    @(negedge clk);
    meta_valid = 1'b1;
    do @(posedge clk); while (!meta_ready);
    @(negedge clk);
    meta_valid = 1'b0;

    for (byte_index = 0; byte_index < 1368; byte_index = byte_index + 1) begin
        @(negedge clk);
        data = byte_index[7:0];
        data_last = (byte_index == 1367);
        data_valid = 1'b1;
        do @(posedge clk); while (!data_ready);
    end
    @(negedge clk);
    data_valid = 1'b0;
    data_last = 1'b0;

    repeat (2500) @(posedge clk);
    if (camera2_good_packets != 1 || camera2_header_errors != 0 ||
        camera2_fcs_errors != 0 || camera2_ip_errors != 0 ||
        camera2_udp_errors != 0 || malformed_frames != 0)
        $fatal(1, "good=%0d header=%0d fcs=%0d ip=%0d udp=%0d malformed=%0d",
               camera2_good_packets, camera2_header_errors,
               camera2_fcs_errors, camera2_ip_errors,
               camera2_udp_errors, malformed_frames);
    $display("PASS tb_camera_udp_tx_rx_loopback");
    $finish;
end

initial begin
    repeat (200000) @(posedge clk);
    $fatal(1, "timeout waiting for camera UDP loopback");
end

endmodule
