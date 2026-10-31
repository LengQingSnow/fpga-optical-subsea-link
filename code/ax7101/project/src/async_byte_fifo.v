`timescale 1ns/1ps

module async_byte_fifo #(
    parameter integer WRITE_WIDTH = 128,
    parameter integer DEPTH_BYTES = 16384,
    parameter integer ALMOST_FULL_FREE_BYTES = 2048
) (
    input  wire                   wr_clk,
    input  wire                   wr_rst_n,
    input  wire [WRITE_WIDTH-1:0] wr_data,
    input  wire                   wr_en,
    output wire                   wr_almost_full,
    output reg  [31:0]            overflow_count,

    input  wire                   rd_clk,
    input  wire                   rd_rst_n,
    output wire [7:0]             rd_data,
    input  wire                   rd_en,
    output wire                   rd_empty,
    output wire                   rd_valid,
    output reg  [31:0]            underflow_count
);

localparam integer WRITE_BYTES = WRITE_WIDTH / 8;
localparam integer WRITE_DEPTH = DEPTH_BYTES / WRITE_BYTES;
localparam integer FREE_WORDS =
    (ALMOST_FULL_FREE_BYTES + WRITE_BYTES - 1) / WRITE_BYTES;
localparam integer PROG_FULL_LEVEL = WRITE_DEPTH - FREE_WORDS;
localparam integer WR_COUNT_WIDTH = $clog2(WRITE_DEPTH + 1);
localparam integer RD_COUNT_WIDTH = $clog2(DEPTH_BYTES + 1);

wire fifo_full;
wire fifo_prog_full;
wire fifo_overflow;
wire fifo_underflow;
wire wr_rst_busy;
wire rd_rst_busy;
wire [WR_COUNT_WIDTH-1:0] unused_wr_count;
wire [RD_COUNT_WIDTH-1:0] unused_rd_count;
wire unused_prog_empty;
wire unused_almost_full;
wire unused_almost_empty;
wire unused_wr_ack;
wire unused_data_valid;
wire unused_sbiterr;
wire unused_dbiterr;
wire fifo_reset;

// XPM FIFO reset is synchronous to the write clock.  The read side is
// released internally by XPM and advertises completion through rd_rst_busy.
assign fifo_reset = !wr_rst_n;
assign wr_almost_full = fifo_prog_full || fifo_full || wr_rst_busy;
assign rd_valid = rd_en && !rd_empty && !rd_rst_busy;

xpm_fifo_async #(
    .FIFO_MEMORY_TYPE("block"),
    .ECC_MODE("no_ecc"),
    .RELATED_CLOCKS(0),
    .SIM_ASSERT_CHK(0),
    .FIFO_WRITE_DEPTH(WRITE_DEPTH),
    .WRITE_DATA_WIDTH(WRITE_WIDTH),
    .WR_DATA_COUNT_WIDTH(WR_COUNT_WIDTH),
    .PROG_FULL_THRESH(PROG_FULL_LEVEL),
    .FULL_RESET_VALUE(0),
    .USE_ADV_FEATURES("0707"),
    .READ_MODE("fwft"),
    .FIFO_READ_LATENCY(0),
    .READ_DATA_WIDTH(8),
    .RD_DATA_COUNT_WIDTH(RD_COUNT_WIDTH),
    .PROG_EMPTY_THRESH(16),
    .DOUT_RESET_VALUE("0"),
    .CDC_SYNC_STAGES(2),
    .WAKEUP_TIME(0)
) u_fifo (
    .sleep(1'b0),
    .rst(fifo_reset),
    .wr_clk(wr_clk),
    .wr_en(wr_en && !wr_rst_busy),
    .din(wr_data),
    .full(fifo_full),
    .prog_full(fifo_prog_full),
    .wr_data_count(unused_wr_count),
    .overflow(fifo_overflow),
    .wr_rst_busy(wr_rst_busy),
    .almost_full(unused_almost_full),
    .wr_ack(unused_wr_ack),
    .rd_clk(rd_clk),
    .rd_en(rd_en && !rd_rst_busy),
    .dout(rd_data),
    .empty(rd_empty),
    .prog_empty(unused_prog_empty),
    .rd_data_count(unused_rd_count),
    .underflow(fifo_underflow),
    .rd_rst_busy(rd_rst_busy),
    .almost_empty(unused_almost_empty),
    .data_valid(unused_data_valid),
    .injectsbiterr(1'b0),
    .injectdbiterr(1'b0),
    .sbiterr(unused_sbiterr),
    .dbiterr(unused_dbiterr)
);

always @(posedge wr_clk or negedge wr_rst_n) begin
    if (!wr_rst_n)
        overflow_count <= 32'd0;
    else if (wr_en && (fifo_full || wr_rst_busy))
        overflow_count <= overflow_count + 1'b1;
end

always @(posedge rd_clk or negedge rd_rst_n) begin
    if (!rd_rst_n)
        underflow_count <= 32'd0;
    else if (rd_en && (rd_empty || rd_rst_busy))
        underflow_count <= underflow_count + 1'b1;
end

endmodule
