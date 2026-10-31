`timescale 1ns / 1ps

// Unit test for compact dynamic segment formatting.  The four descriptors are
// presented together; port 2 deliberately spans two aggregation frames.
module tb_qpsk_frame_aggregator;

localparam FRAME_BYTES = 512;
localparam FRAME_COUNT = 40;
localparam [63:0] SYNC_WORD = 64'hD5C0_1ACF_FC1D_5AA5;

reg clk;
reg rst_n;
reg [7:0] source0 [0:255];
reg [7:0] source1 [0:255];
reg [7:0] source2 [0:767];
reg [7:0] source3 [0:255];
integer source0_index;
integer source1_index;
integer source2_index;
integer source3_index;
reg [23:0] desc0_data;
reg [23:0] desc1_data;
reg [23:0] desc2_data;
reg [23:0] desc3_data;
reg [3:0] desc_valid;
wire [7:0] in0_data;
wire [7:0] in1_data;
wire [7:0] in2_data;
wire [7:0] in3_data;
wire [3:0] in_valid;
wire [3:0] in_pop;
wire [3:0] desc_pop;
wire [127:0] qpsk_bits;
wire qpsk_valid;
wire frame_start;
wire frame_end;
reg [7:0] captured [0:FRAME_COUNT*FRAME_BYTES-1];
integer captured_frames;
integer captured_byte_count;
integer errors;
integer i;
integer j;
integer first_data_frame;
integer second_data_frame;
integer third_data_frame;

assign in0_data = source0[source0_index];
assign in1_data = source1[source1_index];
assign in2_data = source2[source2_index];
assign in3_data = source3[source3_index];
assign in_valid[0] = (source0_index < 130);
assign in_valid[1] = (source1_index < 3);
assign in_valid[2] = (source2_index < 700);
assign in_valid[3] = (source3_index < 2);

qpsk_frame_aggregator dut (
    .clk(clk), .rst_n(rst_n),
    .in0_data(in0_data), .in1_data(in1_data), .in2_data(in2_data), .in3_data(in3_data),
    .in_valid(in_valid), .in_pop(in_pop),
    .desc0_data(desc0_data), .desc1_data(desc1_data),
    .desc2_data(desc2_data), .desc3_data(desc3_data),
    .desc_valid(desc_valid), .desc_pop(desc_pop),
    .qpsk_bits(qpsk_bits), .qpsk_valid(qpsk_valid),
    .frame_start(frame_start), .frame_end(frame_end)
);

always #4 clk = ~clk;

always @(posedge clk) begin
    if (!rst_n) begin
        source0_index = 0;
        source1_index = 0;
        source2_index = 0;
        source3_index = 0;
        desc_valid = 4'd0;
    end else begin
        if (in_pop[0] && in_valid[0]) source0_index = source0_index + 1;
        if (in_pop[1] && in_valid[1]) source1_index = source1_index + 1;
        if (in_pop[2] && in_valid[2]) source2_index = source2_index + 1;
        if (in_pop[3] && in_valid[3]) source3_index = source3_index + 1;
        desc_valid = desc_valid & ~desc_pop;
    end
end

always @(posedge clk) begin
    if (!rst_n) begin
        captured_frames = 0;
        captured_byte_count = 0;
    end else begin
        if (qpsk_valid !== 1'b1) begin
            $display("ERROR: qpsk_valid must be continuous after reset");
            errors = errors + 1;
        end
        if (qpsk_valid) begin
            if (frame_start && captured_byte_count != 0) begin
                $display("ERROR: frame_start is not on a frame boundary");
                errors = errors + 1;
            end
            if (captured_frames < FRAME_COUNT)
                for (j = 0; j < 16; j = j + 1)
                    captured[captured_frames*FRAME_BYTES + captured_byte_count+j] = qpsk_bits[127-j*8 -: 8];
            if (frame_end) begin
                if (captured_byte_count != FRAME_BYTES-16) begin
                    $display("ERROR: frame_end position is invalid");
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
    input integer byte_index;
    input [7:0] value;
    begin
        if (captured[frame_number*FRAME_BYTES + byte_index] !== value) begin
            $display("ERROR: frame %0d byte %0d expected %02x got %02x", frame_number,
                     byte_index, value, captured[frame_number*FRAME_BYTES + byte_index]);
            errors = errors + 1;
        end
    end
endtask

task check_crc;
    input integer frame_number;
    reg [31:0] crc;
    reg [31:0] expected_crc;
    integer byte_index;
    begin
        crc = 32'hffff_ffff;
        for (byte_index = 0; byte_index < 508; byte_index = byte_index + 1)
            crc = crc32_byte(crc, captured[frame_number*FRAME_BYTES + byte_index]);
        expected_crc = ~crc;
        expect_byte(frame_number, 508, expected_crc[31:24]);
        expect_byte(frame_number, 509, expected_crc[23:16]);
        expect_byte(frame_number, 510, expected_crc[15:8]);
        expect_byte(frame_number, 511, expected_crc[7:0]);
    end
endtask

task check_common_header;
    input integer frame_number;
    begin
        for (i = 0; i < 8; i = i + 1)
            expect_byte(frame_number, i, SYNC_WORD[63-i*8 -: 8]);
        expect_byte(frame_number, 8, 8'h01);
        expect_byte(frame_number, 12, frame_number[31:24]);
        expect_byte(frame_number, 13, frame_number[23:16]);
        expect_byte(frame_number, 14, frame_number[15:8]);
        expect_byte(frame_number, 15, frame_number[7:0]);
        check_crc(frame_number);
    end
endtask

task check_prbs_range;
    input integer frame_number;
    input integer first_byte;
    input integer last_byte;
    reg [30:0] state;
    integer byte_index;
    begin
        state = prbs_seed(frame_number);
        for (byte_index = 16; byte_index <= last_byte; byte_index = byte_index + 1) begin
            if (byte_index >= first_byte)
                expect_byte(frame_number, byte_index, prbs31_byte(state));
            state = prbs31_advance8(state);
        end
    end
endtask

task check_idle_frame;
    input integer frame_number;
    begin
        check_common_header(frame_number);
        expect_byte(frame_number, 9, 8'h06);
        expect_byte(frame_number, 10, 8'h00);
        expect_byte(frame_number, 11, 8'h00);
        check_prbs_range(frame_number, 16, 507);
    end
endtask

task check_first_data_frame;
    input integer frame_number;
    integer byte_index;
    begin
        check_common_header(frame_number);
        expect_byte(frame_number, 9, 8'h07);
        expect_byte(frame_number, 10, 8'h01);
        expect_byte(frame_number, 11, 8'h03);
        expect_byte(frame_number, 16, 8'h04);
        expect_byte(frame_number, 17, 8'h10);
        expect_byte(frame_number, 18, 8'h00);
        expect_byte(frame_number, 19, 8'h77);
        for (byte_index = 0; byte_index < 119; byte_index = byte_index + 1)
            expect_byte(frame_number, 20+byte_index, 8'ha0 + byte_index[7:0]);
        expect_byte(frame_number, 139, 8'h0d);
        expect_byte(frame_number, 140, 8'h20);
        expect_byte(frame_number, 141, 8'h00);
        expect_byte(frame_number, 142, 8'h03);
        expect_byte(frame_number, 143, 8'hb0);
        expect_byte(frame_number, 144, 8'hb1);
        expect_byte(frame_number, 145, 8'hb2);
        expect_byte(frame_number, 146, 8'h06);
        expect_byte(frame_number, 147, 8'h30);
        expect_byte(frame_number, 148, 8'h00);
        expect_byte(frame_number, 149, 8'h77);
        for (byte_index = 0; byte_index < 119; byte_index = byte_index + 1)
            expect_byte(frame_number, 150+byte_index, 8'hc0 + byte_index[7:0]);
        expect_byte(frame_number, 269, 8'h0f);
        expect_byte(frame_number, 270, 8'h40);
        expect_byte(frame_number, 271, 8'h00);
        expect_byte(frame_number, 272, 8'h02);
        expect_byte(frame_number, 273, 8'hd0);
        expect_byte(frame_number, 274, 8'hd1);
        check_prbs_range(frame_number, 275, 507);
    end
endtask

task check_second_data_frame;
    input integer frame_number;
    integer byte_index;
    begin
        check_common_header(frame_number);
        expect_byte(frame_number, 9, 8'h07);
        expect_byte(frame_number, 10, 8'h01);
        expect_byte(frame_number, 11, 8'h05);
        expect_byte(frame_number, 16, 8'h08);
        expect_byte(frame_number, 17, 8'h10);
        expect_byte(frame_number, 18, 8'h00);
        expect_byte(frame_number, 19, 8'h0b);
        for (byte_index = 0; byte_index < 11; byte_index = byte_index + 1)
            expect_byte(frame_number, 20+byte_index, 8'ha0 + 8'h77 + byte_index[7:0]);
        expect_byte(frame_number, 31, 8'h02);
        expect_byte(frame_number, 32, 8'h30);
        expect_byte(frame_number, 33, 8'h00);
        expect_byte(frame_number, 34, 8'hf2);
        for (byte_index = 0; byte_index < 242; byte_index = byte_index + 1)
            expect_byte(frame_number, 35+byte_index, 8'hc0 + 8'h77 + byte_index[7:0]);
        check_prbs_range(frame_number, 277, 507);
    end
endtask

task check_third_data_frame;
    input integer frame_number;
    integer byte_index;
    begin
        check_common_header(frame_number);
        expect_byte(frame_number, 9, 8'h07);
        expect_byte(frame_number, 10, 8'h01);
        expect_byte(frame_number, 11, 8'h57);
        expect_byte(frame_number, 16, 8'h0a);
        expect_byte(frame_number, 17, 8'h30);
        expect_byte(frame_number, 18, 8'h01);
        expect_byte(frame_number, 19, 8'h53);
        for (byte_index = 0; byte_index < 339; byte_index = byte_index + 1)
            expect_byte(frame_number, 20+byte_index, 8'hc0 + 8'h69 + byte_index[7:0]);
        check_prbs_range(frame_number, 359, 507);
    end
endtask

initial begin
    clk = 1'b0;
    rst_n = 1'b0;
    source0_index = 0;
    source1_index = 0;
    source2_index = 0;
    source3_index = 0;
    desc0_data = {8'h10, 16'd130};
    desc1_data = {8'h20, 16'd3};
    desc2_data = {8'h30, 16'd700};
    desc3_data = {8'h40, 16'd2};
    desc_valid = 4'd0;
    captured_frames = 0;
    captured_byte_count = 0;
    errors = 0;
    for (i = 0; i < 130; i = i + 1) source0[i] = 8'ha0 + i[7:0];
    for (i = 0; i < 3; i = i + 1) source1[i] = 8'hb0 + i[7:0];
    for (i = 0; i < 700; i = i + 1) source2[i] = 8'hc0 + i[7:0];
    for (i = 0; i < 2; i = i + 1) source3[i] = 8'hd0 + i[7:0];

    repeat (4) @(posedge clk);
    #1 rst_n = 1'b1;
    wait (captured_frames >= 2);
    @(negedge clk);
    desc_valid = 4'hf;
    wait (captured_frames >= FRAME_COUNT);
    @(posedge clk);

    check_idle_frame(0);
    check_idle_frame(1);
    first_data_frame = -1;
    second_data_frame = -1;
    third_data_frame = -1;
    for (i = 0; i < FRAME_COUNT; i = i + 1) begin
        if (captured[i*FRAME_BYTES+9] == 8'h07) begin
            if (first_data_frame < 0)
                first_data_frame = i;
            else if (second_data_frame < 0)
                second_data_frame = i;
            else if (third_data_frame < 0)
                third_data_frame = i;
        end
    end
    if (first_data_frame < 0) begin
        $display("ERROR: expected compact source-tagged frame was not emitted");
        errors = errors + 1;
    end else begin
        check_first_data_frame(first_data_frame);
    end
    if (second_data_frame < 0) begin
        $display("ERROR: expected second compact source-tagged frame was not emitted");
        errors = errors + 1;
    end else begin
        check_second_data_frame(second_data_frame);
    end
    if (third_data_frame < 0) begin
        $display("ERROR: expected third compact source-tagged frame was not emitted");
        errors = errors + 1;
    end else begin
        check_third_data_frame(third_data_frame);
    end

    if (errors == 0)
        $display("PASS: qpsk_frame_aggregator dynamic-segment simulation completed");
    else begin
        $display("FAIL: qpsk_frame_aggregator dynamic-segment simulation found %0d errors", errors);
        $fatal(1, "qpsk_frame_aggregator dynamic-segment simulation failed");
    end
    $finish;
end

endmodule
