`timescale 1ns/1ps

module async_reset_sync #(
    parameter integer STAGES = 3
) (
    input  wire clk,
    input  wire async_reset_n,
    output wire sync_reset_n
);

(* ASYNC_REG = "TRUE" *) reg [STAGES-1:0] sync_pipe;

always @(posedge clk or negedge async_reset_n) begin
    if (!async_reset_n)
        sync_pipe <= {STAGES{1'b0}};
    else
        sync_pipe <= {sync_pipe[STAGES-2:0], 1'b1};
end

assign sync_reset_n = sync_pipe[STAGES-1];

endmodule

