`timescale 1ns/1ps

module pl_sysref_capture (
    input  logic clk,
    input  logic rst_n,
    input  logic sysref_async,
    output logic sysref_sync
);
    (* ASYNC_REG = "TRUE" *) logic [1:0] sync_ff;

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            sync_ff <= 2'b00;
            sysref_sync <= 1'b0;
        end else begin
            sync_ff <= {sync_ff[0], sysref_async};
            sysref_sync <= sync_ff[1];
        end
    end
endmodule
