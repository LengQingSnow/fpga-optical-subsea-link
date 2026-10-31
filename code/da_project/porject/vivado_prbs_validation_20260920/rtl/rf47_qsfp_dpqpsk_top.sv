`timescale 1ns/1ps

module rf47_qsfp_dpqpsk_top (
    input  wire pl_clk_p,
    input  wire pl_clk_n,
    input  wire qsfp_refclk_p,
    input  wire qsfp_refclk_n,
    input  wire [0:3] qsfp_rxp,
    input  wire [0:3] qsfp_rxn,
    input  wire pl_sysref_p,
    input  wire pl_sysref_n,
    input  wire dac0_clk_p,
    input  wire dac0_clk_n,
    input  wire dac2_clk_p,
    input  wire dac2_clk_n,
    input  wire sysref_in_p,
    input  wire sysref_in_n,
    output wire vout00_p,
    output wire vout00_n,
    output wire vout02_p,
    output wire vout02_n,
    output wire vout10_p,
    output wire vout10_n,
    output wire vout12_p,
    output wire vout12_n,
    output wire vout20_p,
    output wire vout20_n,
    output wire vout22_p,
    output wire vout22_n,
    output wire vout30_p,
    output wire vout30_n,
    output wire vout32_p,
    output wire vout32_n,
    inout  wire lmk_sync,
    output wire [3:0] led
);
    wire fclk_100m;
    wire fclk_resetn;
    wire aurora_reset_ready;
    wire rx_user_clk;
    wire rx_channel_up;
    wire [0:3] rx_lane_up;
    wire rx_hard_err;
    wire rx_soft_err;
    wire [255:0] rx_raw_tdata;
    wire [255:0] rx_tdata;
    wire [31:0] rx_tkeep;
    wire rx_tvalid;
    wire rx_tlast;

    qsfp_aurora_rx qsfp_rx_i (
        .init_clk(fclk_100m),
        // Keep Aurora held in reset while the PS/RFDC startup sequence is
        // still configuring the DAC path. This prevents the upstream KU115
        // stream from filling the aggregate FIFO before the read side is
        // enabled, without adding a control path to the DAC clocks.
        .reset_request(~fclk_resetn || !config_done),
        .qsfp_refclk_p(qsfp_refclk_p),
        .qsfp_refclk_n(qsfp_refclk_n),
        .qsfp_rxp(qsfp_rxp),
        .qsfp_rxn(qsfp_rxn),
        .rx_tdata(rx_tdata),
        .rx_tkeep(rx_tkeep),
        .rx_tvalid(rx_tvalid),
        .rx_tlast(rx_tlast),
        .raw_tdata(rx_raw_tdata),
        .user_clk(rx_user_clk),
        .channel_up(rx_channel_up),
        .lane_up(rx_lane_up),
        .hard_err(rx_hard_err),
        .soft_err(rx_soft_err),
        .reset_ready(aurora_reset_ready)
    );

    wire pl_clk_ibuf;
    wire pl_clk_global;
    wire clkfb_mmcm;
    wire clkfb_mmcm_buf;
    wire clk500_mmcm;
    wire clk250_mmcm;
    wire clk500;
    wire clk250;
    wire mmcm_locked;

    IBUFDS #(
        .DIFF_TERM("FALSE"),
        .IBUF_LOW_PWR("FALSE")
    ) pl_clk_ibuf_i (
        .I(pl_clk_p),
        .IB(pl_clk_n),
        .O(pl_clk_ibuf)
    );

    BUFG pl_clk_input_bufg_i (
        .I(pl_clk_ibuf),
        .O(pl_clk_global)
    );

    MMCME4_BASE #(
        .BANDWIDTH("OPTIMIZED"),
        .CLKFBOUT_MULT_F(5.000),
        .CLKIN1_PERIOD(5.000),
        .CLKOUT0_DIVIDE_F(2.000),
        .CLKOUT1_DIVIDE(4),
        .DIVCLK_DIVIDE(1),
        .STARTUP_WAIT("FALSE")
    ) axis_mmcm_i (
        .CLKIN1(pl_clk_global),
        .CLKFBIN(clkfb_mmcm_buf),
        .RST(~fclk_resetn),
        .PWRDWN(1'b0),
        .CLKFBOUT(clkfb_mmcm),
        .CLKOUT0(clk500_mmcm),
        .CLKOUT1(clk250_mmcm),
        .LOCKED(mmcm_locked)
    );

    BUFG axis_mmcm_feedback_bufg_i (.I(clkfb_mmcm), .O(clkfb_mmcm_buf));
    BUFG axis_clk500_bufg_i (.I(clk500_mmcm), .O(clk500));
    BUFG axis_clk250_bufg_i (.I(clk250_mmcm), .O(clk250));

    wire axis_resetn;
    wire rst250_n;
    wire rx_reset_base_n;
    wire rx_stream_rst_n;
    (* ASYNC_REG = "TRUE" *) logic [1:0] rf_mode_rx_sync_ff;

    reset_sync reset_250_i (
        .clk(clk250),
        .arst_n(fclk_resetn && mmcm_locked),
        .srst_n(rst250_n)
    );

    reset_sync reset_rx_i (
        .clk(rx_user_clk),
        .arst_n(aurora_reset_ready),
        .srst_n(rx_reset_base_n)
    );

    always_ff @(posedge rx_user_clk) begin
        if (!rx_reset_base_n)
            rf_mode_rx_sync_ff <= 2'b11;
        else
            rf_mode_rx_sync_ff <= {rf_mode_rx_sync_ff[0], rf_mode[0]};
    end

    // Hold the aggregate receive path in reset while the local square source
    // drives the DACs. Otherwise QSFP keeps filling the FIFO with data that
    // cannot be consumed until calibration ends, leaving a stale overflow
    // and partial-frame backlog when the source switches back to QSFP.
    assign rx_stream_rst_n = rx_reset_base_n && rx_channel_up &&
                             !rf_mode_rx_sync_ff[1];

    wire [255:0] aligned_tdata;
    wire aligned_tvalid;
    wire aligned_frame_start;
    wire aligned_frame_end;
    wire frame_locked;
    wire [31:0] frame_count;
    wire [31:0] header_error_count;
    wire [31:0] keep_error_count;

    aggregate_frame_aligner aligner_i (
        .clk(rx_user_clk),
        .rst_n(rx_stream_rst_n),
        .s_data(rx_tdata),
        .s_keep(rx_tkeep),
        .s_valid(rx_tvalid),
        .m_data(aligned_tdata),
        .m_valid(aligned_tvalid),
        .frame_start(aligned_frame_start),
        .frame_end(aligned_frame_end),
        .locked(frame_locked),
        .frame_count(frame_count),
        .header_error_count(header_error_count),
        .keep_error_count(keep_error_count)
    );

    wire [255:0] rate_matched_tdata;
    wire rate_matched_tvalid;
    wire rate_matched_frame_start;
    wire rate_matched_frame_end;
    wire fifo_near_full;
    wire dropping_idle_frame;
    wire idle_frame_dropped;
    wire [31:0] dropped_idle_frame_count;

    aggregate_idle_frame_dropper idle_rate_matcher_i (
        .clk(rx_user_clk),
        .rst_n(rx_stream_rst_n),
        .s_data(aligned_tdata),
        .s_valid(aligned_tvalid),
        .s_frame_start(aligned_frame_start),
        .s_frame_end(aligned_frame_end),
        .near_full(fifo_near_full),
        .m_data(rate_matched_tdata),
        .m_valid(rate_matched_tvalid),
        .m_frame_start(rate_matched_frame_start),
        .m_frame_end(rate_matched_frame_end),
        .dropping_idle_frame(dropping_idle_frame),
        .idle_frame_dropped(idle_frame_dropped),
        .dropped_idle_frame_count(dropped_idle_frame_count)
    );

    wire [63:0] stream_data;
    wire stream_valid;
    wire stream_ready;
    wire fifo_input_ready;
    wire fifo_streaming;
    wire fifo_overflow;
    wire fifo_underflow;
    aggregate_stream_fifo #(
        // Aurora can deliver a finite 256-bit burst faster than the fixed
        // 64-bit/250 MHz DAC-side drain rate.  Keep enough BRAM-backed
        // storage for that burst before declaring an aggregate FIFO overrun.
        .FIFO_WRITE_DEPTH(32768),
        // Start draining as soon as a small prefetch is available. Keeping
        // the full write depth as headroom is more useful than waiting for
        // an 8K-word write-side fill before the DAC path can consume data.
        .START_THRESHOLD_READ_WORDS(256),
        // Correct independent KU115/RF47 clock drift before the FIFO can
        // truncate a frame. The matcher may discard only complete idle
        // frames while this 64 KiB write-side headroom remains available.
        .HIGH_WATER_HEADROOM_WRITE_WORDS(2048)
    ) stream_fifo_i (
        .wr_clk(rx_user_clk),
        .wr_rst_n(rx_stream_rst_n),
        .s_data(rate_matched_tdata),
        .s_valid(rate_matched_tvalid),
        .s_ready(fifo_input_ready),
        .rd_clk(clk250),
        .rd_rst_n(rst250_n),
        .m_data(stream_data),
        .m_valid(stream_valid),
        .m_ready(stream_ready),
        .streaming(fifo_streaming),
        .near_full(fifo_near_full),
        .overflow(fifo_overflow),
        .underflow(fifo_underflow)
    );

    wire pl_sysref_ibuf;
    IBUFDS #(
        .DIFF_TERM("FALSE"),
        .IBUF_LOW_PWR("FALSE")
    ) pl_sysref_ibuf_i (
        .I(pl_sysref_p),
        .IB(pl_sysref_n),
        .O(pl_sysref_ibuf)
    );

    wire user_sysref_dac;
    pl_sysref_capture sysref_capture_i (
        .clk(clk500),
        .rst_n(axis_resetn),
        .sysref_async(pl_sysref_ibuf),
        .sysref_sync(user_sysref_dac)
    );

    wire [15:0] gpio_tri_i;
    wire [15:0] gpio_tri_o;
    wire [15:0] gpio_tri_t;
    assign gpio_tri_i[15:1] = 15'd0;

    IOBUF lmk_sync_iobuf_i (
        .I(gpio_tri_o[0]),
        .T(gpio_tri_t[0]),
        .O(gpio_tri_i[0]),
        .IO(lmk_sync)
    );

    wire up_rack;
    wire [15:0] up_raddr;
    wire [31:0] up_rdata;
    wire up_rreq;
    wire up_wack;
    wire [15:0] up_waddr;
    wire [31:0] up_wdata;
    wire up_wreq;
    wire mtime_start;
    wire [1:0] pps_select;
    wire [31:0] clock_1pps;
    wire [11:0] phase;
    wire [3:0] rf_mode;
    wire config_done;
    wire [7:0] adc_freeze;
    wire [7:0] adc_clear_ov;
    wire [55:0] lane_delay_codes_axi;
    wire delay_commit_toggle;
    wire [447:0] preeq_coeffs_axi;
    wire [3:0] preeq_enable_mask_axi;
    wire preeq_commit_toggle;
    wire ber_capture_toggle;
    wire ber_replay_enable;
    wire [5:0] ber_reference_address;
    wire [63:0] ber_reference_data;
    wire ber_reference_ready;
    wire ber_replay_active;
    wire [7:0] runtime_status;
    (* ASYNC_REG = "TRUE" *) logic [7:0] runtime_status_sync_ff1;
    (* ASYNC_REG = "TRUE" *) logic [7:0] runtime_status_sync_ff2;
    (* ASYNC_REG = "TRUE" *) logic [1:0] ber_reference_ready_sync_ff;
    (* ASYNC_REG = "TRUE" *) logic [1:0] ber_replay_active_sync_ff;

    user_control control_i (
        .axi_gp_clk(fclk_100m),
        .axi_rst(~fclk_resetn),
        .up_wreq(up_wreq), .up_waddr(up_waddr), .up_wdata(up_wdata), .up_wack(up_wack),
        .up_rreq(up_rreq), .up_raddr(up_raddr), .up_rdata(up_rdata), .up_rack(up_rack),
        .mtime_start(mtime_start), .pps_select(pps_select), .clock_1pps(clock_1pps),
        .phase(phase), .rf_mode(rf_mode), .config_done(config_done),
        .adc_freeze(adc_freeze), .adc_clear_ov(adc_clear_ov),
        .lane_delay_codes(lane_delay_codes_axi),
        .delay_commit_toggle(delay_commit_toggle),
        .preeq_coeffs(preeq_coeffs_axi),
        .preeq_enable_mask(preeq_enable_mask_axi),
        .preeq_commit_toggle(preeq_commit_toggle),
        .ber_capture_toggle(ber_capture_toggle),
        .ber_replay_enable(ber_replay_enable),
        .ber_reference_address(ber_reference_address),
        .ber_reference_data(ber_reference_data),
        .ber_reference_ready(ber_reference_ready_sync_ff[1]),
        .ber_replay_active(ber_replay_active_sync_ff[1]),
        .sdr_info(32'h52463437), .fw_ver(32'h00043101),
        .adc_over_volt(runtime_status_sync_ff2), .dev_clk_locked(mmcm_locked)
    );

    (* ASYNC_REG = "TRUE" *) logic [1:0] mtime_start_sync_ff;
    (* ASYNC_REG = "TRUE" *) logic [1:0] config_done_sync_ff;
    (* ASYNC_REG = "TRUE" *) logic [1:0] rf_mode_sync_ff;
    (* ASYNC_REG = "TRUE" *) logic [1:0] ber_capture_sync_ff;
    (* ASYNC_REG = "TRUE" *) logic [1:0] ber_replay_enable_sync_ff;
    wire ber_capture_pulse_250 = ber_capture_sync_ff[1] ^ ber_capture_sync_ff[0];
    wire ber_replay_enable_250 = ber_replay_enable_sync_ff[1];
    always_ff @(posedge clk250) begin
        if (!rst250_n) begin
            mtime_start_sync_ff <= 2'b00;
            config_done_sync_ff <= 2'b00;
            rf_mode_sync_ff <= 2'b00;
            ber_capture_sync_ff <= 2'b00;
            ber_replay_enable_sync_ff <= 2'b00;
        end else begin
            mtime_start_sync_ff <= {mtime_start_sync_ff[0], mtime_start};
            config_done_sync_ff <= {config_done_sync_ff[0], config_done};
            rf_mode_sync_ff <= {rf_mode_sync_ff[0], rf_mode[0]};
            ber_capture_sync_ff <= {ber_capture_sync_ff[0], ber_capture_toggle};
            ber_replay_enable_sync_ff <= {
                ber_replay_enable_sync_ff[0], ber_replay_enable
            };
        end
    end

    wire [55:0] lane_delay_codes_250;
    wire delay_config_load_250;
    runtime_config_cdc delay_config_cdc_i (
        .src_clk(fclk_100m),
        .src_rst(~fclk_resetn),
        .src_delay_codes(lane_delay_codes_axi),
        .src_commit_toggle(delay_commit_toggle),
        .dst_clk(clk250),
        .dst_rst_n(rst250_n),
        .dst_delay_codes(lane_delay_codes_250),
        .dst_commit_pulse(delay_config_load_250)
    );

    // Four component vectors x seven half-UI taps x 16-bit Q15, plus four enables.
    wire [451:0] preeq_config_250;
    wire preeq_config_load_250;
    wire [447:0] preeq_coeffs_250 = preeq_config_250[447:0];
    wire [3:0] preeq_enable_mask_250 = preeq_config_250[451:448];
    wire datapath_config_load_250 = delay_config_load_250 || preeq_config_load_250;
    preeq_config_cdc #(.CONFIG_WIDTH(452)) preeq_config_cdc_i (
        .src_clk(fclk_100m),
        .src_rst(~fclk_resetn),
        .src_config({preeq_enable_mask_axi, preeq_coeffs_axi}),
        .src_commit_toggle(preeq_commit_toggle),
        .dst_clk(clk250),
        .dst_rst_n(rst250_n),
        .dst_config(preeq_config_250),
        .dst_commit_pulse(preeq_config_load_250)
    );

    wire [8*256-1:0] active_dac_tdata;
    wire [7:0] active_dac_tvalid;
    wire [7:0] active_dac_tready;
    wire [7:0] gearbox_overflow;
    wire [7:0] gearbox_underflow;
    wire source_overflow;
    wire ready_error;
    wire datapath_enable_250 = mtime_start_sync_ff[1] && config_done_sync_ff[1];
    (* ASYNC_REG = "TRUE" *) logic [1:0] datapath_enable_500_sync_ff;
    always_ff @(posedge clk500) begin
        if (!axis_resetn)
            datapath_enable_500_sync_ff <= 2'b00;
        else
            datapath_enable_500_sync_ff <= {
                datapath_enable_500_sync_ff[0], datapath_enable_250
            };
    end

    rf47_qsfp_rrc_core core_i (
        .clk250(clk250), .rst250_n(rst250_n),
        .clk500(clk500), .rst500_n(axis_resetn),
        .enable250(datapath_enable_250),
        .enable500(datapath_enable_500_sync_ff[1]),
        .calibration_mode(rf_mode_sync_ff[1]),
        .lane_delay_codes(lane_delay_codes_250),
        .delay_config_load(datapath_config_load_250),
        .preeq_enable_mask(preeq_enable_mask_250),
        .preeq_coeffs(preeq_coeffs_250),
        .ber_capture_pulse(ber_capture_pulse_250),
        .ber_replay_enable(ber_replay_enable_250),
        .ber_reference_address(ber_reference_address),
        .ber_reference_data(ber_reference_data),
        .ber_reference_ready(ber_reference_ready),
        .ber_replay_active(ber_replay_active),
        .stream_data(stream_data), .stream_valid(stream_valid), .stream_ready(stream_ready),
        .dac_tready(active_dac_tready), .dac_tdata(active_dac_tdata),
        .dac_tvalid(active_dac_tvalid),
        .gearbox_overflow(gearbox_overflow), .gearbox_underflow(gearbox_underflow),
        .source_overflow(source_overflow), .ready_error(ready_error),
        .runtime_status(runtime_status)
    );

    always_ff @(posedge fclk_100m) begin
        if (!fclk_resetn) begin
            runtime_status_sync_ff1 <= '0;
            runtime_status_sync_ff2 <= '0;
            ber_reference_ready_sync_ff <= 2'b00;
            ber_replay_active_sync_ff <= 2'b00;
        end else begin
            runtime_status_sync_ff1 <= runtime_status;
            runtime_status_sync_ff2 <= runtime_status_sync_ff1;
            ber_reference_ready_sync_ff <= {
                ber_reference_ready_sync_ff[0], ber_reference_ready
            };
            ber_replay_active_sync_ff <= {
                ber_replay_active_sync_ff[0], ber_replay_active
            };
        end
    end

    wire s00_axis_tready;
    wire s02_axis_tready;
    wire s10_axis_tready;
    wire s12_axis_tready;
    wire s20_axis_tready;
    wire s22_axis_tready;
    wire s30_axis_tready;
    wire s32_axis_tready;

    assign active_dac_tready = {
        s32_axis_tready, s30_axis_tready, s22_axis_tready, s20_axis_tready,
        s12_axis_tready, s10_axis_tready, s02_axis_tready, s00_axis_tready
    };

    system system_i (
        .GPIO0_tri_i(gpio_tri_i), .GPIO0_tri_o(gpio_tri_o), .GPIO0_tri_t(gpio_tri_t),
        .axis_clk(clk500), .axis_locked(mmcm_locked), .axis_resetn(axis_resetn),
        .dac0_clk_clk_p(dac0_clk_p), .dac0_clk_clk_n(dac0_clk_n),
        .dac2_clk_clk_p(dac2_clk_p), .dac2_clk_clk_n(dac2_clk_n),
        .fclk_100m(fclk_100m), .pl_resetn0(fclk_resetn),
        .s00_axis_tdata(active_dac_tdata[0*256 +: 256]),
        .s00_axis_tvalid(active_dac_tvalid[0]), .s00_axis_tready(s00_axis_tready),
        .s02_axis_tdata(active_dac_tdata[1*256 +: 256]),
        .s02_axis_tvalid(active_dac_tvalid[1]), .s02_axis_tready(s02_axis_tready),
        .s10_axis_tdata(active_dac_tdata[2*256 +: 256]),
        .s10_axis_tvalid(active_dac_tvalid[2]), .s10_axis_tready(s10_axis_tready),
        .s12_axis_tdata(active_dac_tdata[3*256 +: 256]),
        .s12_axis_tvalid(active_dac_tvalid[3]), .s12_axis_tready(s12_axis_tready),
        .s20_axis_tdata(active_dac_tdata[4*256 +: 256]),
        .s20_axis_tvalid(active_dac_tvalid[4]), .s20_axis_tready(s20_axis_tready),
        .s22_axis_tdata(active_dac_tdata[5*256 +: 256]),
        .s22_axis_tvalid(active_dac_tvalid[5]), .s22_axis_tready(s22_axis_tready),
        .s30_axis_tdata(active_dac_tdata[6*256 +: 256]),
        .s30_axis_tvalid(active_dac_tvalid[6]), .s30_axis_tready(s30_axis_tready),
        .s32_axis_tdata(active_dac_tdata[7*256 +: 256]),
        .s32_axis_tvalid(active_dac_tvalid[7]), .s32_axis_tready(s32_axis_tready),
        .sysref_in_diff_p(sysref_in_p), .sysref_in_diff_n(sysref_in_n),
        .user_sysref_dac(user_sysref_dac),
        .up_rack(up_rack), .up_raddr(up_raddr), .up_rdata(up_rdata), .up_rreq(up_rreq),
        .up_wack(up_wack), .up_waddr(up_waddr), .up_wdata(up_wdata), .up_wreq(up_wreq),
        .vout00_v_p(vout00_p), .vout00_v_n(vout00_n),
        .vout02_v_p(vout02_p), .vout02_v_n(vout02_n),
        .vout10_v_p(vout10_p), .vout10_v_n(vout10_n),
        .vout12_v_p(vout12_p), .vout12_v_n(vout12_n),
        .vout20_v_p(vout20_p), .vout20_v_n(vout20_n),
        .vout22_v_p(vout22_p), .vout22_v_n(vout22_n),
        .vout30_v_p(vout30_p), .vout30_v_n(vout30_n),
        .vout32_v_p(vout32_p), .vout32_v_n(vout32_n)
    );

    (* ASYNC_REG = "TRUE" *) logic [3:0] rx_diag_sync_ff1;
    (* ASYNC_REG = "TRUE" *) logic [3:0] rx_diag_sync_ff2;
    always_ff @(posedge rx_user_clk) begin
        if (!rx_stream_rst_n) begin
            rx_diag_sync_ff1 <= 4'b0000;
            rx_diag_sync_ff2 <= 4'b0000;
        end else begin
            rx_diag_sync_ff1 <= {
                fifo_streaming, fifo_overflow, fifo_underflow, mmcm_locked
            };
            rx_diag_sync_ff2 <= rx_diag_sync_ff1;
        end
    end

    ila_rf47_qsfp_rx qsfp_ila_i (
        .clk(rx_user_clk),
        .probe0({rx_channel_up, rx_lane_up, rx_hard_err}),
        .probe1({rx_soft_err, frame_locked, aligned_frame_start, aligned_frame_end,
                 rx_diag_sync_ff2}),
        .probe2(frame_count),
        .probe3(header_error_count),
        .probe4(dropped_idle_frame_count),
        .probe5(rx_raw_tdata),
        .probe6(aligned_tdata),
        .probe7({rx_tvalid, rate_matched_tvalid, fifo_input_ready,
                 dropping_idle_frame})
    );

    wire any_error = rx_hard_err | rx_soft_err | fifo_overflow | fifo_underflow |
                     (|gearbox_overflow) | (|gearbox_underflow) |
                     source_overflow | ready_error;
    assign led[0] = rx_channel_up && (&rx_lane_up);
    assign led[1] = frame_locked;
    assign led[2] = config_done;
    assign led[3] = ~any_error;
endmodule
