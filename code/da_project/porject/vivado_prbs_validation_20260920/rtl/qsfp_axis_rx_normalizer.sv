`timescale 1ns/1ps

module qsfp_axis_rx_normalizer (
    input  logic [255:0] aurora_tdata,
    input  logic [31:0]  aurora_tkeep,
    input  logic         aurora_tvalid,
    input  logic         aurora_tlast,
    output logic [255:0] normalized_tdata,
    output logic [31:0]  normalized_tkeep,
    output logic         normalized_tvalid,
    output logic         normalized_tlast
);
    always_comb begin
        normalized_tdata = {aurora_tdata[127:0],
                            aurora_tdata[191:128], aurora_tdata[255:192]};
        normalized_tkeep = {aurora_tkeep[15:0],
                            aurora_tkeep[23:16], aurora_tkeep[31:24]};
        normalized_tvalid = aurora_tvalid;
        normalized_tlast = aurora_tlast;
    end
endmodule

