`timescale 1ns/1ps

module tb_camera_udp_rx_checker;
    localparam integer FRAME_BYTES = 1454;

    reg clk = 1'b0;
    reg rst_n = 1'b0;
    reg gmii_rx_dv = 1'b0;
    reg gmii_rx_er = 1'b0;
    reg [7:0] gmii_rxd = 8'd0;
    reg [7:0] frame [0:2047];
    integer index;

    wire [1:0] current_source;
    wire [31:0] camera1_good_frames;
    wire [31:0] camera1_good_objects;
    wire [31:0] camera1_fcs_errors;
    wire [31:0] camera1_ip_checksum_errors;
    wire [31:0] camera1_udp_checksum_errors;
    wire [31:0] camera1_header_errors;
    wire [31:0] camera1_sequence_errors;
    wire [31:0] camera1_offset_errors;
    wire [31:0] camera1_object_crc_errors;
    wire [31:0] camera2_good_frames;
    wire [31:0] camera2_good_objects;
    wire [31:0] camera2_fcs_errors;
    wire [31:0] camera2_ip_checksum_errors;
    wire [31:0] camera2_udp_checksum_errors;
    wire [31:0] camera2_header_errors;
    wire [31:0] camera2_sequence_errors;
    wire [31:0] camera2_offset_errors;
    wire [31:0] camera2_object_crc_errors;
    wire [31:0] malformed_frames;
    wire [31:0] gmii_rx_er_frames;

    always #4 clk = ~clk;

    camera_udp_rx_checker dut (
        .rx_clk(clk),
        .rst_n(rst_n),
        .gmii_rx_dv(gmii_rx_dv),
        .gmii_rx_er(gmii_rx_er),
        .gmii_rxd(gmii_rxd),
        .current_source(current_source),
        .camera1_good_frames(camera1_good_frames),
        .camera1_good_objects(camera1_good_objects),
        .camera1_fcs_errors(camera1_fcs_errors),
        .camera1_ip_checksum_errors(camera1_ip_checksum_errors),
        .camera1_udp_checksum_errors(camera1_udp_checksum_errors),
        .camera1_header_errors(camera1_header_errors),
        .camera1_sequence_errors(camera1_sequence_errors),
        .camera1_offset_errors(camera1_offset_errors),
        .camera1_object_crc_errors(camera1_object_crc_errors),
        .camera2_good_frames(camera2_good_frames),
        .camera2_good_objects(camera2_good_objects),
        .camera2_fcs_errors(camera2_fcs_errors),
        .camera2_ip_checksum_errors(camera2_ip_checksum_errors),
        .camera2_udp_checksum_errors(camera2_udp_checksum_errors),
        .camera2_header_errors(camera2_header_errors),
        .camera2_sequence_errors(camera2_sequence_errors),
        .camera2_offset_errors(camera2_offset_errors),
        .camera2_object_crc_errors(camera2_object_crc_errors),
        .malformed_frames(malformed_frames),
        .gmii_rx_er_frames(gmii_rx_er_frames),
        .stats_update_toggle()
    );

    function automatic [31:0] crc32_byte;
        input [31:0] crc_in;
        input [7:0] data_in;
        reg [31:0] value;
        integer bit_index;
        begin
            value = crc_in;
            for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1)
                value = (value[0] ^ data_in[bit_index]) ?
                        ((value >> 1) ^ 32'hedb8_8320) :
                        (value >> 1);
            crc32_byte = value;
        end
    endfunction

    function automatic [15:0] checksum_finish;
        input [31:0] sum_in;
        reg [31:0] sum;
        begin
            sum = sum_in;
            sum = sum[15:0] + sum[31:16];
            sum = sum[15:0] + sum[31:16];
            checksum_finish = ~sum[15:0];
        end
    endfunction

    task automatic set16(input integer at, input [15:0] value);
        begin
            frame[at] = value[15:8];
            frame[at + 1] = value[7:0];
        end
    endtask

    task automatic set32(input integer at, input [31:0] value);
        begin
            frame[at] = value[31:24];
            frame[at + 1] = value[23:16];
            frame[at + 2] = value[15:8];
            frame[at + 3] = value[7:0];
        end
    endtask

    task automatic finish_checksums;
        reg [31:0] sum;
        reg [15:0] checksum;
        reg [31:0] crc;
        reg [31:0] fcs;
        integer byte_index;
        begin
            frame[32] = 0;
            frame[33] = 0;
            sum = 0;
            for (byte_index = 22; byte_index <= 40; byte_index = byte_index + 2)
                sum = sum + {frame[byte_index], frame[byte_index + 1]};
            checksum = checksum_finish(sum);
            frame[32] = checksum[15:8];
            frame[33] = checksum[7:0];

            frame[48] = 0;
            frame[49] = 0;
            sum = 16'hc0a8 + 16'h0067 + 16'hc0a8 + 16'h0014 +
                  16'h0011 + 16'h0580;
            for (byte_index = 42; byte_index <= 1448; byte_index = byte_index + 2)
                sum = sum + {frame[byte_index], frame[byte_index + 1]};
            checksum = checksum_finish(sum);
            if (checksum == 0)
                checksum = 16'hffff;
            frame[48] = checksum[15:8];
            frame[49] = checksum[7:0];

            crc = 32'hffff_ffff;
            for (byte_index = 8; byte_index <= 1449; byte_index = byte_index + 1)
                crc = crc32_byte(crc, frame[byte_index]);
            fcs = ~crc;
            frame[1450] = fcs[7:0];
            frame[1451] = fcs[15:8];
            frame[1452] = fcs[23:16];
            frame[1453] = fcs[31:24];
        end
    endtask

    task automatic build_packet(
        input [15:0] camera_id,
        input [31:0] packet_sequence,
        input [31:0] offset,
        input [7:0] flags
    );
        integer byte_index;
        begin
            for (byte_index = 0; byte_index < FRAME_BYTES;
                 byte_index = byte_index + 1)
                frame[byte_index] = 0;
            for (byte_index = 0; byte_index < 7; byte_index = byte_index + 1)
                frame[byte_index] = 8'h55;
            frame[7] = 8'hd5;
            frame[8] = 8'h00; frame[9] = 8'h0a; frame[10] = 8'h35;
            frame[11] = 8'h01; frame[12] = 8'hfe; frame[13] = 8'hc4;
            frame[14] = 8'h00; frame[15] = 8'h0a; frame[16] = 8'h35;
            frame[17] = 8'h02; frame[18] = 8'hfe; frame[19] = 8'hc3;
            set16(20, 16'h0800);
            frame[22] = 8'h45;
            set16(24, 16'h0594);
            set16(26, packet_sequence[15:0]);
            set16(28, 16'h4000);
            frame[30] = 8'h40;
            frame[31] = 8'h11;
            set32(34, 32'hc0a8_0067);
            set32(38, 32'hc0a8_0014);
            set16(42, 16'h1f90);
            set16(44, 16'h1f90);
            set16(46, 16'h0580);
            set32(50, 32'h4158_4453);
            frame[54] = 8'd1;
            frame[55] = 8'd3;
            frame[56] = 8'd3;
            frame[57] = flags;
            set32(58, 32'd0);
            set16(62, camera_id);
            set16(64, 16'd1368);
            set32(66, packet_sequence);
            set32(70, offset);
            set32(74, 32'd614400);
            set32(78, 32'd0);
            for (byte_index = 0; byte_index < 1368; byte_index = byte_index + 1)
                frame[82 + byte_index] =
                    camera_id[7:0] ^ (offset + byte_index);
            finish_checksums();
        end
    endtask

    task automatic send_packet;
        integer byte_index;
        begin
            for (byte_index = 0; byte_index < FRAME_BYTES;
                 byte_index = byte_index + 1) begin
                @(negedge clk);
                gmii_rx_dv = 1'b1;
                gmii_rxd = frame[byte_index];
            end
            @(negedge clk);
            gmii_rx_dv = 1'b0;
            gmii_rxd = 0;
            repeat (16) @(posedge clk);
        end
    endtask

    function automatic [31:0] total_errors;
        begin
            total_errors =
                camera1_fcs_errors + camera1_ip_checksum_errors +
                camera1_udp_checksum_errors + camera1_header_errors +
                camera1_sequence_errors + camera1_offset_errors +
                camera1_object_crc_errors + camera2_fcs_errors +
                camera2_ip_checksum_errors + camera2_udp_checksum_errors +
                camera2_header_errors + camera2_sequence_errors +
                camera2_offset_errors + camera2_object_crc_errors +
                malformed_frames + gmii_rx_er_frames;
        end
    endfunction

    initial begin
        repeat (8) @(posedge clk);
        rst_n = 1'b1;
        build_packet(1, 0, 0, 8'h01);
        send_packet();
        build_packet(2, 1, 0, 8'h01);
        send_packet();
        build_packet(1, 2, 1368, 8'h00);
        send_packet();
        build_packet(2, 3, 1368, 8'h00);
        send_packet();

        if (camera1_good_frames != 2 || camera2_good_frames != 2)
            $fatal(1, "Good packet counters wrong: %0d/%0d",
                   camera1_good_frames, camera2_good_frames);
        if (camera1_good_objects != 0 || camera2_good_objects != 0)
            $fatal(1, "Unexpected complete camera frame");
        if (total_errors() != 0)
            $fatal(1, "Camera checker errors: %0d", total_errors());
        $display("PASS tb_camera_udp_rx_checker");
        $finish;
    end

endmodule
