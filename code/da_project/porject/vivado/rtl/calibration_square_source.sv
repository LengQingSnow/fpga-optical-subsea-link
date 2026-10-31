`timescale 1ns/1ps

module calibration_square_source (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        enable,
    input  logic        ready,
    output logic [63:0] data,
    output logic        valid
);
    logic level;

    assign data = {64{level}};
    assign valid = enable;

    always_ff @(posedge clk) begin
        if (!rst_n || !enable)
            level <= 1'b0;
        else if (ready)
            level <= ~level;
    end
endmodule

