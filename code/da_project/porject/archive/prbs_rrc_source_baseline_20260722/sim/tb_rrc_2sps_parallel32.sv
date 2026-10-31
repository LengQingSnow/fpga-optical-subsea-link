`timescale 1ns/1ps

module tb_rrc_2sps_parallel32;
    logic clk = 1'b0;
    logic rst_n = 1'b0;
    logic in_valid = 1'b0;
    logic [15:0] symbols = '0;
    logic out_valid;
    logic signed [16*32-1:0] samples;

    integer coeff [0:20] = '{
        -126, 91, 203, -282, -280, 630, 346, -1371, -390, 4655,
        7827,
        4655, -390, -1371, 346, 630, -280, -282, 203, 91, -126
    };
    integer history [0:9];

    always #2 clk = ~clk;

    rrc_2sps_parallel32 dut (
        .clk(clk),
        .rst_n(rst_n),
        .in_valid(in_valid),
        .symbols(symbols),
        .out_valid(out_valid),
        .samples(samples)
    );

    function automatic integer symbol_at(input integer offset);
        if (offset >= 0)
            symbol_at = symbols[offset] ? 1 : -1;
        else
            symbol_at = history[10 + offset];
    endfunction

    task automatic check_block;
        integer expected;
        integer offset;
        integer actual;
        for (int k = 0; k < 32; k++) begin
            expected = 0;
            for (int tap = 0; tap <= 20; tap++) begin
                if (((k - tap) & 1) == 0) begin
                    offset = (k - tap) / 2;
                    expected = expected + coeff[tap] * symbol_at(offset);
                end
            end
            actual = $signed(samples[k*16 +: 16]);
            if (actual !== expected) begin
                $error("sample %0d: expected %0d, got %0d", k, expected, actual);
                $fatal(1);
            end
            if ((actual > 24575) || (actual < -24575))
                $fatal(1, "sample %0d exceeds amplitude bound: %0d", k, actual);
        end
    endtask

    task automatic advance_history;
        for (int i = 0; i < 10; i++)
            history[i] = symbols[i + 6] ? 1 : -1;
    endtask

    initial begin
        for (int i = 0; i < 10; i++)
            history[i] = -1;

        repeat (4) @(posedge clk);
        rst_n <= 1'b1;
        in_valid <= 1'b1;

        symbols <= 16'h0001;
        @(posedge clk);
        #1;
        if (!out_valid) $fatal(1, "missing output valid for impulse block");
        check_block();
        advance_history();

        symbols <= 16'ha53c;
        @(posedge clk);
        #1;
        if (!out_valid) $fatal(1, "missing output valid for mixed block");
        check_block();
        advance_history();

        symbols <= 16'hffff;
        @(posedge clk);
        #1;
        check_block();

        in_valid <= 1'b0;
        @(posedge clk);
        #1;
        if (out_valid !== 1'b0)
            $fatal(1, "out_valid must follow in_valid");

        $display("PASS: 21-tap alpha=0.2 RRC parallel convolution");
        $finish;
    end
endmodule
