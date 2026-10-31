`timescale 1ns/1ps

package rrc_coeffs_pkg;
    localparam int RRC_TAPS = 21;
    localparam int RRC_ABS_SUM = 24575;
    localparam integer signed RRC_COEFF [0:RRC_TAPS-1] = '{
        -126, 91, 203, -282, -280, 630, 346, -1371, -390, 4655,
        7827,
        4655, -390, -1371, 346, 630, -280, -282, 203, 91, -126
    };
endpackage
