`timescale 1ns / 1ps

module async_reset_sync (
    input  clk,
    input  async_reset_n,
    output sync_reset_n
);

(* ASYNC_REG = "TRUE", SHREG_EXTRACT = "NO" *) reg [1:0] sync_ff = 2'b00;

always @(posedge clk or negedge async_reset_n) begin
    if (!async_reset_n)
        sync_ff <= 2'b00;
    else
        sync_ff <= {sync_ff[0], 1'b1};
end

assign sync_reset_n = sync_ff[1];

endmodule
