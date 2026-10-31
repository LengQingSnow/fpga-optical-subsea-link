`timescale 1ns/1ps

module tb_board_support;
    reg sys_clk = 1'b0;
    reg rx_clk = 1'b0;
    reg external_reset_n = 1'b0;
    reg rx_async_reset_n = 1'b0;

    wire phy_reset_n;
    wire rx_reset_n;

    reg [15:0] source_data = 16'd0;
    reg source_toggle = 1'b0;
    wire [15:0] destination_data;
    wire destination_update;

    always #5 sys_clk = ~sys_clk;
    always #7 rx_clk = ~rx_clk;

    phy_reset_controller #(
        .RESET_CYCLES(5)
    ) reset_controller_dut (
        .clk(sys_clk),
        .external_reset_n(external_reset_n),
        .phy_reset_n(phy_reset_n)
    );

    async_reset_sync #(
        .STAGES(3)
    ) reset_sync_dut (
        .clk(rx_clk),
        .async_reset_n(rx_async_reset_n),
        .sync_reset_n(rx_reset_n)
    );

    stats_snapshot_cdc #(
        .WIDTH(16)
    ) snapshot_dut (
        .src_clk(rx_clk),
        .src_rst_n(rx_reset_n),
        .src_data(source_data),
        .src_toggle(source_toggle),
        .dst_clk(sys_clk),
        .dst_rst_n(phy_reset_n),
        .dst_data(destination_data),
        .dst_update_pulse(destination_update)
    );

    initial begin
        repeat (3) @(posedge sys_clk);
        if (phy_reset_n !== 1'b0)
            $fatal(1, "PHY reset released while external reset was active");

        @(negedge sys_clk);
        external_reset_n = 1'b1;
        repeat (4) @(posedge sys_clk);
        #1;
        if (phy_reset_n !== 1'b0)
            $fatal(1, "PHY reset released before RESET_CYCLES");
        @(posedge sys_clk);
        #1;
        if (phy_reset_n !== 1'b1)
            $fatal(1, "PHY reset did not release on RESET_CYCLES");

        @(negedge rx_clk);
        rx_async_reset_n = 1'b1;
        repeat (2) @(posedge rx_clk);
        #1;
        if (rx_reset_n !== 1'b0)
            $fatal(1, "Synchronized reset released too early");
        @(posedge rx_clk);
        #1;
        if (rx_reset_n !== 1'b1)
            $fatal(1, "Synchronized reset did not release after three clocks");

        @(negedge rx_clk);
        source_data = 16'ha55a;
        source_toggle = ~source_toggle;
        wait (destination_update);
        #1;
        if (destination_data !== 16'ha55a)
            $fatal(1, "First snapshot was incoherent");

        repeat (5) @(posedge rx_clk);
        @(negedge rx_clk);
        source_data = 16'h3cc3;
        source_toggle = ~source_toggle;
        wait (destination_update);
        #1;
        if (destination_data !== 16'h3cc3)
            $fatal(1, "Second snapshot was incoherent");

        #2;
        rx_async_reset_n = 1'b0;
        #1;
        if (rx_reset_n !== 1'b0)
            $fatal(1, "Reset did not assert asynchronously");

        $display("PASS tb_board_support");
        $finish;
    end

    initial begin
        #20_000;
        $fatal(1, "Simulation timeout");
    end
endmodule

