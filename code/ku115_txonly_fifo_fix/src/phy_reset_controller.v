`timescale 1ns / 1ps

module phy_reset_controller #(
    parameter integer HOLD_CYCLES = 1_000_000,
    parameter integer COUNTER_WIDTH = 20
) (
    input  wire clk,
    input  wire reset_request,
    input  wire clock_ready,
    output reg  phy_reset_n
);

reg [COUNTER_WIDTH-1:0] hold_count;

always @(posedge clk or posedge reset_request or negedge clock_ready) begin
    if (reset_request || !clock_ready) begin
        hold_count <= {COUNTER_WIDTH{1'b0}};
        phy_reset_n <= 1'b0;
    end else if (!phy_reset_n) begin
        if (HOLD_CYCLES <= 1 || hold_count == HOLD_CYCLES - 1) begin
            phy_reset_n <= 1'b1;
        end else begin
            hold_count <= hold_count + 1'b1;
        end
    end
end

endmodule
