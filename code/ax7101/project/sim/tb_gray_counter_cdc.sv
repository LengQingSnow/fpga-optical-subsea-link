`timescale 1ns/1ps

module tb_gray_counter_cdc;

reg src_clk = 1'b0;
reg dst_clk = 1'b0;
reg src_rst_n = 1'b0;
reg dst_rst_n = 1'b0;
reg [7:0] src_binary = 8'd0;
wire [7:0] dst_binary;
integer test_value;

always #4 src_clk = ~src_clk;
always #2.5 dst_clk = ~dst_clk;

gray_counter_cdc #(.WIDTH(8)) dut (
    .src_clk(src_clk),
    .src_rst_n(src_rst_n),
    .src_binary(src_binary),
    .dst_clk(dst_clk),
    .dst_rst_n(dst_rst_n),
    .dst_binary(dst_binary)
);

task automatic set_and_check(input [7:0] value);
begin
    @(negedge src_clk);
    src_binary = value;
    repeat (8) @(posedge dst_clk);
    if (dst_binary !== value) begin
        $fatal(1, "CDC mismatch: source=%0d destination=%0d",
               value, dst_binary);
    end
end
endtask

initial begin
    repeat (4) @(posedge src_clk);
    src_rst_n = 1'b1;
    dst_rst_n = 1'b1;

    set_and_check(8'h01);
    set_and_check(8'h02);
    set_and_check(8'h03);
    set_and_check(8'h0f);
    set_and_check(8'h10);
    set_and_check(8'h1f);
    set_and_check(8'h20);
    set_and_check(8'h7f);
    set_and_check(8'h80);
    set_and_check(8'hff);

    src_rst_n = 1'b0;
    repeat (2) @(posedge src_clk);
    src_rst_n = 1'b1;
    set_and_check(8'h00);

    $display("PASS tb_gray_counter_cdc");
    $finish;
end

endmodule
