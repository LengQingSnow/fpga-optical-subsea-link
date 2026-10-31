`timescale 1ns/1ps

module tb_dac_axis_lane8;
    logic clk = 1'b0;
    logic rst_n = 1'b0;
    logic enable = 1'b0;
    logic [8*256-1:0] lane_tdata = '0;
    logic [7:0] lane_tvalid = '0;
    logic [7:0] lane_tready;
    logic [7:0] dac_tready = '0;
    logic [8*256-1:0] dac_tdata;
    logic [7:0] dac_tvalid;
    logic ready_error;
    logic [8*256-1:0] first_word;
    logic [8*256-1:0] second_word;

    always #1 clk = ~clk;

    dac_axis_lane8 dut (
        .clk(clk),
        .rst_n(rst_n),
        .enable(enable),
        .lane_tdata(lane_tdata),
        .lane_tvalid(lane_tvalid),
        .lane_tready(lane_tready),
        .dac_tready(dac_tready),
        .dac_tdata(dac_tdata),
        .dac_tvalid(dac_tvalid),
        .ready_error(ready_error)
    );

    initial begin
        for (int lane = 0; lane < 8; lane++)
            lane_tdata[lane*256 +: 256] = {8{32'h1000_0000 + lane}};
        first_word = lane_tdata;
        for (int lane = 0; lane < 8; lane++)
            second_word[lane*256 +: 256] = {8{32'h2000_0000 + lane}};

        repeat (4) @(posedge clk);
        rst_n = 1'b1;
        enable = 1'b1;
        lane_tvalid = 8'hff;
        dac_tready = 8'hff;

        @(posedge clk);
        @(negedge clk);
        if (lane_tready !== 8'hff)
            $fatal(1, "eight lanes were not accepted atomically");
        if (dac_tvalid !== 8'hff || dac_tdata !== first_word)
            $fatal(1, "eight-lane output did not preserve the supplied data");

        // A partial downstream ready must leave TVALID and TDATA stable while
        // one additional upstream word is absorbed by the skid register.
        @(negedge clk);
        dac_tready = 8'h7f;
        lane_tdata = second_word;
        @(posedge clk);
        @(negedge clk);
        if (lane_tready !== 8'h00)
            $fatal(1, "full skid register did not apply registered backpressure");
        if (dac_tvalid !== 8'hff || dac_tdata !== first_word)
            $fatal(1, "AXIS output changed while not all DAC lanes were ready");

        dac_tready = 8'hff;
        lane_tvalid = 8'h00;
        @(posedge clk);
        @(negedge clk);
        if (dac_tvalid !== 8'hff || dac_tdata !== second_word)
            $fatal(1, "queued skid word was not presented after the stall");
        if (!ready_error)
            $fatal(1, "ready mismatch diagnostic was not latched");

        $display("PASS: eight DAC lanes use an atomic registered-ready skid buffer");
        $finish;
    end

    initial begin
        #1000;
        $fatal(1, "eight-lane DAC output timeout");
    end
endmodule
