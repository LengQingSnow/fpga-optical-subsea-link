`timescale 1ns/1ps

module tb_dac_axis_differential4;
    logic clk = 1'b0;
    logic rst_n = 1'b0;
    logic enable = 1'b1;
    logic [4*256-1:0] lane_tdata = '0;
    logic [3:0] lane_tvalid = 4'h0;
    logic [3:0] lane_tready;
    logic [7:0] dac_tready = 8'hff;
    logic [8*256-1:0] dac_tdata;
    logic [7:0] dac_tvalid;
    logic ready_error;

    always #1 clk = ~clk;

    dac_axis_differential4 dut (
        .clk(clk), .rst_n(rst_n), .enable(enable),
        .lane_tdata(lane_tdata), .lane_tvalid(lane_tvalid),
        .lane_tready(lane_tready), .dac_tready(dac_tready),
        .dac_tdata(dac_tdata), .dac_tvalid(dac_tvalid),
        .ready_error(ready_error)
    );

    initial begin
        repeat (4) @(posedge clk);
        rst_n = 1'b1;
        @(negedge clk);
        for (int component = 0; component < 4; component++) begin
            for (int sample = 0; sample < 16; sample++)
                lane_tdata[component*256 + sample*16 +: 16] =
                    $signed(component*1000 + sample + 1);
        end
        lane_tvalid = 4'hf;
        @(negedge clk);
        lane_tvalid = 4'h0;

        wait (dac_tvalid == 8'hff);
        for (int component = 0; component < 4; component++) begin
            for (int sample = 0; sample < 16; sample++) begin
                if ($signed(dac_tdata[(2*component)*256 + sample*16 +: 16]) !==
                    $signed(component*1000 + sample + 1))
                    $fatal(1, "positive component mismatch");
                if ($signed(dac_tdata[(2*component+1)*256 + sample*16 +: 16]) !==
                    -$signed(dac_tdata[(2*component)*256 + sample*16 +: 16]))
                    $fatal(1, "negative component mismatch");
            end
        end
        if (dac_tdata[0*256 +: 256] === dac_tdata[2*256 +: 256])
            $fatal(1, "XI and XQ were incorrectly fanned out");

        @(negedge clk);
        dac_tready = 8'hfe;
        repeat (3) @(posedge clk);
        if (dac_tvalid != 0 || lane_tready != 0)
            $fatal(1, "channels advanced during a partial-ready stall");

        $display("PASS: four independent waveforms drive aligned P/N DAC pairs");
        $finish;
    end
endmodule

