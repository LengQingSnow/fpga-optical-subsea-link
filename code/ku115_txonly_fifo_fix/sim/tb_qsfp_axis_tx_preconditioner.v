`timescale 1ns / 1ps

module tb_qsfp_axis_tx_preconditioner;

reg  [255:0] canonical_tdata;
reg  [31:0]  canonical_tkeep;
wire [255:0] tx_tdata;
wire [31:0]  tx_tkeep;
wire [255:0] measured_link_tdata;
wire [31:0]  measured_link_tkeep;
wire [255:0] normalized_tdata;
wire [31:0]  normalized_tkeep;
wire         normalized_tvalid;
wire         normalized_tlast;

qsfp_axis_tx_preconditioner dut (
    .canonical_tdata(canonical_tdata),
    .canonical_tkeep(canonical_tkeep),
    .aurora_tdata(tx_tdata),
    .aurora_tkeep(tx_tkeep)
);

// KU115-to-RF47 hardware presents transmitted groups i0,i1,i2,i3 as
// i1,i2,i0,i3 before the RF47 normalizer.
assign measured_link_tdata = {tx_tdata[191:128], tx_tdata[127:64],
                              tx_tdata[255:192], tx_tdata[63:0]};
assign measured_link_tkeep = {tx_tkeep[23:16], tx_tkeep[15:8],
                              tx_tkeep[31:24], tx_tkeep[7:0]};

qsfp_axis_rx_normalizer rf47_normalizer (
    .aurora_tdata(measured_link_tdata),
    .aurora_tkeep(measured_link_tkeep),
    .aurora_tvalid(1'b1),
    .aurora_tlast(1'b0),
    .normalized_tdata(normalized_tdata),
    .normalized_tkeep(normalized_tkeep),
    .normalized_tvalid(normalized_tvalid),
    .normalized_tlast(normalized_tlast)
);

initial begin
    canonical_tdata = {
        64'hD5C01ACFFC1D5AA5,
        64'h0106000012345678,
        64'h2233445566778899,
        64'hAABBCCDDEEFF0011
    };
    canonical_tkeep = {8'hf0, 8'hcc, 8'haa, 8'h55};
    #1;

    if (tx_tdata !== {
        64'hD5C01ACFFC1D5AA5,
        64'hAABBCCDDEEFF0011,
        64'h2233445566778899,
        64'h0106000012345678
    })
        $fatal(1, "KU115 TX preconditioning mismatch: %h", tx_tdata);
    if (normalized_tdata !== canonical_tdata)
        $fatal(1, "RF47 canonical data was not restored: %h", normalized_tdata);
    if (normalized_tkeep !== canonical_tkeep)
        $fatal(1, "RF47 canonical keep was not restored: %h", normalized_tkeep);
    if (!normalized_tvalid || normalized_tlast)
        $fatal(1, "RF47 control pass-through mismatch");

    $display("TEST PASSED: KU115 TX preconditioning restores RF47 canonical order");
    $finish;
end

endmodule
