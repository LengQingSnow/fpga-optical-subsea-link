`timescale 1ns/1ps

module rf47_prbs_rrc_top (
    input  wire pl_clk_p,
    input  wire pl_clk_n,
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
    wire pl_clk_ibuf;
    wire pl_clk_global;
    wire pl_sysref_ibuf;
    wire clkfb_mmcm;
    wire clkfb_mmcm_buf;
    wire clk500_mmcm;
    wire clk250_mmcm;
    wire clk500;
    wire clk250;
    wire mmcm_locked;
    wire axis_resetn;
    wire rst250_n;
    wire fclk_100m;
    wire fclk_resetn;

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

    BUFG axis_mmcm_feedback_bufg_i (
        .I(clkfb_mmcm),
        .O(clkfb_mmcm_buf)
    );

    BUFG pl_clk_500_bufg_i (
        .I(clk500_mmcm),
        .O(clk500)
    );

    BUFG pl_clk_250_bufg_i (
        .I(clk250_mmcm),
        .O(clk250)
    );

    IBUFDS #(
        .DIFF_TERM("FALSE"),
        .IBUF_LOW_PWR("FALSE")
    ) pl_sysref_ibuf_i (
        .I(pl_sysref_p),
        .IB(pl_sysref_n),
        .O(pl_sysref_ibuf)
    );

    reset_sync reset_250_i (
        .clk(clk250),
        .arst_n(axis_resetn),
        .srst_n(rst250_n)
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

    user_control control_i (
        .axi_gp_clk(fclk_100m),
        .axi_rst(~fclk_resetn),
        .up_wreq(up_wreq),
        .up_waddr(up_waddr),
        .up_wdata(up_wdata),
        .up_wack(up_wack),
        .up_rreq(up_rreq),
        .up_raddr(up_raddr),
        .up_rdata(up_rdata),
        .up_rack(up_rack),
        .mtime_start(mtime_start),
        .pps_select(pps_select),
        .clock_1pps(clock_1pps),
        .phase(phase),
        .rf_mode(rf_mode),
        .config_done(config_done),
        .adc_freeze(adc_freeze),
        .adc_clear_ov(adc_clear_ov),
        .sdr_info(32'h52463437),
        .fw_ver(32'h00010000),
        .adc_over_volt(8'h00),
        .dev_clk_locked(1'b1)
    );

    (* ASYNC_REG = "TRUE" *) logic [1:0] mtime_start_sync_ff;
    (* ASYNC_REG = "TRUE" *) logic [1:0] config_done_sync_ff;
    always_ff @(posedge clk250) begin
        if (!rst250_n) begin
            mtime_start_sync_ff <= 2'b00;
            config_done_sync_ff <= 2'b00;
        end else begin
            mtime_start_sync_ff <= {mtime_start_sync_ff[0], mtime_start};
            config_done_sync_ff <= {config_done_sync_ff[0], config_done};
        end
    end

    wire [8*256-1:0] active_dac_tdata;
    wire [7:0] active_dac_tvalid;
    wire [7:0] active_dac_tready;
    wire [30:0] prbs_state;
    wire fifo_overflow;
    wire fifo_underflow;
    wire source_overflow;
    wire ready_error;

    rf47_prbs_rrc_core core_i (
        .clk250(clk250),
        .rst250_n(rst250_n),
        .clk500(clk500),
        .rst500_n(axis_resetn),
        .enable(mtime_start_sync_ff[1] && config_done_sync_ff[1]),
        .dac_tready(active_dac_tready),
        .dac_tdata(active_dac_tdata),
        .dac_tvalid(active_dac_tvalid),
        .prbs_state(prbs_state),
        .fifo_overflow(fifo_overflow),
        .fifo_underflow(fifo_underflow),
        .source_overflow(source_overflow),
        .ready_error(ready_error)
    );

    wire s00_axis_tready;
    wire s02_axis_tready;
    wire s10_axis_tready;
    wire s12_axis_tready;
    wire s20_axis_tready;
    wire s22_axis_tready;
    wire s30_axis_tready;
    wire s32_axis_tready;

    assign active_dac_tready = {
        s32_axis_tready, s30_axis_tready,
        s22_axis_tready, s20_axis_tready,
        s12_axis_tready, s10_axis_tready,
        s02_axis_tready, s00_axis_tready
    };

    system system_i (
        .GPIO0_tri_i(gpio_tri_i),
        .GPIO0_tri_o(gpio_tri_o),
        .GPIO0_tri_t(gpio_tri_t),
        .axis_clk(clk500),
        .axis_locked(mmcm_locked),
        .axis_resetn(axis_resetn),
        .dac0_clk_clk_p(dac0_clk_p),
        .dac0_clk_clk_n(dac0_clk_n),
        .dac2_clk_clk_p(dac2_clk_p),
        .dac2_clk_clk_n(dac2_clk_n),
        .fclk_100m(fclk_100m),
        .pl_resetn0(fclk_resetn),
        .s00_axis_tdata(active_dac_tdata[0*256 +: 256]),
        .s00_axis_tvalid(active_dac_tvalid[0]),
        .s00_axis_tready(s00_axis_tready),
        .s02_axis_tdata(active_dac_tdata[1*256 +: 256]),
        .s02_axis_tvalid(active_dac_tvalid[1]),
        .s02_axis_tready(s02_axis_tready),
        .s10_axis_tdata(active_dac_tdata[2*256 +: 256]),
        .s10_axis_tvalid(active_dac_tvalid[2]),
        .s10_axis_tready(s10_axis_tready),
        .s12_axis_tdata(active_dac_tdata[3*256 +: 256]),
        .s12_axis_tvalid(active_dac_tvalid[3]),
        .s12_axis_tready(s12_axis_tready),
        .s20_axis_tdata(active_dac_tdata[4*256 +: 256]),
        .s20_axis_tvalid(active_dac_tvalid[4]),
        .s20_axis_tready(s20_axis_tready),
        .s22_axis_tdata(active_dac_tdata[5*256 +: 256]),
        .s22_axis_tvalid(active_dac_tvalid[5]),
        .s22_axis_tready(s22_axis_tready),
        .s30_axis_tdata(active_dac_tdata[6*256 +: 256]),
        .s30_axis_tvalid(active_dac_tvalid[6]),
        .s30_axis_tready(s30_axis_tready),
        .s32_axis_tdata(active_dac_tdata[7*256 +: 256]),
        .s32_axis_tvalid(active_dac_tvalid[7]),
        .s32_axis_tready(s32_axis_tready),
        .sysref_in_diff_p(sysref_in_p),
        .sysref_in_diff_n(sysref_in_n),
        .user_sysref_dac(user_sysref_dac),
        .up_rack(up_rack),
        .up_raddr(up_raddr),
        .up_rdata(up_rdata),
        .up_rreq(up_rreq),
        .up_wack(up_wack),
        .up_waddr(up_waddr),
        .up_wdata(up_wdata),
        .up_wreq(up_wreq),
        .vout00_v_p(vout00_p),
        .vout00_v_n(vout00_n),
        .vout02_v_p(vout02_p),
        .vout02_v_n(vout02_n),
        .vout10_v_p(vout10_p),
        .vout10_v_n(vout10_n),
        .vout12_v_p(vout12_p),
        .vout12_v_n(vout12_n),
        .vout20_v_p(vout20_p),
        .vout20_v_n(vout20_n),
        .vout22_v_p(vout22_p),
        .vout22_v_n(vout22_n),
        .vout30_v_p(vout30_p),
        .vout30_v_n(vout30_n),
        .vout32_v_p(vout32_p),
        .vout32_v_n(vout32_n)
    );

    wire any_error = fifo_overflow | fifo_underflow | source_overflow | ready_error;
    assign led[0] = &active_dac_tready;
    assign led[1] = &active_dac_tvalid;
    assign led[2] = config_done;
    assign led[3] = ~any_error;
endmodule
