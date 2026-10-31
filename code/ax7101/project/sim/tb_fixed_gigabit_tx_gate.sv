`timescale 1 ns / 1 ps

module tb_fixed_gigabit_tx_gate;

reg link;
reg descriptor_ready;
wire enable;

fixed_gigabit_tx_gate dut (
    .link(link),
    .descriptor_ready(descriptor_ready),
    .enable(enable)
);

initial begin
    link = 1'b0;
    descriptor_ready = 1'b0;
    #1;
    if (enable !== 1'b0)
        $fatal(1, "TX enabled without link or descriptor");

    link = 1'b1;
    #1;
    if (enable !== 1'b0)
        $fatal(1, "TX enabled without descriptor");

    descriptor_ready = 1'b1;
    #1;
    if (enable !== 1'b1)
        $fatal(1, "Fixed-gigabit TX did not enable on link");

    link = 1'b0;
    #1;
    if (enable !== 1'b0)
        $fatal(1, "TX remained enabled after link loss");

    $display("PASS tb_fixed_gigabit_tx_gate");
    $finish;
end

endmodule
