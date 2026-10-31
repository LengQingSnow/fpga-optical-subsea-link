`timescale 1ns/1ps

module tb_dataset_udp_loopback;
    localparam integer IMAGE_BYTES = 32;
    localparam integer WAVEFORM_BYTES = 24;
    localparam integer UDP_FRAME_BYTES = 1454;
    localparam integer ARP_FRAME_BYTES = 72;

    reg clk = 1'b0;
    reg rst_n = 1'b0;
    reg gmii_rx_dv = 1'b0;
    reg gmii_rx_er = 1'b0;
    reg [7:0] gmii_rxd = 8'd0;

    wire [1:0] current_source;
    wire [31:0] image_good_frames;
    wire [31:0] image_good_objects;
    wire [31:0] image_fcs_errors;
    wire [31:0] image_ip_checksum_errors;
    wire [31:0] image_udp_checksum_errors;
    wire [31:0] image_header_errors;
    wire [31:0] image_sequence_errors;
    wire [31:0] image_offset_errors;
    wire [31:0] image_object_crc_errors;
    wire [31:0] waveform_good_frames;
    wire [31:0] waveform_good_objects;
    wire [31:0] waveform_fcs_errors;
    wire [31:0] waveform_ip_checksum_errors;
    wire [31:0] waveform_udp_checksum_errors;
    wire [31:0] waveform_header_errors;
    wire [31:0] waveform_sequence_errors;
    wire [31:0] waveform_offset_errors;
    wire [31:0] waveform_object_crc_errors;
    wire [31:0] malformed_frames;
    wire [31:0] gmii_rx_er_frames;
    wire stats_update_toggle;

    wire arp_tx_en;
    wire arp_tx_er;
    wire [7:0] arp_txd;
    wire [31:0] arp_requests;
    wire [31:0] arp_replies;
    wire [31:0] arp_fcs_errors;
    wire [31:0] arp_malformed_frames;

    reg [7:0] frame [0:2047];
    reg [7:0] reply [0:255];
    integer reply_length = 0;
    integer index;

    always #4 clk = ~clk;

    dataset_udp_rx_checker #(
        .IMAGE_OBJECT_BYTES(IMAGE_BYTES),
        .WAVEFORM_OBJECT_BYTES(WAVEFORM_BYTES),
        .IMAGE_OBJECT_COUNT(45)
    ) dut_checker (
        .rx_clk(clk),
        .rst_n(rst_n),
        .gmii_rx_dv(gmii_rx_dv),
        .gmii_rx_er(gmii_rx_er),
        .gmii_rxd(gmii_rxd),
        .current_source(current_source),
        .image_good_frames(image_good_frames),
        .image_good_objects(image_good_objects),
        .image_fcs_errors(image_fcs_errors),
        .image_ip_checksum_errors(image_ip_checksum_errors),
        .image_udp_checksum_errors(image_udp_checksum_errors),
        .image_header_errors(image_header_errors),
        .image_sequence_errors(image_sequence_errors),
        .image_offset_errors(image_offset_errors),
        .image_object_crc_errors(image_object_crc_errors),
        .waveform_good_frames(waveform_good_frames),
        .waveform_good_objects(waveform_good_objects),
        .waveform_fcs_errors(waveform_fcs_errors),
        .waveform_ip_checksum_errors(waveform_ip_checksum_errors),
        .waveform_udp_checksum_errors(waveform_udp_checksum_errors),
        .waveform_header_errors(waveform_header_errors),
        .waveform_sequence_errors(waveform_sequence_errors),
        .waveform_offset_errors(waveform_offset_errors),
        .waveform_object_crc_errors(waveform_object_crc_errors),
        .malformed_frames(malformed_frames),
        .gmii_rx_er_frames(gmii_rx_er_frames),
        .stats_update_toggle(stats_update_toggle)
    );

    dual_ip_arp_responder responder (
        .clk(clk),
        .rst_n(rst_n),
        .gmii_rx_dv(gmii_rx_dv),
        .gmii_rx_er(gmii_rx_er),
        .gmii_rxd(gmii_rxd),
        .gmii_tx_en(arp_tx_en),
        .gmii_tx_er(arp_tx_er),
        .gmii_txd(arp_txd),
        .arp_requests(arp_requests),
        .arp_replies(arp_replies),
        .arp_fcs_errors(arp_fcs_errors),
        .arp_malformed_frames(arp_malformed_frames)
    );

    always @(posedge clk) begin
        if (arp_tx_en) begin
            reply[reply_length] = arp_txd;
            reply_length = reply_length + 1;
        end
        if (arp_tx_er)
            $fatal(1, "ARP responder asserted gmii_tx_er");
    end

    function automatic [31:0] crc32_byte;
        input [31:0] crc_in;
        input [7:0] data_in;
        reg [31:0] value;
        integer bit_index;
        begin
            value = crc_in;
            for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1) begin
                if (value[0] ^ data_in[bit_index])
                    value = (value >> 1) ^ 32'hedb8_8320;
                else
                    value = value >> 1;
            end
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

    function automatic [7:0] dataset_byte;
        input integer source;
        input integer byte_offset;
        integer value;
        begin
            if (source == 1)
                value = byte_offset * 7 + 3;
            else
                value = byte_offset * 11 + 5;
            dataset_byte = value[7:0];
        end
    endfunction

    function automatic [31:0] complete_object_crc;
        input integer source;
        input integer byte_count;
        reg [31:0] crc;
        integer byte_index;
        begin
            crc = 32'hffff_ffff;
            for (byte_index = 0; byte_index < byte_count;
                 byte_index = byte_index + 1)
                crc = crc32_byte(crc, dataset_byte(source, byte_index));
            complete_object_crc = ~crc;
        end
    endfunction

    function automatic [31:0] total_protocol_errors;
        begin
            total_protocol_errors =
                image_fcs_errors +
                image_ip_checksum_errors +
                image_udp_checksum_errors +
                image_header_errors +
                image_sequence_errors +
                image_offset_errors +
                image_object_crc_errors +
                waveform_fcs_errors +
                waveform_ip_checksum_errors +
                waveform_udp_checksum_errors +
                waveform_header_errors +
                waveform_sequence_errors +
                waveform_offset_errors +
                waveform_object_crc_errors +
                malformed_frames +
                gmii_rx_er_frames;
        end
    endfunction

    task automatic set16;
        input integer at;
        input [15:0] value;
        begin
            frame[at] = value[15:8];
            frame[at + 1] = value[7:0];
        end
    endtask

    task automatic set32;
        input integer at;
        input [31:0] value;
        begin
            frame[at] = value[31:24];
            frame[at + 1] = value[23:16];
            frame[at + 2] = value[15:8];
            frame[at + 3] = value[7:0];
        end
    endtask

    task automatic write_frame_fcs;
        input integer first_byte;
        input integer last_byte;
        input integer fcs_byte;
        reg [31:0] crc;
        reg [31:0] fcs;
        integer byte_index;
        begin
            crc = 32'hffff_ffff;
            for (byte_index = first_byte; byte_index <= last_byte;
                 byte_index = byte_index + 1)
                crc = crc32_byte(crc, frame[byte_index]);
            fcs = ~crc;
            frame[fcs_byte] = fcs[7:0];
            frame[fcs_byte + 1] = fcs[15:8];
            frame[fcs_byte + 2] = fcs[23:16];
            frame[fcs_byte + 3] = fcs[31:24];
        end
    endtask

    task automatic write_ip_checksum;
        reg [31:0] sum;
        reg [15:0] checksum;
        integer byte_index;
        begin
            frame[32] = 8'd0;
            frame[33] = 8'd0;
            sum = 32'd0;
            for (byte_index = 22; byte_index <= 40;
                 byte_index = byte_index + 2)
                sum = sum + {frame[byte_index], frame[byte_index + 1]};
            checksum = checksum_finish(sum);
            frame[32] = checksum[15:8];
            frame[33] = checksum[7:0];
        end
    endtask

    task automatic write_udp_checksum;
        reg [31:0] sum;
        reg [15:0] checksum;
        integer byte_index;
        begin
            frame[48] = 8'd0;
            frame[49] = 8'd0;
            sum = {frame[34], frame[35]} +
                  {frame[36], frame[37]} +
                  {frame[38], frame[39]} +
                  {frame[40], frame[41]} +
                  16'h0011 +
                  16'h0580;
            for (byte_index = 42; byte_index <= 1448;
                 byte_index = byte_index + 2)
                sum = sum + {frame[byte_index], frame[byte_index + 1]};
            checksum = checksum_finish(sum);
            if (checksum == 16'd0)
                checksum = 16'hffff;
            frame[48] = checksum[15:8];
            frame[49] = checksum[7:0];
        end
    endtask

    task automatic build_udp_frame;
        input integer source;
        input [31:0] packet_sequence;
        input [31:0] object_offset;
        input integer valid_bytes;
        input [7:0] flags;
        input [31:0] object_crc;
        integer byte_index;
        integer payload_index;
        begin
            for (byte_index = 0; byte_index < UDP_FRAME_BYTES;
                 byte_index = byte_index + 1)
                frame[byte_index] = 8'd0;

            for (byte_index = 0; byte_index < 7; byte_index = byte_index + 1)
                frame[byte_index] = 8'h55;
            frame[7] = 8'hd5;

            frame[8] = 8'h00;
            frame[9] = 8'h0a;
            frame[10] = 8'h35;
            frame[11] = 8'h01;
            frame[12] = 8'hfe;
            frame[13] = (source == 1) ? 8'hc1 : 8'hc2;
            frame[14] = 8'h00;
            frame[15] = 8'h0a;
            frame[16] = 8'h35;
            frame[17] = 8'h02;
            frame[18] = 8'hfe;
            frame[19] = (source == 1) ? 8'hc1 : 8'hc2;
            set16(20, 16'h0800);

            frame[22] = 8'h45;
            frame[23] = 8'h00;
            set16(24, 16'h0594);
            set16(26, packet_sequence[15:0]);
            set16(28, 16'h4000);
            frame[30] = 8'h40;
            frame[31] = 8'h11;
            if (source == 1) begin
                set32(34, 32'hc0a8_0065);
                set32(38, 32'hc0a8_0011);
            end else begin
                set32(34, 32'hc0a8_0066);
                set32(38, 32'hc0a8_0012);
            end
            write_ip_checksum();

            set16(42, 16'h1f90);
            set16(44, 16'h1f90);
            set16(46, 16'h0580);

            frame[50] = "A";
            frame[51] = "X";
            frame[52] = "D";
            frame[53] = "S";
            frame[54] = 8'h01;
            frame[55] = (source == 1) ? 8'h01 : 8'h02;
            frame[56] = source[7:0];
            frame[57] = flags;
            set32(58, 32'd0);
            set16(62, 16'd1);
            set16(64, valid_bytes[15:0]);
            set32(66, packet_sequence);
            set32(70, object_offset);
            set32(74, (source == 1) ? IMAGE_BYTES : WAVEFORM_BYTES);
            set32(78, object_crc);

            for (payload_index = 0; payload_index < valid_bytes;
                 payload_index = payload_index + 1)
                frame[82 + payload_index] =
                    dataset_byte(source, object_offset + payload_index);

            write_udp_checksum();
            write_frame_fcs(8, 1449, 1450);
        end
    endtask

    task automatic build_arp_request;
        input [7:0] target_host;
        integer byte_index;
        begin
            for (byte_index = 0; byte_index < ARP_FRAME_BYTES;
                 byte_index = byte_index + 1)
                frame[byte_index] = 8'd0;
            for (byte_index = 0; byte_index < 7; byte_index = byte_index + 1)
                frame[byte_index] = 8'h55;
            frame[7] = 8'hd5;
            for (byte_index = 8; byte_index < 14; byte_index = byte_index + 1)
                frame[byte_index] = 8'hff;
            frame[14] = 8'h02;
            frame[15] = 8'h11;
            frame[16] = 8'h22;
            frame[17] = 8'h33;
            frame[18] = 8'h44;
            frame[19] = 8'h55;
            set16(20, 16'h0806);
            set16(22, 16'h0001);
            set16(24, 16'h0800);
            frame[26] = 8'h06;
            frame[27] = 8'h04;
            set16(28, 16'h0001);
            frame[30] = 8'h02;
            frame[31] = 8'h11;
            frame[32] = 8'h22;
            frame[33] = 8'h33;
            frame[34] = 8'h44;
            frame[35] = 8'h55;
            set32(36, 32'hc0a8_0003);
            set32(46, {24'hc0a800, target_host});
            write_frame_fcs(8, 67, 68);
        end
    endtask

    task automatic send_frame;
        input integer byte_count;
        integer byte_index;
        begin
            for (byte_index = 0; byte_index < byte_count;
                 byte_index = byte_index + 1) begin
                @(negedge clk);
                gmii_rx_dv = 1'b1;
                gmii_rx_er = 1'b0;
                gmii_rxd = frame[byte_index];
            end
            @(negedge clk);
            gmii_rx_dv = 1'b0;
            gmii_rx_er = 1'b0;
            gmii_rxd = 8'd0;
            repeat (12) @(posedge clk);
        end
    endtask

    task automatic reset_duts;
        begin
            gmii_rx_dv = 1'b0;
            gmii_rx_er = 1'b0;
            gmii_rxd = 8'd0;
            rst_n = 1'b0;
            repeat (5) @(posedge clk);
            rst_n = 1'b1;
            repeat (3) @(posedge clk);
        end
    endtask

    task automatic check_arp_reply;
        input [7:0] target_host;
        reg [31:0] crc;
        reg [31:0] received_fcs;
        reg [7:0] expected_mac_tail;
        integer byte_index;
        begin
            expected_mac_tail = (target_host == 8'd17) ? 8'hc1 : 8'hc2;
            wait (reply_length == ARP_FRAME_BYTES);
            repeat (2) @(posedge clk);
            if (reply_length != ARP_FRAME_BYTES)
                $fatal(1, "ARP reply length is %0d", reply_length);
            for (byte_index = 0; byte_index < 7; byte_index = byte_index + 1)
                if (reply[byte_index] !== 8'h55)
                    $fatal(1, "ARP reply preamble mismatch");
            if (reply[7] !== 8'hd5)
                $fatal(1, "ARP reply SFD mismatch");
            if ({reply[8], reply[9], reply[10], reply[11], reply[12],
                 reply[13]} !== 48'h0211_2233_4455)
                $fatal(1, "ARP reply destination MAC mismatch");
            if ({reply[14], reply[15], reply[16], reply[17], reply[18],
                 reply[19]} !== {40'h000a_3501_fe, expected_mac_tail})
                $fatal(1, "ARP reply source MAC mismatch");
            if ({reply[20], reply[21]} !== 16'h0806 ||
                {reply[28], reply[29]} !== 16'h0002)
                $fatal(1, "ARP reply protocol fields mismatch");
            if ({reply[30], reply[31], reply[32], reply[33], reply[34],
                 reply[35]} !== {40'h000a_3501_fe, expected_mac_tail})
                $fatal(1, "ARP sender MAC mismatch");
            if ({reply[36], reply[37], reply[38], reply[39]} !==
                {24'hc0a800, target_host})
                $fatal(1, "ARP sender IP mismatch");
            if ({reply[40], reply[41], reply[42], reply[43], reply[44],
                 reply[45]} !== 48'h0211_2233_4455 ||
                {reply[46], reply[47], reply[48], reply[49]} !==
                32'hc0a8_0003)
                $fatal(1, "ARP target fields mismatch");
            crc = 32'hffff_ffff;
            for (byte_index = 8; byte_index <= 67;
                 byte_index = byte_index + 1)
                crc = crc32_byte(crc, reply[byte_index]);
            received_fcs = {reply[71], reply[70], reply[69], reply[68]};
            if (received_fcs !== ~crc)
                $fatal(1, "ARP reply FCS mismatch");
        end
    endtask

    initial begin
        reg [31:0] image_crc;
        reg [31:0] waveform_crc;

        image_crc = complete_object_crc(1, IMAGE_BYTES);
        waveform_crc = complete_object_crc(2, WAVEFORM_BYTES);

        reset_duts();
        reply_length = 0;
        build_arp_request(8'd17);
        send_frame(ARP_FRAME_BYTES);
        check_arp_reply(8'd17);
        if (arp_requests !== 32'd1 || arp_replies !== 32'd1 ||
            arp_fcs_errors !== 32'd0 || arp_malformed_frames !== 32'd0)
            $fatal(1, "ARP .17 counters mismatch");

        reply_length = 0;
        build_arp_request(8'd18);
        send_frame(ARP_FRAME_BYTES);
        check_arp_reply(8'd18);
        if (arp_requests !== 32'd2 || arp_replies !== 32'd2)
            $fatal(1, "ARP .18 counters mismatch");

        reset_duts();
        build_udp_frame(1, 32'd0, 32'd0, 16, 8'h01, image_crc);
        send_frame(UDP_FRAME_BYTES);
        build_udp_frame(1, 32'd1, 32'd16, 16, 8'h02, image_crc);
        send_frame(UDP_FRAME_BYTES);
        if (image_good_frames !== 32'd2 ||
            image_good_objects !== 32'd1 ||
            waveform_good_frames !== 32'd0 ||
            total_protocol_errors() !== 32'd0)
            $fatal(1, "Valid image object was not accepted");

        build_udp_frame(2, 32'd0, 32'd0, 12, 8'h01, waveform_crc);
        send_frame(UDP_FRAME_BYTES);
        build_udp_frame(2, 32'd1, 32'd12, 12, 8'h02, waveform_crc);
        send_frame(UDP_FRAME_BYTES);
        if (waveform_good_frames !== 32'd2 ||
            waveform_good_objects !== 32'd1 ||
            current_source !== 2'd2 ||
            total_protocol_errors() !== 32'd0)
            $fatal(1, "Valid waveform object was not accepted");

        reset_duts();
        build_udp_frame(1, 32'd0, 32'd0, IMAGE_BYTES, 8'h03, image_crc);
        frame[1450] = frame[1450] ^ 8'h01;
        send_frame(UDP_FRAME_BYTES);
        if (image_fcs_errors !== 32'd1 ||
            total_protocol_errors() !== 32'd1)
            $fatal(1, "FCS error isolation failed");

        reset_duts();
        build_udp_frame(1, 32'd0, 32'd0, IMAGE_BYTES, 8'h03, image_crc);
        frame[32] = frame[32] ^ 8'h01;
        write_frame_fcs(8, 1449, 1450);
        send_frame(UDP_FRAME_BYTES);
        if (image_ip_checksum_errors !== 32'd1 ||
            total_protocol_errors() !== 32'd1)
            $fatal(1, "IP checksum error isolation failed");

        reset_duts();
        build_udp_frame(1, 32'd0, 32'd0, IMAGE_BYTES, 8'h03, image_crc);
        frame[48] = frame[48] ^ 8'h01;
        write_frame_fcs(8, 1449, 1450);
        send_frame(UDP_FRAME_BYTES);
        if (image_udp_checksum_errors !== 32'd1 ||
            total_protocol_errors() !== 32'd1)
            $fatal(1, "UDP checksum error isolation failed");

        reset_duts();
        build_udp_frame(1, 32'd0, 32'd0, IMAGE_BYTES, 8'h03, image_crc);
        frame[50] = "B";
        write_udp_checksum();
        write_frame_fcs(8, 1449, 1450);
        send_frame(UDP_FRAME_BYTES);
        if (image_header_errors !== 32'd1 ||
            total_protocol_errors() !== 32'd1)
            $fatal(1, "AXDS header error isolation failed");

        reset_duts();
        build_udp_frame(1, 32'd1, 32'd0, IMAGE_BYTES, 8'h03, image_crc);
        send_frame(UDP_FRAME_BYTES);
        if (image_sequence_errors !== 32'd1 ||
            total_protocol_errors() !== 32'd1)
            $fatal(1, "Sequence error isolation failed");

        reset_duts();
        build_udp_frame(1, 32'd0, 32'd4, 16, 8'h00, image_crc);
        send_frame(UDP_FRAME_BYTES);
        if (image_offset_errors !== 32'd1 ||
            total_protocol_errors() !== 32'd1)
            $fatal(1, "Offset error isolation failed");

        reset_duts();
        build_udp_frame(1, 32'd0, 32'd0, IMAGE_BYTES, 8'h03,
                        image_crc ^ 32'h0000_0001);
        send_frame(UDP_FRAME_BYTES);
        if (image_object_crc_errors !== 32'd1 ||
            total_protocol_errors() !== 32'd1)
            $fatal(1, "Object CRC error isolation failed");

        reset_duts();
        build_udp_frame(2, 32'd0, 32'd0, WAVEFORM_BYTES, 8'h03,
                        waveform_crc);
        frame[1453] = frame[1453] ^ 8'h80;
        send_frame(UDP_FRAME_BYTES);
        if (waveform_fcs_errors !== 32'd1 ||
            image_fcs_errors !== 32'd0 ||
            total_protocol_errors() !== 32'd1)
            $fatal(1, "Waveform source classification failed");

        $display("PASS tb_dataset_udp_loopback");
        $finish;
    end

    initial begin
        #20_000_000;
        $fatal(1, "Simulation timeout");
    end
endmodule
