`timescale 1ns/1ps

module tb_reset_level_cdc;

reg dst_clk = 1'b0;
reg async_reset_n = 1'b0;
reg async_level = 1'b0;
wire dst_reset_n;
wire dst_level;

integer release_edges;

always #5 dst_clk = ~dst_clk;

reset_level_cdc #(
    .RESET_STAGES(3)
) dut (
    .dst_clk(dst_clk),
    .async_reset_n(async_reset_n),
    .async_level(async_level),
    .dst_reset_n(dst_reset_n),
    .dst_level(dst_level)
);

initial begin
    repeat (2) @(posedge dst_clk);
    if (dst_reset_n !== 1'b0 || dst_level !== 1'b0)
        $fatal(1, "outputs must stay reset while async reset is active");

    #2 async_reset_n = 1'b1;
    release_edges = 0;
    while (!dst_reset_n) begin
        @(posedge dst_clk);
        #1;
        release_edges = release_edges + 1;
        if (release_edges > 4)
            $fatal(1, "synchronous reset release took too long");
    end
    if (release_edges != 3)
        $fatal(1, "reset released after %0d edges, expected 3",
               release_edges);

    #2 async_level = 1'b1;
    @(posedge dst_clk);
    #1;
    if (dst_level !== 1'b0)
        $fatal(1, "level crossed with fewer than two synchronizer stages");
    @(posedge dst_clk);
    #1;
    if (dst_level !== 1'b1)
        $fatal(1, "level did not cross after two synchronizer stages");

    #3 async_reset_n = 1'b0;
    #1;
    if (dst_reset_n !== 1'b0 || dst_level !== 1'b0)
        $fatal(1, "asynchronous assertion did not clear outputs");

    $display("PASS tb_reset_level_cdc");
    $finish;
end

endmodule
