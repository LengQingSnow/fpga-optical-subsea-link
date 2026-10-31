`timescale 1ns/1ps

module tb_tx_preeq_7tap_parallel32;
    logic clk = 1'b0;
    logic rst_n = 1'b0;
    logic in_valid = 1'b0;
    logic clear_history = 1'b0;
    logic config_load = 1'b0;
    logic bypass = 1'b0;
    logic signed [16*7-1:0] coeffs = '0;
    logic signed [16*32-1:0] in_samples = '0;
    logic out_valid;
    logic signed [16*32-1:0] out_samples;
    logic signed [15:0] input_blocks [0:3][0:31];
    integer output_block = 0;
    integer failures = 0;

    always #2 clk = ~clk;

    tx_preeq_7tap_parallel32 dut (
        .clk(clk), .rst_n(rst_n), .in_valid(in_valid),
        .clear_history(clear_history), .config_load(config_load),
        .bypass(bypass), .coeffs(coeffs),
        .in_samples(in_samples), .out_valid(out_valid), .out_samples(out_samples)
    );

    function automatic logic signed [15:0] expected_identity(
        input integer block_index,
        input integer sample_index
    );
        integer source_index;
        logic signed [40:0] scaled;
        logic signed [15:0] source_value;
        begin
            source_index = sample_index - 3;
            if (source_index >= 0)
                source_value = input_blocks[block_index][source_index];
            else if (block_index > 0)
                source_value = input_blocks[block_index-1][32 + source_index];
            else
                source_value = '0;
            scaled = source_value * 41'sd32767;
            expected_identity = scaled >>> 15;
        end
    endfunction

    task automatic drive_block(input integer block_index);
        begin
            @(negedge clk);
            for (int sample = 0; sample < 32; sample++) begin
                input_blocks[block_index][sample] = $signed(block_index*100 + sample + 1);
                in_samples[sample*16 +: 16] = input_blocks[block_index][sample];
            end
            in_valid = 1'b1;
            @(negedge clk);
            in_valid = 1'b0;
        end
    endtask

    always @(posedge clk) begin
        #1;
        if (out_valid && !bypass) begin
            for (int sample = 0; sample < 32; sample++) begin
                if ($signed(out_samples[sample*16 +: 16]) !==
                    expected_identity(output_block, sample)) begin
                    $display("FAIL block=%0d sample=%0d got=%0d exp=%0d",
                        output_block, sample,
                        $signed(out_samples[sample*16 +: 16]),
                        expected_identity(output_block, sample));
                    failures = failures + 1;
                end
            end
            output_block = output_block + 1;
        end
    end

    initial begin
        coeffs[3*16 +: 16] = 16'sh7fff;
        repeat (4) @(posedge clk);
        rst_n = 1'b1;
        @(negedge clk);
        config_load = 1'b1;
        @(negedge clk);
        config_load = 1'b0;
        for (int block = 0; block < 4; block++)
            drive_block(block);
        wait (output_block == 4);
        if (failures != 0)
            $fatal(1, "identity FFE failed with %0d mismatches", failures);

        wait (!out_valid);
        @(negedge clk);
        clear_history = 1'b1;
        @(negedge clk);
        clear_history = 1'b0;
        bypass = 1'b1;
        for (int sample = 0; sample < 32; sample++)
            in_samples[sample*16 +: 16] = $signed(1000 + sample);
        in_valid = 1'b1;
        @(negedge clk);
        in_valid = 1'b0;
        wait (out_valid);
        #1;
        for (int sample = 0; sample < 32; sample++) begin
            logic signed [15:0] expected_bypass;
            expected_bypass = (sample >= 3) ? $signed(1000 + sample - 3) : 16'sd0;
            if ($signed(out_samples[sample*16 +: 16]) !== expected_bypass)
                $fatal(1, "bypass mismatch sample=%0d got=%0d exp=%0d",
                    sample, $signed(out_samples[sample*16 +: 16]), expected_bypass);
        end
        $display("PASS: 7-tap half-UI FFE and runtime bypass");
        $finish;
    end

    initial begin
        #20000;
        $fatal(1, "7-tap FFE timeout");
    end
endmodule
