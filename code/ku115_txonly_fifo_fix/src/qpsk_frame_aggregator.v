`timescale 1ns / 1ps

// Source-tagged four-port UDP aggregation protocol.
//
// Bytes 16..507 contain compact segment records:
//   [tag][packet_id][fragment_length:16][fragment_payload]
// The tag carries port_id, SOP and EOP, allowing the receiver to restore the
// source port and packet boundaries.  Every remaining byte is PRBS31.
module qpsk_frame_aggregator
(
    input              clk,
    input              rst_n,

    input      [7:0]   in0_data,
    input      [7:0]   in1_data,
    input      [7:0]   in2_data,
    input      [7:0]   in3_data,
    input      [3:0]   in_valid,
    output reg [3:0]   in_pop,

    input      [23:0]  desc0_data,
    input      [23:0]  desc1_data,
    input      [23:0]  desc2_data,
    input      [23:0]  desc3_data,
    input      [3:0]   desc_valid,
    output reg [3:0]   desc_pop,

    output reg [127:0] qpsk_bits,
    output reg         qpsk_valid,
    output reg         frame_start,
    output reg         frame_end
);

localparam [8:0] SEGMENT_START = 9'd16;
localparam [8:0] CRC_START = 9'd508;
localparam [8:0] SEGMENT_CAPACITY = 9'd492;
localparam [63:0] SYNC_WORD = 64'hD5C0_1ACF_FC1D_5AA5;
localparam [7:0] PROTOCOL_VERSION = 8'h01;
localparam [7:0] FRAME_FLAGS_IDLE = 8'h06;
localparam [7:0] FRAME_FLAGS_DATA = 8'h07;
localparam [30:0] PRBS31_SEED = 31'h7fff_ffff;
localparam [127:0] RESET_IDLE_HEADER = {
    SYNC_WORD, PROTOCOL_VERSION, FRAME_FLAGS_IDLE, 16'h0000, 32'h0000_0000
};

reg [3:0] ctx_active;
reg [15:0] ctx_remaining [0:3];
reg [7:0] ctx_packet_id [0:3];
reg [1:0] round_robin_ptr;

// Pipeline descriptor selection before it controls the frame-store write.
// This leaves the on-wire 512-byte format unchanged while shortening the
// 125 MHz control path for a continuous 16 Gbit/s, 4 Gbaud DP-QPSK stream.
reg plan_valid;
reg plan_buf;
reg [8:0] plan_segment_length;
reg [3:0] plan_present;
reg [3:0] plan_sop;
reg [3:0] plan_eop;
reg [1:0] plan_round_robin_next;
reg [8:0] plan_len [0:3];
reg [15:0] plan_remaining_after [0:3];
reg [7:0] plan_packet_id [0:3];
reg [8:0] plan_start [0:3];

reg build_active;
reg build_buf;
reg [8:0] build_len [0:3];
reg [8:0] build_progress [0:3];
reg [15:0] build_remaining_after [0:3];
reg [7:0] build_packet_id [0:3];
reg [8:0] build_start [0:3];
reg [3:0] build_sop;
reg [3:0] build_eop;
reg [3:0] build_record_present;
reg [1:0] build_round_robin_next;

reg [1:0] buf_in_use;
reg [1:0] buf_ready;
reg [8:0] buf_segment_length [0:1];
reg [3:0] buf_present [0:1];
reg [8:0] buf_len [0:1][0:3];
reg [7:0] buf_packet_id [0:1][0:3];
reg [8:0] buf_start [0:1][0:3];
reg [3:0] buf_sop [0:1];
reg [3:0] buf_eop [0:1];

reg tx_data;
reg tx_buf;
reg [5:0] tx_word_index;
reg [31:0] tx_sequence;
reg [30:0] prbs_state;
reg [31:0] crc_state;
reg [127:0] raw_word_pipe;
reg [5:0] pipe_word_index;

reg [3:0] selected_present;
reg [3:0] selected_uses_desc;
reg [15:0] selected_total_remaining [0:3];
reg [8:0] selected_len [0:3];
reg [15:0] selected_remaining_after [0:3];
reg [7:0] selected_packet_id [0:3];
reg [8:0] selected_start [0:3];
reg [3:0] selected_sop;
reg [3:0] selected_eop;
reg [1:0] selected_round_robin_next;
reg [8:0] selected_segment_length;

reg [15:0] bank_write_en [0:3];
reg [4:0] bank_write_addr [0:3][0:15];
reg [7:0] bank_write_data [0:3][0:15];
wire [7:0] buf0_rdata [0:3][0:15];
wire [7:0] buf1_rdata [0:3][0:15];
wire [4:0] buf0_rd_addr;
wire [4:0] buf1_rd_addr;

wire [7:0] input_data [0:3];
wire [23:0] descriptor_data [0:3];
wire [15:0] descriptor_length [0:3];
wire [7:0] descriptor_packet_id [0:3];
wire [3:0] candidate_present;
wire [2:0] candidate_count;
wire [8:0] candidate_quota;
wire can_start_build;
wire start_buf;
wire build_complete;
wire [8:0] build_offset0;
wire [8:0] build_offset1;
wire [8:0] build_offset2;
wire [8:0] build_offset3;

wire [8:0] tx_segment_length;
wire [3:0] tx_present;
wire [8:0] tx_len0;
wire [8:0] tx_len1;
wire [8:0] tx_len2;
wire [8:0] tx_len3;
wire [7:0] tx_packet_id0;
wire [7:0] tx_packet_id1;
wire [7:0] tx_packet_id2;
wire [7:0] tx_packet_id3;
wire [8:0] tx_start0;
wire [8:0] tx_start1;
wire [8:0] tx_start2;
wire [8:0] tx_start3;
wire tx_sop0;
wire tx_sop1;
wire tx_sop2;
wire tx_sop3;
wire tx_eop0;
wire tx_eop1;
wire tx_eop2;
wire tx_eop3;
wire [7:0] tx_tag0;
wire [7:0] tx_tag1;
wire [7:0] tx_tag2;
wire [7:0] tx_tag3;

reg [127:0] raw_word;
reg [127:0] next_qpsk_word;
reg [30:0] prbs_after_word;
reg [30:0] prbs_work;
reg [7:0] output_byte;
reg [31:0] crc_final;
integer select_port;
integer select_scan;
integer select_candidate;
reg [8:0] select_segment_offset;
integer write_port;
integer write_bank;
integer state_port;
integer output_index;
reg [8:0] global_byte;

assign input_data[0] = in0_data;
assign input_data[1] = in1_data;
assign input_data[2] = in2_data;
assign input_data[3] = in3_data;
assign descriptor_data[0] = desc0_data;
assign descriptor_data[1] = desc1_data;
assign descriptor_data[2] = desc2_data;
assign descriptor_data[3] = desc3_data;
assign candidate_present = ctx_active | desc_valid;
assign candidate_count = {2'b00, candidate_present[0]} +
                         {2'b00, candidate_present[1]} +
                         {2'b00, candidate_present[2]} +
                         {2'b00, candidate_present[3]};
// Each active port receives an equal record slot.  Four bytes in every slot
// are reserved for the segment header; the rest is fragment payload.
assign candidate_quota = (candidate_count == 3'd1) ? 9'd488 :
                         (candidate_count == 3'd2) ? 9'd242 :
                         (candidate_count == 3'd3) ? 9'd160 :
                         (candidate_count == 3'd4) ? 9'd119 : 9'd0;

generate
    genvar metadata_index;
    for (metadata_index = 0; metadata_index < 4; metadata_index = metadata_index + 1) begin : g_input_metadata
        assign descriptor_length[metadata_index] = descriptor_data[metadata_index][15:0];
        assign descriptor_packet_id[metadata_index] = descriptor_data[metadata_index][23:16];
    end
endgenerate

assign can_start_build = !build_active && !plan_valid && (|ctx_active || |desc_valid) &&
                         (!buf_in_use[0] || !buf_in_use[1]);
assign start_buf = !buf_in_use[0] ? 1'b0 : 1'b1;
assign build_offset0 = build_start[0] + 9'd4 + build_progress[0];
assign build_offset1 = build_start[1] + 9'd4 + build_progress[1];
assign build_offset2 = build_start[2] + 9'd4 + build_progress[2];
assign build_offset3 = build_start[3] + 9'd4 + build_progress[3];
assign build_complete = ((build_progress[0] + (in_pop[0] ? 1'b1 : 1'b0)) >= build_len[0]) &&
                        ((build_progress[1] + (in_pop[1] ? 1'b1 : 1'b0)) >= build_len[1]) &&
                        ((build_progress[2] + (in_pop[2] ? 1'b1 : 1'b0)) >= build_len[2]) &&
                        ((build_progress[3] + (in_pop[3] ? 1'b1 : 1'b0)) >= build_len[3]);

assign buf0_rd_addr = (tx_data && !tx_buf) ? tx_word_index[4:0] : 5'd0;
assign buf1_rd_addr = (tx_data && tx_buf) ? tx_word_index[4:0] : 5'd0;
assign tx_segment_length = tx_buf ? buf_segment_length[1] : buf_segment_length[0];
assign tx_present = tx_buf ? buf_present[1] : buf_present[0];
assign tx_len0 = tx_buf ? buf_len[1][0] : buf_len[0][0];
assign tx_len1 = tx_buf ? buf_len[1][1] : buf_len[0][1];
assign tx_len2 = tx_buf ? buf_len[1][2] : buf_len[0][2];
assign tx_len3 = tx_buf ? buf_len[1][3] : buf_len[0][3];
assign tx_packet_id0 = tx_buf ? buf_packet_id[1][0] : buf_packet_id[0][0];
assign tx_packet_id1 = tx_buf ? buf_packet_id[1][1] : buf_packet_id[0][1];
assign tx_packet_id2 = tx_buf ? buf_packet_id[1][2] : buf_packet_id[0][2];
assign tx_packet_id3 = tx_buf ? buf_packet_id[1][3] : buf_packet_id[0][3];
assign tx_start0 = tx_buf ? buf_start[1][0] : buf_start[0][0];
assign tx_start1 = tx_buf ? buf_start[1][1] : buf_start[0][1];
assign tx_start2 = tx_buf ? buf_start[1][2] : buf_start[0][2];
assign tx_start3 = tx_buf ? buf_start[1][3] : buf_start[0][3];
assign tx_sop0 = tx_buf ? buf_sop[1][0] : buf_sop[0][0];
assign tx_sop1 = tx_buf ? buf_sop[1][1] : buf_sop[0][1];
assign tx_sop2 = tx_buf ? buf_sop[1][2] : buf_sop[0][2];
assign tx_sop3 = tx_buf ? buf_sop[1][3] : buf_sop[0][3];
assign tx_eop0 = tx_buf ? buf_eop[1][0] : buf_eop[0][0];
assign tx_eop1 = tx_buf ? buf_eop[1][1] : buf_eop[0][1];
assign tx_eop2 = tx_buf ? buf_eop[1][2] : buf_eop[0][2];
assign tx_eop3 = tx_buf ? buf_eop[1][3] : buf_eop[0][3];
assign tx_tag0 = {3'b000, 1'b0, tx_eop0, tx_sop0, 2'b00};
assign tx_tag1 = {3'b000, 1'b0, tx_eop1, tx_sop1, 2'b01};
assign tx_tag2 = {3'b000, 1'b0, tx_eop2, tx_sop2, 2'b10};
assign tx_tag3 = {3'b000, 1'b0, tx_eop3, tx_sop3, 2'b11};

function [31:0] crc32_byte;
    input [31:0] crc_in;
    input [7:0] data_in;
    reg [31:0] crc;
    integer bit_index;
    begin
        crc = crc_in ^ {data_in, 24'h0};
        for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1) begin
            if (crc[31]) crc = (crc << 1) ^ 32'h04C11DB7;
            else crc = crc << 1;
        end
        crc32_byte = crc;
    end
endfunction

function [31:0] crc32_word;
    input [31:0] crc_in;
    input [127:0] data_in;
    input [4:0] byte_count;
    reg [31:0] crc;
    integer byte_index;
    begin
        crc = crc_in;
        for (byte_index = 0; byte_index < 16; byte_index = byte_index + 1)
            if (byte_index < byte_count)
                crc = crc32_byte(crc, data_in[127-byte_index*8 -: 8]);
        crc32_word = crc;
    end
endfunction

function [7:0] prbs31_byte;
    input [30:0] state_in;
    reg [30:0] shift_state;
    integer bit_index;
    begin
        shift_state = state_in;
        for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1) begin
            prbs31_byte[7-bit_index] = shift_state[30];
            shift_state = {shift_state[29:0], shift_state[30] ^ shift_state[27]};
        end
    end
endfunction

function [30:0] prbs31_advance8;
    input [30:0] state_in;
    reg [30:0] shift_state;
    integer bit_index;
    begin
        shift_state = state_in;
        for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1)
            shift_state = {shift_state[29:0], shift_state[30] ^ shift_state[27]};
        prbs31_advance8 = shift_state;
    end
endfunction

function [30:0] prbs_seed;
    input [31:0] frame_sequence;
    begin
        prbs_seed = (PRBS31_SEED ^ frame_sequence[30:0]) | 31'h0000_0001;
    end
endfunction

// One compact segment is selected for each active port.  The quota depends
// only on the active-port count, keeping the scheduling path constant depth.
always @(*) begin
    selected_present = 4'd0;
    selected_uses_desc = 4'd0;
    selected_sop = 4'd0;
    selected_eop = 4'd0;
    selected_round_robin_next = round_robin_ptr;
    selected_segment_length = 9'd0;

    for (select_port = 0; select_port < 4; select_port = select_port + 1) begin
        selected_total_remaining[select_port] = 16'd0;
        selected_len[select_port] = 9'd0;
        selected_remaining_after[select_port] = 16'd0;
        selected_packet_id[select_port] = 8'd0;
        selected_start[select_port] = 9'd0;
        if (ctx_active[select_port]) begin
            selected_present[select_port] = 1'b1;
            selected_total_remaining[select_port] = ctx_remaining[select_port];
            selected_packet_id[select_port] = ctx_packet_id[select_port];
            selected_sop[select_port] = 1'b0;
        end else if (desc_valid[select_port]) begin
            selected_present[select_port] = 1'b1;
            selected_uses_desc[select_port] = 1'b1;
            selected_total_remaining[select_port] = descriptor_length[select_port];
            selected_packet_id[select_port] = descriptor_packet_id[select_port];
            selected_sop[select_port] = 1'b1;
        end
        if (selected_present[select_port]) begin
            if (selected_total_remaining[select_port] < candidate_quota)
                selected_len[select_port] = selected_total_remaining[select_port][8:0];
            else
                selected_len[select_port] = candidate_quota;
        end
    end

    if (candidate_count != 0) begin
        select_segment_offset = SEGMENT_START;
        for (select_scan = 0; select_scan < 4; select_scan = select_scan + 1) begin
            select_candidate = round_robin_ptr + select_scan;
            if (select_candidate >= 4)
                select_candidate = select_candidate - 4;
            if (selected_present[select_candidate]) begin
                selected_start[select_candidate] = select_segment_offset;
                selected_remaining_after[select_candidate] =
                    selected_total_remaining[select_candidate] - selected_len[select_candidate];
                selected_eop[select_candidate] =
                    (selected_total_remaining[select_candidate] <= selected_len[select_candidate]);
                select_segment_offset = select_segment_offset + 4 + selected_len[select_candidate];
                if (select_candidate == 3)
                    selected_round_robin_next = 2'd0;
                else
                    selected_round_robin_next = select_candidate + 1'b1;
            end
        end
        selected_segment_length = select_segment_offset - SEGMENT_START;
    end
end

always @(*) begin
    in_pop = 4'd0;
    desc_pop = 4'd0;
    for (write_port = 0; write_port < 4; write_port = write_port + 1)
        for (write_bank = 0; write_bank < 16; write_bank = write_bank + 1) begin
            bank_write_en[write_port][write_bank] = 1'b0;
            bank_write_addr[write_port][write_bank] = 5'd0;
            bank_write_data[write_port][write_bank] = 8'd0;
        end

    if (can_start_build) begin
        for (write_port = 0; write_port < 4; write_port = write_port + 1)
            desc_pop[write_port] = selected_uses_desc[write_port];
    end

    if (build_active) begin
        for (write_port = 0; write_port < 4; write_port = write_port + 1)
            in_pop[write_port] = (build_progress[write_port] < build_len[write_port]) && in_valid[write_port];

        if (in_pop[0]) begin
            bank_write_en[0][build_offset0[3:0]] = 1'b1;
            bank_write_addr[0][build_offset0[3:0]] = build_offset0[8:4];
            bank_write_data[0][build_offset0[3:0]] = input_data[0];
        end
        if (in_pop[1]) begin
            bank_write_en[1][build_offset1[3:0]] = 1'b1;
            bank_write_addr[1][build_offset1[3:0]] = build_offset1[8:4];
            bank_write_data[1][build_offset1[3:0]] = input_data[1];
        end
        if (in_pop[2]) begin
            bank_write_en[2][build_offset2[3:0]] = 1'b1;
            bank_write_addr[2][build_offset2[3:0]] = build_offset2[8:4];
            bank_write_data[2][build_offset2[3:0]] = input_data[2];
        end
        if (in_pop[3]) begin
            bank_write_en[3][build_offset3[3:0]] = 1'b1;
            bank_write_addr[3][build_offset3[3:0]] = build_offset3[8:4];
            bank_write_data[3][build_offset3[3:0]] = input_data[3];
        end
    end
end

generate
    genvar port_index;
    genvar bank_index;
    for (port_index = 0; port_index < 4; port_index = port_index + 1) begin : g_port_frame_banks
        for (bank_index = 0; bank_index < 16; bank_index = bank_index + 1) begin : g_byte_lane
            frame_byte_bank buffer0_bank (
                .clk     (clk),
                .wr_en   (build_active && !build_buf && bank_write_en[port_index][bank_index]),
                .wr_addr (bank_write_addr[port_index][bank_index]),
                .wr_data (bank_write_data[port_index][bank_index]),
                .rd_addr (buf0_rd_addr),
                .rd_data (buf0_rdata[port_index][bank_index])
            );
            frame_byte_bank buffer1_bank (
                .clk     (clk),
                .wr_en   (build_active && build_buf && bank_write_en[port_index][bank_index]),
                .wr_addr (bank_write_addr[port_index][bank_index]),
                .wr_data (bank_write_data[port_index][bank_index]),
                .rd_addr (buf1_rd_addr),
                .rd_data (buf1_rdata[port_index][bank_index])
            );
        end
    end
endgenerate

always @(*) begin
    raw_word = 128'd0;
    prbs_work = prbs_state;
    for (output_index = 0; output_index < 16; output_index = output_index + 1) begin
        global_byte = tx_word_index*16 + output_index;
        output_byte = 8'd0;
        if (global_byte < SEGMENT_START) begin
            case (global_byte)
                0: output_byte = SYNC_WORD[63:56];
                1: output_byte = SYNC_WORD[55:48];
                2: output_byte = SYNC_WORD[47:40];
                3: output_byte = SYNC_WORD[39:32];
                4: output_byte = SYNC_WORD[31:24];
                5: output_byte = SYNC_WORD[23:16];
                6: output_byte = SYNC_WORD[15:8];
                7: output_byte = SYNC_WORD[7:0];
                8: output_byte = PROTOCOL_VERSION;
                9: output_byte = tx_data ? FRAME_FLAGS_DATA : FRAME_FLAGS_IDLE;
                10: output_byte = tx_data ? {7'd0, tx_segment_length[8]} : 8'd0;
                11: output_byte = tx_data ? tx_segment_length[7:0] : 8'd0;
                12: output_byte = tx_sequence[31:24];
                13: output_byte = tx_sequence[23:16];
                14: output_byte = tx_sequence[15:8];
                15: output_byte = tx_sequence[7:0];
                default: output_byte = 8'd0;
            endcase
        end else begin
            output_byte = prbs31_byte(prbs_work);
            prbs_work = prbs31_advance8(prbs_work);
        end

        if (tx_data) begin
            if (tx_present[0] && global_byte == tx_start0) begin
                output_byte = tx_tag0;
            end else if (tx_present[0] && global_byte == tx_start0 + 1) begin
                output_byte = tx_packet_id0;
            end else if (tx_present[0] && global_byte == tx_start0 + 2) begin
                output_byte = {7'd0, tx_len0[8]};
            end else if (tx_present[0] && global_byte == tx_start0 + 3) begin
                output_byte = tx_len0[7:0];
            end else if (tx_present[0] && global_byte >= tx_start0 + 4 &&
                global_byte < tx_start0 + 4 + tx_len0) begin
                output_byte = tx_buf ? buf1_rdata[0][output_index] : buf0_rdata[0][output_index];
            end else if (tx_present[1] && global_byte == tx_start1) begin
                output_byte = tx_tag1;
            end else if (tx_present[1] && global_byte == tx_start1 + 1) begin
                output_byte = tx_packet_id1;
            end else if (tx_present[1] && global_byte == tx_start1 + 2) begin
                output_byte = {7'd0, tx_len1[8]};
            end else if (tx_present[1] && global_byte == tx_start1 + 3) begin
                output_byte = tx_len1[7:0];
            end else if (tx_present[1] && global_byte >= tx_start1 + 4 &&
                         global_byte < tx_start1 + 4 + tx_len1) begin
                output_byte = tx_buf ? buf1_rdata[1][output_index] : buf0_rdata[1][output_index];
            end else if (tx_present[2] && global_byte == tx_start2) begin
                output_byte = tx_tag2;
            end else if (tx_present[2] && global_byte == tx_start2 + 1) begin
                output_byte = tx_packet_id2;
            end else if (tx_present[2] && global_byte == tx_start2 + 2) begin
                output_byte = {7'd0, tx_len2[8]};
            end else if (tx_present[2] && global_byte == tx_start2 + 3) begin
                output_byte = tx_len2[7:0];
            end else if (tx_present[2] && global_byte >= tx_start2 + 4 &&
                         global_byte < tx_start2 + 4 + tx_len2) begin
                output_byte = tx_buf ? buf1_rdata[2][output_index] : buf0_rdata[2][output_index];
            end else if (tx_present[3] && global_byte == tx_start3) begin
                output_byte = tx_tag3;
            end else if (tx_present[3] && global_byte == tx_start3 + 1) begin
                output_byte = tx_packet_id3;
            end else if (tx_present[3] && global_byte == tx_start3 + 2) begin
                output_byte = {7'd0, tx_len3[8]};
            end else if (tx_present[3] && global_byte == tx_start3 + 3) begin
                output_byte = tx_len3[7:0];
            end else if (tx_present[3] && global_byte >= tx_start3 + 4 &&
                         global_byte < tx_start3 + 4 + tx_len3) begin
                output_byte = tx_buf ? buf1_rdata[3][output_index] : buf0_rdata[3][output_index];
            end
        end
        raw_word[127-output_index*8 -: 8] = output_byte;
    end
    prbs_after_word = prbs_work;
    crc_final = ~crc32_word(crc_state, raw_word_pipe, 5'd12);
    next_qpsk_word = raw_word_pipe;
    if (pipe_word_index == 6'd31)
        next_qpsk_word[31:0] = crc_final;

    qpsk_valid = rst_n;
    qpsk_bits = rst_n ? next_qpsk_word : 128'd0;
    frame_start = rst_n && (pipe_word_index == 6'd0);
    frame_end = rst_n && (pipe_word_index == 6'd31);
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        ctx_active <= 4'd0;
        round_robin_ptr <= 2'd0;
        plan_valid <= 1'b0;
        plan_buf <= 1'b0;
        plan_segment_length <= 16'd0;
        plan_present <= 4'd0;
        plan_sop <= 4'd0;
        plan_eop <= 4'd0;
        plan_round_robin_next <= 2'd0;
        build_active <= 1'b0;
        build_buf <= 1'b0;
        build_sop <= 4'd0;
        build_eop <= 4'd0;
        build_record_present <= 4'd0;
        build_round_robin_next <= 2'd0;
        buf_in_use <= 2'd0;
        buf_ready <= 2'd0;
        tx_data <= 1'b0;
        tx_buf <= 1'b0;
        // Word 0 of the first idle frame is preloaded into raw_word_pipe.
        tx_word_index <= 6'd1;
        tx_sequence <= 32'd0;
        prbs_state <= prbs_seed(32'd0);
        crc_state <= 32'hffff_ffff;
        raw_word_pipe <= RESET_IDLE_HEADER;
        pipe_word_index <= 6'd0;
        for (state_port = 0; state_port < 4; state_port = state_port + 1) begin
            ctx_remaining[state_port] <= 16'd0;
            ctx_packet_id[state_port] <= 8'd0;
            plan_len[state_port] <= 16'd0;
            plan_remaining_after[state_port] <= 16'd0;
            plan_packet_id[state_port] <= 8'd0;
            plan_start[state_port] <= 9'd0;
            build_len[state_port] <= 16'd0;
            build_progress[state_port] <= 16'd0;
            build_remaining_after[state_port] <= 16'd0;
            build_packet_id[state_port] <= 8'd0;
            build_start[state_port] <= 9'd0;
            buf_len[0][state_port] <= 16'd0;
            buf_len[1][state_port] <= 16'd0;
            buf_packet_id[0][state_port] <= 8'd0;
            buf_packet_id[1][state_port] <= 8'd0;
            buf_start[0][state_port] <= 9'd0;
            buf_start[1][state_port] <= 9'd0;
        end
        buf_segment_length[0] <= 16'd0;
        buf_segment_length[1] <= 16'd0;
        buf_present[0] <= 4'd0;
        buf_present[1] <= 4'd0;
        buf_sop[0] <= 4'd0;
        buf_sop[1] <= 4'd0;
        buf_eop[0] <= 4'd0;
        buf_eop[1] <= 4'd0;
    end else begin
        raw_word_pipe <= raw_word;
        pipe_word_index <= tx_word_index;
        if (pipe_word_index == 6'd31)
            crc_state <= 32'hffff_ffff;
        else
            crc_state <= crc32_word(crc_state, raw_word_pipe, 5'd16);

        if (can_start_build) begin
            plan_valid <= 1'b1;
            plan_buf <= start_buf;
            plan_segment_length <= selected_segment_length;
            plan_present <= selected_present;
            plan_sop <= selected_sop;
            plan_eop <= selected_eop;
            plan_round_robin_next <= selected_round_robin_next;
            for (state_port = 0; state_port < 4; state_port = state_port + 1) begin
                plan_len[state_port] <= selected_len[state_port];
                plan_remaining_after[state_port] <= selected_remaining_after[state_port];
                plan_packet_id[state_port] <= selected_packet_id[state_port];
                plan_start[state_port] <= selected_start[state_port];
            end
        end else if (plan_valid) begin
            plan_valid <= 1'b0;
            build_active <= 1'b1;
            build_buf <= plan_buf;
            buf_in_use[plan_buf] <= 1'b1;
            buf_segment_length[plan_buf] <= plan_segment_length;
            buf_present[plan_buf] <= plan_present;
            buf_sop[plan_buf] <= plan_sop;
            buf_eop[plan_buf] <= plan_eop;
            build_sop <= plan_sop;
            build_eop <= plan_eop;
            build_record_present <= plan_present;
            build_round_robin_next <= plan_round_robin_next;
            for (state_port = 0; state_port < 4; state_port = state_port + 1) begin
                build_len[state_port] <= plan_len[state_port];
                build_progress[state_port] <= 16'd0;
                build_remaining_after[state_port] <= plan_remaining_after[state_port];
                build_packet_id[state_port] <= plan_packet_id[state_port];
                build_start[state_port] <= plan_start[state_port];
                buf_len[plan_buf][state_port] <= plan_len[state_port];
                buf_packet_id[plan_buf][state_port] <= plan_packet_id[state_port];
                buf_start[plan_buf][state_port] <= plan_start[state_port];
            end
        end else if (build_active) begin
            for (state_port = 0; state_port < 4; state_port = state_port + 1)
                if (in_pop[state_port])
                    build_progress[state_port] <= build_progress[state_port] + 1'b1;
            if (build_complete) begin
                build_active <= 1'b0;
                buf_ready[build_buf] <= 1'b1;
                round_robin_ptr <= build_round_robin_next;
                for (state_port = 0; state_port < 4; state_port = state_port + 1) begin
                    if (build_record_present[state_port]) begin
                        if (build_eop[state_port]) begin
                            ctx_active[state_port] <= 1'b0;
                            ctx_remaining[state_port] <= 16'd0;
                        end else begin
                            ctx_active[state_port] <= 1'b1;
                            ctx_remaining[state_port] <= build_remaining_after[state_port];
                            ctx_packet_id[state_port] <= build_packet_id[state_port];
                        end
                    end
                end
            end
        end

        if (tx_word_index == 6'd31) begin
            tx_word_index <= 6'd0;
            tx_sequence <= tx_sequence + 1'b1;
            prbs_state <= prbs_seed(tx_sequence + 1'b1);
            if (tx_data)
                buf_in_use[tx_buf] <= 1'b0;
            if (buf_ready[0] && !(tx_data && !tx_buf)) begin
                tx_data <= 1'b1;
                tx_buf <= 1'b0;
                buf_ready[0] <= 1'b0;
            end else if (buf_ready[1] && !(tx_data && tx_buf)) begin
                tx_data <= 1'b1;
                tx_buf <= 1'b1;
                buf_ready[1] <= 1'b0;
            end else begin
                tx_data <= 1'b0;
            end
        end else begin
            tx_word_index <= tx_word_index + 1'b1;
            if (tx_word_index != 6'd0)
                prbs_state <= prbs_after_word;
        end
    end
end

endmodule
