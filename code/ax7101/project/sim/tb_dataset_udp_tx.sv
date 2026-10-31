`timescale 1ns / 1ps

module tb_dataset_udp_tx;

localparam [47:0] SOURCE_MAC = 48'h000A3502FEC1;
localparam [31:0] SOURCE_IP  = 32'hC0A80065;
localparam [31:0] DEST_IP    = 32'hC0A80011;
localparam [47:0] DEST_MAC   = 48'h000A3501FEC1;

reg clk = 1'b0;
reg rst_n = 1'b0;
reg enable = 1'b0;
reg link_up = 1'b0;
reg clear_arp_cache = 1'b0;

reg        packet_meta_valid = 1'b0;
wire       packet_meta_ready;
reg [7:0]  packet_type = 8'd0;
reg [7:0]  packet_flags = 8'd0;
reg [31:0] packet_cycle = 32'd0;
reg [15:0] packet_object_id = 16'd0;
reg [15:0] packet_valid_length = 16'd0;
reg [31:0] packet_sequence = 32'd0;
reg [31:0] packet_object_offset = 32'd0;
reg [31:0] packet_object_length = 32'd0;
reg [31:0] packet_object_crc32 = 32'd0;

reg        packet_data_valid = 1'b0;
wire       packet_data_ready;
reg [7:0]  packet_data = 8'd0;
reg        packet_data_last = 1'b0;

reg        gmii_rx_dv = 1'b0;
reg        gmii_rx_er = 1'b0;
reg [7:0]  gmii_rxd = 8'd0;
wire       gmii_tx_en;
wire       gmii_tx_er;
wire [7:0] gmii_txd;

wire        arp_resolved;
wire [47:0] resolved_mac;
wire        packet_sent;
wire [31:0] arp_request_count;
wire [31:0] udp_packet_count;
wire [31:0] input_error_count;

byte unsigned captured [0:2][0:2047];
integer captured_length [0:2];
integer gap_cycles [0:2];
integer capture_frame = 0;
integer capture_index = 0;
integer idle_cycles = 0;
reg capture_active = 1'b0;

always #4 clk = ~clk;

dataset_udp_tx #(
    .SOURCE_MAC(SOURCE_MAC),
    .SOURCE_IP(SOURCE_IP),
    .DEST_IP(DEST_IP),
    .SOURCE_PORT_ID(1),
    .ARP_RETRY_CYCLES(256)
) dut (
    .clk(clk),
    .rst_n(rst_n),
    .enable(enable),
    .link_up(link_up),
    .clear_arp_cache(clear_arp_cache),
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
    .gmii_rx_dv(gmii_rx_dv),
    .gmii_rx_er(gmii_rx_er),
    .gmii_rxd(gmii_rxd),
    .gmii_tx_en(gmii_tx_en),
    .gmii_tx_er(gmii_tx_er),
    .gmii_txd(gmii_txd),
    .arp_resolved(arp_resolved),
    .resolved_mac(resolved_mac),
    .packet_sent(packet_sent),
    .arp_request_count(arp_request_count),
    .udp_packet_count(udp_packet_count),
    .input_error_count(input_error_count)
);

always @(negedge clk) begin
    if (!rst_n) begin
        capture_frame = 0;
        capture_index = 0;
        idle_cycles = 0;
        capture_active = 1'b0;
    end else if (gmii_tx_en) begin
        if (!capture_active) begin
            if (capture_frame > 0)
                gap_cycles[capture_frame] = idle_cycles;
            capture_active = 1'b1;
            capture_index = 0;
            idle_cycles = 0;
        end
        if (capture_frame <= 2 && capture_index <= 2047)
            captured[capture_frame][capture_index] = gmii_txd;
        capture_index = capture_index + 1;
    end else begin
        if (capture_active) begin
            captured_length[capture_frame] = capture_index;
            capture_frame = capture_frame + 1;
            capture_active = 1'b0;
            capture_index = 0;
            idle_cycles = 1;
        end else if (capture_frame > 0) begin
            idle_cycles = idle_cycles + 1;
        end
    end
end

function automatic [31:0] crc32_byte_ref;
    input [31:0] crc_in;
    input [7:0] data_in;
    integer bit_index;
    reg [31:0] value;
    begin
        value = crc_in;
        for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1) begin
            if (value[0] ^ data_in[bit_index])
                value = (value >> 1) ^ 32'hEDB88320;
            else
                value = value >> 1;
        end
        crc32_byte_ref = value;
    end
endfunction

function automatic [15:0] checksum_add_ref;
    input [15:0] sum_in;
    input [15:0] word_in;
    reg [16:0] value;
    begin
        value = {1'b0, sum_in} + {1'b0, word_in};
        checksum_add_ref = value[15:0] + value[16];
    end
endfunction

task automatic check_preamble;
    input integer frame_number;
    integer index;
    begin
        for (index = 0; index < 7; index = index + 1)
            if (captured[frame_number][index] !== 8'h55)
                $fatal(1, "Frame %0d has bad preamble byte %0d", frame_number, index);
        if (captured[frame_number][7] !== 8'hD5)
            $fatal(1, "Frame %0d has bad SFD", frame_number);
    end
endtask

task automatic check_fcs;
    input integer frame_number;
    input integer frame_length;
    integer index;
    reg [31:0] crc;
    reg [31:0] expected;
    begin
        crc = 32'hFFFFFFFF;
        for (index = 8; index < frame_length - 4; index = index + 1)
            crc = crc32_byte_ref(crc, captured[frame_number][index]);
        expected = ~crc;
        if (captured[frame_number][frame_length-4] !== expected[7:0] ||
            captured[frame_number][frame_length-3] !== expected[15:8] ||
            captured[frame_number][frame_length-2] !== expected[23:16] ||
            captured[frame_number][frame_length-1] !== expected[31:24])
            $fatal(1, "Frame %0d Ethernet FCS mismatch", frame_number);
    end
endtask

task automatic check_ipv4_checksum;
    input integer frame_number;
    integer index;
    reg [15:0] sum;
    begin
        sum = 16'd0;
        for (index = 22; index < 42; index = index + 2)
            sum = checksum_add_ref(sum,
                {captured[frame_number][index], captured[frame_number][index+1]});
        if (sum !== 16'hFFFF)
            $fatal(1, "Frame %0d IPv4 checksum failed: %04x", frame_number, sum);
    end
endtask

task automatic check_udp_checksum;
    input integer frame_number;
    integer index;
    reg [15:0] sum;
    begin
        if ({captured[frame_number][48], captured[frame_number][49]} == 16'd0)
            $fatal(1, "Frame %0d UDP checksum is zero", frame_number);

        sum = 16'd0;
        sum = checksum_add_ref(sum,
            {captured[frame_number][34], captured[frame_number][35]});
        sum = checksum_add_ref(sum,
            {captured[frame_number][36], captured[frame_number][37]});
        sum = checksum_add_ref(sum,
            {captured[frame_number][38], captured[frame_number][39]});
        sum = checksum_add_ref(sum,
            {captured[frame_number][40], captured[frame_number][41]});
        sum = checksum_add_ref(sum, 16'h0011);
        sum = checksum_add_ref(sum,
            {captured[frame_number][46], captured[frame_number][47]});
        for (index = 42; index < 1450; index = index + 2)
            sum = checksum_add_ref(sum,
                {captured[frame_number][index], captured[frame_number][index+1]});
        if (sum !== 16'hFFFF)
            $fatal(1, "Frame %0d UDP checksum failed: %04x", frame_number, sum);
    end
endtask

task automatic drive_rx_byte;
    input [7:0] value;
    begin
        @(negedge clk);
        gmii_rx_dv = 1'b1;
        gmii_rxd = value;
    end
endtask

task automatic send_arp_reply;
    integer index;
    begin
        for (index = 0; index < 7; index = index + 1)
            drive_rx_byte(8'h55);
        drive_rx_byte(8'hD5);
        drive_rx_byte(SOURCE_MAC[47:40]);
        drive_rx_byte(SOURCE_MAC[39:32]);
        drive_rx_byte(SOURCE_MAC[31:24]);
        drive_rx_byte(SOURCE_MAC[23:16]);
        drive_rx_byte(SOURCE_MAC[15:8]);
        drive_rx_byte(SOURCE_MAC[7:0]);
        drive_rx_byte(DEST_MAC[47:40]);
        drive_rx_byte(DEST_MAC[39:32]);
        drive_rx_byte(DEST_MAC[31:24]);
        drive_rx_byte(DEST_MAC[23:16]);
        drive_rx_byte(DEST_MAC[15:8]);
        drive_rx_byte(DEST_MAC[7:0]);
        drive_rx_byte(8'h08);
        drive_rx_byte(8'h06);
        drive_rx_byte(8'h00);
        drive_rx_byte(8'h01);
        drive_rx_byte(8'h08);
        drive_rx_byte(8'h00);
        drive_rx_byte(8'h06);
        drive_rx_byte(8'h04);
        drive_rx_byte(8'h00);
        drive_rx_byte(8'h02);
        drive_rx_byte(DEST_MAC[47:40]);
        drive_rx_byte(DEST_MAC[39:32]);
        drive_rx_byte(DEST_MAC[31:24]);
        drive_rx_byte(DEST_MAC[23:16]);
        drive_rx_byte(DEST_MAC[15:8]);
        drive_rx_byte(DEST_MAC[7:0]);
        drive_rx_byte(DEST_IP[31:24]);
        drive_rx_byte(DEST_IP[23:16]);
        drive_rx_byte(DEST_IP[15:8]);
        drive_rx_byte(DEST_IP[7:0]);
        drive_rx_byte(SOURCE_MAC[47:40]);
        drive_rx_byte(SOURCE_MAC[39:32]);
        drive_rx_byte(SOURCE_MAC[31:24]);
        drive_rx_byte(SOURCE_MAC[23:16]);
        drive_rx_byte(SOURCE_MAC[15:8]);
        drive_rx_byte(SOURCE_MAC[7:0]);
        drive_rx_byte(SOURCE_IP[31:24]);
        drive_rx_byte(SOURCE_IP[23:16]);
        drive_rx_byte(SOURCE_IP[15:8]);
        drive_rx_byte(SOURCE_IP[7:0]);
        repeat (22) drive_rx_byte(8'h00);
        @(negedge clk);
        gmii_rx_dv = 1'b0;
        gmii_rxd = 8'd0;
    end
endtask

task automatic send_packet;
    input [7:0]  value_type;
    input [7:0]  value_flags;
    input [31:0] value_cycle;
    input [15:0] value_object_id;
    input [15:0] value_length;
    input [31:0] value_sequence;
    input [31:0] value_offset;
    input [31:0] value_object_length;
    input [31:0] value_crc;
    input [7:0]  data_seed;
    integer index;
    integer checksum_wait_cycles;
    begin
        @(negedge clk);
        packet_type = value_type;
        packet_flags = value_flags;
        packet_cycle = value_cycle;
        packet_object_id = value_object_id;
        packet_valid_length = value_length;
        packet_sequence = value_sequence;
        packet_object_offset = value_offset;
        packet_object_length = value_object_length;
        packet_object_crc32 = value_crc;
        packet_meta_valid = 1'b1;
        while (!packet_meta_ready)
            @(negedge clk);
        @(negedge clk);
        packet_meta_valid = 1'b0;

        checksum_wait_cycles = 0;
        while (!packet_data_ready) begin
            checksum_wait_cycles = checksum_wait_cycles + 1;
            @(negedge clk);
        end
        if (checksum_wait_cycles < 20) begin
            $fatal(1,
                "UDP base checksum was not prepared over multiple cycles");
        end

        for (index = 0; index < value_length; index = index + 1) begin
            packet_data = data_seed + index[7:0];
            packet_data_last = (index == value_length - 1);
            packet_data_valid = 1'b1;
            while (!packet_data_ready)
                @(negedge clk);
            @(negedge clk);
        end
        packet_data_valid = 1'b0;
        packet_data_last = 1'b0;
        packet_data = 8'd0;
    end
endtask

task automatic check_udp_frame;
    input integer frame_number;
    input [7:0] expected_type;
    input [7:0] expected_flags;
    input [31:0] expected_cycle;
    input [15:0] expected_object_id;
    input [15:0] expected_valid_length;
    input [31:0] expected_sequence;
    input [31:0] expected_offset;
    input [31:0] expected_object_length;
    input [31:0] expected_crc;
    input [7:0] expected_seed;
    integer index;
    begin
        if (captured_length[frame_number] !== 1454)
            $fatal(1, "Frame %0d length is %0d, expected 1454",
                frame_number, captured_length[frame_number]);
        check_preamble(frame_number);
        check_fcs(frame_number, captured_length[frame_number]);

        if ({captured[frame_number][8], captured[frame_number][9],
             captured[frame_number][10], captured[frame_number][11],
             captured[frame_number][12], captured[frame_number][13]} !== DEST_MAC)
            $fatal(1, "Frame %0d destination MAC mismatch", frame_number);
        if ({captured[frame_number][14], captured[frame_number][15],
             captured[frame_number][16], captured[frame_number][17],
             captured[frame_number][18], captured[frame_number][19]} !== SOURCE_MAC)
            $fatal(1, "Frame %0d source MAC mismatch", frame_number);
        if ({captured[frame_number][20], captured[frame_number][21]} !== 16'h0800)
            $fatal(1, "Frame %0d EtherType is not IPv4", frame_number);

        if (captured[frame_number][22] !== 8'h45 ||
            {captured[frame_number][24], captured[frame_number][25]} !== 16'h0594 ||
            captured[frame_number][31] !== 8'h11)
            $fatal(1, "Frame %0d IPv4 fixed fields mismatch", frame_number);
        if ({captured[frame_number][34], captured[frame_number][35],
             captured[frame_number][36], captured[frame_number][37]} !== SOURCE_IP ||
            {captured[frame_number][38], captured[frame_number][39],
             captured[frame_number][40], captured[frame_number][41]} !== DEST_IP)
            $fatal(1, "Frame %0d IPv4 address mismatch", frame_number);
        check_ipv4_checksum(frame_number);

        if ({captured[frame_number][42], captured[frame_number][43]} !== 16'd8080 ||
            {captured[frame_number][44], captured[frame_number][45]} !== 16'd8080 ||
            {captured[frame_number][46], captured[frame_number][47]} !== 16'h0580)
            $fatal(1, "Frame %0d UDP header mismatch", frame_number);
        check_udp_checksum(frame_number);

        if ({captured[frame_number][50], captured[frame_number][51],
             captured[frame_number][52], captured[frame_number][53]} !== 32'h41584453 ||
            captured[frame_number][54] !== 8'd1 ||
            captured[frame_number][55] !== expected_type ||
            captured[frame_number][56] !== 8'd1 ||
            captured[frame_number][57] !== expected_flags)
            $fatal(1, "Frame %0d AXDS prefix mismatch", frame_number);
        if ({captured[frame_number][58], captured[frame_number][59],
             captured[frame_number][60], captured[frame_number][61]} !== expected_cycle ||
            {captured[frame_number][62], captured[frame_number][63]} !== expected_object_id ||
            {captured[frame_number][64], captured[frame_number][65]} !== expected_valid_length ||
            {captured[frame_number][66], captured[frame_number][67],
             captured[frame_number][68], captured[frame_number][69]} !== expected_sequence ||
            {captured[frame_number][70], captured[frame_number][71],
             captured[frame_number][72], captured[frame_number][73]} !== expected_offset ||
            {captured[frame_number][74], captured[frame_number][75],
             captured[frame_number][76], captured[frame_number][77]} !== expected_object_length ||
            {captured[frame_number][78], captured[frame_number][79],
             captured[frame_number][80], captured[frame_number][81]} !== expected_crc)
            $fatal(1, "Frame %0d AXDS metadata mismatch", frame_number);

        for (index = 0; index < expected_valid_length; index = index + 1)
            if (captured[frame_number][82+index] !== (expected_seed + index[7:0]))
                $fatal(1, "Frame %0d payload mismatch at %0d", frame_number, index);
        for (index = expected_valid_length; index < 1368; index = index + 1)
            if (captured[frame_number][82+index] !== 8'd0)
                $fatal(1, "Frame %0d padding is nonzero at %0d", frame_number, index);
    end
endtask

integer timeout;

initial begin
    repeat (8) @(negedge clk);
    rst_n = 1'b1;
    enable = 1'b1;
    link_up = 1'b1;

    timeout = 0;
    while (capture_frame < 1 && timeout < 1000) begin
        @(negedge clk);
        timeout = timeout + 1;
    end
    if (capture_frame < 1)
        $fatal(1, "No ARP request was transmitted");
    if (captured_length[0] !== 72)
        $fatal(1, "ARP frame length is %0d, expected 72", captured_length[0]);
    check_preamble(0);
    check_fcs(0, captured_length[0]);
    if ({captured[0][8], captured[0][9], captured[0][10],
         captured[0][11], captured[0][12], captured[0][13]} !== 48'hFFFFFFFFFFFF ||
        {captured[0][20], captured[0][21]} !== 16'h0806 ||
        {captured[0][28], captured[0][29]} !== 16'h0001 ||
        {captured[0][36], captured[0][37], captured[0][38], captured[0][39]} !== SOURCE_IP ||
        {captured[0][46], captured[0][47], captured[0][48], captured[0][49]} !== DEST_IP)
        $fatal(1, "ARP request fields mismatch");

    send_arp_reply();
    timeout = 0;
    while (!arp_resolved && timeout < 100) begin
        @(negedge clk);
        timeout = timeout + 1;
    end
    if (!arp_resolved || resolved_mac !== DEST_MAC)
        $fatal(1, "ARP reply was not cached");

    send_packet(8'd1, 8'h03, 32'h01020304, 16'd45, 16'd5,
        32'h10203040, 32'd0, 32'd230400, 32'h89ABCDEF, 8'hA0);
    send_packet(8'd2, 8'h03, 32'h11223344, 16'd1, 16'd1368,
        32'h10203041, 32'd0, 32'd28800, 32'h76543210, 8'h20);

    timeout = 0;
    while (capture_frame < 3 && timeout < 10000) begin
        @(negedge clk);
        timeout = timeout + 1;
    end
    if (capture_frame < 3)
        $fatal(1, "Expected two UDP frames, captured %0d total frames", capture_frame);

    check_udp_frame(1, 8'd1, 8'h03, 32'h01020304, 16'd45, 16'd5,
        32'h10203040, 32'd0, 32'd230400, 32'h89ABCDEF, 8'hA0);
    check_udp_frame(2, 8'd2, 8'h03, 32'h11223344, 16'd1, 16'd1368,
        32'h10203041, 32'd0, 32'd28800, 32'h76543210, 8'h20);

    if (gap_cycles[1] < 12 || gap_cycles[2] !== 12)
        $fatal(1, "IFG mismatch: ARP-to-UDP=%0d UDP-to-UDP=%0d",
            gap_cycles[1], gap_cycles[2]);
    if (gmii_tx_er !== 1'b0 || arp_request_count !== 32'd1 ||
        udp_packet_count !== 32'd2 || input_error_count !== 32'd0)
        $fatal(1, "Status counters mismatch");

    $display("PASS tb_dataset_udp_tx");
    $finish;
end

endmodule
