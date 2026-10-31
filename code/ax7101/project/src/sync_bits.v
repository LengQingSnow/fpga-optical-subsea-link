`timescale 1ns/1ps

module sync_bits #(
    parameter integer WIDTH = 1
) (
    input  wire             clk,
    input  wire             rst_n,
    input  wire [WIDTH-1:0] async_data,
    output wire [WIDTH-1:0] sync_data
);

(* ASYNC_REG = "TRUE" *) reg [WIDTH-1:0] sync_meta;
(* ASYNC_REG = "TRUE" *) reg [WIDTH-1:0] sync_stage;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        sync_meta <= {WIDTH{1'b0}};
        sync_stage <= {WIDTH{1'b0}};
    end else begin
        sync_meta <= async_data;
        sync_stage <= sync_meta;
    end
end

assign sync_data = sync_stage;

endmodule

