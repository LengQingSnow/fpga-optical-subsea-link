`timescale 1ns/1ps

module tb_nrz_2sps_parallel32_configurable;
    localparam logic signed [15:0] AMPLITUDE = 16'sd14779;

    logic clk = 1'b0;
    logic rst_n = 1'b0;
    logic in_valid = 1'b0;
    logic [15:0] symbols = '0;
    logic clear_history = 1'b0;
    logic config_load = 1'b0;
    logic [4:0] fractional_delay = 5'd0;
    logic out_valid;
    logic signed [16*32-1:0] samples;

    always #2 clk = ~clk;

    nrz_2sps_parallel32_configurable dut (
        .clk(clk),
        .rst_n(rst_n),
        .in_valid(in_valid),
        .symbols(symbols),
        .clear_history(clear_history),
        .config_load(config_load),
        .fractional_delay(fractional_delay),
        .out_valid(out_valid),
        .samples(samples)
    );

    task send_symbols(input logic [15:0] word);
        begin
            @(negedge clk);
            symbols = word;
            in_valid = 1'b1;
            @(negedge clk);
            in_valid = 1'b0;
        end
    endtask

    task load_phase(input logic [4:0] phase);
        begin
            @(negedge clk);
            fractional_delay = phase;
            config_load = 1'b1;
            @(negedge clk);
            config_load = 1'b0;
        end
    endtask

    task expect_sample(input int index, input logic signed [15:0] expected);
        logic signed [15:0] actual;
        begin
            actual = $signed(samples[index*16 +: 16]);
            if (actual !== expected)
                $fatal(1, "sample %0d expected %0d, got %0d", index, expected, actual);
        end
    endtask

    initial begin
        repeat (3) @(posedge clk);
        rst_n = 1'b1;

        send_symbols(16'h0003);
        if (!out_valid)
            $fatal(1, "phase-zero output valid missing");
        for (int sample_index = 0; sample_index < 32; sample_index++) begin
            int symbol_index;
            symbol_index = sample_index / 2;
            expect_sample(sample_index,
                symbols[symbol_index] ? AMPLITUDE : -AMPLITUDE);
        end

        // End the prior block low, then switch high at the next block. At a
        // half-sample delay the first transition sample must be the midpoint.
        load_phase(5'd16);
        send_symbols(16'hffff);
        if (!out_valid)
            $fatal(1, "fractional-delay output valid missing");
        expect_sample(0, 16'sd0);
        expect_sample(1, AMPLITUDE);
        for (int sample_index = 2; sample_index < 32; sample_index++)
            expect_sample(sample_index, AMPLITUDE);

        // History must continue across a 32-sample word. A high-to-low edge
        // at the next word receives the same midpoint interpolation.
        send_symbols(16'h0000);
        if (!out_valid)
            $fatal(1, "history output valid missing");
        expect_sample(0, 16'sd0);
        expect_sample(1, -AMPLITUDE);

        @(negedge clk);
        in_valid = 1'b1;
        symbols = 16'hffff;
        @(negedge clk);
        in_valid = 1'b0;
        clear_history = 1'b1;
        @(negedge clk);
        clear_history = 1'b0;
        if (out_valid)
            $fatal(1, "clear_history did not flush the pending NRZ word");

        $display("PASS: rectangular NRZ mapping and 1/32-sample delay are correct");
        $finish;
    end

    initial begin
        #2000;
        $fatal(1, "NRZ shaper timeout");
    end
endmodule
