`timescale 1ns/1ps

module reset_level_cdc #(
    parameter integer RESET_STAGES = 3
) (
    input  wire dst_clk,
    input  wire async_reset_n,
    input  wire async_level,
    output wire dst_reset_n,
    output wire dst_level
);

(* ASYNC_REG = "TRUE" *) reg [RESET_STAGES-1:0] reset_pipe;
(* ASYNC_REG = "TRUE" *) reg level_meta;
(* ASYNC_REG = "TRUE" *) reg level_stage;

always @(posedge dst_clk or negedge async_reset_n) begin
    if (!async_reset_n)
        reset_pipe <= {RESET_STAGES{1'b0}};
    else
        reset_pipe <= {reset_pipe[RESET_STAGES-2:0], 1'b1};
end

assign dst_reset_n = reset_pipe[RESET_STAGES-1];

always @(posedge dst_clk or negedge dst_reset_n) begin
    if (!dst_reset_n) begin
        level_meta <= 1'b0;
        level_stage <= 1'b0;
    end else begin
        level_meta <= async_level;
        level_stage <= level_meta;
    end
end

assign dst_level = level_stage;

endmodule
