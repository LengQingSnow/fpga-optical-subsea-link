`timescale 1ns / 1ps

module qsfp_payload_fifo_xpm #(
    parameter ADDR_WIDTH = 10,
    parameter DATA_WIDTH = 257
) (
    input                       wr_clk,
    input                       wr_rst_n,
    input                       wr_en,
    input      [DATA_WIDTH-1:0] wr_data,
    output                      wr_full,
    output                      wr_ready,

    input                       rd_clk,
    input                       rd_rst_n,
    input                       rd_en,
    output     [DATA_WIDTH-1:0] rd_data,
    output                      rd_valid,
    output                      rd_empty
);

localparam FIFO_DEPTH = (ADDR_WIDTH < 4) ? 16 : (1 << ADDR_WIDTH);

wire fifo_reset;
wire fifo_full_raw;
wire fifo_empty_raw;
wire fifo_valid_raw;
wire wr_rst_busy;
wire rd_rst_busy;

assign fifo_reset = !wr_rst_n;
assign wr_full = fifo_full_raw;
assign wr_ready = !fifo_reset && !wr_rst_busy && wr_rst_n;
assign rd_empty = fifo_empty_raw || rd_rst_busy || !rd_rst_n;
assign rd_valid = fifo_valid_raw && !rd_rst_busy && rd_rst_n;

xpm_fifo_async #(
    .CDC_SYNC_STAGES(2),
    .DOUT_RESET_VALUE("0"),
    .ECC_MODE("no_ecc"),
    .FIFO_MEMORY_TYPE("block"),
    .FIFO_READ_LATENCY(1),
    .FIFO_WRITE_DEPTH(FIFO_DEPTH),
    .FULL_RESET_VALUE(0),
    .PROG_EMPTY_THRESH(10),
    .PROG_FULL_THRESH(10),
    .RD_DATA_COUNT_WIDTH(ADDR_WIDTH + 1),
    .READ_DATA_WIDTH(DATA_WIDTH),
    .READ_MODE("std"),
    .RELATED_CLOCKS(0),
    .SIM_ASSERT_CHK(0),
    .USE_ADV_FEATURES("1000"),
    .WAKEUP_TIME(0),
    .WRITE_DATA_WIDTH(DATA_WIDTH),
    .WR_DATA_COUNT_WIDTH(ADDR_WIDTH + 1)
) payload_fifo_xpm (
    .almost_empty(),
    .almost_full(),
    .data_valid(fifo_valid_raw),
    .dbiterr(),
    .din(wr_data),
    .dout(rd_data),
    .empty(fifo_empty_raw),
    .full(fifo_full_raw),
    .injectdbiterr(1'b0),
    .injectsbiterr(1'b0),
    .overflow(),
    .prog_empty(),
    .prog_full(),
    .rd_clk(rd_clk),
    .rd_data_count(),
    .rd_en(rd_en),
    .rd_rst_busy(rd_rst_busy),
    .rst(fifo_reset),
    .sbiterr(),
    .sleep(1'b0),
    .underflow(),
    .wr_ack(),
    .wr_clk(wr_clk),
    .wr_data_count(),
    .wr_en(wr_en),
    .wr_rst_busy(wr_rst_busy)
);

endmodule
