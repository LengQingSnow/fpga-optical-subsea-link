`timescale 1ns/1ps

module tb_user_control;
    logic axi_gp_clk = 1'b0;
    logic axi_rst = 1'b1;
    logic up_wreq = 1'b0;
    logic [15:0] up_waddr = '0;
    logic [31:0] up_wdata = '0;
    logic up_wack;
    logic up_rreq = 1'b0;
    logic [15:0] up_raddr = '0;
    logic [31:0] up_rdata;
    logic up_rack;
    logic mtime_start;
    logic [1:0] pps_select;
    logic [31:0] clock_1pps;
    logic [11:0] phase;
    logic [3:0] rf_mode;
    logic config_done;
    logic [7:0] adc_freeze;
    logic [7:0] adc_clear_ov;
    logic [55:0] lane_delay_codes;
    logic delay_commit_toggle;
    logic [447:0] preeq_coeffs;
    logic [3:0] preeq_enable_mask;
    logic preeq_commit_toggle;
    logic ber_capture_toggle;
    logic ber_replay_enable;
    logic [5:0] ber_reference_address;

    always #5 axi_gp_clk = ~axi_gp_clk;

    user_control dut (
        .axi_gp_clk(axi_gp_clk), .axi_rst(axi_rst),
        .up_wreq(up_wreq), .up_waddr(up_waddr), .up_wdata(up_wdata),
        .up_wack(up_wack), .up_rreq(up_rreq), .up_raddr(up_raddr),
        .up_rdata(up_rdata), .up_rack(up_rack),
        .mtime_start(mtime_start), .pps_select(pps_select),
        .clock_1pps(clock_1pps), .phase(phase), .rf_mode(rf_mode),
        .config_done(config_done), .adc_freeze(adc_freeze),
        .adc_clear_ov(adc_clear_ov), .lane_delay_codes(lane_delay_codes),
        .delay_commit_toggle(delay_commit_toggle),
        .preeq_coeffs(preeq_coeffs), .preeq_enable_mask(preeq_enable_mask),
        .preeq_commit_toggle(preeq_commit_toggle),
        .ber_capture_toggle(ber_capture_toggle),
        .ber_replay_enable(ber_replay_enable),
        .ber_reference_address(ber_reference_address),
        .ber_reference_data(64'h11223344_55667788),
        .ber_reference_ready(1'b1), .ber_replay_active(1'b1),
        .sdr_info(32'h52463437), .fw_ver(32'h00030000),
        .adc_over_volt(8'h00), .dev_clk_locked(1'b1)
    );

    task write_reg(input integer word_index, input logic [31:0] value);
        begin
            @(negedge axi_gp_clk);
            up_waddr = word_index * 4;
            up_wdata = value;
            up_wreq = 1'b1;
            @(negedge axi_gp_clk);
            up_wreq = 1'b0;
        end
    endtask

    task write_reg_held(input integer word_index, input logic [31:0] value,
                        input integer cycles);
        begin
            @(negedge axi_gp_clk);
            up_waddr = word_index * 4;
            up_wdata = value;
            up_wreq = 1'b1;
            repeat (cycles) @(negedge axi_gp_clk);
            up_wreq = 1'b0;
        end
    endtask

    task read_reg(input integer word_index, output logic [31:0] value);
        begin
            @(negedge axi_gp_clk);
            up_raddr = word_index * 4;
            up_rreq = 1'b1;
            @(posedge axi_gp_clk);
            #1 value = up_rdata;
            @(negedge axi_gp_clk);
            up_rreq = 1'b0;
        end
    endtask

    initial begin
        logic [31:0] read_value;
        repeat (3) @(posedge axi_gp_clk);
        axi_rst = 1'b0;
        if (lane_delay_codes !== 56'd0 || delay_commit_toggle !== 1'b0)
            $fatal(1, "runtime calibration registers did not reset to zero");

        for (int lane = 0; lane < 8; lane++)
            write_reg(10 + lane, 7'h11 + lane);
        for (int lane = 0; lane < 8; lane++)
            if (lane_delay_codes[lane*7 +: 7] !== 7'h11 + lane)
                $fatal(1, "lane %0d delay register mismatch", lane);

        write_reg(18, 32'd1);
        if (delay_commit_toggle !== 1'b1)
            $fatal(1, "first commit did not toggle");
        write_reg(18, 32'd0);
        if (delay_commit_toggle !== 1'b1)
            $fatal(1, "zero write changed commit state");
        write_reg(18, 32'd1);
        if (delay_commit_toggle !== 1'b0)
            $fatal(1, "second commit did not toggle");
        write_reg_held(18, 32'd1, 3);
        if (delay_commit_toggle !== 1'b1)
            $fatal(1, "held write toggled commit more than once");

        write_reg(6, 32'd1);
        if (rf_mode !== 4'd1)
            $fatal(1, "runtime source mode register mismatch");

        write_reg(19 + 3*7 + 3, 32'h00007abc);
        write_reg(19 + 3*7 + 6, 32'h00008001);
        write_reg(47, 32'h0000000f);
        if (preeq_coeffs[(3*7+3)*16 +: 16] !== 16'h7abc ||
            preeq_coeffs[(3*7+6)*16 +: 16] !== 16'h8001 ||
            preeq_enable_mask !== 4'hf)
            $fatal(1, "7-tap FFE register mismatch");
        write_reg(48, 32'd1);
        if (preeq_commit_toggle !== 1'b1)
            $fatal(1, "7-tap FFE commit did not toggle");

        read_reg(3, read_value);
        if (read_value !== 32'd1)
            $fatal(1, "MMCM lock status readback mismatch");

        write_reg(65, 32'd3);
        if (ber_capture_toggle !== 1'b1 || ber_replay_enable !== 1'b1)
            $fatal(1, "BER capture/replay control write mismatch");
        read_reg(65, read_value);
        if (read_value !== 32'd3)
            $fatal(1, "BER control readback mismatch");
        read_reg(66, read_value);
        if (read_value !== 32'd3)
            $fatal(1, "BER status readback mismatch");
        read_reg(68, read_value);
        if (read_value !== 32'h55667788 || ber_reference_address !== 6'd0)
            $fatal(1, "BER reference low dword readback mismatch");
        read_reg(69, read_value);
        if (read_value !== 32'h11223344 || ber_reference_address !== 6'd0)
            $fatal(1, "BER reference high dword readback mismatch");

        $display("PASS: runtime control, FFE, and BER reference registers");
        $finish;
    end

    initial begin
        #3000;
        $fatal(1, "user control timeout");
    end
endmodule
