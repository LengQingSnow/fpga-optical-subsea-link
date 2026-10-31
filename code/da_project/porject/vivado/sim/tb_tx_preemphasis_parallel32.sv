`timescale 1ns/1ps

module tb_tx_preemphasis_parallel32;
    logic clk = 1'b0;
    logic rst_n = 1'b0;
    logic in_valid = 1'b0;
    logic clear_history = 1'b0;
    logic signed [16*32-1:0] in_samples = '0;
    logic identity_valid;
    logic custom_valid;
    logic signed [16*32-1:0] identity_samples;
    logic signed [16*32-1:0] custom_samples;
    logic signed [15:0] input_stream [0:95];

    always #2 clk = ~clk;

    tx_preemphasis_parallel32 #(.BYPASS(1'b1)) identity_i (
        .clk(clk), .rst_n(rst_n), .in_valid(in_valid),
        .clear_history(clear_history), .bypass(1'b0), .in_samples(in_samples),
        .out_valid(identity_valid), .out_samples(identity_samples)
    );

    tx_preemphasis_parallel32 #(
        .COEFF_0(16'sd375), .COEFF_1(-16'sd94),
        .COEFF_2(16'sd617), .COEFF_3(-16'sd1642),
        .COEFF_4(16'sd32767), .COEFF_5(-16'sd3569),
        .COEFF_6(-16'sd748), .COEFF_7(16'sd17),
        .COEFF_8(-16'sd1127)
    ) custom_i (
        .clk(clk), .rst_n(rst_n), .in_valid(in_valid),
        .clear_history(clear_history), .bypass(1'b0), .in_samples(in_samples),
        .out_valid(custom_valid), .out_samples(custom_samples)
    );

    function automatic integer expected_value(
        input integer block_index,
        input integer sample_index,
        input bit custom
    );
        integer tap;
        integer source_index;
        integer coefficient;
        longint signed accumulator;
        longint signed scaled;
        begin
            accumulator = 0;
            for (tap = 0; tap < 9; tap = tap + 1) begin
                source_index = block_index * 32 + sample_index - 2 * tap;
                if (custom) begin
                    case (tap)
                        0: coefficient = 375;
                        1: coefficient = -94;
                        2: coefficient = 617;
                        3: coefficient = -1642;
                        4: coefficient = 32767;
                        5: coefficient = -3569;
                        6: coefficient = -748;
                        7: coefficient = 17;
                        default: coefficient = -1127;
                    endcase
                end else begin
                    coefficient = 0;
                end
                if ((source_index >= 0) && (source_index < 96))
                    accumulator = accumulator + input_stream[source_index] * coefficient;
            end
            if (!custom) begin
                source_index = block_index * 32 + sample_index - 8;
                if (source_index >= 0)
                    accumulator = input_stream[source_index] <<< 15;
            end
            scaled = accumulator >>> 15;
            if (scaled > 32767)
                expected_value = 32767;
            else if (scaled < -32768)
                expected_value = -32768;
            else
                expected_value = scaled;
        end
    endfunction

    task automatic send_and_check(input integer block_index);
        integer sample;
        integer expected_identity;
        integer expected_custom;
        integer actual_identity;
        integer actual_custom;
        begin
            @(negedge clk);
            for (sample = 0; sample < 32; sample = sample + 1)
                in_samples[sample*16 +: 16] = input_stream[block_index*32 + sample];
            in_valid = 1'b1;
            @(negedge clk);
            in_valid = 1'b0;
            @(negedge clk);
            @(negedge clk);
            if (!identity_valid || !custom_valid)
                $fatal(1, "expected one-cycle valid latency at block %0d", block_index);
            for (sample = 0; sample < 32; sample = sample + 1) begin
                expected_identity = expected_value(block_index, sample, 1'b0);
                expected_custom = expected_value(block_index, sample, 1'b1);
                actual_identity = $signed(identity_samples[sample*16 +: 16]);
                actual_custom = $signed(custom_samples[sample*16 +: 16]);
                if ((actual_identity - expected_identity > 1) ||
                    (expected_identity - actual_identity > 1))
                    $fatal(1, "identity mismatch block=%0d sample=%0d got=%0d exp=%0d",
                        block_index, sample, actual_identity, expected_identity);
                if ((actual_custom - expected_custom > 1) ||
                    (expected_custom - actual_custom > 1))
                    $fatal(1, "custom mismatch block=%0d sample=%0d got=%0d exp=%0d",
                        block_index, sample, actual_custom, expected_custom);
            end
        end
    endtask

    initial begin
        for (int index = 0; index < 96; index = index + 1)
            input_stream[index] = 16'sd0;
        for (int index = 0; index < 32; index = index + 1)
            input_stream[index] = 16'sd100 + index * 16'sd100;
        input_stream[20] = 16'sd16000;
        repeat (4) @(posedge clk);
        rst_n = 1'b1;
        send_and_check(0);
        send_and_check(1);
        send_and_check(2);
        $display("PASS: TX pre-emphasis identity delay and measured 9-tap response");
        $finish;
    end

    initial begin
        #1000;
        $fatal(1, "pre-emphasis test timeout");
    end
endmodule
