`timescale 1ns/1ps

module gmii_tx_output_register (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       input_tx_en,
    input  wire       input_tx_er,
    input  wire [7:0] input_txd,
    output wire       output_tx_en,
    output wire       output_tx_er,
    output wire [7:0] output_txd
);

(* IOB = "TRUE" *) reg tx_en_iob;
(* IOB = "TRUE" *) reg tx_er_iob;
(* IOB = "TRUE" *) reg [7:0] txd_iob;

assign output_tx_en = tx_en_iob;
assign output_tx_er = tx_er_iob;
assign output_txd = txd_iob;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        tx_en_iob <= 1'b0;
        tx_er_iob <= 1'b0;
        txd_iob <= 8'd0;
    end else begin
        tx_en_iob <= input_tx_en;
        tx_er_iob <= input_tx_er;
        txd_iob <= input_txd;
    end
end

endmodule
