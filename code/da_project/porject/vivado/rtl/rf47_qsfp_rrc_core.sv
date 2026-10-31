`timescale 1ns/1ps

module rf47_qsfp_rrc_core (
    input  logic             clk250,
    input  logic             rst250_n,
    input  logic             clk500,
    input  logic             rst500_n,
    input  logic             enable250,
    input  logic             enable500,
    input  logic             calibration_mode,
    input  logic [55:0]      lane_delay_codes,
    input  logic             delay_config_load,
    input  logic [3:0]       preeq_enable_mask,
    input  logic [447:0]     preeq_coeffs,
    input  logic             ber_capture_pulse,
    input  logic             ber_replay_enable,
    input  logic [5:0]       ber_reference_address,
    output logic [63:0]      ber_reference_data,
    output logic             ber_reference_ready,
    output logic             ber_replay_active,
    input  logic [63:0]      stream_data,
    input  logic             stream_valid,
    output logic             stream_ready,
    input  logic [7:0]       dac_tready,
    output logic [8*256-1:0] dac_tdata,
    output logic [7:0]       dac_tvalid,
    output logic [7:0]       gearbox_overflow,
    output logic [7:0]       gearbox_underflow,
    output logic             source_overflow,
    output logic             ready_error,
    output logic [7:0]       runtime_status
);
    logic [63:0] square_data;
    logic square_valid;
    logic source_ready;
    logic [63:0] ber_stream_data;
    logic ber_stream_valid;
    logic ber_live_ready;
    logic [63:0] selected_data;
    logic selected_valid;
    (* MAX_FANOUT = 32 *) logic [63:0] source_pipeline_data;
    logic source_pipeline_valid;
    logic [15:0] symbols [0:3];
    logic [7:0] nrz_valid;
    logic signed [511:0] nrz_samples [0:7];
    logic signed [511:0] signed_nrz_samples [0:7];
    logic [7:0] preeq_valid;
    logic signed [511:0] preeq_samples [0:7];
    logic signed [511:0] paired_preeq_samples [0:7];
    logic signed [15:0] lane_fractional_history [0:7];
    logic signed [15:0] lane_fractional_history2 [0:7];
    logic signed [22:0] interpolation_product_reg [0:7][0:31];
    logic signed [22:0] interpolation_current_reg [0:7][0:31];
    logic [7:0] interpolation_valid;
    logic [7:0] paired_preeq_pipeline_valid;
    logic signed [511:0] paired_preeq_pipeline_samples [0:7];
    logic [7:0] delay_valid;
    logic signed [511:0] delayed_samples [0:7];
    logic [7:0] gearbox_ready;
    logic [7:0] gearbox_start_ready;
    logic [8*256-1:0] gearbox_tdata;
    logic [7:0] gearbox_tvalid;
    logic [8*256-1:0] lane_tdata;
    logic [7:0] lane_tvalid;
    logic [7:0] lane_tready;
    logic symbol_take;
    logic lane_stage_valid;
    logic lane_stage_status;
    logic lane_stage_ready;
    logic gearbox_read_enable;
    logic gearbox_read_start;
    logic gearbox_alignment_error;
    logic dac_ready_error;
    // Runtime delay/FFE updates are atomic at clk250. Keep the source and
    // asynchronous gearboxes running so a commit cannot drain the FIFOs and
    // select a different half-word phase on individual DAC lanes. At most one
    // data word straddles the old and new settings during a live update.
    wire config_reload_active = 1'b0;

    function automatic logic signed [15:0] quantize_interpolation(
        input logic signed [22:0] sum
    );
        logic signed [22:0] magnitude;
        begin
            if (sum >= 0)
                quantize_interpolation = sum >>> 5;
            else begin
                magnitude = -sum;
                quantize_interpolation = -(magnitude >>> 5);
            end
        end
    endfunction

    calibration_square_source square_source_i (
        .clk(clk250),
        .rst_n(rst250_n && !config_reload_active),
        .enable(enable250 && calibration_mode),
        .ready(source_ready),
        .data(square_data),
        .valid(square_valid)
    );

    ber_reference_replay ber_reference_i (
        .clk(clk250),
        .rst_n(rst250_n),
        .capture_pulse(ber_capture_pulse),
        .replay_enable(ber_replay_enable),
        .live_data(stream_data),
        .live_valid(stream_valid),
        .live_ready(ber_live_ready),
        .downstream_ready(source_ready),
        .output_data(ber_stream_data),
        .output_valid(ber_stream_valid),
        .reference_address(ber_reference_address),
        .reference_data(ber_reference_data),
        .reference_ready(ber_reference_ready),
        .replay_active(ber_replay_active)
    );

    assign source_ready = enable250 && (&gearbox_ready);
    assign selected_data = calibration_mode ? square_data : ber_stream_data;
    assign selected_valid = calibration_mode ? square_valid : ber_stream_valid;
    assign stream_ready = calibration_mode ? enable250 :
        (enable250 && ber_live_ready);
    assign symbol_take = selected_valid && source_ready;

    // The mapper ignores payload whenever valid is low, so capture the payload
    // unconditionally. This avoids replicating symbol_take into a 64-bit clock-
    // enable tree while preserving the ready/valid transaction boundary.
    always_ff @(posedge clk250) begin
        source_pipeline_data <= selected_data;
        if (!rst250_n || !enable250 || config_reload_active)
            source_pipeline_valid <= 1'b0;
        else
            source_pipeline_valid <= symbol_take;
    end

    dpqpsk_bit_mapper mapper_i (
        .stream_word(source_pipeline_data),
        .xi_symbols(symbols[0]),
        .xq_symbols(symbols[1]),
        .yi_symbols(symbols[2]),
        .yq_symbols(symbols[3])
    );

    always_ff @(posedge clk250) begin
        if (!rst250_n)
            source_overflow <= 1'b0;
        else if (!config_reload_active && (|delay_valid) && !(&gearbox_ready))
            source_overflow <= 1'b1;
    end

    generate
        for (genvar lane = 0; lane < 8; lane++) begin : g_lane
            localparam int COMPONENT = lane / 2;
            localparam bit PREEQ_COMPILED = ((lane & 1) == 0);
            wire [6:0] lane_delay = lane_delay_codes[lane*7 +: 7];
            wire [4:0] pair_fractional_delay =
                lane_delay_codes[(2*COMPONENT)*7 +: 5];
            wire [5:0] relative_fractional_delay =
                6'd32 + {1'b0, lane_delay[4:0]} -
                {1'b0, pair_fractional_delay};

            // RRC pulse shaping is intentionally absent. Generate a
            // rectangular two-sample-per-symbol waveform while retaining the
            // original 1/32-sample runtime timing adjustment.
            nrz_2sps_parallel32_configurable nrz_i (
                .clk(clk250),
                .rst_n(rst250_n),
                .in_valid(source_pipeline_valid),
                .symbols(symbols[COMPONENT]),
                .clear_history(!enable250 || config_reload_active),
                .config_load(delay_config_load),
                .fractional_delay(PREEQ_COMPILED ? pair_fractional_delay : 5'd0),
                .out_valid(nrz_valid[lane]),
                .samples(nrz_samples[lane])
            );

            for (genvar sample = 0; sample < 32; sample++) begin : g_polarity
                if ((lane & 1) == 0) begin : g_positive
                    assign signed_nrz_samples[lane][sample*16 +: 16] =
                        nrz_samples[lane][sample*16 +: 16];
                end else begin : g_negative
                    assign signed_nrz_samples[lane][sample*16 +: 16] =
                        -$signed(nrz_samples[lane][sample*16 +: 16]);
                end
            end

            // One runtime seven-tap, half-UI FFE is shared by each
            // differential pair. The odd lane receives an independent
            // fractional delay after the shared FFE.
            wire [16*7-1:0] lane_preeq_coeffs =
                preeq_coeffs[COMPONENT*16*7 +: 16*7];
            wire lane_preeq_enabled = preeq_enable_mask[COMPONENT];
            tx_preeq_7tap_parallel32 #(
                .BYPASS(!PREEQ_COMPILED)
            ) preemphasis_i (
                .clk(clk250),
                .rst_n(rst250_n),
                .in_valid(nrz_valid[lane]),
                .clear_history(!enable250 || config_reload_active),
                .config_load(delay_config_load),
                .bypass(calibration_mode || !lane_preeq_enabled),
                .coeffs(lane_preeq_coeffs),
                .in_samples(signed_nrz_samples[lane]),
                .out_valid(preeq_valid[lane]),
                .out_samples(preeq_samples[lane])
            );

            wire paired_lane_valid;
            if ((lane & 1) == 0) begin : g_even_valid
                assign paired_lane_valid = preeq_valid[lane];
            end else begin : g_odd_valid
                assign paired_lane_valid = preeq_valid[lane-1];
            end

            for (genvar sample = 0; sample < 32; sample++) begin : g_preeq_pair
                wire signed [15:0] pair_sample =
                    preeq_samples[2*COMPONENT][sample*16 +: 16];
                wire signed [15:0] previous_sample1;
                wire signed [15:0] previous_sample2;
                if (sample == 0) begin : g_first_sample
                    assign previous_sample1 = lane_fractional_history[lane];
                    assign previous_sample2 = lane_fractional_history2[lane];
                end else if (sample == 1) begin : g_second_sample
                    assign previous_sample1 =
                        preeq_samples[2*COMPONENT][0 +: 16];
                    assign previous_sample2 = lane_fractional_history[lane];
                end else begin : g_later_sample
                    assign previous_sample1 =
                        preeq_samples[2*COMPONENT][(sample-1)*16 +: 16];
                    assign previous_sample2 =
                        preeq_samples[2*COMPONENT][(sample-2)*16 +: 16];
                end

                if ((lane & 1) == 0) begin : g_pair_positive
                    always_ff @(posedge clk250) begin
                        interpolation_product_reg[lane][sample] <= '0;
                        interpolation_current_reg[lane][sample] <=
                            $signed({{7{previous_sample1[15]}},
                                previous_sample1}) <<< 5;
                    end
                    assign paired_preeq_samples[lane][sample*16 +: 16] =
                        quantize_interpolation(
                            interpolation_current_reg[lane][sample]);
                end else begin : g_pair_negative
                    wire signed [15:0] interpolation_base =
                        relative_fractional_delay[5] ? previous_sample1 : pair_sample;
                    wire signed [15:0] interpolation_previous =
                        relative_fractional_delay[5] ? previous_sample2 : previous_sample1;
                    wire signed [16:0] sample_delta =
                        $signed({interpolation_previous[15], interpolation_previous}) -
                        $signed({interpolation_base[15], interpolation_base});

                    always_ff @(posedge clk250) begin
                        interpolation_product_reg[lane][sample] <=
                            sample_delta *
                            $signed({1'b0, relative_fractional_delay[4:0]});
                        interpolation_current_reg[lane][sample] <=
                            $signed({{7{interpolation_base[15]}},
                                interpolation_base}) <<< 5;
                    end

                    assign paired_preeq_samples[lane][sample*16 +: 16] =
                        -$signed(quantize_interpolation(
                            interpolation_current_reg[lane][sample] +
                            interpolation_product_reg[lane][sample]));
                end
            end

            always_ff @(posedge clk250) begin
                if (!rst250_n || !enable250 || config_reload_active) begin
                    lane_fractional_history[lane] <= '0;
                    lane_fractional_history2[lane] <= '0;
                    interpolation_valid[lane] <= 1'b0;
                end else begin
                    interpolation_valid[lane] <= paired_lane_valid;
                    if (paired_lane_valid) begin
                        lane_fractional_history[lane] <=
                            preeq_samples[2*COMPONENT][31*16 +: 16];
                        lane_fractional_history2[lane] <=
                            preeq_samples[2*COMPONENT][30*16 +: 16];
                    end
                end
            end

            // Break the equalizer-to-delay path before the per-lane variable
            // sample selector. Payload is sampled unconditionally so the
            // valid signal does not become a 512-bit clock-enable tree.
            always_ff @(posedge clk250) begin
                if (!rst250_n || !enable250 || config_reload_active)
                    paired_preeq_pipeline_valid[lane] <= 1'b0;
                else
                    paired_preeq_pipeline_valid[lane] <=
                        interpolation_valid[lane];
                paired_preeq_pipeline_samples[lane] <= paired_preeq_samples[lane];
            end

            sample_delay_parallel32 integer_delay_i (
                .clk(clk250),
                .rst_n(rst250_n),
                .in_valid(paired_preeq_pipeline_valid[lane]),
                .clear_history(!enable250 || config_reload_active),
                .samples(paired_preeq_pipeline_samples[lane]),
                .delay_samples(lane_delay[6:5]),
                .out_valid(delay_valid[lane]),
                .delayed_samples(delayed_samples[lane])
            );

            sample_gearbox_512_to_256 gearbox_i (
                .wr_clk(clk250),
                .wr_rst_n(rst250_n && enable250),
                .s_data(delayed_samples[lane]),
                .s_valid(delay_valid[lane]),
                .s_ready(gearbox_ready[lane]),
                .rd_clk(clk500),
                .rd_rst_n(rst500_n && enable500),
                .read_start(gearbox_read_start),
                .start_ready(gearbox_start_ready[lane]),
                .m_data(gearbox_tdata[lane*256 +: 256]),
                .m_valid(gearbox_tvalid[lane]),
                .m_ready(gearbox_read_enable),
                .overflow(gearbox_overflow[lane]),
                .underflow(gearbox_underflow[lane])
            );
        end
    endgenerate

    // Independent XPM reset-busy synchronizers can release on different
    // clk500 cycles in silicon. Wait until every lane is buffered, then start
    // all read sides from one registered event so their TVALID phases align.
    always_ff @(posedge clk500) begin
        if (!rst500_n || !enable500 || !(&gearbox_start_ready))
            gearbox_read_start <= 1'b0;
        else
            gearbox_read_start <= 1'b1;
    end

    assign lane_stage_ready = !lane_stage_valid || (&lane_tready);
    // Each lane FIFO is written and reset atomically. Let each FIFO qualify its
    // own read with local m_valid instead of feeding an eight-lane valid
    // reduction back into every 500 MHz BRAM enable.
    // lane_stage_valid is cleared while disabled and each gearbox suppresses
    // m_valid until its local read side has restarted. The shared read command
    // therefore needs only the registered lane-stage capacity.
    assign gearbox_read_enable = lane_stage_ready;
    assign lane_tvalid = {8{lane_stage_valid && enable500}};
    assign ready_error = dac_ready_error || gearbox_alignment_error;
    assign runtime_status = {
        &dac_tready,
        &gearbox_tvalid,
        lane_stage_status,
        &delay_valid,
        &preeq_valid,
        source_pipeline_valid,
        enable500,
        enable250
    };

    always_ff @(posedge clk500) begin
        if (!rst500_n || !enable500) begin
            lane_stage_valid <= 1'b0;
            lane_stage_status <= 1'b0;
            gearbox_alignment_error <= 1'b0;
        end else if (lane_stage_ready) begin
            lane_stage_valid <= &gearbox_tvalid;
            // Keep the software-visible status on a separate register so it
            // cannot merge with the high-fanout DAC valid control net.
            lane_stage_status <= lane_stage_valid;
            // Payload contents are don't-care while lane_stage_valid is low.
            // Sampling unconditionally keeps the eight-lane valid reduction
            // off the clock enable of all 2048 payload flip-flops.
            lane_tdata <= gearbox_tdata;
            if ((|gearbox_tvalid) && !(&gearbox_tvalid))
                gearbox_alignment_error <= 1'b1;
        end
    end

    dac_axis_lane8 dac_output_i (
        .clk(clk500),
        .rst_n(rst500_n),
        .enable(enable500),
        .lane_tdata(lane_tdata),
        .lane_tvalid(lane_tvalid),
        .lane_tready(lane_tready),
        .dac_tready(dac_tready),
        .dac_tdata(dac_tdata),
        .dac_tvalid(dac_tvalid),
        .ready_error(dac_ready_error)
    );
endmodule
