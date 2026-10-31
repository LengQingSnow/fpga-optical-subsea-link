`timescale 1ns/1ps

module tb_runtime_config_cdc;
    logic src_clk = 1'b0;
    logic src_rst = 1'b1;
    logic [55:0] src_delay_codes = '0;
    logic src_commit_toggle = 1'b0;
    logic dst_clk = 1'b0;
    logic dst_rst_n = 1'b0;
    logic [55:0] dst_delay_codes;
    logic dst_commit_pulse;
    integer pulse_count = 0;

    always #5 src_clk = ~src_clk;
    always #2 dst_clk = ~dst_clk;

    runtime_config_cdc dut (
        .src_clk(src_clk),
        .src_rst(src_rst),
        .src_delay_codes(src_delay_codes),
        .src_commit_toggle(src_commit_toggle),
        .dst_clk(dst_clk),
        .dst_rst_n(dst_rst_n),
        .dst_delay_codes(dst_delay_codes),
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
        src_delay_codes = 56'h01_23_45_67_89_ab_cd;
        @(negedge src_clk);
        src_commit_toggle = ~src_commit_toggle;
        wait (pulse_count == 1);
        @(negedge dst_clk);
        if (dst_delay_codes !== 56'h01_23_45_67_89_ab_cd)
            $fatal(1, "first bundled CDC value mismatch");

        repeat (4) @(negedge src_clk);
        if (pulse_count != 1)
            $fatal(1, "commit pulse lasted more than one destination cycle");

        src_delay_codes = 56'h7f_00_7e_01_7d_02_7c;
        @(negedge src_clk);
        src_commit_toggle = ~src_commit_toggle;
        wait (pulse_count == 2);
        @(negedge dst_clk);
        if (dst_delay_codes !== 56'h7f_00_7e_01_7d_02_7c)
            $fatal(1, "second bundled CDC value mismatch");

        $display("PASS: runtime delay configuration crosses atomically");
        $finish;
    end

    initial begin
        #3000;
        $fatal(1, "runtime configuration CDC timeout");
    end
endmodule

