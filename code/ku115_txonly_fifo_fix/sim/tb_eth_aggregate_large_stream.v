`timescale 1ns / 1ps

module tb_eth_aggregate_large_stream;

localparam integer BYTES_PER_PORT = 2*1024*1024;
localparam integer UDP_PAYLOAD_MAX = 1400;
// Preamble/SFD (8), Ethernet header (14), IP/UDP headers (28), FCS (4)
// and the inter-frame gap (12) occupy 66 GMII byte times per packet.
localparam integer PACKET_WIRE_OVERHEAD = 66;
localparam integer EXPECTED_PACKETS = (BYTES_PER_PORT + UDP_PAYLOAD_MAX - 1) / UDP_PAYLOAD_MAX;
localparam [63:0] SYNC_WORD = 64'hD5C0_1ACF_FC1D_5AA5;

reg rst_n;
reg agg_clk;
reg in0_clk;
reg in1_clk;
reg in2_clk;
reg in3_clk;

wire [7:0] in0_data;
wire [7:0] in1_data;
wire [7:0] in2_data;
wire [7:0] in3_data;
wire in0_valid;
wire in1_valid;
wire in2_valid;
wire in3_valid;
wire [23:0] in0_desc_data;
wire [23:0] in1_desc_data;
wire [23:0] in2_desc_data;
wire [23:0] in3_desc_data;
wire in0_desc_valid;
wire in1_desc_valid;
wire in2_desc_valid;
wire in3_desc_valid;
wire source0_done;
wire source1_done;
wire source2_done;
wire source3_done;

wire [127:0] qpsk_bits;
wire qpsk_valid;
wire frame_start;
wire frame_end;
wire [31:0] accepted_packet_count0;
wire [31:0] accepted_packet_count1;
wire [31:0] accepted_packet_count2;
wire [31:0] accepted_packet_count3;
wire [31:0] accepted_byte_count0;
wire [31:0] accepted_byte_count1;
wire [31:0] accepted_byte_count2;
wire [31:0] accepted_byte_count3;
wire [3:0] payload_overflow;
wire [3:0] descriptor_overflow;

reg [7:0] frame_mem [0:511];
integer frame_byte_index;
integer expected_frame_sequence;
integer frame_count;
integer data_frame_count;
integer reconstructed_bytes [0:3];
integer reconstructed_packets [0:3];
integer current_packet_bytes [0:3];
integer current_packet_length [0:3];
integer expected_packet_id [0:3];
reg [3:0] packet_active;
integer errors;
integer byte_lane;
integer guard_frame_count;
integer port_index;

large_stream_source #(
    .PORT_ID(0), .TOTAL_BYTES(BYTES_PER_PORT), .MAX_PAYLOAD(UDP_PAYLOAD_MAX),
    .PACKET_WIRE_OVERHEAD(PACKET_WIRE_OVERHEAD)
) source0 (
    .clk(in0_clk), .rst_n(rst_n), .data(in0_data), .data_valid(in0_valid),
    .desc_data(in0_desc_data), .desc_valid(in0_desc_valid), .done(source0_done)
);

large_stream_source #(
    .PORT_ID(1), .TOTAL_BYTES(BYTES_PER_PORT), .MAX_PAYLOAD(UDP_PAYLOAD_MAX),
    .PACKET_WIRE_OVERHEAD(PACKET_WIRE_OVERHEAD)
) source1 (
    .clk(in1_clk), .rst_n(rst_n), .data(in1_data), .data_valid(in1_valid),
    .desc_data(in1_desc_data), .desc_valid(in1_desc_valid), .done(source1_done)
);

large_stream_source #(
    .PORT_ID(2), .TOTAL_BYTES(BYTES_PER_PORT), .MAX_PAYLOAD(UDP_PAYLOAD_MAX),
    .PACKET_WIRE_OVERHEAD(PACKET_WIRE_OVERHEAD)
) source2 (
    .clk(in2_clk), .rst_n(rst_n), .data(in2_data), .data_valid(in2_valid),
    .desc_data(in2_desc_data), .desc_valid(in2_desc_valid), .done(source2_done)
);

large_stream_source #(
    .PORT_ID(3), .TOTAL_BYTES(BYTES_PER_PORT), .MAX_PAYLOAD(UDP_PAYLOAD_MAX),
    .PACKET_WIRE_OVERHEAD(PACKET_WIRE_OVERHEAD)
) source3 (
    .clk(in3_clk), .rst_n(rst_n), .data(in3_data), .data_valid(in3_valid),
    .desc_data(in3_desc_data), .desc_valid(in3_desc_valid), .done(source3_done)
);

eth_aggregate_4port dut (
    .rst_n(rst_n), .agg_clk(agg_clk),
    .in0_clk(in0_clk), .in0_data(in0_data), .in0_valid(in0_valid),
    .in0_desc_data(in0_desc_data), .in0_desc_valid(in0_desc_valid),
    .in1_clk(in1_clk), .in1_data(in1_data), .in1_valid(in1_valid),
    .in1_desc_data(in1_desc_data), .in1_desc_valid(in1_desc_valid),
    .in2_clk(in2_clk), .in2_data(in2_data), .in2_valid(in2_valid),
    .in2_desc_data(in2_desc_data), .in2_desc_valid(in2_desc_valid),
    .in3_clk(in3_clk), .in3_data(in3_data), .in3_valid(in3_valid),
    .in3_desc_data(in3_desc_data), .in3_desc_valid(in3_desc_valid),
    .qpsk_bits(qpsk_bits), .qpsk_valid(qpsk_valid),
    .frame_start(frame_start), .frame_end(frame_end),
    .accepted_packet_count0(accepted_packet_count0),
    .accepted_packet_count1(accepted_packet_count1),
    .accepted_packet_count2(accepted_packet_count2),
    .accepted_packet_count3(accepted_packet_count3),
    .accepted_byte_count0(accepted_byte_count0),
    .accepted_byte_count1(accepted_byte_count1),
    .accepted_byte_count2(accepted_byte_count2),
    .accepted_byte_count3(accepted_byte_count3),
    .payload_overflow(payload_overflow),
    .descriptor_overflow(descriptor_overflow)
);

initial begin
    agg_clk = 1'b0;
    forever #4.0 agg_clk = ~agg_clk;
end

initial begin
    in0_clk = 1'b0;
    forever #4.0 in0_clk = ~in0_clk;
end

initial begin
    in1_clk = 1'b0;
    #0.7;
    forever #4.001 in1_clk = ~in1_clk;
end

initial begin
    in2_clk = 1'b0;
    #1.3;
    forever #3.999 in2_clk = ~in2_clk;
end

initial begin
    in3_clk = 1'b0;
    #2.1;
    forever #4.002 in3_clk = ~in3_clk;
end

function [7:0] expected_payload_byte;
    input integer source_port;
    input integer absolute_index;
    begin
        expected_payload_byte = absolute_index[7:0] ^ absolute_index[15:8] ^
                                (8'h3d * source_port) ^ 8'ha7;
    end
endfunction

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

task report_error;
    input [8*120-1:0] message;
    begin
        if (errors < 20)
            $display("ERROR: %0s", message);
        errors = errors + 1;
    end
endtask

task check_completed_frame;
    reg [63:0] observed_sync;
    reg [31:0] observed_sequence;
    reg [31:0] crc;
    reg [31:0] observed_crc;
    reg [30:0] prbs_state;
    reg [3:0] frame_port_seen;
    reg [7:0] tag;
    reg [7:0] packet_id;
    integer segment_length;
    integer segment_end;
    integer offset;
    integer fragment_length;
    integer payload_index;
    integer source_port;
    integer sop;
    integer eop;
    integer expected_length;
    integer check_index;
    begin
        observed_sync = {frame_mem[0], frame_mem[1], frame_mem[2], frame_mem[3],
                         frame_mem[4], frame_mem[5], frame_mem[6], frame_mem[7]};
        observed_sequence = {frame_mem[12], frame_mem[13], frame_mem[14], frame_mem[15]};
        if (observed_sync !== SYNC_WORD)
            report_error("sync word mismatch");
        if (frame_mem[8] !== 8'h01)
            report_error("protocol version mismatch");
        if (observed_sequence !== expected_frame_sequence[31:0])
            report_error("frame sequence mismatch");
        expected_frame_sequence = expected_frame_sequence + 1;

        crc = 32'hffff_ffff;
        for (check_index = 0; check_index < 508; check_index = check_index + 1)
            crc = crc32_byte(crc, frame_mem[check_index]);
        observed_crc = {frame_mem[508], frame_mem[509], frame_mem[510], frame_mem[511]};
        if (observed_crc !== ~crc)
            report_error("frame CRC mismatch");

        segment_length = {frame_mem[10][0], frame_mem[11]};
        if (frame_mem[9] == 8'h06) begin
            if (segment_length != 0)
                report_error("idle frame has nonzero segment length");
        end else if (frame_mem[9] == 8'h07) begin
            if (segment_length <= 0 || segment_length > 492)
                report_error("data frame segment length out of range");
            data_frame_count = data_frame_count + 1;
        end else begin
            report_error("unknown frame type");
        end

        segment_end = 16 + segment_length;
        frame_port_seen = 4'b0000;
        offset = 16;
        while (offset < segment_end) begin
            if (offset + 4 > segment_end) begin
                report_error("truncated segment header");
                offset = segment_end;
            end else begin
                tag = frame_mem[offset];
                packet_id = frame_mem[offset+1];
                fragment_length = {frame_mem[offset+2][0], frame_mem[offset+3]};
                source_port = tag[1:0];
                sop = tag[2];
                eop = tag[3];
                if (tag[7:4] != 4'b0000)
                    report_error("reserved tag bits are nonzero");
                if (frame_port_seen[source_port])
                    report_error("port appears twice in one frame");
                frame_port_seen[source_port] = 1'b1;
                if (fragment_length <= 0 || offset + 4 + fragment_length > segment_end) begin
                    report_error("fragment length exceeds segment region");
                    offset = segment_end;
                end else begin
                    if (sop) begin
                        if (packet_active[source_port])
                            report_error("SOP arrived while packet is active");
                        if (packet_id !== expected_packet_id[source_port][7:0])
                            report_error("packet ID mismatch at SOP");
                        packet_active[source_port] = 1'b1;
                        current_packet_bytes[source_port] = 0;
                        expected_length = BYTES_PER_PORT - reconstructed_bytes[source_port];
                        if (expected_length > UDP_PAYLOAD_MAX)
                            expected_length = UDP_PAYLOAD_MAX;
                        current_packet_length[source_port] = expected_length;
                    end else begin
                        if (!packet_active[source_port])
                            report_error("continuation arrived without SOP");
                        if (packet_id !== expected_packet_id[source_port][7:0])
                            report_error("packet ID mismatch in continuation");
                    end

                    for (payload_index = 0; payload_index < fragment_length; payload_index = payload_index + 1) begin
                        if (reconstructed_bytes[source_port] >= BYTES_PER_PORT) begin
                            report_error("received more bytes than generated");
                        end else if (frame_mem[offset+4+payload_index] !==
                                     expected_payload_byte(source_port, reconstructed_bytes[source_port])) begin
                            if (errors < 20)
                                $display("ERROR: payload port=%0d index=%0d expected=%02x got=%02x",
                                         source_port, reconstructed_bytes[source_port],
                                         expected_payload_byte(source_port, reconstructed_bytes[source_port]),
                                         frame_mem[offset+4+payload_index]);
                            errors = errors + 1;
                        end
                        reconstructed_bytes[source_port] = reconstructed_bytes[source_port] + 1;
                        current_packet_bytes[source_port] = current_packet_bytes[source_port] + 1;
                    end

                    if (eop) begin
                        if (!packet_active[source_port])
                            report_error("EOP arrived without active packet");
                        if (current_packet_bytes[source_port] != current_packet_length[source_port])
                            report_error("packet payload length mismatch at EOP");
                        packet_active[source_port] = 1'b0;
                        reconstructed_packets[source_port] = reconstructed_packets[source_port] + 1;
                        expected_packet_id[source_port] = (expected_packet_id[source_port] + 1) & 255;
                    end
                    offset = offset + 4 + fragment_length;
                end
            end
        end
        if (offset != segment_end)
            report_error("segment records do not match segment length");

        prbs_state = (31'h7fff_ffff ^ observed_sequence[30:0]) | 31'h0000_0001;
        for (check_index = 16; check_index < 508; check_index = check_index + 1) begin
            if (check_index >= segment_end && frame_mem[check_index] !== prbs31_byte(prbs_state))
                report_error("PRBS31 fill mismatch");
            prbs_state = prbs31_advance8(prbs_state);
        end
        frame_count = frame_count + 1;
    end
endtask

always @(posedge agg_clk) begin
    if (!rst_n) begin
        frame_byte_index = 0;
    end else if (qpsk_valid) begin
        if (frame_start && frame_byte_index != 0)
            report_error("frame_start is not aligned to byte zero");
        for (byte_lane = 0; byte_lane < 16; byte_lane = byte_lane + 1)
            frame_mem[frame_byte_index+byte_lane] = qpsk_bits[127-byte_lane*8 -: 8];
        if (frame_end) begin
            if (frame_byte_index != 496)
                report_error("frame_end is not aligned to byte 511");
            check_completed_frame;
            frame_byte_index = 0;
        end else begin
            frame_byte_index = frame_byte_index + 16;
        end
    end
end

initial begin
    rst_n = 1'b0;
    frame_byte_index = 0;
    expected_frame_sequence = 0;
    frame_count = 0;
    data_frame_count = 0;
    errors = 0;
    packet_active = 4'b0000;
    guard_frame_count = 0;
    for (port_index = 0; port_index < 4; port_index = port_index + 1) begin
        reconstructed_bytes[port_index] = 0;
        reconstructed_packets[port_index] = 0;
        current_packet_bytes[port_index] = 0;
        current_packet_length[port_index] = 0;
        expected_packet_id[port_index] = 0;
    end

    #102;
    rst_n = 1'b1;

    wait (reconstructed_bytes[0] == BYTES_PER_PORT &&
          reconstructed_bytes[1] == BYTES_PER_PORT &&
          reconstructed_bytes[2] == BYTES_PER_PORT &&
          reconstructed_bytes[3] == BYTES_PER_PORT);
    wait (source0_done && source1_done && source2_done && source3_done);

    while (guard_frame_count < 8) begin
        @(posedge agg_clk);
        if (frame_end)
            guard_frame_count = guard_frame_count + 1;
    end

    if (packet_active != 4'b0000)
        report_error("packet remains active after stream completion");
    if (payload_overflow != 4'b0000)
        report_error("payload FIFO overflowed");
    if (descriptor_overflow != 4'b0000)
        report_error("descriptor FIFO overflowed");
    if (accepted_packet_count0 != EXPECTED_PACKETS || accepted_packet_count1 != EXPECTED_PACKETS ||
        accepted_packet_count2 != EXPECTED_PACKETS || accepted_packet_count3 != EXPECTED_PACKETS)
        report_error("accepted packet counter mismatch");
    if (accepted_byte_count0 != BYTES_PER_PORT || accepted_byte_count1 != BYTES_PER_PORT ||
        accepted_byte_count2 != BYTES_PER_PORT || accepted_byte_count3 != BYTES_PER_PORT)
        report_error("accepted byte counter mismatch");
    for (port_index = 0; port_index < 4; port_index = port_index + 1)
        if (reconstructed_packets[port_index] != EXPECTED_PACKETS)
            report_error("reconstructed packet counter mismatch");

    if (errors == 0) begin
        $display("PASS: large stream reconstructed %0d bytes across four ports (%0d per port, %0d packets per port)",
                 4*BYTES_PER_PORT, BYTES_PER_PORT, EXPECTED_PACKETS);
    end else begin
        $display("FAIL: large stream simulation found %0d errors", errors);
        $fatal(1, "large stream aggregation failed");
    end
    $finish;
end

initial begin
    #100000000;
    $fatal(1, "large stream simulation timeout");
end

endmodule

module large_stream_source #(
    parameter integer PORT_ID = 0,
    parameter integer TOTAL_BYTES = 2097152,
    parameter integer MAX_PAYLOAD = 1400,
    parameter integer PACKET_WIRE_OVERHEAD = 66
) (
    input clk,
    input rst_n,
    output [7:0] data,
    output data_valid,
    output [23:0] desc_data,
    output desc_valid,
    output done
);

localparam [1:0] STATE_DATA = 2'd0;
localparam [1:0] STATE_DESC = 2'd1;
localparam [1:0] STATE_GAP  = 2'd2;
localparam [1:0] STATE_DONE = 2'd3;

reg [1:0] state;
reg [31:0] total_byte_index;
reg [15:0] packet_byte_index;
reg [15:0] packet_length;
reg [7:0] packet_id;
reg [7:0] gap_cycles_remaining;

function [7:0] payload_byte;
    input integer source_port;
    input [31:0] absolute_index;
    begin
        payload_byte = absolute_index[7:0] ^ absolute_index[15:8] ^
                       (8'h3d * source_port) ^ 8'ha7;
    end
endfunction

assign data = payload_byte(PORT_ID, total_byte_index);
assign data_valid = rst_n && (state == STATE_DATA);
assign desc_data = {packet_id, packet_length};
assign desc_valid = rst_n && (state == STATE_DESC);
assign done = (state == STATE_DONE);

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= STATE_DATA;
        total_byte_index <= 32'd0;
        packet_byte_index <= 16'd0;
        packet_id <= 8'd0;
        gap_cycles_remaining <= 8'd0;
        if (TOTAL_BYTES < MAX_PAYLOAD)
            packet_length <= TOTAL_BYTES;
        else
            packet_length <= MAX_PAYLOAD;
    end else begin
        case (state)
            STATE_DATA: begin
                total_byte_index <= total_byte_index + 1'b1;
                if (packet_byte_index + 1'b1 >= packet_length) begin
                    packet_byte_index <= 16'd0;
                    state <= STATE_DESC;
                end else begin
                    packet_byte_index <= packet_byte_index + 1'b1;
                end
            end
            STATE_DESC: begin
                packet_id <= packet_id + 1'b1;
                if (total_byte_index >= TOTAL_BYTES) begin
                    state <= STATE_DONE;
                end else begin
                    if ((TOTAL_BYTES - total_byte_index) < MAX_PAYLOAD)
                        packet_length <= TOTAL_BYTES - total_byte_index;
                    else
                        packet_length <= MAX_PAYLOAD;
                    if (PACKET_WIRE_OVERHEAD > 1) begin
                        gap_cycles_remaining <= PACKET_WIRE_OVERHEAD - 1;
                        state <= STATE_GAP;
                    end else begin
                        state <= STATE_DATA;
                    end
                end
            end
            STATE_GAP: begin
                if (gap_cycles_remaining <= 1) begin
                    gap_cycles_remaining <= 8'd0;
                    state <= STATE_DATA;
                end else begin
                    gap_cycles_remaining <= gap_cycles_remaining - 1'b1;
                end
            end
            default: state <= STATE_DONE;
        endcase
    end
end

endmodule
