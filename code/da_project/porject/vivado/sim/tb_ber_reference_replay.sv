`timescale 1ns/1ps

module tb_ber_reference_replay;
    logic clk = 1'b0;
    logic rst_n = 1'b0;
    logic capture_pulse = 1'b0;
    logic replay_enable = 1'b0;
    logic [63:0] live_data = '0;
    logic live_valid = 1'b0;
    logic live_ready;
    logic downstream_ready = 1'b1;
    logic [63:0] output_data;
    logic output_valid;
    logic [5:0] reference_address = '0;
    logic [63:0] reference_data;
    logic reference_ready;
    logic replay_active;

    always #2 clk = ~clk;

    ber_reference_replay dut (
        .clk(clk), .rst_n(rst_n),
        .capture_pulse(capture_pulse), .replay_enable(replay_enable),
        .live_data(live_data), .live_valid(live_valid), .live_ready(live_ready),
        .downstream_ready(downstream_ready),
        .output_data(output_data), .output_valid(output_valid),
        .reference_address(reference_address), .reference_data(reference_data),
        .reference_ready(reference_ready), .replay_active(replay_active)
    );

    initial begin
        repeat (3) @(posedge clk);
        rst_n = 1'b1;
        replay_enable = 1'b1;
        @(negedge clk);
        capture_pulse = 1'b1;
        @(negedge clk);
        capture_pulse = 1'b0;

        for (int word_index = 0; word_index < 64; word_index++) begin
            live_data = 64'h4700_0000_0000_0000 + word_index;
            live_valid = 1'b1;
            #1;
            if (!live_ready || !output_valid || output_data !== live_data)
                $fatal(1, "live capture path mismatch at word %0d", word_index);
            @(posedge clk);
            @(negedge clk);
        end
        live_valid = 1'b0;
        if (!reference_ready || !replay_active)
            $fatal(1, "reference did not enter replay after 64 words");

        for (int word_index = 0; word_index < 70; word_index++) begin
            #1;
            if (!output_valid || output_data !==
                    (64'h4700_0000_0000_0000 + (word_index % 64)))
                $fatal(1, "replay mismatch at word %0d", word_index);
            @(posedge clk);
            @(negedge clk);
        end

        downstream_ready = 1'b0;
        live_valid = 1'b1;
        live_data = 64'hdead_beef_cafe_0047;
        #1;
        if (!live_ready)
            $fatal(1, "live input was not drained during replay stall");
        if (output_data !== 64'h4700_0000_0000_0000 + 6)
            $fatal(1, "replay word changed while downstream stalled");
        downstream_ready = 1'b1;
        live_valid = 1'b0;

        for (int word_index = 0; word_index < 64; word_index++) begin
            reference_address = word_index;
            #1;
            if (reference_data !== 64'h4700_0000_0000_0000 + word_index)
                $fatal(1, "reference readback mismatch at word %0d", word_index);
        end

        replay_enable = 1'b0;
        live_data = 64'h1234_5678_9abc_def0;
        live_valid = 1'b1;
        #1;
        if (replay_active || output_data !== live_data || !output_valid)
            $fatal(1, "replay disable did not restore the live path");

        $display("PASS: DA reference capture, readback, replay, and disable");
        $finish;
    end

    initial begin
        #5000;
        $fatal(1, "BER reference replay timeout");
    end
endmodule
