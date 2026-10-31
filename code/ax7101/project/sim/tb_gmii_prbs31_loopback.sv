`timescale 1ns/1ps

module tb_gmii_prbs31_loopback;
    localparam [63:0] BITS_PER_FRAME = 64'd11872;

    reg clk = 1'b0;
    reg rst_n = 1'b0;
    reg [1:0] selected_port = 2'd0;
    reg inject_one_bit = 1'b0;
    reg drop_frame = 1'b0;

    wire en1, en2, en3;
    wire er1, er2, er3;
    wire [7:0] data1, data2, data3;
    wire [31:0] seq1, seq2, seq3;
    wire [31:0] tx_count1, tx_count2, tx_count3;

    reg [15:0] mux_byte_index = 16'd0;
    reg mux_in_frame = 1'b0;
    wire selected_en;
    wire selected_er;
    wire [7:0] selected_data;
    wire corrupted_byte;
    wire rx_dv;
    wire rx_er;
    wire [7:0] rx_data;

    wire [1:0] current_source;
    wire [31:0] good_frames_1;
    wire [31:0] good_frames_2;
    wire [31:0] good_frames_3;
    wire [31:0] fcs_errors_1;
    wire [31:0] fcs_errors_2;
    wire [31:0] fcs_errors_3;
    wire [31:0] sequence_errors_1;
    wire [31:0] sequence_errors_2;
    wire [31:0] sequence_errors_3;
    wire [63:0] bit_errors_1;
    wire [63:0] bit_errors_2;
    wire [63:0] bit_errors_3;
    wire [63:0] bits_checked_1;
    wire [63:0] bits_checked_2;
    wire [63:0] bits_checked_3;
    wire [31:0] malformed_frames;
    wire [31:0] gmii_rx_er_frames;
    wire stats_update_toggle;

    always #4 clk = ~clk;

    gmii_prbs31_tx #(.SOURCE_PORT(1)) tx1 (
        .clk(clk), .rst_n(rst_n), .enable(selected_port == 2'd1),
        .gmii_tx_en(en1), .gmii_tx_er(er1), .gmii_txd(data1),
        .frame_sequence(seq1), .frame_count(tx_count1)
    );

    gmii_prbs31_tx #(.SOURCE_PORT(2)) tx2 (
        .clk(clk), .rst_n(rst_n), .enable(selected_port == 2'd2),
        .gmii_tx_en(en2), .gmii_tx_er(er2), .gmii_txd(data2),
        .frame_sequence(seq2), .frame_count(tx_count2)
    );

    gmii_prbs31_tx #(.SOURCE_PORT(3)) tx3 (
        .clk(clk), .rst_n(rst_n), .enable(selected_port == 2'd3),
        .gmii_tx_en(en3), .gmii_tx_er(er3), .gmii_txd(data3),
        .frame_sequence(seq3), .frame_count(tx_count3)
    );

    assign selected_en = (selected_port == 2'd1) ? en1 :
                         (selected_port == 2'd2) ? en2 :
                         (selected_port == 2'd3) ? en3 : 1'b0;
    assign selected_er = (selected_port == 2'd1) ? er1 :
                         (selected_port == 2'd2) ? er2 :
                         (selected_port == 2'd3) ? er3 : 1'b0;
    assign selected_data = (selected_port == 2'd1) ? data1 :
                           (selected_port == 2'd2) ? data2 :
                           (selected_port == 2'd3) ? data3 : 8'd0;

    assign corrupted_byte = inject_one_bit && selected_en &&
                            (mux_byte_index == 16'd100);
    assign rx_dv = selected_en && !drop_frame;
    assign rx_er = selected_er && !drop_frame;
    assign rx_data = selected_data ^ {7'd0, corrupted_byte};

    always @(posedge clk) begin
        if (!rst_n) begin
            mux_byte_index <= 16'd0;
            mux_in_frame <= 1'b0;
        end else if (selected_en) begin
            if (!mux_in_frame)
                mux_byte_index <= 16'd0;
            else
                mux_byte_index <= mux_byte_index + 1'b1;
            mux_in_frame <= 1'b1;
        end else begin
            mux_byte_index <= 16'd0;
            mux_in_frame <= 1'b0;
        end
    end

    gmii_prbs31_rx_checker rx_checker (
        .rx_clk(clk),
        .rst_n(rst_n),
        .gmii_rx_dv(rx_dv),
        .gmii_rx_er(rx_er),
        .gmii_rxd(rx_data),
        .current_source(current_source),
        .good_frames_1(good_frames_1),
        .good_frames_2(good_frames_2),
        .good_frames_3(good_frames_3),
        .fcs_errors_1(fcs_errors_1),
        .fcs_errors_2(fcs_errors_2),
        .fcs_errors_3(fcs_errors_3),
        .sequence_errors_1(sequence_errors_1),
        .sequence_errors_2(sequence_errors_2),
        .sequence_errors_3(sequence_errors_3),
        .bit_errors_1(bit_errors_1),
        .bit_errors_2(bit_errors_2),
        .bit_errors_3(bit_errors_3),
        .bits_checked_1(bits_checked_1),
        .bits_checked_2(bits_checked_2),
        .bits_checked_3(bits_checked_3),
        .malformed_frames(malformed_frames),
        .gmii_rx_er_frames(gmii_rx_er_frames),
        .stats_update_toggle(stats_update_toggle)
    );

    task automatic wait_for_tx_frame_end;
        begin
            while (!selected_en) @(posedge clk);
            while (selected_en) @(posedge clk);
            repeat (2) @(posedge clk);
        end
    endtask

    initial begin
        repeat (5) @(posedge clk);
        rst_n = 1'b1;

        selected_port = 2'd1;
        wait (good_frames_1 == 32'd2);
        selected_port = 2'd0;
        repeat (20) @(posedge clk);

        if (bit_errors_1 !== 64'd0 ||
            bits_checked_1 !== (BITS_PER_FRAME * 2))
            $fatal(1, "Port 1 BER counters are incorrect");

        selected_port = 2'd2;
        wait (good_frames_2 == 32'd1);
        inject_one_bit = 1'b1;
        wait (fcs_errors_2 == 32'd1);
        inject_one_bit = 1'b0;
        selected_port = 2'd0;
        repeat (20) @(posedge clk);

        if (bit_errors_2 !== 64'd1)
            $fatal(1, "Port 2 did not count exactly one injected bit error");
        if (bits_checked_2 !== (BITS_PER_FRAME * 2))
            $fatal(1, "Port 2 checked-bit count is incorrect");
        if (good_frames_2 !== 32'd1 || fcs_errors_2 !== 32'd1)
            $fatal(1, "Port 2 FCS classification is incorrect");
        if (sequence_errors_2 !== 32'd0)
            $fatal(1, "A received bad-FCS frame was incorrectly counted lost");

        selected_port = 2'd3;
        wait (good_frames_3 == 32'd1);
        drop_frame = 1'b1;
        wait_for_tx_frame_end();
        drop_frame = 1'b0;
        wait (good_frames_3 == 32'd2);
        selected_port = 2'd0;
        repeat (20) @(posedge clk);

        if (sequence_errors_3 !== 32'd1)
            $fatal(1, "Port 3 did not detect one dropped frame");
        if (bit_errors_3 !== 64'd0)
            $fatal(1, "Port 3 reported unexpected bit errors");
        if (bits_checked_3 !== (BITS_PER_FRAME * 2))
            $fatal(1, "Port 3 checked-bit count is incorrect");

        if (malformed_frames !== 32'd0 || gmii_rx_er_frames !== 32'd0)
            $fatal(1, "Unexpected global receive errors");
        if (current_source !== 2'd3)
            $fatal(1, "Current source did not retain port 3");

        $display("PASS tb_gmii_prbs31_loopback");
        $finish;
    end

    initial begin
        #2_000_000;
        $fatal(1, "Simulation timeout");
    end
endmodule
