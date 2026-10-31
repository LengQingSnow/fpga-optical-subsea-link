`timescale 1ns/1ps

module tb_aurora_reset_sequence;
    logic init_clk = 1'b0;
    logic reset_request = 1'b1;
    logic pma_init;
    logic reset_pb;
    logic ready;

    always #5 init_clk = ~init_clk;

    aurora_reset_sequence #(
        .PMA_HOLD_CYCLES(4),
        .CORE_HOLD_CYCLES(3),
        .COUNTER_WIDTH(4)
    ) dut (.*);

    initial begin
        repeat (3) @(posedge init_clk);
        if (!pma_init || !reset_pb || ready)
            $fatal(1, "reset was not asserted initially");
        @(negedge init_clk);
        reset_request = 1'b0;
        repeat (4) begin
            @(negedge init_clk);
            if (!pma_init || !reset_pb || ready) $fatal(1, "bad PMA phase");
        end
        repeat (3) begin
            @(negedge init_clk);
            if (pma_init || !reset_pb || ready) $fatal(1, "bad core reset phase");
        end
        @(negedge init_clk);
        if (pma_init || reset_pb || !ready) $fatal(1, "sequence did not reach ready");
        $display("PASS: Aurora PMA/core reset ordering");
        $finish;
    end
endmodule

