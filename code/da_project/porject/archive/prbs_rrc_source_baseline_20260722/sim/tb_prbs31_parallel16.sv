`timescale 1ns/1ps

module tb_prbs31_parallel16;
    logic clk = 1'b0;
    logic rst_n = 1'b0;
    logic enable = 1'b0;
    logic [15:0] bits;
    logic [30:0] state;

    localparam logic [15:0] EXPECTED [0:7] = '{
        16'hffff, 16'h7fff, 16'h0000, 16'h3800,
        16'h0000, 16'h1f80, 16'h0000, 16'h0e38
    };

    always #2 clk = ~clk;

    prbs31_parallel16 dut (
        .clk(clk),
        .rst_n(rst_n),
        .enable(enable),
        .bits(bits),
        .state(state)
    );

    initial begin
        repeat (4) @(posedge clk);
        rst_n <= 1'b1;
        @(posedge clk);
        enable <= 1'b1;

        for (int cycle = 0; cycle < 8; cycle++) begin
            @(posedge clk);
            #1;
            if (bits !== EXPECTED[cycle]) begin
                $error("cycle %0d: expected %04h, got %04h", cycle,
                       EXPECTED[cycle], bits);
                $fatal(1);
            end
        end

        enable <= 1'b0;
        @(posedge clk);
        #1;
        if (bits !== 16'h0000)
            $fatal(1, "disabled output must be zero");

        $display("PASS: PRBS31 parallel16 sequence and enable behavior");
        $finish;
    end
endmodule
