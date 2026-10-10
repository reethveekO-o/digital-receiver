`timescale 1ns / 1ps

module radix8_butterfly #(
    parameter IN_W  = 16,
    parameter INT_W = 20
)(
    // 8 complex inputs
    input  signed [IN_W-1:0] x0_re,
    input  signed [IN_W-1:0] x0_im,
    input  signed [IN_W-1:0] x1_re,
    input  signed [IN_W-1:0] x1_im,
    input  signed [IN_W-1:0] x2_re,
    input  signed [IN_W-1:0] x2_im,
    input  signed [IN_W-1:0] x3_re,
    input  signed [IN_W-1:0] x3_im,
    input  signed [IN_W-1:0] x4_re,
    input  signed [IN_W-1:0] x4_im,
    input  signed [IN_W-1:0] x5_re,
    input  signed [IN_W-1:0] x5_im,
    input  signed [IN_W-1:0] x6_re,
    input  signed [IN_W-1:0] x6_im,
    input  signed [IN_W-1:0] x7_re,
    input  signed [IN_W-1:0] x7_im,

    // 8 complex outputs
    output signed [INT_W-1:0] X0_re,
    output signed [INT_W-1:0] X0_im,
    output signed [INT_W-1:0] X1_re,
    output signed [INT_W-1:0] X1_im,
    output signed [INT_W-1:0] X2_re,
    output signed [INT_W-1:0] X2_im,
    output signed [INT_W-1:0] X3_re,
    output signed [INT_W-1:0] X3_im,
    output signed [INT_W-1:0] X4_re,
    output signed [INT_W-1:0] X4_im,
    output signed [INT_W-1:0] X5_re,
    output signed [INT_W-1:0] X5_im,
    output signed [INT_W-1:0] X6_re,
    output signed [INT_W-1:0] X6_im,
    output signed [INT_W-1:0] X7_re,
    output signed [INT_W-1:0] X7_im
);

    // ------------------------------------------------------------
    // Q15 constant:
    // round(1/sqrt(2) * 2^15) = 23170
    // ------------------------------------------------------------

    localparam signed [15:0] K = 16'sd23170;

    // ------------------------------------------------------------
    // Pair sums/differences
    // ------------------------------------------------------------

    wire signed [INT_W-1:0] A0_re = x0_re + x4_re;
    wire signed [INT_W-1:0] A0_im = x0_im + x4_im;
    wire signed [INT_W-1:0] B0_re = x0_re - x4_re;
    wire signed [INT_W-1:0] B0_im = x0_im - x4_im;

    wire signed [INT_W-1:0] A1_re = x1_re + x5_re;
    wire signed [INT_W-1:0] A1_im = x1_im + x5_im;
    wire signed [INT_W-1:0] B1_re = x1_re - x5_re;
    wire signed [INT_W-1:0] B1_im = x1_im - x5_im;

    wire signed [INT_W-1:0] A2_re = x2_re + x6_re;
    wire signed [INT_W-1:0] A2_im = x2_im + x6_im;
    wire signed [INT_W-1:0] B2_re = x2_re - x6_re;
    wire signed [INT_W-1:0] B2_im = x2_im - x6_im;

    wire signed [INT_W-1:0] A3_re = x3_re + x7_re;
    wire signed [INT_W-1:0] A3_im = x3_im + x7_im;
    wire signed [INT_W-1:0] B3_re = x3_re - x7_re;
    wire signed [INT_W-1:0] B3_im = x3_im - x7_im;

    // ------------------------------------------------------------
    // Q15 multiplication helper signals
    //
    // z * (1-j)/sqrt(2)
    //
    // re = (re + im) / sqrt(2)
    // im = (im - re) / sqrt(2)
    // ------------------------------------------------------------

    wire signed [INT_W:0] c1_re_num = B1_re + B1_im;
    wire signed [INT_W:0] c1_im_num = B1_im - B1_re;

    wire signed [INT_W+15:0] c1_re_mult = c1_re_num * K;
    wire signed [INT_W+15:0] c1_im_mult = c1_im_num * K;

    wire signed [INT_W-1:0] C1_re =
        c1_re_mult >>> 15;

    wire signed [INT_W-1:0] C1_im =
        c1_im_mult >>> 15;

    // ------------------------------------------------------------
    // C2 = -j * B2
    // ------------------------------------------------------------

    wire signed [INT_W-1:0] C2_re = B2_im;
    wire signed [INT_W-1:0] C2_im = -B2_re;

    // ------------------------------------------------------------
    // C3 = B3 * (-1-j)/sqrt(2)
    //
    // re = (-re + im) / sqrt(2)
    // im = (-re - im) / sqrt(2)
    // ------------------------------------------------------------

    wire signed [INT_W:0] c3_re_num = -B3_re + B3_im;
    wire signed [INT_W:0] c3_im_num = -B3_re - B3_im;

    wire signed [INT_W+15:0] c3_re_mult = c3_re_num * K;
    wire signed [INT_W+15:0] c3_im_mult = c3_im_num * K;

    wire signed [INT_W-1:0] C3_re =
        c3_re_mult >>> 15;

    wire signed [INT_W-1:0] C3_im =
        c3_im_mult >>> 15;

    // ------------------------------------------------------------
    // Even outputs
    // ------------------------------------------------------------

    assign X0_re =
        A0_re + A1_re + A2_re + A3_re;

    assign X0_im =
        A0_im + A1_im + A2_im + A3_im;

    assign X2_re =
        A0_re + A1_im - A2_re - A3_im;

    assign X2_im =
        A0_im - A1_re - A2_im + A3_re;

    assign X4_re =
        A0_re - A1_re + A2_re - A3_re;

    assign X4_im =
        A0_im - A1_im + A2_im - A3_im;

    assign X6_re =
        A0_re - A1_im - A2_re + A3_im;

    assign X6_im =
        A0_im + A1_re - A2_im - A3_re;

    // ------------------------------------------------------------
    // Odd outputs
    // ------------------------------------------------------------

    assign X1_re =
        B0_re + C1_re + C2_re + C3_re;

    assign X1_im =
        B0_im + C1_im + C2_im + C3_im;

    assign X3_re =
        B0_re + C1_im - C2_re - C3_im;

    assign X3_im =
        B0_im - C1_re - C2_im + C3_re;

    assign X5_re =
        B0_re - C1_re + C2_re - C3_re;

    assign X5_im =
        B0_im - C1_im + C2_im - C3_im;

    assign X7_re =
        B0_re - C1_im - C2_re + C3_im;

    assign X7_im =
        B0_im + C1_re - C2_im - C3_re;

endmodule