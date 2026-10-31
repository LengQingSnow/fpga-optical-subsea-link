`timescale 1ns/1ps

module dac_axis_differential4 (
    input  logic             clk,
    input  logic             rst_n,
    input  logic             enable,
    input  logic [4*256-1:0] lane_tdata,
    input  logic [3:0]       lane_tvalid,
    output logic [3:0]       lane_tready,
    input  logic [7:0]       dac_tready,
    output logic [8*256-1:0] dac_tdata,
    output logic [7:0]       dac_tvalid,
    output logic             ready_error
);
    (* DONT_TOUCH = "TRUE" *) logic [8*256-1:0] data_reg;
    logic data_valid;
    logic output_slot_ready;
    logic all_lane_valid;
    logic all_dac_ready;
    logic ready_seen;

    always_comb begin
        all_lane_valid = &lane_tvalid;
        all_dac_ready = &dac_tready;
        output_slot_ready = !data_valid || all_dac_ready;
        lane_tready = {4{enable && all_lane_valid && output_slot_ready}};
        dac_tdata = data_reg;
        dac_tvalid = {8{data_valid && all_dac_ready}};
    end

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            data_reg <= '0;
            data_valid <= 1'b0;
            ready_seen <= 1'b0;
            ready_error <= 1'b0;
        end else begin
            if (output_slot_ready) begin
                data_valid <= enable && all_lane_valid;
                if (enable && all_lane_valid) begin
                    for (int component = 0; component < 4; component++) begin
                        data_reg[(2*component)*256 +: 256] <=
                            lane_tdata[component*256 +: 256];
                        for (int sample = 0; sample < 16; sample++) begin
                            data_reg[(2*component+1)*256 + sample*16 +: 16] <=
                                -$signed(lane_tdata[component*256 + sample*16 +: 16]);
                        end
                    end
                end
            end

            if (data_valid && all_dac_ready)
                ready_seen <= 1'b1;
            if (ready_seen && data_valid && !all_dac_ready)
                ready_error <= 1'b1;
        end
    end
endmodule

