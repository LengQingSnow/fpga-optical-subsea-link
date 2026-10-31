`timescale 1ns/1ps

module tb_port4_runtime_mode_control;

reg clk = 1'b0;
reg rst_n = 1'b0;
reg request_tx = 1'b0;
reg arp_tx_en = 1'b0;
reg prbs_tx_en = 1'b0;
wire active_tx_mode;
wire prbs_enable;

always #4 clk = ~clk;

port4_runtime_mode_control dut (
    .clk(clk),
    .rst_n(rst_n),
    .request_tx(request_tx),
    .arp_tx_en(arp_tx_en),
    .prbs_tx_en(prbs_tx_en),
    .active_tx_mode(active_tx_mode),
    .prbs_enable(prbs_enable)
);

task automatic check_state;
    input expected_mode;
    input expected_enable;
    input [255:0] message;
    begin
        if ((active_tx_mode !== expected_mode) ||
            (prbs_enable !== expected_enable))
            $fatal(1, "%0s: mode=%0b enable=%0b",
                   message, active_tx_mode, prbs_enable);
    end
endtask

initial begin
    repeat (3) @(posedge clk);
    rst_n <= 1'b1;
    @(posedge clk);
    #1 check_state(1'b0, 1'b0, "default mode is not receive");

    arp_tx_en <= 1'b1;
    request_tx <= 1'b1;
    repeat (3) @(posedge clk);
    #1 check_state(1'b0, 1'b0, "controller interrupted ARP frame");

    arp_tx_en <= 1'b0;
    @(posedge clk);
    #1 check_state(1'b1, 1'b1, "controller did not enter PRBS mode");

    prbs_tx_en <= 1'b1;
    request_tx <= 1'b0;
    repeat (3) @(posedge clk);
    #1 check_state(1'b1, 1'b1, "controller truncated PRBS frame");

    prbs_tx_en <= 1'b0;
    @(posedge clk);
    #1 check_state(1'b0, 1'b0, "controller did not return to receive");

    request_tx <= 1'b1;
    @(posedge clk);
    #1 check_state(1'b1, 1'b1, "second PRBS entry failed");

    rst_n <= 1'b0;
    @(posedge clk);
    #1 check_state(1'b0, 1'b0, "reset did not restore receive mode");

    $display("PASS tb_port4_runtime_mode_control");
    $finish;
end

endmodule
