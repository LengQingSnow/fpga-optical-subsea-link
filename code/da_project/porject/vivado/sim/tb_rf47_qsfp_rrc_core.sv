`timescale 1ns/1ps

module tb_rf47_qsfp_rrc_core;
    logic clk250 = 1'b0;
    logic clk500 = 1'b0;
    logic rst250_n = 1'b0;
    logic rst500_n = 1'b0;
    logic enable250 = 1'b0;
    logic enable500 = 1'b0;
    logic calibration_mode = 1'b0;
    logic [55:0] lane_delay_codes = '0;
    logic delay_config_load = 1'b0;
    logic [3:0] preeq_enable_mask = 4'b0000;
    logic [447:0] preeq_coeffs = '0;
    logic ber_capture_pulse = 1'b0;
    logic ber_replay_enable = 1'b0;
    logic [5:0] ber_reference_address = '0;
    logic [63:0] ber_reference_data;
    logic ber_reference_ready;
    logic ber_replay_active;
    logic [63:0] stream_data = '0;
    logic stream_valid = 1'b0;
    logic stream_ready;
    logic [7:0] dac_tready = 8'hff;
    logic [8*256-1:0] dac_tdata;
    logic [7:0] dac_tvalid;
    logic [7:0] gearbox_overflow;
    logic [7:0] gearbox_underflow;
    logic source_overflow;
    logic ready_error;
    logic [7:0] runtime_status;
    integer valid_words = 0;
    logic xi_xq_different = 1'b0;
    logic xi_yi_different = 1'b0;
    logic xi_yq_different = 1'b0;
    logic calibration_equal = 1'b1;
    logic calibration_check = 1'b0;
    logic calibration_nonzero = 1'b0;
    logic calibration_changed = 1'b0;
    logic [255:0] calibration_previous = '0;
    logic calibration_previous_valid = 1'b0;

    always #2 clk250 = ~clk250;
    always #1 clk500 = ~clk500;

    rf47_qsfp_rrc_core dut (
        .clk250(clk250), .rst250_n(rst250_n),
        .clk500(clk500), .rst500_n(rst500_n),
        .enable250(enable250), .enable500(enable500),
        .calibration_mode(calibration_mode),
        .lane_delay_codes(lane_delay_codes),
        .delay_config_load(delay_config_load),
        .preeq_enable_mask(preeq_enable_mask),
        .preeq_coeffs(preeq_coeffs),
        .ber_capture_pulse(ber_capture_pulse),
        .ber_replay_enable(ber_replay_enable),
        .ber_reference_address(ber_reference_address),
        .ber_reference_data(ber_reference_data),
        .ber_reference_ready(ber_reference_ready),
        .ber_replay_active(ber_replay_active),
        .stream_data(stream_data), .stream_valid(stream_valid), .stream_ready(stream_ready),
        .dac_tready(dac_tready), .dac_tdata(dac_tdata), .dac_tvalid(dac_tvalid),
        .gearbox_overflow(gearbox_overflow), .gearbox_underflow(gearbox_underflow),
        .source_overflow(source_overflow), .ready_error(ready_error),
        .runtime_status(runtime_status)
    );

    task send_stream_word(input int index);
        begin
            @(negedge clk250);
            while (!stream_ready) @(negedge clk250);
            stream_data = 64'h8421_F00F_A55A_3CC3 ^ (64'h0101_0101_0101_0101 * index);
            stream_valid = 1'b1;
            @(negedge clk250);
            stream_valid = 1'b0;
        end
    endtask

    always @(posedge clk500) begin
        if (dac_tvalid == 8'hff) begin
            for (int component = 0; component < 4; component++) begin
                for (int sample = 0; sample < 16; sample++) begin
                    if ($signed(dac_tdata[(2*component+1)*256 + sample*16 +: 16]) !==
                        -$signed(dac_tdata[(2*component)*256 + sample*16 +: 16]))
                        $fatal(1, "P/N mismatch component=%0d sample=%0d", component, sample);
                end
            end
            if (dac_tdata[0*256 +: 256] != dac_tdata[2*256 +: 256]) xi_xq_different <= 1'b1;
            if (dac_tdata[0*256 +: 256] != dac_tdata[4*256 +: 256]) xi_yi_different <= 1'b1;
            if (dac_tdata[0*256 +: 256] != dac_tdata[6*256 +: 256]) xi_yq_different <= 1'b1;
            if (calibration_check) begin
                if ((dac_tdata[0*256 +: 256] != dac_tdata[2*256 +: 256]) ||
                    (dac_tdata[0*256 +: 256] != dac_tdata[4*256 +: 256]) ||
                    (dac_tdata[0*256 +: 256] != dac_tdata[6*256 +: 256]))
                    calibration_equal <= 1'b0;
                if (dac_tdata[0*256 +: 256] != '0)
                    calibration_nonzero <= 1'b1;
                if (calibration_previous_valid &&
                    (dac_tdata[0*256 +: 256] != calibration_previous))
                    calibration_changed <= 1'b1;
                calibration_previous <= dac_tdata[0*256 +: 256];
                calibration_previous_valid <= 1'b1;
            end
            if (dac_tready == 8'hff)
                valid_words++;
        end
    end

    initial begin
        repeat (10) @(posedge clk500);
        rst250_n = 1'b1;
        rst500_n = 1'b1;
        enable250 = 1'b1;
        enable500 = 1'b1;
        dac_tready = 8'h00;
        for (int i = 0; i < 16; i++)
            send_stream_word(i);
        repeat (8) @(posedge clk500);
        dac_tready = 8'hff;
        wait (valid_words == 32);
        enable250 = 1'b0;
        repeat (20) @(posedge clk500);
        if (valid_words != 32)
            $fatal(1, "expected exactly 32 drained DAC words, got %0d", valid_words);
        if (!(xi_xq_different && xi_yi_different && xi_yq_different))
            $fatal(1, "four NRZ component outputs were not independent");
        if ((|gearbox_overflow) || (|gearbox_underflow) || source_overflow)
            $fatal(1, "unexpected core data-path error");

        enable500 = 1'b0;
        rst250_n = 1'b0;
        rst500_n = 1'b0;
        repeat (8) @(posedge clk500);
        valid_words = 0;
        calibration_check = 1'b1;
        calibration_mode = 1'b1;
        stream_valid = 1'b1;
        stream_data = 64'h1234_5678_9abc_def0;
        rst250_n = 1'b1;
        rst500_n = 1'b1;
        enable250 = 1'b1;
        enable500 = 1'b1;
        wait (valid_words >= 24);
        if (runtime_status !== 8'hff)
            $fatal(1, "runtime pipeline status incomplete: %02x", runtime_status);
        if (!stream_ready)
            $fatal(1, "calibration mode did not drain the QSFP input");
        if (!calibration_equal)
            $fatal(1, "calibration source did not drive four identical components");
        if (!calibration_nonzero)
            $fatal(1, "calibration source produced only zero-valued DAC samples");
        if (!calibration_changed)
            $fatal(1, "calibration source DAC samples did not change over time");
        calibration_check = 1'b0;

        for (int reload = 0; reload < 2; reload++) begin
            @(negedge clk250);
            for (int lane = 0; lane < 8; lane++)
                lane_delay_codes[lane*7 +: 7] =
                    4 + 8*reload + 16*(lane/2);
            delay_config_load = 1'b1;
            @(posedge clk250);
            #1;
            if (dut.g_lane[0].gearbox_i.fifo_reset ||
                dut.g_lane[1].gearbox_i.fifo_reset ||
                dut.g_lane[2].gearbox_i.fifo_reset ||
                dut.g_lane[3].gearbox_i.fifo_reset ||
                dut.g_lane[4].gearbox_i.fifo_reset ||
                dut.g_lane[5].gearbox_i.fifo_reset ||
                dut.g_lane[6].gearbox_i.fifo_reset ||
                dut.g_lane[7].gearbox_i.fifo_reset)
                $fatal(1, "runtime delay commit reset a gearbox FIFO");
            @(negedge clk250);
            delay_config_load = 1'b0;
            repeat (16) @(posedge clk500);
            if (runtime_status !== 8'hff)
                $fatal(1, "runtime pipeline did not recover after reload %0d", reload);
            if (dut.config_reload_active)
                $fatal(1, "runtime delay commit paused the source pipeline");
            if (!(dut.g_lane[0].gearbox_i.read_active &&
                  dut.g_lane[1].gearbox_i.read_active &&
                  dut.g_lane[2].gearbox_i.read_active &&
                  dut.g_lane[3].gearbox_i.read_active &&
                  dut.g_lane[4].gearbox_i.read_active &&
                  dut.g_lane[5].gearbox_i.read_active &&
                  dut.g_lane[6].gearbox_i.read_active &&
                  dut.g_lane[7].gearbox_i.read_active))
                $fatal(1, "runtime delay commit restarted a gearbox read phase");
        end

        enable250 = 1'b0;
        stream_valid = 1'b0;
        repeat (20) @(posedge clk500);
        if ((|gearbox_overflow) || source_overflow)
            $fatal(1, "unexpected calibration data-path overflow");

        $display("PASS: QSFP and local square modes drive eight aligned DAC lanes");
        $finish;
    end

    initial begin
        #30000;
        $fatal(1, "core timeout valid_words=%0d", valid_words);
    end
endmodule
