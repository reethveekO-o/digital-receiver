`timescale 1ns / 1ps

module radix4_butterfly #(
    parameter IN_W  = 16,
    parameter OUT_W = 18
)(
    // ============================================================
    // Inputs
    // ============================================================

    input wire signed [IN_W-1:0] x0_re,
    input wire signed [IN_W-1:0] x0_im,

    input wire signed [IN_W-1:0] x1_re,
    input wire signed [IN_W-1:0] x1_im,

    input wire signed [IN_W-1:0] x2_re,
    input wire signed [IN_W-1:0] x2_im,
    
    input wire signed [IN_W-1:0] x3_re,
    input wire signed [IN_W-1:0] x3_im,

    // ============================================================
    // Outputs
    // ============================================================

    output wire signed [OUT_W-1:0] X0_re,
    output wire signed [OUT_W-1:0] X0_im,

    output wire signed [OUT_W-1:0] X1_re,
    output wire signed [OUT_W-1:0] X1_im,

    output wire signed [OUT_W-1:0] X2_re,
    output wire signed [OUT_W-1:0] X2_im,

    output wire signed [OUT_W-1:0] X3_re,
    output wire signed [OUT_W-1:0] X3_im
);

    // ============================================================
    // Radix-4 equations
    //
    // X0 = x0 + x1 + x2 + x3
    //
    // X1 = x0 - j*x1 - x2 + j*x3
    //
    // X2 = x0 - x1 + x2 - x3
    //
    // X3 = x0 + j*x1 - x2 - j*x3
    //
    // No non-trivial multipliers are required.
    // ============================================================

    // ------------------------------------------------------------
    // X0
    // ------------------------------------------------------------

    assign X0_re =
        x0_re + x1_re + x2_re + x3_re;

    assign X0_im =
        x0_im + x1_im + x2_im + x3_im;


    // ------------------------------------------------------------
    // X1
    //
    // -j(a + jb) = b - ja
    //
    // +j(a + jb) = -b + ja
    // ------------------------------------------------------------

    assign X1_re =
        x0_re
        + x1_im
        - x2_re
        - x3_im;

    assign X1_im =
        x0_im
        - x1_re
        - x2_im
        + x3_re;


    // ------------------------------------------------------------
    // X2
    // ------------------------------------------------------------

    assign X2_re =
        x0_re
        - x1_re
        + x2_re
        - x3_re;

    assign X2_im =
        x0_im
        - x1_im
        + x2_im
        - x3_im;


    // ------------------------------------------------------------
    // X3
    // ------------------------------------------------------------

    assign X3_re =
        x0_re
        - x1_im
        - x2_re
        + x3_im;

    assign X3_im =
        x0_im
        + x1_re
        - x2_im
        - x3_re;

endmodule