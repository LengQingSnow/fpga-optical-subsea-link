`timescale 1ns/1ps

module tb_rf47_prbs_rrc_core;
    logic clk250 = 1'b0;
    logic clk500 = 1'b0;
    logic rst250_n = 1'b0;
    logic rst500_n = 1'b0;
    logic enable = 1'b0;
    logic [7:0] dac_tready = 8'hff;
    logic [8*256-1:0] dac_tdata;
    logic [7:0] dac_tvalid;
    logic [30:0] prbs_state;
    logic fifo_overflow;
    logic fifo_underflow;
    logic source_overflow;
    logic ready_error;
    integer valid_cycles = 0;
    logic [255:0] previous = '0;
    logic [255:0] stalled_word = '0;
    integer changes = 0;
    integer cycles_before_stall = 0;

    always #2 clk250 = ~clk250;
    always #1 clk500 = ~clk500;

    rf47_prbs_rrc_core dut (
        .clk250(clk250),
        .rst250_n(rst250_n),
        .clk500(clk500),
        .rst500_n(rst500_n),
        .enable(enable),
        .dac_tready(dac_tready),
        .dac_tdata(dac_tdata),
        .dac_tvalid(dac_tvalid),
        .prbs_state(prbs_state),
        .fifo_overflow(fifo_overflow),
        .fifo_underflow(fifo_underflow),
        .source_overflow(source_overflow),
        .ready_error(ready_error)
    );

    always @(posedge clk500) begin
        if (rst500_n && (dac_tvalid == 8'hff)) begin
            for (int pair = 0; pair < 4; pair++) begin
                for (int lane = 0; lane < 16; lane++) begin
                    if ($signed(dac_tdata[(2*pair)*256 + lane*16 +: 16]) !==
                        $signed(dac_tdata[lane*16 +: 16]))
                        $fatal(1, "positive outputs diverged: pair=%0d lane=%0d", pair, lane);
                    if ($signed(dac_tdata[(2*pair+1)*256 + lane*16 +: 16]) !==
                        -$signed(dac_tdata[(2*pair)*256 + lane*16 +: 16]))
                        $fatal(1, "differential outputs misaligned: pair=%0d lane=%0d", pair, lane);
                    if (($signed(dac_tdata[(2*pair)*256 + lane*16 +: 16]) > 24575) ||
                        ($signed(dac_tdata[(2*pair)*256 + lane*16 +: 16]) < -24575))
                        $fatal(1, "lane %0d exceeds RRC amplitude bound", lane);
                end
            end
            if (dac_tdata[255:0] !== previous)
                changes <= changes + 1;
            previous <= dac_tdata[255:0];
            valid_cycles <= valid_cycles + 1;
        end
    end

    initial begin
        #120;
        repeat (8) @(posedge clk500);
        rst250_n <= 1'b1;
        rst500_n <= 1'b1;
        repeat (8) @(posedge clk250);
        enable <= 1'b1;

        wait (valid_cycles >= 64);
        @(negedge clk500);
        stalled_word = dac_tdata[255:0];
        cycles_before_stall = valid_cycles;
        dac_tready = 8'b1111_1110;
        repeat (8) begin
            @(posedge clk500);
            #1;
            if (dac_tvalid !== 8'h00)
                $fatal(1, "DAC channels did not stop together during ready stall");
            if (dac_tdata[255:0] !== stalled_word)
                $fatal(1, "source word advanced while one DAC channel was stalled");
        end

        @(negedge clk500);
        dac_tready = 8'hff;
        wait (valid_cycles >= cycles_before_stall + 64);
        if (changes < 100)
            $fatal(1, "output did not vary as a PRBS-shaped waveform: %0d changes", changes);
        if (prbs_state == 31'h7fffffff)
            $fatal(1, "PRBS state did not advance");
        if (fifo_overflow || fifo_underflow || source_overflow)
            $fatal(1, "unexpected FIFO/source errors %b%b%b", fifo_overflow,
                   fifo_underflow, source_overflow);
        if (!ready_error)
            $fatal(1, "ready stall diagnostic was not latched");

        $display("PASS: end-to-end PRBS31/RRC/gearbox/four aligned differential pairs");
        $finish;
    end

    initial begin
        #5000;
        $fatal(1, "core timeout, valid cycles=%0d", valid_cycles);
    end
endmodule
