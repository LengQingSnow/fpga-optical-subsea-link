`timescale 1ns/1ps

module phy_reset_controller #(
    parameter integer RESET_CYCLES = 4_000_000
) (
    input  wire clk,
    input  wire external_reset_n,
    output reg  phy_reset_n
);

localparam integer COUNTER_WIDTH = $clog2(RESET_CYCLES + 1);
reg [COUNTER_WIDTH-1:0] reset_count;

always @(posedge clk or negedge external_reset_n) begin
    if (!external_reset_n) begin
        reset_count <= {COUNTER_WIDTH{1'b0}};
        phy_reset_n <= 1'b0;
    end else if (!phy_reset_n) begin
        if (reset_count == RESET_CYCLES - 1) begin
            phy_reset_n <= 1'b1;
        end else begin
            reset_count <= reset_count + 1'b1;
        end
    end
end

endmodule

