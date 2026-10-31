`timescale 1ns / 1ps

// Hardware presents the four 64-bit lane groups as q3,q2,q0,q1.  Restore the
// canonical aggregate ordering q0,q1,q2,q3 before comparison or consumption.
module qsfp_axis_rx_normalizer (
    input      [255:0] aurora_tdata,
    input      [31:0]  aurora_tkeep,
    input              aurora_tvalid,
    input              aurora_tlast,
    output     [255:0] normalized_tdata,
    output     [31:0]  normalized_tkeep,
    output             normalized_tvalid,
    output             normalized_tlast
);

assign normalized_tdata = {aurora_tdata[127:0],
                           aurora_tdata[191:128], aurora_tdata[255:192]};
assign normalized_tkeep = {aurora_tkeep[15:0],
                           aurora_tkeep[23:16], aurora_tkeep[31:24]};
assign normalized_tvalid = aurora_tvalid;
assign normalized_tlast = aurora_tlast;

endmodule
