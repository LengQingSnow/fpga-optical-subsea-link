`timescale 1ns / 1ps

module tb_qsfp_axis_rx_normalizer;

reg  [255:0] aurora_tdata;
reg  [31:0]  aurora_tkeep;
reg          aurora_tvalid;
reg          aurora_tlast;
wire [255:0] normalized_tdata;
wire [31:0]  normalized_tkeep;
wire         normalized_tvalid;
wire         normalized_tlast;

qsfp_axis_rx_normalizer dut (
    .aurora_tdata(aurora_tdata),
    .aurora_tkeep(aurora_tkeep),
    .aurora_tvalid(aurora_tvalid),
    .aurora_tlast(aurora_tlast),
    .normalized_tdata(normalized_tdata),
    .normalized_tkeep(normalized_tkeep),
    .normalized_tvalid(normalized_tvalid),
    .normalized_tlast(normalized_tlast)
);

initial begin
    // Four-lane hardware ordering is q3, q2, q0, q1.
    aurora_tdata = {64'h3333333333333333, 64'h2222222222222222,
                    64'h0000000000000000, 64'h1111111111111111};
    aurora_tkeep = {8'h08, 8'h04, 8'h01, 8'h02};
    aurora_tvalid = 1'b1;
    aurora_tlast = 1'b0;
    #1;

    if (normalized_tdata !==
        {64'h0000000000000000, 64'h1111111111111111,
         64'h2222222222222222, 64'h3333333333333333})
        $fatal(1, "RX data half normalization failed: %h", normalized_tdata);
    if (normalized_tkeep !== {8'h01, 8'h02, 8'h04, 8'h08})
        $fatal(1, "RX keep half normalization failed: %h", normalized_tkeep);
    if (!normalized_tvalid || normalized_tlast)
        $fatal(1, "RX control pass-through failed");

    $display("TEST PASSED: qsfp_axis_rx_normalizer restores canonical ordering");
    $finish;
end

endmodule
