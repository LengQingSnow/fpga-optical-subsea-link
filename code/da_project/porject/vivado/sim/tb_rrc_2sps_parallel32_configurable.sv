`timescale 1ns/1ps

module tb_rrc_2sps_parallel32_configurable;
    logic clk = 1'b0;
    logic rst_n = 1'b0;
    logic in_valid = 1'b0;
    logic [15:0] symbols = '0;
    logic config_load = 1'b0;
    logic clear_history = 1'b0;
    logic [4:0] fractional_delay = 5'd0;
    logic reference_valid;
    logic configured_valid;
    logic signed [16*32-1:0] reference_samples;
    logic signed [16*32-1:0] configured_samples;
    logic signed [16*32-1:0] saved_reference_samples;
    integer different_samples;

    always #2 clk = ~clk;

    rrc_2sps_parallel32 reference_i (
        .clk(clk),
        .rst_n(rst_n),
        .in_valid(in_valid),
        .symbols(symbols),
        .out_valid(reference_valid),
        .samples(reference_samples)
    );

    rrc_2sps_parallel32_configurable dut (
        .clk(clk),
        .rst_n(rst_n),
        .in_valid(in_valid),
        .symbols(symbols),
        .clear_history(clear_history),
        .config_load(config_load),
        .fractional_delay(fractional_delay),
        .out_valid(configured_valid),
        .samples(configured_samples)
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

    initial begin
        repeat (3) @(posedge clk);
        rst_n = 1'b1;

        fractional_delay = 5'd0;
        send_symbols(16'h8421);
        if (!reference_valid)
            $fatal(1, "phase-zero reference output valid missing");
        if (configured_valid)
            $fatal(1, "configurable RRC must insert the timing pipeline stage");
        saved_reference_samples = reference_samples;
        @(negedge clk);
        if (!configured_valid)
            $fatal(1, "pipelined phase-zero output valid missing");
        if (configured_samples !== saved_reference_samples)
            $fatal(1, "phase zero must be bit-exact with the original RRC");

        fractional_delay = 5'd16;
        @(negedge clk);
        config_load = 1'b1;
        @(negedge clk);
        config_load = 1'b0;
        send_symbols(16'ha55a);
        if (!reference_valid)
            $fatal(1, "fractional reference output valid missing");
        if (configured_valid)
            $fatal(1, "fractional output bypassed the timing pipeline");
        saved_reference_samples = reference_samples;
        @(negedge clk);
        if (!configured_valid)
            $fatal(1, "pipelined fractional output valid missing");
        different_samples = 0;
        for (int sample = 0; sample < 32; sample++)
            if (configured_samples[sample*16 +: 16] !==
                saved_reference_samples[sample*16 +: 16])
                different_samples++;
        if (different_samples < 8)
            $fatal(1, "fractional phase did not materially change the RRC output");

        @(negedge clk);
        symbols = 16'h3c3c;
        in_valid = 1'b1;
        @(negedge clk);
        in_valid = 1'b0;
        clear_history = 1'b1;
        @(negedge clk);
        clear_history = 1'b0;
        if (configured_valid)
            $fatal(1, "clear_history did not flush the pending pipeline word");

        $display("PASS: configurable RRC is pipelined, phase-exact, and flushable");
        $finish;
    end

    initial begin
        #2000;
        $fatal(1, "configurable RRC timeout");
    end
endmodule
