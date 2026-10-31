`timescale 1ns/1ps

module tb_camera_udp_packet_source;
    reg rst_n = 1'b0;
    reg tx_rst_n = 1'b0;
    reg camera1_pclk = 1'b0;
    reg camera2_pclk = 1'b0;
    reg tx_clk = 1'b0;
    reg camera1_vsync = 1'b0;
    reg camera2_vsync = 1'b0;
    reg [15:0] camera1_pixel = 16'd0;
    reg [15:0] camera2_pixel = 16'd0;
    reg camera1_pixel_valid = 1'b0;
    reg camera2_pixel_valid = 1'b0;
    reg packet_meta_ready = 1'b1;
    reg packet_data_ready = 1'b1;

    wire packet_meta_valid;
    wire [7:0] packet_type;
    wire [7:0] packet_flags;
    wire [31:0] packet_cycle;
    wire [15:0] packet_object_id;
    wire [15:0] packet_valid_length;
    wire [31:0] packet_sequence;
    wire [31:0] packet_object_offset;
    wire [31:0] packet_object_length;
    wire [31:0] packet_object_crc32;
    wire packet_data_valid;
    wire [7:0] packet_data;
    wire packet_data_last;
    wire [31:0] camera1_fifo_overflows;
    wire [31:0] camera2_fifo_overflows;
    wire [31:0] camera1_resyncs;
    wire [31:0] camera2_resyncs;
    wire [31:0] packets_issued;

    integer packet_count = 0;
    integer byte_count = 0;
    integer active_camera = 0;
    integer pixel_index;
    reg [15:0] expected_pixel;

    always #6 camera1_pclk = ~camera1_pclk;
    always #7 camera2_pclk = ~camera2_pclk;
    always #4 tx_clk = ~tx_clk;

    camera_udp_packet_source dut (
        .rst_n(rst_n),
        .camera1_pclk(camera1_pclk),
        .camera1_vsync(camera1_vsync),
        .camera1_pixel(camera1_pixel),
        .camera1_pixel_valid(camera1_pixel_valid),
        .camera2_pclk(camera2_pclk),
        .camera2_vsync(camera2_vsync),
        .camera2_pixel(camera2_pixel),
        .camera2_pixel_valid(camera2_pixel_valid),
        .tx_clk(tx_clk),
        .tx_rst_n(tx_rst_n),
        .packet_meta_valid(packet_meta_valid),
        .packet_meta_ready(packet_meta_ready),
        .packet_type(packet_type),
        .packet_flags(packet_flags),
        .packet_cycle(packet_cycle),
        .packet_object_id(packet_object_id),
        .packet_valid_length(packet_valid_length),
        .packet_sequence(packet_sequence),
        .packet_object_offset(packet_object_offset),
        .packet_object_length(packet_object_length),
        .packet_object_crc32(packet_object_crc32),
        .packet_data_valid(packet_data_valid),
        .packet_data_ready(packet_data_ready),
        .packet_data(packet_data),
        .packet_data_last(packet_data_last),
        .camera1_fifo_overflows(camera1_fifo_overflows),
        .camera2_fifo_overflows(camera2_fifo_overflows),
        .camera1_resyncs(camera1_resyncs),
        .camera2_resyncs(camera2_resyncs),
        .packets_issued(packets_issued)
    );

    always @(posedge tx_clk) begin
        if (packet_meta_valid && packet_meta_ready) begin
            if (packet_type != 8'd3 ||
                packet_valid_length != 16'd1368 ||
                packet_object_length != 32'd614400 ||
                packet_object_crc32 != 32'd0)
                $fatal(1, "Bad camera metadata");
            if (packet_count == 0) begin
                if (packet_object_id != 16'd1 ||
                    packet_sequence != 32'd0 ||
                    packet_object_offset != 32'd0 ||
                    packet_flags != 8'h01)
                    $fatal(1, "Bad camera1 first packet metadata");
            end else if (packet_count == 1) begin
                if (packet_object_id != 16'd2 ||
                    packet_sequence != 32'd1 ||
                    packet_object_offset != 32'd0 ||
                    packet_flags != 8'h01)
                    $fatal(1, "Bad camera2 first packet metadata");
            end
            active_camera = packet_object_id;
            byte_count = 0;
        end

        if (packet_data_valid && packet_data_ready) begin
            pixel_index = byte_count >> 1;
            expected_pixel = (active_camera == 1) ?
                             (16'h1000 + pixel_index) :
                             (16'h8000 + pixel_index);
            if ((!byte_count[0] && packet_data != expected_pixel[15:8]) ||
                (byte_count[0] && packet_data != expected_pixel[7:0]))
                $fatal(1, "Payload mismatch camera=%0d byte=%0d",
                       active_camera, byte_count);
            byte_count = byte_count + 1;
            if (packet_data_last) begin
                if (byte_count != 1368)
                    $fatal(1, "Wrong payload length %0d", byte_count);
                packet_count = packet_count + 1;
                if (packet_count == 2) begin
                    if (camera1_fifo_overflows != 0 ||
                        camera2_fifo_overflows != 0 ||
                        camera1_resyncs != 0 ||
                        camera2_resyncs != 0)
                        $fatal(1, "Unexpected FIFO error counters");
                    $display("PASS tb_camera_udp_packet_source");
                    $finish;
                end
            end
        end
    end

    task automatic send_camera1_pixels;
        integer index;
        begin
            @(posedge camera1_pclk);
            camera1_vsync <= 1'b1;
            @(posedge camera1_pclk);
            camera1_vsync <= 1'b0;
            for (index = 0; index < 1600; index = index + 1) begin
                camera1_pixel <= 16'h1000 + index;
                camera1_pixel_valid <= 1'b1;
                @(posedge camera1_pclk);
            end
            camera1_pixel_valid <= 1'b0;
        end
    endtask

    task automatic send_camera2_pixels;
        integer index;
        begin
            @(posedge camera2_pclk);
            camera2_vsync <= 1'b1;
            @(posedge camera2_pclk);
            camera2_vsync <= 1'b0;
            for (index = 0; index < 1600; index = index + 1) begin
                camera2_pixel <= 16'h8000 + index;
                camera2_pixel_valid <= 1'b1;
                @(posedge camera2_pclk);
            end
            camera2_pixel_valid <= 1'b0;
        end
    endtask

    initial begin
        repeat (10) @(posedge tx_clk);
        rst_n = 1'b1;
        tx_rst_n = 1'b1;
        repeat (40) @(posedge tx_clk);
        fork
            send_camera1_pixels();
            send_camera2_pixels();
        join_none

        repeat (200000) @(posedge tx_clk);
        $display("debug state=%0d fifo1=%0d fifo2=%0d empty=%0b/%0b meta=%0b packets=%0d overflow=%0d/%0d",
                 dut.state, dut.fifo1_count, dut.fifo2_count,
                 dut.fifo1_empty, dut.fifo2_empty,
                 packet_meta_valid, packets_issued,
                 camera1_fifo_overflows, camera2_fifo_overflows);
        $fatal(1, "Timeout waiting for camera packets");
    end

endmodule
