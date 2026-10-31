`timescale 1 ns / 1 ps

module tb_smi_config_gigabit_only;

reg clk = 1'b0;
reg rst_n = 1'b0;
wire mdc;
tri mdio;
wire [1:0] speed;
wire link;
wire [3:0] led;
integer step;

always #5 clk = ~clk;

smi_config #(
    .REF_CLK(50),
    .MDC_CLK(500)
) dut (
    .clk(clk),
    .rst_n(rst_n),
    .mdc(mdc),
    .mdio(mdio),
    .speed(speed),
    .link(link),
    .led(led)
);

task check_write;
    input [4:0] expected_addr;
    input [15:0] expected_data;
    begin
        wait(dut.state == dut.W_REG);
        #1;
        if (dut.reg_addr !== expected_addr ||
            dut.write_data !== expected_data)
            $fatal(1,
                "write %0d mismatch addr=%0d data=%h",
                step, dut.reg_addr, dut.write_data);

        force dut.done = 1'b1;
        @(posedge clk);
        #1;
        release dut.done;
        step = step + 1;
    end
endtask

initial begin
    step = 0;
    repeat (3) @(posedge clk);
    rst_n = 1'b1;

    check_write(5'd4, 16'h0001);
    check_write(5'd9, 16'h0200);
    check_write(5'd0, 16'h1340);

    wait(dut.state == dut.R_REG);
    #1;
    if (dut.reg_addr !== 5'd17)
        $fatal(1, "status read did not select PHY register 17");

    $display("PASS tb_smi_config_gigabit_only");
    $finish;
end

initial begin
    #2000;
    $fatal(1, "timeout");
end

endmodule
