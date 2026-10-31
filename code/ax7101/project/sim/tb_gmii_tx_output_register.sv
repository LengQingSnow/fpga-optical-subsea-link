`timescale 1ns/1ps

module tb_gmii_tx_output_register;

reg clk = 1'b0;
reg rst_n = 1'b0;
reg input_tx_en = 1'b0;
reg input_tx_er = 1'b0;
reg [7:0] input_txd = 8'd0;
wire output_tx_en;
wire output_tx_er;
wire [7:0] output_txd;

always #4 clk = ~clk;

gmii_tx_output_register dut (
    .clk(clk),
    .rst_n(rst_n),
    .input_tx_en(input_tx_en),
    .input_tx_er(input_tx_er),
    .input_txd(input_txd),
    .output_tx_en(output_tx_en),
    .output_tx_er(output_tx_er),
    .output_txd(output_txd)
);

initial begin
    repeat (2) @(posedge clk);
    #1;
    if ({output_tx_en, output_tx_er, output_txd} !== 10'd0)
        $fatal(1, "Outputs were not zero during reset");

    rst_n <= 1'b1;
    input_tx_en <= 1'b1;
    input_tx_er <= 1'b0;
    input_txd <= 8'ha5;
    @(posedge clk);
    #1;
    if ({output_tx_en, output_tx_er, output_txd} !== {1'b1, 1'b0, 8'ha5})
        $fatal(1, "First GMII word was not registered together");

    input_tx_en <= 1'b0;
    input_tx_er <= 1'b1;
    input_txd <= 8'h3c;
    @(posedge clk);
    #1;
    if ({output_tx_en, output_tx_er, output_txd} !== {1'b0, 1'b1, 8'h3c})
        $fatal(1, "Second GMII word was not registered together");

    rst_n <= 1'b0;
    #1;
    if ({output_tx_en, output_tx_er, output_txd} !== 10'd0)
        $fatal(1, "Asynchronous reset did not clear outputs");

    $display("PASS tb_gmii_tx_output_register");
    $finish;
end

endmodule
