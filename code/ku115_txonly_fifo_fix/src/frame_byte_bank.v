`timescale 1ns / 1ps

// One byte lane of a 128-bit, 32-word frame buffer.  Fixed instances of this
// module let Vivado infer LUTRAM instead of constructing a dynamic bank mux.
module frame_byte_bank
#(
    parameter ADDR_WIDTH = 5
)
(
    input                  clk,
    input                  wr_en,
    input  [ADDR_WIDTH-1:0] wr_addr,
    input  [7:0]            wr_data,
    input  [ADDR_WIDTH-1:0] rd_addr,
    output [7:0]            rd_data
);

(* ram_style = "distributed" *) reg [7:0] mem [0:(1 << ADDR_WIDTH)-1];

always @(posedge clk) begin
    if (wr_en)
        mem[wr_addr] <= wr_data;
end

assign rd_data = mem[rd_addr];

endmodule
