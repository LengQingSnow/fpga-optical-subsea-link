`timescale 1ns/1ps

module tb_prbs31_crc;
    reg clk = 1'b0;
    reg rst_n = 1'b0;
    reg prbs_restart = 1'b0;
    reg prbs_advance = 1'b0;
    wire [7:0] prbs_data;

    reg crc_init = 1'b0;
    reg crc_enable = 1'b0;
    reg [7:0] crc_data = 8'd0;
    wire [31:0] crc_state;

    reg [7:0] expected_prbs [0:15];
    reg [7:0] crc_message [0:8];
    integer i;

    always #4 clk = ~clk;

    prbs31_byte_source prbs_dut (
        .clk(clk),
        .rst_n(rst_n),
        .restart(prbs_restart),
        .advance(prbs_advance),
        .data(prbs_data)
    );

    eth_crc32_8 crc_dut (
        .clk(clk),
        .rst_n(rst_n),
        .init(crc_init),
        .enable(crc_enable),
        .data(crc_data),
        .crc(crc_state)
    );

    initial begin
        expected_prbs[0]  = 8'hff;
        expected_prbs[1]  = 8'hff;
        expected_prbs[2]  = 8'hff;
        expected_prbs[3]  = 8'hfe;
        expected_prbs[4]  = 8'h00;
        expected_prbs[5]  = 8'h00;
        expected_prbs[6]  = 8'h00;
        expected_prbs[7]  = 8'h1c;
        expected_prbs[8]  = 8'h00;
        expected_prbs[9]  = 8'h00;
        expected_prbs[10] = 8'h01;
        expected_prbs[11] = 8'hf8;
        expected_prbs[12] = 8'h00;
        expected_prbs[13] = 8'h00;
        expected_prbs[14] = 8'h1c;
        expected_prbs[15] = 8'h70;

        crc_message[0] = "1";
        crc_message[1] = "2";
        crc_message[2] = "3";
        crc_message[3] = "4";
        crc_message[4] = "5";
        crc_message[5] = "6";
        crc_message[6] = "7";
        crc_message[7] = "8";
        crc_message[8] = "9";

        repeat (4) @(posedge clk);
        rst_n = 1'b1;

        @(negedge clk);
        prbs_restart = 1'b1;
        @(posedge clk);
        #1;
        prbs_restart = 1'b0;

        for (i = 0; i < 16; i = i + 1) begin
            if (prbs_data !== expected_prbs[i])
                $fatal(1, "PRBS byte %0d mismatch: got %02x expected %02x",
                       i, prbs_data, expected_prbs[i]);
            @(negedge clk);
            prbs_advance = 1'b1;
            @(posedge clk);
            #1;
            prbs_advance = 1'b0;
        end

        @(negedge clk);
        crc_init = 1'b1;
        @(posedge clk);
        #1;
        crc_init = 1'b0;

        for (i = 0; i < 9; i = i + 1) begin
            @(negedge clk);
            crc_data = crc_message[i];
            crc_enable = 1'b1;
            @(posedge clk);
            #1;
            crc_enable = 1'b0;
        end

        if (~crc_state !== 32'hcbf4_3926)
            $fatal(1, "CRC32 mismatch: got %08x expected CBF43926",
                   ~crc_state);

        $display("PASS tb_prbs31_crc");
        $finish;
    end
endmodule

