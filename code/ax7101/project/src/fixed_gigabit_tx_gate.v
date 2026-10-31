`timescale 1 ns / 1 ps

module fixed_gigabit_tx_gate (
    input  wire link,
    input  wire descriptor_ready,
    output wire enable
);

assign enable = link && descriptor_ready;

endmodule
