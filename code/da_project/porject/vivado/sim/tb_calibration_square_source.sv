`timescale 1ns/1ps

module tb_calibration_square_source;
    logic clk = 1'b0;
    logic rst_n = 1'b0;
    logic enable = 1'b0;
    logic ready = 1'b0;
    logic [63:0] data;
    logic valid;

    always #2 clk = ~clk;

    calibration_square_source dut (
        .clk(clk),
        .rst_n(rst_n),
        .enable(enable),
        .ready(ready),
        .data(data),
        .valid(valid)
    );

    initial begin
        repeat (3) @(posedge clk);
        rst_n = 1'b1;
        @(negedge clk);
        if (valid || data !== 64'h0000_0000_0000_0000)
            $fatal(1, "disabled source must be idle at zero");

        enable = 1'b1;
        ready = 1'b0;
        repeat (3) begin
            @(negedge clk);
            if (!valid || data !== 64'h0000_0000_0000_0000)
                $fatal(1, "source changed while backpressured");
        end

        ready = 1'b1;
        @(negedge clk);
        if (data !== 64'hffff_ffff_ffff_ffff)
            $fatal(1, "first accepted word did not toggle to ones");
        @(negedge clk);
        if (data !== 64'h0000_0000_0000_0000)
            $fatal(1, "second accepted word did not toggle to zeros");

        ready = 1'b0;
        repeat (2) begin
            @(negedge clk);
            if (data !== 64'h0000_0000_0000_0000)
                $fatal(1, "source did not hold the current word");
        end

        enable = 1'b0;
        @(negedge clk);
        if (valid || data !== 64'h0000_0000_0000_0000)
            $fatal(1, "source did not restart from zero when disabled");

        $display("PASS: calibration square source handshake and phase");
        $finish;
    end

    initial begin
        #1000;
        $fatal(1, "square source timeout");
    end
endmodule

