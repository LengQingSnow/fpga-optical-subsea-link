`timescale 1ns/1ps

module tb_sample_delay_parallel32;
    logic clk = 1'b0;
    logic rst_n = 1'b0;
    logic in_valid = 1'b0;
    logic clear_history = 1'b0;
    logic signed [16*32-1:0] samples = '0;
    logic [1:0] delay_samples = 2'd0;
    logic out_valid;
    logic signed [16*32-1:0] delayed_samples;

    always #2 clk = ~clk;

    sample_delay_parallel32 dut (
        .clk(clk),
        .rst_n(rst_n),
        .in_valid(in_valid),
        .clear_history(clear_history),
        .samples(samples),
        .delay_samples(delay_samples),
        .out_valid(out_valid),
        .delayed_samples(delayed_samples)
    );

    task set_word(input integer first_value);
        for (int sample = 0; sample < 32; sample++)
            samples[sample*16 +: 16] = first_value + sample;
    endtask

    task check_word(input integer first_value, input integer previous_first,
                    input integer delay);
        integer expected;
        begin
            if (!out_valid)
                $fatal(1, "missing delayed output");
            for (int sample = 0; sample < 32; sample++) begin
                if (sample < delay)
                    expected = previous_first + 32 - delay + sample;
                else
                    expected = first_value + sample - delay;
                if ($signed(delayed_samples[sample*16 +: 16]) !== expected)
                    $fatal(1, "delay=%0d sample=%0d expected=%0d got=%0d",
                           delay, sample, expected,
                           $signed(delayed_samples[sample*16 +: 16]));
            end
        end
    endtask

    initial begin
        repeat (3) @(posedge clk);
        rst_n = 1'b1;

        delay_samples = 2'd0;
        @(negedge clk);
        set_word(1);
        in_valid = 1'b1;
        @(negedge clk);
        check_word(1, -31, 0);
        in_valid = 1'b0;

        @(negedge clk);
        rst_n = 1'b0;
        @(negedge clk);
        rst_n = 1'b1;
        delay_samples = 2'd3;
        set_word(1);
        in_valid = 1'b1;
        @(negedge clk);
        if (!out_valid)
            $fatal(1, "missing first delayed block");
        for (int sample = 0; sample < 3; sample++)
            if ($signed(delayed_samples[sample*16 +: 16]) !== 0)
                $fatal(1, "reset history was not zero");
        for (int sample = 3; sample < 32; sample++)
            if ($signed(delayed_samples[sample*16 +: 16]) !== sample - 2)
                $fatal(1, "first delayed block mismatch sample=%0d", sample);

        set_word(33);
        @(negedge clk);
        check_word(33, 1, 3);

        in_valid = 1'b0;
        @(negedge clk);
        if (out_valid)
            $fatal(1, "out_valid did not follow accepted blocks");

        $display("PASS: 32-sample block delay crosses word boundaries");
        $finish;
    end

    initial begin
        #2000;
        $fatal(1, "sample delay timeout");
    end
endmodule
