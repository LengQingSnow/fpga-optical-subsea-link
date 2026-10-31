`timescale 1ns/1ps

module tb_camera_udp_packet_boundaries;

reg rst_n = 1'b0;
reg camera_pclk = 1'b0;
reg tx_clk = 1'b0;
reg camera_vsync = 1'b0;
reg [15:0] camera_pixel = 16'd0;
reg camera_pixel_valid = 1'b0;
reg packet_meta_ready = 1'b0;
reg packet_data_ready = 1'b1;

wire packet_meta_valid;
wire [7:0] packet_flags;
wire [15:0] packet_valid_length;
wire [31:0] packet_object_offset;
wire packet_data_valid;
wire packet_data_last;
wire [7:0] packet_data;

integer packet_count = 0;
integer byte_count = 0;
integer pixel_index;
reg [15:0] expected_length [0:5];
reg [31:0] expected_offset [0:5];
reg [7:0] expected_flags [0:5];

always #6 camera_pclk = ~camera_pclk;
always #4 tx_clk = ~tx_clk;

camera_udp_packet_source #(
    .FIFO_DEPTH_PIXELS(8192),
    .FRAME_BYTES(20),
    .MAX_PACKET_BYTES(8)
) dut (
    .rst_n(rst_n),
    .camera1_pclk(camera_pclk),
    .camera1_vsync(camera_vsync),
    .camera1_pixel(camera_pixel),
    .camera1_pixel_valid(camera_pixel_valid),
    .camera2_pclk(camera_pclk),
    .camera2_vsync(1'b0),
    .camera2_pixel(16'd0),
    .camera2_pixel_valid(1'b0),
    .tx_clk(tx_clk),
    .tx_rst_n(rst_n),
    .packet_meta_valid(packet_meta_valid),
    .packet_meta_ready(packet_meta_ready),
    .packet_type(),
    .packet_flags(packet_flags),
    .packet_cycle(),
    .packet_object_id(),
    .packet_valid_length(packet_valid_length),
    .packet_sequence(),
    .packet_object_offset(packet_object_offset),
    .packet_object_length(),
    .packet_object_crc32(),
    .packet_data_valid(packet_data_valid),
    .packet_data_ready(packet_data_ready),
    .packet_data(packet_data),
    .packet_data_last(packet_data_last),
    .camera1_fifo_overflows(),
    .camera2_fifo_overflows(),
    .camera1_resyncs(),
    .camera2_resyncs(),
    .packets_issued()
);

always @(posedge tx_clk) begin
    if (packet_meta_valid && packet_meta_ready) begin
        if (packet_count > 5)
            $fatal(1, "unexpected seventh packet");
        if (packet_valid_length != expected_length[packet_count] ||
            packet_object_offset != expected_offset[packet_count] ||
            packet_flags != expected_flags[packet_count])
            $fatal(1, "packet %0d metadata length=%0d offset=%0d flags=%02x",
                   packet_count, packet_valid_length,
                   packet_object_offset, packet_flags);
        byte_count = 0;
    end

    if (packet_data_valid && packet_data_ready) begin
        byte_count = byte_count + 1;
        if (packet_data_last) begin
            if (byte_count != expected_length[packet_count])
                $fatal(1, "packet %0d ended at %0d bytes",
                       packet_count, byte_count);
            packet_count = packet_count + 1;
            if (packet_count == 6) begin
                $display("PASS tb_camera_udp_packet_boundaries");
                $finish;
            end
        end
    end
end

initial begin
    expected_length[0] = 8;
    expected_length[1] = 8;
    expected_length[2] = 4;
    expected_offset[0] = 0;
    expected_offset[1] = 8;
    expected_offset[2] = 16;
    expected_flags[0] = 8'h01;
    expected_flags[1] = 8'h00;
    expected_flags[2] = 8'h02;
    expected_length[3] = 8;
    expected_length[4] = 8;
    expected_length[5] = 4;
    expected_offset[3] = 0;
    expected_offset[4] = 8;
    expected_offset[5] = 16;
    expected_flags[3] = 8'h01;
    expected_flags[4] = 8'h00;
    expected_flags[5] = 8'h02;

    repeat (8) @(posedge tx_clk);
    rst_n = 1'b1;
    wait (!dut.u_camera1_fifo.fifo_wr_reset_busy);
    repeat (3) @(posedge camera_pclk);
    @(negedge camera_pclk);
    camera_vsync = 1'b1;
    @(posedge camera_pclk);
    @(negedge camera_pclk);
    camera_vsync = 1'b0;
    for (pixel_index = 0; pixel_index < 64; pixel_index = pixel_index + 1) begin
        camera_pixel = {(8'h40 + pixel_index), (8'h20 + pixel_index)};
        camera_pixel_valid = 1'b1;
        @(posedge camera_pclk);
        @(negedge camera_pclk);
    end
    camera_pixel_valid = 1'b0;
    repeat (10) @(posedge tx_clk);
    packet_meta_ready = 1'b1;

    wait (packet_count == 3);
    @(negedge camera_pclk);
    camera_vsync = 1'b1;
    @(posedge camera_pclk);
    @(negedge camera_pclk);
    camera_vsync = 1'b0;
    for (pixel_index = 0; pixel_index < 10; pixel_index = pixel_index + 1) begin
        camera_pixel = {(8'h80 + pixel_index), (8'h60 + pixel_index)};
        camera_pixel_valid = 1'b1;
        @(posedge camera_pclk);
        @(negedge camera_pclk);
    end
    camera_pixel_valid = 1'b0;

    repeat (2000) @(posedge tx_clk);
    $display("state=%0d count=%0d empty=%0b data=%h ready=%0b index=%0d",
             dut.state, dut.fifo1_count, dut.fifo1_empty,
             dut.fifo1_data, dut.camera1_ready,
             dut.camera1_packet_index);
    $fatal(1, "timeout after %0d packets", packet_count);
end

endmodule
