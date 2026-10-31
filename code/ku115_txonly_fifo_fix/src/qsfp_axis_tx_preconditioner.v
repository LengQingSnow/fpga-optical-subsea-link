`timescale 1ns / 1ps

// Precondition the KU115 TX lane groups so the existing RF47 RX normalizer
// reconstructs canonical q0,q1,q2,q3 ordering on the physical link.
module qsfp_axis_tx_preconditioner (
    input      [255:0] canonical_tdata,
    input      [31:0]  canonical_tkeep,
    output     [255:0] aurora_tdata,
    output     [31:0]  aurora_tkeep
);

assign aurora_tdata = {canonical_tdata[255:192], canonical_tdata[63:0],
                       canonical_tdata[127:64], canonical_tdata[191:128]};
assign aurora_tkeep = {canonical_tkeep[31:24], canonical_tkeep[7:0],
                       canonical_tkeep[15:8], canonical_tkeep[23:16]};

endmodule
