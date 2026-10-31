`timescale 1ns / 1ps

module tb_async_reset_sync;

reg clk = 1'b0;
reg async_reset_n = 1'b0;
wire sync_reset_n;

always #5 clk = ~clk;

async_reset_sync dut (
    .clk(clk),
    .async_reset_n(async_reset_n),
    .sync_reset_n(sync_reset_n)
);

initial begin
    #3;
    async_reset_n = 1'b1;

    @(posedge clk);
    #1;
    if (sync_reset_n !== 1'b0) begin
        $display("TEST FAILED: reset released after only one clock edge");
        $finish;
    end

    @(posedge clk);
    #1;
    if (sync_reset_n !== 1'b1) begin
        $display("TEST FAILED: reset did not release after two clock edges");
        $finish;
    end

    #2;
    async_reset_n = 1'b0;
    #1;
    if (sync_reset_n !== 1'b0) begin
        $display("TEST FAILED: asynchronous assertion was not immediate");
        $finish;
    end

    $display("TEST PASSED: async_reset_sync assertion and release ordering");
    $finish;
end

endmodule
