`timescale 1ns / 1ps

module tb_radix8_butterfly;

    // ============================================================
    // Inputs
    // ============================================================

    reg signed [15:0] x0_re, x0_im;
    reg signed [15:0] x1_re, x1_im;
    reg signed [15:0] x2_re, x2_im;
    reg signed [15:0] x3_re, x3_im;
    reg signed [15:0] x4_re, x4_im;
    reg signed [15:0] x5_re, x5_im;
    reg signed [15:0] x6_re, x6_im;
    reg signed [15:0] x7_re, x7_im;


    // ============================================================
    // Outputs
    // ============================================================

    wire signed [19:0] X0_re, X0_im;
    wire signed [19:0] X1_re, X1_im;
    wire signed [19:0] X2_re, X2_im;
    wire signed [19:0] X3_re, X3_im;
    wire signed [19:0] X4_re, X4_im;
    wire signed [19:0] X5_re, X5_im;
    wire signed [19:0] X6_re, X6_im;
    wire signed [19:0] X7_re, X7_im;


    // ============================================================
    // DUT
    // ============================================================

    radix8_butterfly #(
        .IN_W  (16),
        .INT_W (20)
    ) dut (

        .x0_re(x0_re), .x0_im(x0_im),
        .x1_re(x1_re), .x1_im(x1_im),
        .x2_re(x2_re), .x2_im(x2_im),
        .x3_re(x3_re), .x3_im(x3_im),
        .x4_re(x4_re), .x4_im(x4_im),
        .x5_re(x5_re), .x5_im(x5_im),
        .x6_re(x6_re), .x6_im(x6_im),
        .x7_re(x7_re), .x7_im(x7_im),

        .X0_re(X0_re), .X0_im(X0_im),
        .X1_re(X1_re), .X1_im(X1_im),
        .X2_re(X2_re), .X2_im(X2_im),
        .X3_re(X3_re), .X3_im(X3_im),
        .X4_re(X4_re), .X4_im(X4_im),
        .X5_re(X5_re), .X5_im(X5_im),
        .X6_re(X6_re), .X6_im(X6_im),
        .X7_re(X7_re), .X7_im(X7_im)
    );


    // ============================================================
    // Test stimulus
    // ============================================================

    initial begin

        // Exact vector used by Python fixed-point reference

        x0_re = -26919;
        x0_im = -19565;

        x1_re =  17953;
        x1_im = -26596;

        x2_re =  10129;
        x2_im =   1735;

        x3_re =  -4006;
        x3_im =  31170;

        x4_re =  -4390;
        x4_im =  15450;

        x5_re =  23501;
        x5_im =  17114;

        x6_re = -27136;
        x6_im =  14252;

        x7_re =  12934;
        x7_im =  18747;


        #10;

        // --------------------------------------------------------
        // Print results
        // --------------------------------------------------------

        $display("============================================================");
        $display("VERILOG RADIX-8 BUTTERFLY TEST");
        $display("============================================================");

        $display("X0 = %0d + j(%0d)", X0_re, X0_im);
        $display("X1 = %0d + j(%0d)", X1_re, X1_im);
        $display("X2 = %0d + j(%0d)", X2_re, X2_im);
        $display("X3 = %0d + j(%0d)", X3_re, X3_im);
        $display("X4 = %0d + j(%0d)", X4_re, X4_im);
        $display("X5 = %0d + j(%0d)", X5_re, X5_im);
        $display("X6 = %0d + j(%0d)", X6_re, X6_im);
        $display("X7 = %0d + j(%0d)", X7_re, X7_im);


        $display("============================================================");

        #10;
        $finish;

    end

endmodule