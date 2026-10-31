`timescale 1ns/1ps

module tb_gmii_prbs31_tx;
    localparam integer FRAME_BYTES = 1526;
    localparam integer PRBS_FIRST = 38;
    localparam integer PRBS_LAST = 1521;

    reg clk = 1'b0;
    reg rst_n = 1'b0;
    reg enable = 1'b0;

    wire en1, er1;
    wire en2, er2;
    wire en3, er3;
    wire [7:0] data1, data2, data3;
    wire [31:0] seq1, seq2, seq3;
    wire [31:0] count1, count2, count3;

    reg [7:0] frame1 [0:FRAME_BYTES-1];
    reg [31:0] reference_crc;
    reg [30:0] reference_prbs;
    reg [7:0] expected_byte;
    integer frame_index;
    integer idle_cycles;
    integer bit_index;

    always #4 clk = ~clk;

    gmii_prbs31_tx #(.SOURCE_PORT(1)) tx1 (
        .clk(clk), .rst_n(rst_n), .enable(enable),
        .gmii_tx_en(en1), .gmii_tx_er(er1), .gmii_txd(data1),
        .frame_sequence(seq1), .frame_count(count1)
    );

    gmii_prbs31_tx #(.SOURCE_PORT(2)) tx2 (
        .clk(clk), .rst_n(rst_n), .enable(enable),
        .gmii_tx_en(en2), .gmii_tx_er(er2), .gmii_txd(data2),
        .frame_sequence(seq2), .frame_count(count2)
    );

    gmii_prbs31_tx #(.SOURCE_PORT(3)) tx3 (
        .clk(clk), .rst_n(rst_n), .enable(enable),
        .gmii_tx_en(en3), .gmii_tx_er(er3), .gmii_txd(data3),
        .frame_sequence(seq3), .frame_count(count3)
    );

    function automatic [31:0] crc32_byte_ref;
        input [31:0] crc_in;
        input [7:0] data_in;
        reg [31:0] value;
        integer k;
        begin
            value = crc_in;
            for (k = 0; k < 8; k = k + 1) begin
                if (value[0] ^ data_in[k])
                    value = (value >> 1) ^ 32'hedb8_8320;
                else
                    value = value >> 1;
            end
            crc32_byte_ref = value;
        end
    endfunction

    task automatic advance_prbs_ref;
        integer k;
        reg feedback;
        begin
            for (k = 0; k < 8; k = k + 1) begin
                feedback = reference_prbs[30] ^ reference_prbs[27];
                reference_prbs = {reference_prbs[29:0], feedback};
            end
        end
    endtask

    function automatic [7:0] prbs_byte_ref;
        input [30:0] state;
        reg [30:0] value;
        reg feedback;
        integer k;
        begin
            value = state;
            for (k = 0; k < 8; k = k + 1) begin
                prbs_byte_ref[7-k] = value[30];
                feedback = value[30] ^ value[27];
                value = {value[29:0], feedback};
            end
        end
    endfunction

    initial begin
        repeat (5) @(posedge clk);
        rst_n = 1'b1;
        repeat (2) @(posedge clk);
        enable = 1'b1;

        while (!en1) begin
            @(posedge clk);
            #1;
        end

        frame_index = 0;
        while (frame_index < FRAME_BYTES) begin
            #1;
            if (!(en1 && en2 && en3))
                $fatal(1, "Transmitters lost alignment at byte %0d",
                       frame_index);
            if (er1 || er2 || er3)
                $fatal(1, "GMII TX_ER asserted");
            frame1[frame_index] = data1;

            if ((frame_index >= PRBS_FIRST) &&
                (frame_index <= PRBS_LAST) &&
                ((data1 !== data2) || (data1 !== data3)))
                $fatal(1, "PRBS payload differs between ports at byte %0d",
                       frame_index);

            frame_index = frame_index + 1;
            @(posedge clk);
        end

        #1;
        if (en1 || en2 || en3)
            $fatal(1, "Frame exceeded %0d bytes", FRAME_BYTES);

        if ({frame1[0], frame1[1], frame1[2], frame1[3],
             frame1[4], frame1[5], frame1[6], frame1[7]} !==
            64'h5555_5555_5555_55d5)
            $fatal(1, "Preamble or SFD mismatch");

        if ({frame1[8], frame1[9], frame1[10], frame1[11],
             frame1[12], frame1[13]} !== 48'h0200_0000_0004)
            $fatal(1, "Destination MAC mismatch");

        if ({frame1[14], frame1[15], frame1[16], frame1[17],
             frame1[18], frame1[19]} !== 48'h0200_0000_0001)
            $fatal(1, "Source MAC mismatch");

        if ({frame1[20], frame1[21]} !== 16'h88b5)
            $fatal(1, "EtherType mismatch");

        if ({frame1[22], frame1[23], frame1[24], frame1[25]} !==
            32'h4158_3731)
            $fatal(1, "Test magic mismatch");
        if (frame1[26] !== 8'd1 || frame1[27] !== 8'd1)
            $fatal(1, "Version or source header mismatch");
        if ({frame1[28], frame1[29]} !== 16'd16)
            $fatal(1, "Header length mismatch");
        if ({frame1[30], frame1[31], frame1[32], frame1[33]} !== 32'd0)
            $fatal(1, "Initial frame sequence mismatch");
        if ({frame1[34], frame1[35]} !== 16'd1484)
            $fatal(1, "PRBS length mismatch");
        if ({frame1[36], frame1[37]} !== 16'd0)
            $fatal(1, "Reserved header mismatch");

        reference_prbs = 31'h7fff_ffff;
        for (frame_index = PRBS_FIRST;
             frame_index <= PRBS_LAST;
             frame_index = frame_index + 1) begin
            expected_byte = prbs_byte_ref(reference_prbs);
            if (frame1[frame_index] !== expected_byte)
                $fatal(1, "PRBS mismatch at byte %0d: got %02x expected %02x",
                       frame_index, frame1[frame_index], expected_byte);
            advance_prbs_ref();
        end

        reference_crc = 32'hffff_ffff;
        for (frame_index = 8; frame_index <= PRBS_LAST;
             frame_index = frame_index + 1)
            reference_crc = crc32_byte_ref(reference_crc,
                                           frame1[frame_index]);
        reference_crc = ~reference_crc;

        if ({frame1[1525], frame1[1524], frame1[1523], frame1[1522]} !==
            reference_crc)
            $fatal(1, "Ethernet FCS mismatch: got %02x%02x%02x%02x expected %08x",
                   frame1[1525], frame1[1524], frame1[1523], frame1[1522],
                   reference_crc);

        idle_cycles = 0;
        while (!en1) begin
            idle_cycles = idle_cycles + 1;
            @(posedge clk);
            #1;
            if (idle_cycles > 20)
                $fatal(1, "Next frame did not start");
        end
        if (idle_cycles !== 12)
            $fatal(1, "IFG was %0d clocks, expected 12", idle_cycles);

        if (seq1 !== 32'd1 || seq2 !== 32'd1 || seq3 !== 32'd1)
            $fatal(1, "Frame sequence did not advance once");
        if (count1 !== 32'd1 || count2 !== 32'd1 || count3 !== 32'd1)
            $fatal(1, "Frame count did not advance once");

        $display("PASS tb_gmii_prbs31_tx");
        $finish;
    end
endmodule
