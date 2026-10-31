`timescale 1ns/1ps

module tb_smi_read_write;
    reg         clk = 1'b0;
    reg         rst_n = 1'b0;
    wire        mdc;
    tri         mdio;
    reg  [4:0]  phy_addr = 5'd1;
    reg  [4:0]  reg_addr = 5'd0;
    reg         write_req = 1'b0;
    reg  [15:0] write_data = 16'd0;
    reg         read_req = 1'b0;
    wire [15:0] read_data;
    wire        data_valid;
    wire        done;
    integer     errors = 0;

    smi_read_write #(
        .REF_CLK(50),
        .MDC_CLK(100)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .mdc(mdc),
        .mdio(mdio),
        .phy_addr(phy_addr),
        .reg_addr(reg_addr),
        .write_req(write_req),
        .write_data(write_data),
        .read_req(read_req),
        .read_data(read_data),
        .data_valid(data_valid),
        .done(done)
    );

    always #10 clk = ~clk;

    task check_mdio_en(
        input [2:0] forced_state,
        input [5:0] forced_write_count,
        input       expected
    );
        begin
            force dut.state = forced_state;
            force dut.write_cnt = forced_write_count;
            #1;
            if (dut.mdio_en !== expected) begin
                $error("state=%0d write_cnt=%0d: mdio_en=%b, expected=%b",
                       forced_state, forced_write_count, dut.mdio_en, expected);
                errors = errors + 1;
            end
        end
    endtask

    initial begin
        repeat (2) @(posedge clk);
        rst_n = 1'b1;

        check_mdio_en(3'd0, 6'd0, 1'b1);
        check_mdio_en(3'd2, 6'd14, 1'b1);
        check_mdio_en(3'd2, 6'd15, 1'b0);
        check_mdio_en(3'd4, 6'd17, 1'b0);

        // Completing a read must release MDIO instead of retaining R_DATA's 0.
        check_mdio_en(3'd6, 6'd0, 1'b1);
        check_mdio_en(3'd5, 6'd0, 1'b1);

        release dut.state;
        release dut.write_cnt;
        if (errors != 0) begin
            $display("FAIL tb_smi_read_write: %0d errors", errors);
            $finish;
        end

        $display("PASS tb_smi_read_write");
        $finish;
    end
endmodule
