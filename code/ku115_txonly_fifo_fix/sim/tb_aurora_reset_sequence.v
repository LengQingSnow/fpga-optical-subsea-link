`timescale 1ns / 1ps

module tb_aurora_reset_sequence;

reg init_clk = 1'b0;
reg reset_request = 1'b1;
wire pma_init;
wire reset_pb;
wire ready;
integer errors = 0;
integer cycle;

always #10 init_clk = ~init_clk;

aurora_reset_sequence #(
    .PMA_HOLD_CYCLES(4),
    .CORE_HOLD_CYCLES(3),
    .COUNTER_WIDTH(4)
) dut (
    .init_clk(init_clk),
    .reset_request(reset_request),
    .pma_init(pma_init),
    .reset_pb(reset_pb),
    .ready(ready)
);

initial begin
    repeat (3) @(posedge init_clk);
    if (!pma_init || !reset_pb || ready) begin
        $display("ERROR: reset was not asserted initially");
        errors = errors + 1;
    end

    @(negedge init_clk);
    reset_request = 1'b0;
    for (cycle = 0; cycle < 4; cycle = cycle + 1) begin
        @(negedge init_clk);
        if (!pma_init || !reset_pb || ready) begin
            $display("ERROR: PMA phase cycle %0d outputs %b %b %b",
                     cycle, pma_init, reset_pb, ready);
            errors = errors + 1;
        end
    end
    for (cycle = 0; cycle < 3; cycle = cycle + 1) begin
        @(negedge init_clk);
        if (pma_init || !reset_pb || ready) begin
            $display("ERROR: core phase cycle %0d outputs %b %b %b",
                     cycle, pma_init, reset_pb, ready);
            errors = errors + 1;
        end
    end
    @(negedge init_clk);
    if (pma_init || reset_pb || !ready) begin
        $display("ERROR: reset sequence did not reach ready");
        errors = errors + 1;
    end

    reset_request = 1'b1;
    @(negedge init_clk);
    if (!pma_init || !reset_pb || ready) begin
        $display("ERROR: reset request did not restart sequence");
        errors = errors + 1;
    end

    if (errors == 0)
        $display("TEST PASSED: aurora_reset_sequence ordering");
    else
        $fatal(1, "aurora_reset_sequence found %0d errors", errors);
    $finish;
end

endmodule
