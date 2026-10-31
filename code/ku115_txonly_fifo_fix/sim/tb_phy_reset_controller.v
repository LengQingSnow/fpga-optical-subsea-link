`timescale 1ns / 1ps

module tb_phy_reset_controller;

localparam integer HOLD_CYCLES = 20;

reg clk = 1'b0;
reg reset_request = 1'b1;
reg clock_ready = 1'b0;
wire phy_reset_n;
integer cycle;

always #10 clk = ~clk;

phy_reset_controller #(
    .HOLD_CYCLES(HOLD_CYCLES),
    .COUNTER_WIDTH(5)
) dut (
    .clk(clk),
    .reset_request(reset_request),
    .clock_ready(clock_ready),
    .phy_reset_n(phy_reset_n)
);

task expect_reset;
    input expected;
    begin
        #1;
        if (phy_reset_n !== expected) begin
            $display("FAIL: expected phy_reset_n=%0b, got %0b at %0t", expected, phy_reset_n, $time);
            $finish;
        end
    end
endtask

initial begin
    repeat (2) @(posedge clk);
    expect_reset(1'b0);

    @(negedge clk);
    reset_request = 1'b0;
    repeat (3) begin
        @(posedge clk);
        expect_reset(1'b0);
    end

    @(negedge clk);
    clock_ready = 1'b1;
    for (cycle = 1; cycle < HOLD_CYCLES; cycle = cycle + 1) begin
        @(posedge clk);
        expect_reset(1'b0);
    end
    @(posedge clk);
    expect_reset(1'b1);

    #3 reset_request = 1'b1;
    expect_reset(1'b0);
    @(negedge clk);
    reset_request = 1'b0;

    repeat (5) @(posedge clk);
    expect_reset(1'b0);
    #3 clock_ready = 1'b0;
    expect_reset(1'b0);

    $display("PASS: phy reset hold and asynchronous assertion verified");
    $finish;
end

endmodule
