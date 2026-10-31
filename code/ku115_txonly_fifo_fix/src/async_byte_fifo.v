`timescale 1ns / 1ps

module async_byte_fifo
#(
    parameter ADDR_WIDTH = 11,
    parameter DATA_WIDTH = 8
)
(
    input                  wr_clk,
    input                  wr_rst_n,
    input                  wr_en,
    input      [DATA_WIDTH-1:0] wr_data,
    output reg             wr_full,

    input                  rd_clk,
    input                  rd_rst_n,
    input                  rd_en,
    output reg [DATA_WIDTH-1:0] rd_data,
    output reg             rd_valid,
    output reg             rd_empty
);

localparam PTR_WIDTH = ADDR_WIDTH + 1;

reg [DATA_WIDTH-1:0] mem [0:(1<<ADDR_WIDTH)-1];
reg [PTR_WIDTH-1:0] wr_bin;
reg [PTR_WIDTH-1:0] wr_gray;
reg [PTR_WIDTH-1:0] rd_bin;
reg [PTR_WIDTH-1:0] rd_gray;
(* ASYNC_REG = "TRUE" *) reg [PTR_WIDTH-1:0] rd_gray_sync1;
(* ASYNC_REG = "TRUE" *) reg [PTR_WIDTH-1:0] rd_gray_sync2;
(* ASYNC_REG = "TRUE" *) reg [PTR_WIDTH-1:0] wr_gray_sync1;
(* ASYNC_REG = "TRUE" *) reg [PTR_WIDTH-1:0] wr_gray_sync2;

wire wr_take;
wire rd_take;
wire [PTR_WIDTH-1:0] wr_bin_next;
wire [PTR_WIDTH-1:0] wr_gray_next;
wire [PTR_WIDTH-1:0] rd_bin_next;
wire [PTR_WIDTH-1:0] rd_gray_next;
wire wr_full_next;
wire rd_empty_next;

assign wr_take = wr_en && !wr_full;
assign rd_take = rd_en && !rd_empty;
assign wr_bin_next = wr_bin + wr_take;
assign wr_gray_next = (wr_bin_next >> 1) ^ wr_bin_next;
assign rd_bin_next = rd_bin + rd_take;
assign rd_gray_next = (rd_bin_next >> 1) ^ rd_bin_next;
assign wr_full_next = (wr_gray_next == {~rd_gray_sync2[PTR_WIDTH-1:PTR_WIDTH-2], rd_gray_sync2[PTR_WIDTH-3:0]});
assign rd_empty_next = (rd_gray_next == wr_gray_sync2);

always @(posedge wr_clk or negedge wr_rst_n) begin
    if (!wr_rst_n) begin
        rd_gray_sync1 <= {PTR_WIDTH{1'b0}};
        rd_gray_sync2 <= {PTR_WIDTH{1'b0}};
    end else begin
        rd_gray_sync1 <= rd_gray;
        rd_gray_sync2 <= rd_gray_sync1;
    end
end

always @(posedge rd_clk or negedge rd_rst_n) begin
    if (!rd_rst_n) begin
        wr_gray_sync1 <= {PTR_WIDTH{1'b0}};
        wr_gray_sync2 <= {PTR_WIDTH{1'b0}};
    end else begin
        wr_gray_sync1 <= wr_gray;
        wr_gray_sync2 <= wr_gray_sync1;
    end
end

always @(posedge wr_clk) begin
    if (wr_take)
        mem[wr_bin[ADDR_WIDTH-1:0]] <= wr_data;
end

always @(posedge wr_clk or negedge wr_rst_n) begin
    if (!wr_rst_n) begin
        wr_bin <= {PTR_WIDTH{1'b0}};
        wr_gray <= {PTR_WIDTH{1'b0}};
        wr_full <= 1'b0;
    end else begin
        wr_bin <= wr_bin_next;
        wr_gray <= wr_gray_next;
        wr_full <= wr_full_next;
    end
end

always @(posedge rd_clk or negedge rd_rst_n) begin
    if (!rd_rst_n) begin
        rd_bin <= {PTR_WIDTH{1'b0}};
        rd_gray <= {PTR_WIDTH{1'b0}};
        rd_empty <= 1'b1;
        rd_data <= {DATA_WIDTH{1'b0}};
        rd_valid <= 1'b0;
    end else begin
        rd_bin <= rd_bin_next;
        rd_gray <= rd_gray_next;
        rd_empty <= rd_empty_next;
        rd_valid <= rd_take;
        if (rd_take)
            rd_data <= mem[rd_bin[ADDR_WIDTH-1:0]];
    end
end

endmodule
