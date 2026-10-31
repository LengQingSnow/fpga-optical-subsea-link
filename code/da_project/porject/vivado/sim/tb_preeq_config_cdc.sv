`timescale 1ns/1ps

module tb_preeq_config_cdc;
    logic src_clk = 1'b0;
    logic src_rst = 1'b1;
    logic [451:0] src_config = '0;
    logic src_commit_toggle = 1'b0;
    logic dst_clk = 1'b0;
    logic dst_rst_n = 1'b0;
    logic [451:0] dst_config;
    logic dst_commit_pulse;
    integer pulse_count = 0;

    always #5 src_clk = ~src_clk;
    always #2 dst_clk = ~dst_clk;

    preeq_config_cdc dut (
        .src_clk(src_clk), .src_rst(src_rst), .src_config(src_config),
        .src_commit_toggle(src_commit_toggle), .dst_clk(dst_clk),
        .dst_rst_n(dst_rst_n), .dst_config(dst_config),
        .dst_commit_pulse(dst_commit_pulse)
    );

    always @(posedge dst_clk)
        if (dst_commit_pulse)
            pulse_count++;

    initial begin
        repeat (3) @(posedge src_clk);
        src_rst = 1'b0;
        dst_rst_n = 1'b1;

        @(negedge src_clk);
        src_config = '0;
        src_config[451:448] = 4'hf;
        src_config[447:0] = {14{32'h01234567}};
        src_commit_toggle = ~src_commit_toggle;
        wait (pulse_count == 1);
        @(negedge dst_clk);
        if (dst_config !== src_config)
            $fatal(1, "first 7-tap configuration mismatch");

        repeat (4) @(negedge src_clk);
        if (pulse_count != 1)
            $fatal(1, "commit pulse lasted more than one destination cycle");

        @(negedge src_clk);
        src_config = '0;
        src_config[451:448] = 4'h5;
        src_config[447:0] = {14{32'hfedcba98}};
        src_commit_toggle = ~src_commit_toggle;
        wait (pulse_count == 2);
        @(negedge dst_clk);
        if (dst_config !== src_config)
            $fatal(1, "second 7-tap configuration mismatch");

        $display("PASS: 452-bit 7-tap FFE configuration crosses atomically");
        $finish;
    end

    initial begin
        #3000;
        $fatal(1, "7-tap configuration CDC timeout");
    end
endmodule
