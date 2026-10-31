`timescale 1ns/1ps

module tb_dac_axis_diff_fanout8;
    logic clk = 1'b0;
    logic rst_n = 1'b0;
    logic enable = 1'b0;
    logic [255:0] in_data = '0;
    logic in_valid = 1'b0;
    logic [7:0] dac_tready = 8'hff;
    logic [8*256-1:0] dac_tdata;
    logic [7:0] dac_tvalid;
    logic in_ready;
    logic all_ready;
    logic ready_error;
    logic [255:0] first_word;

    always #1 clk = ~clk;

    dac_axis_diff_fanout8 dut (
        .clk(clk),
        .rst_n(rst_n),
        .enable(enable),
        .in_data(in_data),
        .in_valid(in_valid),
        .dac_tready(dac_tready),
        .dac_tdata(dac_tdata),
        .dac_tvalid(dac_tvalid),
        .in_ready(in_ready),
        .all_ready(all_ready),
        .ready_error(ready_error)
    );

    function automatic logic signed [15:0] negate_sample(
        input logic signed [15:0] sample
    );
        negate_sample = -sample;
    endfunction

    initial begin
        for (int lane = 0; lane < 16; lane++)
            in_data[lane*16 +: 16] = $signed((lane * 16'sd173) - 16'sd1200);

        repeat (4) @(posedge clk);
        rst_n <= 1'b1;
        enable <= 1'b1;
        in_valid <= 1'b1;
        @(posedge clk);
        #1;

        if (dac_tvalid !== 8'hff || !all_ready)
            $fatal(1, "differential fanout valid/ready mismatch");

        for (int pair = 0; pair < 4; pair++) begin
            for (int lane = 0; lane < 16; lane++) begin
                if ($signed(dac_tdata[(2*pair)*256 + lane*16 +: 16]) !==
                    $signed(in_data[lane*16 +: 16]))
                    $fatal(1, "positive output mismatch: pair=%0d lane=%0d", pair, lane);
                if ($signed(dac_tdata[(2*pair+1)*256 + lane*16 +: 16]) !==
                    negate_sample($signed(in_data[lane*16 +: 16])))
                    $fatal(1, "negative output mismatch: pair=%0d lane=%0d", pair, lane);
            end
        end
        if (ready_error)
            $fatal(1, "spurious ready error");

        first_word = in_data;
        @(negedge clk);
        in_data = ~first_word;
        #1;
        if (dac_tdata[0 +: 256] !== first_word)
            $fatal(1, "DAC output changed without a clock edge");
        @(posedge clk);
        #1;
        if (dac_tdata[0 +: 256] !== in_data)
            $fatal(1, "registered DAC output did not advance on the clock edge");

        dac_tready <= 8'b1111_0111;
        @(posedge clk);
        #1;
        if (all_ready || (dac_tvalid !== 8'h00) || !ready_error)
            $fatal(1, "single-channel ready drop was not reported");

        dac_tready <= 8'hff;
        @(posedge clk);
        #1;
        if (!ready_error)
            $fatal(1, "ready_error must be sticky");

        $display("PASS: eight-channel differential DAC fanout and ready diagnostics");
        $finish;
    end
endmodule
