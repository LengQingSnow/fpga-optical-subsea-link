`timescale 1ns/1ps

module rf47_prbs_rrc_core (
    input  logic             clk250,
    input  logic             rst250_n,
    input  logic             clk500,
    input  logic             rst500_n,
    input  logic             enable,
    input  logic [7:0]       dac_tready,
    output logic [8*256-1:0] dac_tdata,
    output logic [7:0]       dac_tvalid,
    output logic [30:0]      prbs_state,
    output logic             fifo_overflow,
    output logic             fifo_underflow,
    output logic             source_overflow,
    output logic             ready_error
);
    logic [15:0] prbs_bits;
    logic prbs_valid;
    logic rrc_valid;
    logic [511:0] rrc_samples;
    logic fifo_ready;
    logic [255:0] fifo_data;
    logic fifo_valid;
    logic source_active;
    logic dac_input_ready;

    always_ff @(posedge clk250) begin
        if (!rst250_n)
            source_active <= 1'b0;
        else if (!enable)
            source_active <= 1'b0;
        else if (fifo_ready)
            source_active <= 1'b1;
    end

    prbs31_parallel16 prbs_i (
        .clk(clk250),
        .rst_n(rst250_n),
        .enable(source_active),
        .bits(prbs_bits),
        .state(prbs_state)
    );

    always_ff @(posedge clk250) begin
        if (!rst250_n)
            prbs_valid <= 1'b0;
        else
            prbs_valid <= source_active;
    end

    rrc_2sps_parallel32 rrc_i (
        .clk(clk250),
        .rst_n(rst250_n),
        .in_valid(prbs_valid),
        .symbols(prbs_bits),
        .out_valid(rrc_valid),
        .samples(rrc_samples)
    );

    always_ff @(posedge clk250) begin
        if (!rst250_n)
            source_overflow <= 1'b0;
        else if (rrc_valid && !fifo_ready)
            source_overflow <= 1'b1;
    end

    sample_gearbox_512_to_256 gearbox_i (
        .wr_clk(clk250),
        .wr_rst_n(rst250_n),
        .s_data(rrc_samples),
        .s_valid(rrc_valid),
        .s_ready(fifo_ready),
        .rd_clk(clk500),
        .rd_rst_n(rst500_n),
        .m_data(fifo_data),
        .m_valid(fifo_valid),
        .m_ready(dac_input_ready),
        .overflow(fifo_overflow),
        .underflow(fifo_underflow)
    );

    dac_axis_diff_fanout8 fanout_i (
        .clk(clk500),
        .rst_n(rst500_n),
        .enable(1'b1),
        .in_data(fifo_data),
        .in_valid(fifo_valid),
        .dac_tready(dac_tready),
        .dac_tdata(dac_tdata),
        .dac_tvalid(dac_tvalid),
        .in_ready(dac_input_ready),
        .all_ready(),
        .ready_error(ready_error)
    );
endmodule
