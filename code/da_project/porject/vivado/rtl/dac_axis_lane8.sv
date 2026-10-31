`timescale 1ns/1ps

module dac_axis_lane8 (
    input  logic             clk,
    input  logic             rst_n,
    input  logic             enable,
    input  logic [8*256-1:0] lane_tdata,
    input  logic [7:0]       lane_tvalid,
    output logic [7:0]       lane_tready,
    input  logic [7:0]       dac_tready,
    output logic [8*256-1:0] dac_tdata,
    output logic [7:0]       dac_tvalid,
    output logic             ready_error
);
    logic [8*256-1:0] data_reg;
    logic [8*256-1:0] skid_reg;
    logic data_valid;
    logic skid_valid;
    logic all_lane_valid;
    logic all_dac_ready;
    logic push;
    logic pop;

    always_comb begin
        all_lane_valid = &lane_tvalid;
        all_dac_ready = &dac_tready;
        lane_tready = {8{enable && !skid_valid}};
        dac_tdata = data_reg;
        dac_tvalid = {8{data_valid}};
        push = enable && all_lane_valid && !skid_valid;
        pop = data_valid && all_dac_ready;
    end

    always_ff @(posedge clk) begin
        if (!rst_n || !enable) begin
            data_valid <= 1'b0;
            skid_valid <= 1'b0;
            ready_error <= 1'b0;
        end else begin
            case ({push, pop})
                2'b01: begin
                    if (skid_valid) begin
                        data_reg <= skid_reg;
                        data_valid <= 1'b1;
                        skid_valid <= 1'b0;
                    end else begin
                        data_valid <= 1'b0;
                    end
                end
                2'b10: begin
                    if (data_valid) begin
                        skid_reg <= lane_tdata;
                        skid_valid <= 1'b1;
                    end else begin
                        data_reg <= lane_tdata;
                        data_valid <= 1'b1;
                    end
                end
                2'b11: begin
                    if (skid_valid) begin
                        data_reg <= skid_reg;
                        skid_reg <= lane_tdata;
                        skid_valid <= 1'b1;
                    end else begin
                        data_reg <= lane_tdata;
                        skid_valid <= 1'b0;
                    end
                    data_valid <= 1'b1;
                end
                default: begin
                end
            endcase

            if (data_valid && !all_dac_ready)
                ready_error <= 1'b1;
        end
    end
endmodule
