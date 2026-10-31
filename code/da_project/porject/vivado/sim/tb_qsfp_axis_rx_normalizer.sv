`timescale 1ns/1ps

module tb_qsfp_axis_rx_normalizer;
    logic [255:0] aurora_tdata;
    logic [31:0] aurora_tkeep;
    logic aurora_tvalid;
    logic aurora_tlast;
    logic [255:0] normalized_tdata;
    logic [31:0] normalized_tkeep;
    logic normalized_tvalid;
    logic normalized_tlast;

    qsfp_axis_rx_normalizer dut (.*);

    initial begin
        aurora_tdata = {64'h3333333333333333, 64'h2222222222222222,
                        64'h0000000000000000, 64'h1111111111111111};
        aurora_tkeep = {8'h08, 8'h04, 8'h01, 8'h02};
        aurora_tvalid = 1'b1;
        aurora_tlast = 1'b0;
        #1;
        if (normalized_tdata !==
            {64'h0000000000000000, 64'h1111111111111111,
             64'h2222222222222222, 64'h3333333333333333})
            $fatal(1, "RX lane-group normalization failed");
        if (normalized_tkeep !== {8'h01, 8'h02, 8'h04, 8'h08})
            $fatal(1, "RX keep normalization failed");
        if (!normalized_tvalid || normalized_tlast)
            $fatal(1, "RX controls did not pass through");
        $display("PASS: Aurora lane groups restore canonical order");
        $finish;
    end
endmodule

