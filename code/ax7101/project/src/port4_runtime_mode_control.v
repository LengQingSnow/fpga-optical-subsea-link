`timescale 1ns/1ps

module port4_runtime_mode_control (
    input  wire clk,
    input  wire rst_n,
    input  wire request_tx,
    input  wire arp_tx_en,
    input  wire prbs_tx_en,
    output reg  active_tx_mode,
    output reg  prbs_enable
);

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        active_tx_mode <= 1'b0;
        prbs_enable <= 1'b0;
    end else if (!active_tx_mode) begin
        prbs_enable <= 1'b0;
        if (request_tx && !arp_tx_en) begin
            active_tx_mode <= 1'b1;
            prbs_enable <= 1'b1;
        end
    end else begin
        if (!request_tx && !prbs_tx_en) begin
            active_tx_mode <= 1'b0;
            prbs_enable <= 1'b0;
        end else begin
            prbs_enable <= 1'b1;
        end
    end
end

endmodule
