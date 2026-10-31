`timescale 1ps / 1ps

module tb_rgmii_rx_clock_phase;

reg clk_in;
reg reset;
wire clk_out;
wire locked;

real last_input_edge;
real previous_output_edge;
real phase_delta;
real output_period;

rgmii_rx_clock_phase dut (
    .clk_in(clk_in),
    .reset(reset),
    .clk_out(clk_out),
    .locked(locked)
);

initial begin
    clk_in = 1'b0;
    forever #4000 clk_in = ~clk_in;
end

always @(posedge clk_in)
    last_input_edge = $realtime;

initial begin
    reset = 1'b1;
    last_input_edge = 0.0;
    previous_output_edge = 0.0;

    #40000;
    reset = 1'b0;
    wait (locked == 1'b1);
    repeat (4) @(posedge clk_out);

    phase_delta = $realtime - last_input_edge;
    previous_output_edge = $realtime;
    @(posedge clk_out);
    output_period = $realtime - previous_output_edge;

    if (phase_delta < 5800.0 || phase_delta > 6200.0) begin
        $display("FAIL: expected -2 ns phase (6 ns modulo period), measured %0.1f ps", phase_delta);
        $finish;
    end
    if (output_period < 7900.0 || output_period > 8100.0) begin
        $display("FAIL: expected 8 ns output period, measured %0.1f ps", output_period);
        $finish;
    end

    reset = 1'b1;
    repeat (4) @(posedge clk_in);
    if (locked !== 1'b0) begin
        $display("FAIL: PLL lock did not clear during reset");
        $finish;
    end
    else begin
        $display("PASS: RGMII receive clock PLL locks at 125 MHz with -90 degree phase");
        $finish;
    end
end

initial begin
    #2000000;
    $display("FAIL: timeout waiting for RGMII receive clock PLL");
    $finish;
end

endmodule
