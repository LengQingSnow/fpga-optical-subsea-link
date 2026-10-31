`timescale 1ns / 1ps

module tb_mac_test_udp_ingress;

localparam [47:0] LOCAL_MAC = 48'h00_0a_35_01_fe_c1;
localparam [31:0] LOCAL_IP  = 32'hc0a8_0011;
localparam [31:0] SOURCE_IP = 32'hc0a8_0003;

reg rst_n = 1'b0;
reg gmii_tx_clk = 1'b0;
reg gmii_rx_clk = 1'b0;
reg gmii_rx_dv = 1'b0;
reg [7:0] gmii_rxd = 8'd0;
wire gmii_tx_en;
wire [7:0] gmii_txd;
wire [7:0] aggregate_data;
wire aggregate_valid;
wire [23:0] aggregate_packet_data;
wire aggregate_packet_valid;

reg [7:0] frame_mem [0:2047];
reg [7:0] expected_stream [0:65535];
integer expected_packet_end [0:63];
integer expected_packet_length [0:63];
integer expected_total_bytes = 0;
integer expected_packets = 0;
integer observed_bytes = 0;
integer observed_packets = 0;
integer failures = 0;
reg monitor_enable = 1'b0;

always #4.000 gmii_tx_clk = ~gmii_tx_clk;
always #4.100 gmii_rx_clk = ~gmii_rx_clk;

mac_test #(
    .LOCAL_MAC_ADDR(LOCAL_MAC),
    .LOCAL_IP_ADDR(LOCAL_IP),
    .DEST_IP_ADDR(SOURCE_IP)
) dut (
    .rst_n(rst_n),
    .pack_total_len(32'hffff_ffff),
    .gmii_tx_clk(gmii_tx_clk),
    .gmii_rx_clk(gmii_rx_clk),
    .gmii_rx_dv(gmii_rx_dv),
    .gmii_rxd(gmii_rxd),
    .gmii_tx_en(gmii_tx_en),
    .gmii_txd(gmii_txd),
    .aggregate_data(aggregate_data),
    .aggregate_valid(aggregate_valid),
    .aggregate_ready(1'b1),
    .aggregate_packet_data(aggregate_packet_data),
    .aggregate_packet_valid(aggregate_packet_valid)
);

function [7:0] payload_byte;
    input integer byte_index;
    input [7:0] seed;
    begin
        payload_byte = seed + byte_index[7:0] + (byte_index >> 8);
    end
endfunction

function [31:0] crc32_byte;
    input [31:0] crc_in;
    input [7:0] data_in;
    integer bit_index;
    reg [31:0] crc_value;
    begin
        crc_value = crc_in;
        for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1) begin
            if (crc_value[0] ^ data_in[bit_index])
                crc_value = (crc_value >> 1) ^ 32'hedb8_8320;
            else
                crc_value = crc_value >> 1;
        end
        crc32_byte = crc_value;
    end
endfunction

task clear_scoreboard;
    begin
        expected_total_bytes = 0;
        expected_packets = 0;
        observed_bytes = 0;
        observed_packets = 0;
    end
endtask

task append_expected_packet;
    input integer payload_length;
    input [7:0] seed;
    integer index;
    begin
        for (index = 0; index < payload_length; index = index + 1)
            expected_stream[expected_total_bytes + index] = payload_byte(index, seed);
        expected_total_bytes = expected_total_bytes + payload_length;
        expected_packet_length[expected_packets] = payload_length;
        expected_packet_end[expected_packets] = expected_total_bytes;
        expected_packets = expected_packets + 1;
    end
endtask

task build_udp_frame;
    input integer payload_length;
    input [7:0] seed;
    output integer frame_bytes;
    integer index;
    integer ip_length;
    integer udp_length;
    integer l2_length;
    integer fcs_index;
    reg [31:0] checksum_sum;
    reg [15:0] checksum_value;
    reg [31:0] crc_value;
    reg [31:0] fcs_value;
    begin
        for (index = 0; index < 2048; index = index + 1)
            frame_mem[index] = 8'd0;
        for (index = 0; index < 7; index = index + 1)
            frame_mem[index] = 8'h55;
        frame_mem[7] = 8'hd5;

        frame_mem[8]  = LOCAL_MAC[47:40];
        frame_mem[9]  = LOCAL_MAC[39:32];
        frame_mem[10] = LOCAL_MAC[31:24];
        frame_mem[11] = LOCAL_MAC[23:16];
        frame_mem[12] = LOCAL_MAC[15:8];
        frame_mem[13] = LOCAL_MAC[7:0];
        frame_mem[14] = 8'h10;
        frame_mem[15] = 8'h20;
        frame_mem[16] = 8'h30;
        frame_mem[17] = 8'h40;
        frame_mem[18] = 8'h50;
        frame_mem[19] = 8'h60;
        frame_mem[20] = 8'h08;
        frame_mem[21] = 8'h00;

        udp_length = payload_length + 8;
        ip_length = udp_length + 20;
        frame_mem[22] = 8'h45;
        frame_mem[23] = 8'h00;
        frame_mem[24] = ip_length[15:8];
        frame_mem[25] = ip_length[7:0];
        frame_mem[26] = 8'h12;
        frame_mem[27] = seed;
        frame_mem[28] = 8'h40;
        frame_mem[29] = 8'h00;
        frame_mem[30] = 8'h40;
        frame_mem[31] = 8'h11;
        frame_mem[32] = 8'h00;
        frame_mem[33] = 8'h00;
        frame_mem[34] = SOURCE_IP[31:24];
        frame_mem[35] = SOURCE_IP[23:16];
        frame_mem[36] = SOURCE_IP[15:8];
        frame_mem[37] = SOURCE_IP[7:0];
        frame_mem[38] = LOCAL_IP[31:24];
        frame_mem[39] = LOCAL_IP[23:16];
        frame_mem[40] = LOCAL_IP[15:8];
        frame_mem[41] = LOCAL_IP[7:0];

        checksum_sum = 32'd0;
        for (index = 22; index < 42; index = index + 2)
            checksum_sum = checksum_sum + {frame_mem[index], frame_mem[index + 1]};
        while (checksum_sum[31:16] != 0)
            checksum_sum = checksum_sum[15:0] + checksum_sum[31:16];
        checksum_value = ~checksum_sum[15:0];
        frame_mem[32] = checksum_value[15:8];
        frame_mem[33] = checksum_value[7:0];

        frame_mem[42] = 8'h1f;
        frame_mem[43] = 8'h90;
        frame_mem[44] = 8'h1f;
        frame_mem[45] = 8'h90;
        frame_mem[46] = udp_length[15:8];
        frame_mem[47] = udp_length[7:0];
        frame_mem[48] = 8'h00;
        frame_mem[49] = 8'h00;
        for (index = 0; index < payload_length; index = index + 1)
            frame_mem[50 + index] = payload_byte(index, seed);

        checksum_sum = {16'd0, SOURCE_IP[31:16]} +
                       {16'd0, SOURCE_IP[15:0]} +
                       {16'd0, LOCAL_IP[31:16]} +
                       {16'd0, LOCAL_IP[15:0]} + 32'h0011 + udp_length;
        for (index = 42; index < 50; index = index + 2)
            checksum_sum = checksum_sum + {frame_mem[index], frame_mem[index + 1]};
        for (index = 0; index < payload_length - 1; index = index + 2)
            checksum_sum = checksum_sum +
                           {frame_mem[50 + index], frame_mem[51 + index]};
        if (payload_length[0])
            checksum_sum = checksum_sum + {frame_mem[49 + payload_length], 8'h00};
        while (checksum_sum[31:16] != 0)
            checksum_sum = checksum_sum[15:0] + checksum_sum[31:16];
        checksum_value = ~checksum_sum[15:0];
        if (checksum_value == 16'h0000)
            checksum_value = 16'hffff;
        frame_mem[48] = checksum_value[15:8];
        frame_mem[49] = checksum_value[7:0];

        l2_length = 14 + ip_length;
        crc_value = 32'hffff_ffff;
        for (index = 8; index < 8 + l2_length; index = index + 1)
            crc_value = crc32_byte(crc_value, frame_mem[index]);
        fcs_value = ~crc_value;
        fcs_index = 8 + l2_length;
        frame_mem[fcs_index]     = fcs_value[7:0];
        frame_mem[fcs_index + 1] = fcs_value[15:8];
        frame_mem[fcs_index + 2] = fcs_value[23:16];
        frame_mem[fcs_index + 3] = fcs_value[31:24];
        frame_bytes = fcs_index + 4;
    end
endtask

task reset_dut;
    begin
        monitor_enable = 1'b0;
        rst_n = 1'b0;
        gmii_rx_dv = 1'b0;
        gmii_rxd = 8'd0;
        repeat (16) @(posedge gmii_tx_clk);
        rst_n = 1'b1;
        repeat (16) @(posedge gmii_tx_clk);
        monitor_enable = 1'b1;
    end
endtask

task send_frame;
    input integer frame_bytes;
    input integer ifg_cycles;
    integer index;
    begin
        @(negedge gmii_rx_clk);
        gmii_rx_dv = 1'b1;
        for (index = 0; index < frame_bytes; index = index + 1) begin
            gmii_rxd = frame_mem[index];
            @(negedge gmii_rx_clk);
        end
        gmii_rx_dv = 1'b0;
        gmii_rxd = 8'd0;
        repeat (ifg_cycles) @(posedge gmii_rx_clk);
    end
endtask

task wait_for_expected_packets;
    input integer timeout_cycles;
    integer wait_count;
    begin
        wait_count = 0;
        while (observed_packets < expected_packets && wait_count < timeout_cycles) begin
            @(posedge gmii_tx_clk);
            wait_count = wait_count + 1;
        end
        if (observed_packets != expected_packets) begin
            failures = failures + 1;
            $display("STREAM_FAIL expected_packets=%0d observed_packets=%0d expected_bytes=%0d observed_bytes=%0d udp_overflow=%0d udp_state=%02x mac_state=%02x",
                     expected_packets, observed_packets, expected_total_bytes,
                     observed_bytes, dut.udp_rec_overflow_count,
                     dut.mac_top0.mac_rx0.udp0.state,
                     dut.mac_top0.mac_rx0.mac0.rec_state);
        end
    end
endtask

always @(posedge gmii_tx_clk) begin
    #1;
    if (monitor_enable) begin
        if (aggregate_valid) begin
            if (observed_bytes >= expected_total_bytes) begin
                failures = failures + 1;
                $display("UNEXPECTED_BYTE index=%0d data=%02x", observed_bytes,
                         aggregate_data);
            end else if (aggregate_data !== expected_stream[observed_bytes]) begin
                failures = failures + 1;
                $display("STREAM_DATA_MISMATCH index=%0d got=%02x expected=%02x",
                         observed_bytes, aggregate_data,
                         expected_stream[observed_bytes]);
            end
            observed_bytes = observed_bytes + 1;
        end

        if (aggregate_packet_valid) begin
            if (observed_packets >= expected_packets) begin
                failures = failures + 1;
                $display("UNEXPECTED_DESCRIPTOR packet=%0d", observed_packets);
            end else begin
                if (aggregate_packet_data[15:0] !=
                    expected_packet_length[observed_packets]) begin
                    failures = failures + 1;
                    $display("DESCRIPTOR_LENGTH_MISMATCH packet=%0d got=%0d expected=%0d",
                             observed_packets, aggregate_packet_data[15:0],
                             expected_packet_length[observed_packets]);
                end
                if (aggregate_packet_data[23:16] != observed_packets[7:0]) begin
                    failures = failures + 1;
                    $display("DESCRIPTOR_ID_MISMATCH packet=%0d got=%0d",
                             observed_packets, aggregate_packet_data[23:16]);
                end
                if (observed_bytes != expected_packet_end[observed_packets]) begin
                    failures = failures + 1;
                    $display("DESCRIPTOR_BOUNDARY_MISMATCH packet=%0d bytes=%0d expected=%0d",
                             observed_packets, observed_bytes,
                             expected_packet_end[observed_packets]);
                end
            end
            observed_packets = observed_packets + 1;
        end
    end
end

integer frame_bytes;
integer packet_index;
initial begin
    force dut.mac_not_exist = 1'b0;
    force dut.almost_full = 1'b0;
    force dut.udp_ram_data_req = 1'b1;
    force dut.mac_send_end = 1'b1;

    clear_scoreboard;
    append_expected_packet(1400, 8'h31);
    build_udp_frame(1400, 8'h31, frame_bytes);
    reset_dut;
    send_frame(frame_bytes, 12);
    wait_for_expected_packets(10000);
    if (observed_packets == 1 && observed_bytes == 1400)
        $display("SINGLE_PACKET_PASS length=1400");

    clear_scoreboard;
    reset_dut;
    build_udp_frame(1400, 8'h42, frame_bytes);
    frame_mem[frame_bytes - 1] = frame_mem[frame_bytes - 1] ^ 8'h01;
    send_frame(frame_bytes, 12);
    repeat (1000) @(posedge gmii_tx_clk);
    if (observed_packets != 0 || observed_bytes != 0) begin
        failures = failures + 1;
        $display("BAD_FCS_ACCEPTED packets=%0d bytes=%0d",
                 observed_packets, observed_bytes);
    end
    append_expected_packet(1400, 8'h43);
    build_udp_frame(1400, 8'h43, frame_bytes);
    send_frame(frame_bytes, 12);
    wait_for_expected_packets(10000);
    if (observed_packets == 1 && observed_bytes == 1400)
        $display("BAD_FCS_RECOVERY_PASS length=1400");

    clear_scoreboard;
    reset_dut;
    for (packet_index = 0; packet_index < 20; packet_index = packet_index + 1) begin
        append_expected_packet(1400, 8'h60 + packet_index[7:0]);
        build_udp_frame(1400, 8'h60 + packet_index[7:0], frame_bytes);
        send_frame(frame_bytes, 12);
    end
    wait_for_expected_packets(100000);

    if (dut.udp_rec_overflow_count != 0) begin
        failures = failures + 1;
        $display("UDP_BUFFER_OVERFLOW count=%0d", dut.udp_rec_overflow_count);
    end
    if (observed_bytes != expected_total_bytes) begin
        failures = failures + 1;
        $display("STREAM_BYTE_TOTAL_MISMATCH got=%0d expected=%0d",
                 observed_bytes, expected_total_bytes);
    end

    // Aggregation is a receive-side function. A stalled legacy UDP transmit
    // FIFO must not retain receive banks or drop aggregate packets.
    clear_scoreboard;
    reset_dut;
    force dut.mac_not_exist = 1'b0;
    force dut.almost_full = 1'b1;
    for (packet_index = 0; packet_index < 4; packet_index = packet_index + 1) begin
        append_expected_packet(1400, 8'ha0 + packet_index[7:0]);
        build_udp_frame(1400, 8'ha0 + packet_index[7:0], frame_bytes);
        send_frame(frame_bytes, 12);
    end
    wait_for_expected_packets(100000);
    release dut.almost_full;
    release dut.mac_not_exist;

    if (dut.udp_rec_overflow_count != 0) begin
        failures = failures + 1;
        $display("BLOCKED_EGRESS_OVERFLOW count=%0d",
                 dut.udp_rec_overflow_count);
    end
    if (observed_packets != expected_packets ||
        observed_bytes != expected_total_bytes) begin
        failures = failures + 1;
        $display("BLOCKED_EGRESS_AGGREGATE_MISMATCH packets=%0d/%0d bytes=%0d/%0d",
                 observed_packets, expected_packets,
                 observed_bytes, expected_total_bytes);
    end

    if (failures != 0)
        $fatal(1, "FAIL tb_mac_test_udp_ingress failures=%0d", failures);

    $display("PASS tb_mac_test_udp_ingress packets=%0d bytes=%0d",
             observed_packets, observed_bytes);
    $finish;
end

endmodule
