`timescale 1ns/1ps

module gray_counter_cdc #(
    parameter integer WIDTH = 32
) (
    input  wire             src_clk,
    input  wire             src_rst_n,
    input  wire [WIDTH-1:0] src_binary,
    input  wire             dst_clk,
    input  wire             dst_rst_n,
    output reg  [WIDTH-1:0] dst_binary
);

reg [WIDTH-1:0] src_gray;
(* ASYNC_REG = "TRUE" *) reg [WIDTH-1:0] gray_meta;
(* ASYNC_REG = "TRUE" *) reg [WIDTH-1:0] gray_sync;
integer shift;
reg [WIDTH-1:0] decoded_gray;

always @(posedge src_clk or negedge src_rst_n) begin
    if (!src_rst_n)
        src_gray <= {WIDTH{1'b0}};
    else
        src_gray <= src_binary ^ (src_binary >> 1);
end

always @(posedge dst_clk or negedge dst_rst_n) begin
    if (!dst_rst_n) begin
        gray_meta <= {WIDTH{1'b0}};
        gray_sync <= {WIDTH{1'b0}};
        dst_binary <= {WIDTH{1'b0}};
    end else begin
        gray_meta <= src_gray;
        gray_sync <= gray_meta;
        dst_binary <= decoded_gray;
    end
end

always @(*) begin
    decoded_gray = gray_sync;
    for (shift = 1; shift < WIDTH; shift = shift << 1)
        decoded_gray = decoded_gray ^ (decoded_gray >> shift);
end

endmodule
