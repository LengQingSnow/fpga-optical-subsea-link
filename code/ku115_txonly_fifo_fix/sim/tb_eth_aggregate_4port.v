`timescale 1ns / 1ps

// End-to-end verification of the dynamic-segment aggregation protocol.
// Each source first commits all payload bytes, then publishes its packet
// descriptor.  The checker acts as the downstream receiver: it parses
// segments from any data frame and reassembles one UDP packet per port.
module tb_eth_aggregate_4port;

localparam FRAME_BYTES = 512;
localparam FRAME_COUNT = 32;
localparam [63:0] SYNC_WORD = 64'hD5C0_1ACF_FC1D_5AA5;
localparam [7:0] PROTOCOL_VERSION = 8'h01;
localparam [7:0] FRAME_FLAGS_IDLE = 8'h06;
localparam [7:0] FRAME_FLAGS_DATA = 8'h07;
localparam MAX_FRAGMENT = 488;

reg rst_n;
reg agg_clk;
reg in0_clk;
reg in1_clk;
reg in2_clk;
reg in3_clk;
reg [7:0] in0_data;
reg [7:0] in1_data;
reg [7:0] in2_data;
reg [7:0] in3_data;
reg in0_valid;
reg in1_valid;
reg in2_valid;
reg in3_valid;
reg [23:0] in0_desc_data;
reg [23:0] in1_desc_data;
reg [23:0] in2_desc_data;
reg [23:0] in3_desc_data;
reg in0_desc_valid;
reg in1_desc_valid;
reg in2_desc_valid;
reg in3_desc_valid;
wire [127:0] qpsk_bits;
wire qpsk_valid;
wire frame_start;
wire frame_end;

reg [7:0] captured [0:FRAME_COUNT*FRAME_BYTES-1];
reg [7:0] expected [0:3][0:255];
reg [7:0] reassembled [0:3][0:255];
reg [15:0] expected_length [0:3];
reg [7:0] expected_packet_id [0:3];
reg [15:0] received_length [0:3];
reg [7:0] received_packet_id [0:3];
reg [3:0] receiver_active;
reg [3:0] receiver_complete;
integer captured_frames;
integer captured_byte_count;
integer errors;
integer i;
integer j;
integer port;
integer byte_index;
integer segment_start;
integer segment_end;
integer fragment_length;
reg [7:0] tag;
reg [7:0] packet_id;
reg [15:0] segment_valid_length;
reg [30:0] prbs_state;

eth_aggregate_4port dut (
    .rst_n          (rst_n),
    .agg_clk        (agg_clk),
    .in0_clk        (in0_clk),
    .in0_data       (in0_data),
    .in0_valid      (in0_valid),
    .in0_desc_data  (in0_desc_data),
    .in0_desc_valid (in0_desc_valid),
    .in1_clk        (in1_clk),
    .in1_data       (in1_data),
    .in1_valid      (in1_valid),
    .in1_desc_data  (in1_desc_data),
    .in1_desc_valid (in1_desc_valid),
    .in2_clk        (in2_clk),
    .in2_data       (in2_data),
    .in2_valid      (in2_valid),
    .in2_desc_data  (in2_desc_data),
    .in2_desc_valid (in2_desc_valid),
    .in3_clk        (in3_clk),
    .in3_data       (in3_data),
    .in3_valid      (in3_valid),
    .in3_desc_data  (in3_desc_data),
    .in3_desc_valid (in3_desc_valid),
    .qpsk_bits      (qpsk_bits),
    .qpsk_valid     (qpsk_valid),
    .frame_start    (frame_start),
    .frame_end      (frame_end)
);

always #4.0 agg_clk = ~agg_clk;
always #4.0 in0_clk = ~in0_clk;
always #5.0 in1_clk = ~in1_clk;
always #6.0 in2_clk = ~in2_clk;
always #7.0 in3_clk = ~in3_clk;

always @(posedge agg_clk) begin
    if (!rst_n) begin
        captured_frames = 0;
        captured_byte_count = 0;
    end else begin
        if (qpsk_valid !== 1'b1) begin
            $display("ERROR: qpsk_valid must remain asserted after reset");
            errors = errors + 1;
        end
        if (qpsk_valid) begin
            if (frame_start && captured_byte_count != 0) begin
                $display("ERROR: frame_start is not aligned to a frame boundary");
                errors = errors + 1;
            end
            if (captured_frames < FRAME_COUNT) begin
                for (j = 0; j < 16; j = j + 1)
                    captured[captured_frames*FRAME_BYTES + captured_byte_count + j] =
                        qpsk_bits[127-j*8 -: 8];
            end
            if (frame_end) begin
                if (captured_byte_count != FRAME_BYTES-16) begin
                    $display("ERROR: frame_end occurred at %0d bytes", captured_byte_count + 16);
                    errors = errors + 1;
                end
                captured_frames = captured_frames + 1;
                captured_byte_count = 0;
            end else begin
                captured_byte_count = captured_byte_count + 16;
            end
        end
    end
end

function [31:0] crc32_byte;
    input [31:0] crc_in;
    input [7:0] data_in;
    reg [31:0] crc;
    integer bit_index;
    begin
        crc = crc_in ^ {data_in, 24'h0};
        for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1) begin
            if (crc[31]) crc = (crc << 1) ^ 32'h04c11db7;
            else crc = crc << 1;
        end
        crc32_byte = crc;
    end
endfunction

function [7:0] prbs31_byte;
    input [30:0] state_in;
    reg [30:0] state;
    integer bit_index;
    begin
        state = state_in;
        for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1) begin
            prbs31_byte[7-bit_index] = state[30];
            state = {state[29:0], state[30] ^ state[27]};
        end
    end
endfunction

function [30:0] prbs31_advance8;
    input [30:0] state_in;
    reg [30:0] state;
    integer bit_index;
    begin
        state = state_in;
        for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1)
            state = {state[29:0], state[30] ^ state[27]};
        prbs31_advance8 = state;
    end
endfunction

function [30:0] prbs_seed;
    input [31:0] frame_sequence;
    begin
        prbs_seed = (31'h7fff_ffff ^ frame_sequence[30:0]) | 31'h0000_0001;
    end
endfunction

task expect_byte;
    input integer frame_number;
    input integer index;
    input [7:0] value;
    begin
        if (captured[frame_number*FRAME_BYTES + index] !== value) begin
            $display("ERROR: frame %0d byte %0d expected %02x got %02x", frame_number,
                     index, value, captured[frame_number*FRAME_BYTES + index]);
            errors = errors + 1;
        end
    end
endtask

task check_frame_crc;
    input integer frame_number;
    reg [31:0] crc;
    reg [31:0] expected_crc;
    integer index;
    begin
        crc = 32'hffff_ffff;
        for (index = 0; index < 508; index = index + 1)
            crc = crc32_byte(crc, captured[frame_number*FRAME_BYTES + index]);
        expected_crc = ~crc;
        expect_byte(frame_number, 508, expected_crc[31:24]);
        expect_byte(frame_number, 509, expected_crc[23:16]);
        expect_byte(frame_number, 510, expected_crc[15:8]);
        expect_byte(frame_number, 511, expected_crc[7:0]);
    end
endtask

task check_frame_header;
    input integer frame_number;
    begin
        for (byte_index = 0; byte_index < 8; byte_index = byte_index + 1)
            expect_byte(frame_number, byte_index, SYNC_WORD[63-byte_index*8 -: 8]);
        expect_byte(frame_number, 8, PROTOCOL_VERSION);
        expect_byte(frame_number, 12, frame_number[31:24]);
        expect_byte(frame_number, 13, frame_number[23:16]);
        expect_byte(frame_number, 14, frame_number[15:8]);
        expect_byte(frame_number, 15, frame_number[7:0]);
        check_frame_crc(frame_number);
    end
endtask

task parse_frame;
    input integer frame_number;
    integer local_start;
    integer local_end;
    integer local_length;
    integer local_port;
    integer local_index;
    reg [7:0] local_tag;
    reg [7:0] local_packet_id;
    reg [15:0] local_valid_length;
    reg [30:0] local_prbs;
    begin
        check_frame_header(frame_number);
        local_valid_length = {captured[frame_number*FRAME_BYTES + 10],
                              captured[frame_number*FRAME_BYTES + 11]};
        if (captured[frame_number*FRAME_BYTES + 9] == FRAME_FLAGS_IDLE) begin
            if (local_valid_length != 0) begin
                $display("ERROR: idle frame %0d has nonzero segment length", frame_number);
                errors = errors + 1;
            end
        end else if (captured[frame_number*FRAME_BYTES + 9] != FRAME_FLAGS_DATA) begin
            $display("ERROR: frame %0d has invalid flags %02x", frame_number,
                     captured[frame_number*FRAME_BYTES + 9]);
            errors = errors + 1;
        end

        if (local_valid_length > 492) begin
            $display("ERROR: frame %0d segment area exceeds 492 bytes", frame_number);
            errors = errors + 1;
        end
        local_start = 16;
        local_end = 16 + local_valid_length;
        while (local_start < local_end) begin
            if (local_start + 4 > local_end) begin
                $display("ERROR: frame %0d has a truncated segment header", frame_number);
                errors = errors + 1;
                local_start = local_end;
            end else begin
                local_tag = captured[frame_number*FRAME_BYTES + local_start];
                local_packet_id = captured[frame_number*FRAME_BYTES + local_start + 1];
                local_length = {captured[frame_number*FRAME_BYTES + local_start + 2],
                                captured[frame_number*FRAME_BYTES + local_start + 3]};
                local_port = local_tag[1:0];
                if (local_tag[7:5] != 3'd0 || local_tag[4]) begin
                    $display("ERROR: frame %0d segment has reserved or abort bits set", frame_number);
                    errors = errors + 1;
                end
                if (local_length > MAX_FRAGMENT || local_start + 4 + local_length > local_end) begin
                    $display("ERROR: frame %0d has invalid fragment length %0d", frame_number,
                             local_length);
                    errors = errors + 1;
                    local_start = local_end;
                end else begin
                    if (local_tag[2]) begin
                        if (receiver_active[local_port]) begin
                            $display("ERROR: port %0d received SOP before EOP", local_port);
                            errors = errors + 1;
                        end
                        receiver_active[local_port] = 1'b1;
                        received_packet_id[local_port] = local_packet_id;
                        received_length[local_port] = 0;
                    end else if (!receiver_active[local_port] ||
                                 received_packet_id[local_port] != local_packet_id) begin
                        $display("ERROR: port %0d continuation does not match an open packet", local_port);
                        errors = errors + 1;
                    end
                    for (local_index = 0; local_index < local_length; local_index = local_index + 1) begin
                        if (received_length[local_port] < 256)
                            reassembled[local_port][received_length[local_port]] =
                                captured[frame_number*FRAME_BYTES + local_start + 4 + local_index];
                        received_length[local_port] = received_length[local_port] + 1'b1;
                    end
                    if (local_tag[3]) begin
                        if (!receiver_active[local_port]) begin
                            $display("ERROR: port %0d received EOP without an open packet", local_port);
                            errors = errors + 1;
                        end
                        receiver_active[local_port] = 1'b0;
                        receiver_complete[local_port] = 1'b1;
                    end
                    local_start = local_start + 4 + local_length;
                end
            end
        end

        local_prbs = prbs_seed(frame_number);
        for (local_index = 16; local_index < 508; local_index = local_index + 1) begin
            if (local_index >= local_end)
                expect_byte(frame_number, local_index, prbs31_byte(local_prbs));
            local_prbs = prbs31_advance8(local_prbs);
        end
    end
endtask

task send_port0;
    input [7:0] first_byte;
    input [15:0] payload_length;
    input [7:0] packet_id_value;
    integer index;
    begin
        @(negedge in0_clk);
        in0_valid = 1'b1;
        for (index = 0; index < payload_length; index = index + 1) begin
            in0_data = first_byte + index[7:0];
            @(negedge in0_clk);
        end
        in0_valid = 1'b0;
        repeat (2) @(negedge in0_clk);
        in0_desc_data = {packet_id_value, payload_length};
        in0_desc_valid = 1'b1;
        @(negedge in0_clk);
        in0_desc_valid = 1'b0;
    end
endtask

task send_port1;
    input [7:0] first_byte;
    input [15:0] payload_length;
    input [7:0] packet_id_value;
    integer index;
    begin
        @(negedge in1_clk);
        in1_valid = 1'b1;
        for (index = 0; index < payload_length; index = index + 1) begin
            in1_data = first_byte + index[7:0];
            @(negedge in1_clk);
        end
        in1_valid = 1'b0;
        repeat (2) @(negedge in1_clk);
        in1_desc_data = {packet_id_value, payload_length};
        in1_desc_valid = 1'b1;
        @(negedge in1_clk);
        in1_desc_valid = 1'b0;
    end
endtask

task send_port2;
    input [7:0] first_byte;
    input [15:0] payload_length;
    input [7:0] packet_id_value;
    integer index;
    begin
        @(negedge in2_clk);
        in2_valid = 1'b1;
        for (index = 0; index < payload_length; index = index + 1) begin
            in2_data = first_byte + index[7:0];
            @(negedge in2_clk);
        end
        in2_valid = 1'b0;
        repeat (2) @(negedge in2_clk);
        in2_desc_data = {packet_id_value, payload_length};
        in2_desc_valid = 1'b1;
        @(negedge in2_clk);
        in2_desc_valid = 1'b0;
    end
endtask

task send_port3;
    input [7:0] first_byte;
    input [15:0] payload_length;
    input [7:0] packet_id_value;
    integer index;
    begin
        @(negedge in3_clk);
        in3_valid = 1'b1;
        for (index = 0; index < payload_length; index = index + 1) begin
            in3_data = first_byte + index[7:0];
            @(negedge in3_clk);
        end
        in3_valid = 1'b0;
        repeat (2) @(negedge in3_clk);
        in3_desc_data = {packet_id_value, payload_length};
        in3_desc_valid = 1'b1;
        @(negedge in3_clk);
        in3_desc_valid = 1'b0;
    end
endtask

initial begin
    rst_n = 1'b0;
    agg_clk = 1'b0;
    in0_clk = 1'b0;
    in1_clk = 1'b0;
    in2_clk = 1'b0;
    in3_clk = 1'b0;
    in0_data = 8'd0;
    in1_data = 8'd0;
    in2_data = 8'd0;
    in3_data = 8'd0;
    in0_valid = 1'b0;
    in1_valid = 1'b0;
    in2_valid = 1'b0;
    in3_valid = 1'b0;
    in0_desc_data = 24'd0;
    in1_desc_data = 24'd0;
    in2_desc_data = 24'd0;
    in3_desc_data = 24'd0;
    in0_desc_valid = 1'b0;
    in1_desc_valid = 1'b0;
    in2_desc_valid = 1'b0;
    in3_desc_valid = 1'b0;
    captured_frames = 0;
    captured_byte_count = 0;
    receiver_active = 4'd0;
    receiver_complete = 4'd0;
    errors = 0;

    expected_length[0] = 16'd130;
    expected_length[1] = 16'd3;
    expected_length[2] = 16'd200;
    expected_length[3] = 16'd2;
    expected_packet_id[0] = 8'h10;
    expected_packet_id[1] = 8'h20;
    expected_packet_id[2] = 8'h30;
    expected_packet_id[3] = 8'h40;
    for (port = 0; port < 4; port = port + 1) begin
        received_length[port] = 0;
        received_packet_id[port] = 8'd0;
        for (i = 0; i < 256; i = i + 1)
            expected[port][i] = 8'h00;
    end
    for (i = 0; i < 130; i = i + 1) expected[0][i] = 8'ha0 + i[7:0];
    for (i = 0; i < 3; i = i + 1) expected[1][i] = 8'hb0 + i[7:0];
    for (i = 0; i < 200; i = i + 1) expected[2][i] = 8'hc0 + i[7:0];
    for (i = 0; i < 2; i = i + 1) expected[3][i] = 8'hd0 + i[7:0];

    repeat (5) @(posedge agg_clk);
    #1 rst_n = 1'b1;
    wait (captured_frames >= 2);
    fork
        send_port0(8'ha0, 16'd130, 8'h10);
        send_port1(8'hb0, 16'd3, 8'h20);
        send_port2(8'hc0, 16'd200, 8'h30);
        send_port3(8'hd0, 16'd2, 8'h40);
    join

    wait (captured_frames >= FRAME_COUNT);
    @(posedge agg_clk);
    for (i = 0; i < FRAME_COUNT; i = i + 1)
        parse_frame(i);

    if (receiver_active != 4'd0) begin
        $display("ERROR: receiver still has an incomplete packet after all frames");
        errors = errors + 1;
    end
    for (port = 0; port < 4; port = port + 1) begin
        if (!receiver_complete[port]) begin
            $display("ERROR: port %0d packet was not completed", port);
            errors = errors + 1;
        end
        if (received_packet_id[port] != expected_packet_id[port]) begin
            $display("ERROR: port %0d expected packet_id %02x got %02x", port,
                     expected_packet_id[port], received_packet_id[port]);
            errors = errors + 1;
        end
        if (received_length[port] != expected_length[port]) begin
            $display("ERROR: port %0d expected length %0d got %0d", port,
                     expected_length[port], received_length[port]);
            errors = errors + 1;
        end
        for (byte_index = 0; byte_index < expected_length[port]; byte_index = byte_index + 1)
            if (reassembled[port][byte_index] !== expected[port][byte_index]) begin
                $display("ERROR: port %0d byte %0d expected %02x got %02x", port,
                         byte_index, expected[port][byte_index], reassembled[port][byte_index]);
                errors = errors + 1;
            end
    end

    if (errors == 0)
        $display("PASS: eth_aggregate_4port dynamic-segment simulation completed");
    else begin
        $display("FAIL: eth_aggregate_4port dynamic-segment simulation found %0d errors", errors);
        $fatal(1, "eth_aggregate_4port dynamic-segment simulation failed");
    end
    $finish;
end

endmodule
