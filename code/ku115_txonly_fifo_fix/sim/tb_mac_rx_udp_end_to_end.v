`timescale 1ns / 1ps

module tb_mac_rx_udp_end_to_end;

localparam [47:0] LOCAL_MAC = 48'h00_0a_35_01_fe_c1;
localparam [31:0] LOCAL_IP  = 32'hc0a8_0011;

reg clk = 1'b0;
reg read_clk = 1'b0;
reg rst_n = 1'b0;
reg rx_dv = 1'b0;
reg [7:0] mac_rx_datain = 8'd0;
reg [10:0] udp_rec_ram_read_addr = 11'd0;
reg udp_rec_ram_read_en = 1'b0;
reg udp_rec_data_done = 1'b0;

wire [7:0] udp_rec_ram_rdata;
wire udp_rec_ram_read_valid;
wire [15:0] udp_rec_data_length;
wire udp_rec_data_valid;
wire udp_rec_overflow_sticky;
wire [31:0] udp_rec_overflow_count;
wire [31:0] mac_good_count;
wire [31:0] mac_crc_error_count;
wire [31:0] ip_checksum_error_count;
wire [31:0] udp_checksum_error_count;
wire [31:0] udp_packet_commit_count;
wire [7:0] mac_rx_dataout;
wire [15:0] upper_layer_data_length;
wire [15:0] ip_total_data_length;
wire icmp_rx_req;
wire icmp_rev_error;
wire arp_found;

reg [7:0] frame_mem [0:2047];
integer failures = 0;

always #4.000 clk = ~clk;
always #3.200 read_clk = ~read_clk;

mac_rx_top dut (
    .clk(clk),
    .udp_read_clk(read_clk),
    .rst_n(rst_n),
    .rx_dv(rx_dv),
    .mac_rx_datain(mac_rx_datain),
    .local_ip_addr(LOCAL_IP),
    .local_mac_addr(LOCAL_MAC),
    .arp_reply_ack(1'b0),
    .arp_reply_req(),
    .arp_rec_source_ip_addr(),
    .arp_rec_source_mac_addr(),
    .udp_rec_ram_rdata(udp_rec_ram_rdata),
    .udp_rec_ram_read_addr(udp_rec_ram_read_addr),
    .udp_rec_ram_read_en(udp_rec_ram_read_en),
    .udp_rec_ram_read_valid(udp_rec_ram_read_valid),
    .udp_rec_data_length(udp_rec_data_length),
    .udp_rec_data_valid(udp_rec_data_valid),
    .udp_rec_data_done(udp_rec_data_done),
    .udp_rec_overflow_sticky(udp_rec_overflow_sticky),
    .udp_rec_overflow_count(udp_rec_overflow_count),
    .mac_good_count(mac_good_count),
    .mac_crc_error_count(mac_crc_error_count),
    .ip_checksum_error_count(ip_checksum_error_count),
    .udp_checksum_error_count(udp_checksum_error_count),
    .udp_packet_commit_count(udp_packet_commit_count),
    .mac_rx_dataout(mac_rx_dataout),
    .upper_layer_data_length(upper_layer_data_length),
    .ip_total_data_length(ip_total_data_length),
    .icmp_rx_req(icmp_rx_req),
    .icmp_rev_error(icmp_rev_error),
    .arp_found(arp_found)
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
        frame_mem[27] = 8'h34;
        frame_mem[28] = 8'h40;
        frame_mem[29] = 8'h00;
        frame_mem[30] = 8'h40;
        frame_mem[31] = 8'h11;
        frame_mem[32] = 8'h00;
        frame_mem[33] = 8'h00;
        frame_mem[34] = 8'hc0;
        frame_mem[35] = 8'ha8;
        frame_mem[36] = 8'h00;
        frame_mem[37] = 8'h03;
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

        checksum_sum = 32'hc0a8 + 32'h0003 +
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
        rst_n = 1'b0;
        rx_dv = 1'b0;
        mac_rx_datain = 8'd0;
        udp_rec_ram_read_addr = 11'd0;
        udp_rec_ram_read_en = 1'b0;
        udp_rec_data_done = 1'b0;
        repeat (12) @(posedge clk);
        rst_n = 1'b1;
        repeat (12) @(posedge clk);
    end
endtask

task send_frame;
    input integer frame_bytes;
    integer index;
    begin
        @(negedge clk);
        rx_dv = 1'b1;
        for (index = 0; index < frame_bytes; index = index + 1) begin
            mac_rx_datain = frame_mem[index];
            @(negedge clk);
        end
        rx_dv = 1'b0;
        mac_rx_datain = 8'd0;
    end
endtask

task verify_payload;
    input integer payload_length;
    input [7:0] seed;
    integer index;
    integer mismatch_count;
    reg [7:0] expected_byte;
    begin
        mismatch_count = 0;
        for (index = 0; index < payload_length; index = index + 1) begin
            @(negedge read_clk);
            udp_rec_ram_read_addr = index[10:0];
            udp_rec_ram_read_en = 1'b1;
            @(negedge read_clk);
            udp_rec_ram_read_en = 1'b0;
            expected_byte = payload_byte(index, seed);
            if (!udp_rec_ram_read_valid || udp_rec_ram_rdata !== expected_byte) begin
                if (mismatch_count < 8)
                    $display("PAYLOAD_MISMATCH length=%0d index=%0d got=%02x valid=%b expected=%02x",
                             payload_length, index, udp_rec_ram_rdata,
                             udp_rec_ram_read_valid, expected_byte);
                mismatch_count = mismatch_count + 1;
            end
        end
        if (mismatch_count != 0) begin
            failures = failures + 1;
            $display("CASE_FAIL length=%0d payload mismatches=%0d",
                     payload_length, mismatch_count);
        end

        @(negedge read_clk);
        udp_rec_data_done = 1'b1;
        @(negedge read_clk);
        udp_rec_data_done = 1'b0;
        repeat (12) @(posedge read_clk);
    end
endtask

task verify_good_frame_counters;
    input integer payload_length;
    begin
        if (mac_good_count != 1 || mac_crc_error_count != 0 ||
            ip_checksum_error_count != 0 || udp_checksum_error_count != 0 ||
            udp_packet_commit_count != 1 || udp_rec_overflow_count != 0) begin
            failures = failures + 1;
            $display("COUNTER_MISMATCH length=%0d mac_good=%0d mac_error=%0d ip_error=%0d udp_error=%0d commit=%0d overflow=%0d",
                     payload_length, mac_good_count, mac_crc_error_count,
                     ip_checksum_error_count, udp_checksum_error_count,
                     udp_packet_commit_count, udp_rec_overflow_count);
        end
    end
endtask

task run_valid_case;
    input integer payload_length;
    input [7:0] seed;
    integer frame_bytes;
    integer wait_cycles;
    begin
        build_udp_frame(payload_length, seed, frame_bytes);
        reset_dut;
        send_frame(frame_bytes);

        wait_cycles = 0;
        while (!udp_rec_data_valid && wait_cycles < 10000) begin
            @(posedge read_clk);
            wait_cycles = wait_cycles + 1;
        end

        if (!udp_rec_data_valid) begin
            failures = failures + 1;
            $display("CASE_FAIL length=%0d timeout mac_state=%02x mac_error=%b ip_state=%02x ip_checksum_error=%b udp_state=%02x udp_checksum_error=%b udp_count=%0d overflow=%0d",
                     payload_length, dut.mac0.rec_state, dut.mac0.mac_rec_error,
                     dut.ip0.state, dut.ip0.ip_checksum_error,
                     dut.udp0.state, dut.udp0.udp_checksum_error,
                     dut.udp0.udp_rx_cnt, udp_rec_overflow_count);
        end else if (udp_rec_data_length !== payload_length + 16'd8) begin
            failures = failures + 1;
            $display("CASE_FAIL length=%0d descriptor_length=%0d expected=%0d",
                     payload_length, udp_rec_data_length, payload_length + 8);
            verify_payload(payload_length, seed);
        end else begin
            verify_payload(payload_length, seed);
            verify_good_frame_counters(payload_length);
            $display("CASE_PASS length=%0d descriptor_length=%0d",
                     payload_length, udp_rec_data_length);
        end
    end
endtask

initial begin
    run_valid_case(32,   8'h11);
    run_valid_case(256,  8'h22);
    run_valid_case(257,  8'h33);
    run_valid_case(512,  8'h44);
    run_valid_case(1024, 8'h55);
    run_valid_case(1400, 8'h66);
    run_valid_case(1472, 8'h77);

    if (failures != 0)
        $fatal(1, "FAIL tb_mac_rx_udp_end_to_end failures=%0d", failures);

    $display("PASS tb_mac_rx_udp_end_to_end");
    $finish;
end

endmodule
