`timescale 1ns / 1ps

// Crosses each GMII-domain UDP byte stream and its completed-packet descriptor
// into the 125 MHz aggregation domain.  Data and descriptor FIFOs remain
// separate so payload bytes have no per-byte metadata overhead.
module eth_aggregate_4port
(
    input              rst_n,
    input              agg_clk,

    input              in0_clk,
    input      [7:0]   in0_data,
    input              in0_valid,
    output             in0_ready,
    input      [23:0]  in0_desc_data,
    input              in0_desc_valid,
    input              in1_clk,
    input      [7:0]   in1_data,
    input              in1_valid,
    output             in1_ready,
    input      [23:0]  in1_desc_data,
    input              in1_desc_valid,
    input              in2_clk,
    input      [7:0]   in2_data,
    input              in2_valid,
    output             in2_ready,
    input      [23:0]  in2_desc_data,
    input              in2_desc_valid,
    input              in3_clk,
    input      [7:0]   in3_data,
    input              in3_valid,
    output             in3_ready,
    input      [23:0]  in3_desc_data,
    input              in3_desc_valid,

    output     [127:0] qpsk_bits,
    output             qpsk_valid,
    output             frame_start,
    output             frame_end,

    output reg [31:0]  accepted_packet_count0,
    output reg [31:0]  accepted_packet_count1,
    output reg [31:0]  accepted_packet_count2,
    output reg [31:0]  accepted_packet_count3,
    output reg [31:0]  accepted_byte_count0,
    output reg [31:0]  accepted_byte_count1,
    output reg [31:0]  accepted_byte_count2,
    output reg [31:0]  accepted_byte_count3,
    output     [3:0]   payload_overflow,
    output     [3:0]   descriptor_overflow
);

wire [7:0] fifo0_data;
wire [7:0] fifo1_data;
wire [7:0] fifo2_data;
wire [7:0] fifo3_data;
wire fifo0_valid;
wire fifo1_valid;
wire fifo2_valid;
wire fifo3_valid;
wire [3:0] fifo_pop;
wire [23:0] desc0_data;
wire [23:0] desc1_data;
wire [23:0] desc2_data;
wire [23:0] desc3_data;
wire desc0_valid;
wire desc1_valid;
wire desc2_valid;
wire desc3_valid;
wire [3:0] desc_pop;

async_byte_stream_bridge #(
    .FIFO_ADDR_WIDTH(15), .SUPPORT_BACKPRESSURE(1)
) fifo0 (
    .rst_n    (rst_n), .wr_clk(in0_clk), .wr_data(in0_data), .wr_valid(in0_valid),
    .wr_ready (in0_ready),
    .rd_clk   (agg_clk), .rd_data(fifo0_data), .rd_valid(fifo0_valid), .rd_pop(fifo_pop[0]),
    .overflow_sticky(payload_overflow[0])
);

async_byte_stream_bridge #(
    .FIFO_ADDR_WIDTH(15), .SUPPORT_BACKPRESSURE(1)
) fifo1 (
    .rst_n    (rst_n), .wr_clk(in1_clk), .wr_data(in1_data), .wr_valid(in1_valid),
    .wr_ready (in1_ready),
    .rd_clk   (agg_clk), .rd_data(fifo1_data), .rd_valid(fifo1_valid), .rd_pop(fifo_pop[1]),
    .overflow_sticky(payload_overflow[1])
);

async_byte_stream_bridge #(
    .FIFO_ADDR_WIDTH(15), .SUPPORT_BACKPRESSURE(1)
) fifo2 (
    .rst_n    (rst_n), .wr_clk(in2_clk), .wr_data(in2_data), .wr_valid(in2_valid),
    .wr_ready (in2_ready),
    .rd_clk   (agg_clk), .rd_data(fifo2_data), .rd_valid(fifo2_valid), .rd_pop(fifo_pop[2]),
    .overflow_sticky(payload_overflow[2])
);

async_byte_stream_bridge #(
    .FIFO_ADDR_WIDTH(15), .SUPPORT_BACKPRESSURE(1)
) fifo3 (
    .rst_n    (rst_n), .wr_clk(in3_clk), .wr_data(in3_data), .wr_valid(in3_valid),
    .wr_ready (in3_ready),
    .rd_clk   (agg_clk), .rd_data(fifo3_data), .rd_valid(fifo3_valid), .rd_pop(fifo_pop[3]),
    .overflow_sticky(payload_overflow[3])
);

async_byte_stream_bridge #(
    .DATA_WIDTH(24), .FIFO_ADDR_WIDTH(6), .BUFFER_ADDR_WIDTH(3)
) desc_fifo0 (
    .rst_n    (rst_n), .wr_clk(in0_clk), .wr_data(in0_desc_data), .wr_valid(in0_desc_valid),
    .rd_clk   (agg_clk), .rd_data(desc0_data), .rd_valid(desc0_valid), .rd_pop(desc_pop[0]),
    .overflow_sticky(descriptor_overflow[0])
);

async_byte_stream_bridge #(
    .DATA_WIDTH(24), .FIFO_ADDR_WIDTH(6), .BUFFER_ADDR_WIDTH(3)
) desc_fifo1 (
    .rst_n    (rst_n), .wr_clk(in1_clk), .wr_data(in1_desc_data), .wr_valid(in1_desc_valid),
    .rd_clk   (agg_clk), .rd_data(desc1_data), .rd_valid(desc1_valid), .rd_pop(desc_pop[1]),
    .overflow_sticky(descriptor_overflow[1])
);

async_byte_stream_bridge #(
    .DATA_WIDTH(24), .FIFO_ADDR_WIDTH(6), .BUFFER_ADDR_WIDTH(3)
) desc_fifo2 (
    .rst_n    (rst_n), .wr_clk(in2_clk), .wr_data(in2_desc_data), .wr_valid(in2_desc_valid),
    .rd_clk   (agg_clk), .rd_data(desc2_data), .rd_valid(desc2_valid), .rd_pop(desc_pop[2]),
    .overflow_sticky(descriptor_overflow[2])
);

async_byte_stream_bridge #(
    .DATA_WIDTH(24), .FIFO_ADDR_WIDTH(6), .BUFFER_ADDR_WIDTH(3)
) desc_fifo3 (
    .rst_n    (rst_n), .wr_clk(in3_clk), .wr_data(in3_desc_data), .wr_valid(in3_desc_valid),
    .rd_clk   (agg_clk), .rd_data(desc3_data), .rd_valid(desc3_valid), .rd_pop(desc_pop[3]),
    .overflow_sticky(descriptor_overflow[3])
);

qpsk_frame_aggregator frame_builder (
    .clk         (agg_clk),
    .rst_n       (rst_n),
    .in0_data    (fifo0_data),
    .in1_data    (fifo1_data),
    .in2_data    (fifo2_data),
    .in3_data    (fifo3_data),
    .in_valid    ({fifo3_valid, fifo2_valid, fifo1_valid, fifo0_valid}),
    .in_pop      (fifo_pop),
    .desc0_data  (desc0_data),
    .desc1_data  (desc1_data),
    .desc2_data  (desc2_data),
    .desc3_data  (desc3_data),
    .desc_valid  ({desc3_valid, desc2_valid, desc1_valid, desc0_valid}),
    .desc_pop    (desc_pop),
    .qpsk_bits   (qpsk_bits),
    .qpsk_valid  (qpsk_valid),
    .frame_start (frame_start),
    .frame_end   (frame_end)
);

always @(posedge agg_clk or negedge rst_n) begin
    if (!rst_n) begin
        accepted_packet_count0 <= 32'd0;
        accepted_packet_count1 <= 32'd0;
        accepted_packet_count2 <= 32'd0;
        accepted_packet_count3 <= 32'd0;
        accepted_byte_count0 <= 32'd0;
        accepted_byte_count1 <= 32'd0;
        accepted_byte_count2 <= 32'd0;
        accepted_byte_count3 <= 32'd0;
    end else begin
        if (desc_pop[0] && desc0_valid) begin
            accepted_packet_count0 <= accepted_packet_count0 + 1'b1;
            accepted_byte_count0 <= accepted_byte_count0 + desc0_data[15:0];
        end
        if (desc_pop[1] && desc1_valid) begin
            accepted_packet_count1 <= accepted_packet_count1 + 1'b1;
            accepted_byte_count1 <= accepted_byte_count1 + desc1_data[15:0];
        end
        if (desc_pop[2] && desc2_valid) begin
            accepted_packet_count2 <= accepted_packet_count2 + 1'b1;
            accepted_byte_count2 <= accepted_byte_count2 + desc2_data[15:0];
        end
        if (desc_pop[3] && desc3_valid) begin
            accepted_packet_count3 <= accepted_packet_count3 + 1'b1;
            accepted_byte_count3 <= accepted_byte_count3 + desc3_data[15:0];
        end
    end
end

endmodule

// A small destination-domain prefetch buffer makes the asynchronous FIFO look
// like a stable valid/pop stream to the scheduler.  DATA_WIDTH is 8 for
// payloads and 24 for completed-packet descriptors.
module async_byte_stream_bridge
#(
    parameter DATA_WIDTH = 8,
    parameter FIFO_ADDR_WIDTH = 11,
    parameter BUFFER_ADDR_WIDTH = 4,
    parameter SUPPORT_BACKPRESSURE = 0
)
(
    input                  rst_n,
    input                  wr_clk,
    input  [DATA_WIDTH-1:0] wr_data,
    input                  wr_valid,
    output                 wr_ready,
    input                  rd_clk,
    output [DATA_WIDTH-1:0] rd_data,
    output                 rd_valid,
    input                  rd_pop,
    output                 overflow_sticky
);

localparam BUFFER_DEPTH = (1 << BUFFER_ADDR_WIDTH);

wire [DATA_WIDTH-1:0] fifo_rd_data;
wire fifo_rd_valid;
wire fifo_rd_empty;
wire fifo_wr_full;
wire fifo_rd_en;
wire local_pop;
wire [BUFFER_ADDR_WIDTH:0] buffered_after_response;
reg [DATA_WIDTH-1:0] buffer_mem [0:BUFFER_DEPTH-1];
reg [BUFFER_ADDR_WIDTH-1:0] buffer_wr_ptr;
reg [BUFFER_ADDR_WIDTH-1:0] buffer_rd_ptr;
reg [BUFFER_ADDR_WIDTH:0] buffer_count;
reg wr_overflow_sticky;
(* ASYNC_REG = "TRUE" *) reg overflow_sync1;
(* ASYNC_REG = "TRUE" *) reg overflow_sync2;

assign rd_valid = (buffer_count != 0);
assign rd_data = rd_valid ? buffer_mem[buffer_rd_ptr] : {DATA_WIDTH{1'b0}};
assign local_pop = rd_pop && rd_valid;
assign buffered_after_response = buffer_count + (fifo_rd_valid ? 1'b1 : 1'b0) -
                                 (local_pop ? 1'b1 : 1'b0);
assign fifo_rd_en = !fifo_rd_empty && (buffered_after_response < BUFFER_DEPTH);
assign overflow_sticky = overflow_sync2;
assign wr_ready = !fifo_wr_full;

async_byte_fifo #(
    .ADDR_WIDTH(FIFO_ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH)
) fifo (
    .wr_clk   (wr_clk), .wr_rst_n(rst_n), .wr_en(wr_valid && wr_ready), .wr_data(wr_data), .wr_full(fifo_wr_full),
    .rd_clk   (rd_clk), .rd_rst_n(rst_n), .rd_en(fifo_rd_en), .rd_data(fifo_rd_data),
    .rd_valid (fifo_rd_valid), .rd_empty(fifo_rd_empty)
);

always @(posedge rd_clk or negedge rst_n) begin
    if (!rst_n) begin
        buffer_wr_ptr <= {BUFFER_ADDR_WIDTH{1'b0}};
        buffer_rd_ptr <= {BUFFER_ADDR_WIDTH{1'b0}};
        buffer_count <= {(BUFFER_ADDR_WIDTH+1){1'b0}};
    end else begin
        case ({fifo_rd_valid, local_pop})
            2'b10: begin
                buffer_mem[buffer_wr_ptr] <= fifo_rd_data;
                buffer_wr_ptr <= buffer_wr_ptr + 1'b1;
                buffer_count <= buffer_count + 1'b1;
            end
            2'b01: begin
                buffer_rd_ptr <= buffer_rd_ptr + 1'b1;
                buffer_count <= buffer_count - 1'b1;
            end
            2'b11: begin
                buffer_mem[buffer_wr_ptr] <= fifo_rd_data;
                buffer_wr_ptr <= buffer_wr_ptr + 1'b1;
                buffer_rd_ptr <= buffer_rd_ptr + 1'b1;
            end
            default: buffer_count <= buffer_count;
        endcase
    end
end

always @(posedge wr_clk or negedge rst_n) begin
    if (!rst_n)
        wr_overflow_sticky <= 1'b0;
    else if (!SUPPORT_BACKPRESSURE && wr_valid && !wr_ready)
        wr_overflow_sticky <= 1'b1;
end

always @(posedge rd_clk or negedge rst_n) begin
    if (!rst_n) begin
        overflow_sync1 <= 1'b0;
        overflow_sync2 <= 1'b0;
    end else begin
        overflow_sync1 <= wr_overflow_sticky;
        overflow_sync2 <= overflow_sync1;
    end
end

endmodule
