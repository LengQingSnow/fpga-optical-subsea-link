`timescale 1ns/1ps

module dac_axis_diff_fanout8 (
    input  logic             clk,
    input  logic             rst_n,
    input  logic             enable,
    input  logic [255:0]     in_data,
    input  logic             in_valid,
    input  logic [7:0]       dac_tready,
    output logic [8*256-1:0] dac_tdata,
    output logic [7:0]       dac_tvalid,
    output logic             in_ready,
    output logic             all_ready,
    output logic             ready_error
);
    (* DONT_TOUCH = "TRUE" *) logic [8*256-1:0] data_reg;
    logic data_valid;
    logic ready_seen;

    always_comb begin
        dac_tdata = data_reg;
        all_ready = &dac_tready;
        in_ready = !data_valid || all_ready;
        dac_tvalid = {8{data_valid && all_ready}};
    end

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            data_valid <= 1'b0;
            ready_seen <= 1'b0;
            ready_error <= 1'b0;
        end else begin
            if (in_ready) begin
                data_valid <= enable && in_valid;
                if (enable && in_valid) begin
                    for (int pair = 0; pair < 4; pair++) begin
                        data_reg[(2*pair)*256 +: 256] <= in_data;
                        for (int lane = 0; lane < 16; lane++) begin
                            data_reg[(2*pair+1)*256 + lane*16 +: 16] <=
                                -$signed(in_data[lane*16 +: 16]);
                        end
                    end
                end
            end

            if (data_valid && all_ready)
                ready_seen <= 1'b1;
            if (ready_seen && data_valid && !all_ready)
                ready_error <= 1'b1;
        end
    end
endmodule
