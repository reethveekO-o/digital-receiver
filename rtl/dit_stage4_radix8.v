`timescale 1ns / 1ps

module dit_stage4_radix8 #(
    parameter IN_W  = 23,
    parameter OUT_W = 26
)(
    input wire clk,
    input wire rst,

    input wire signed [IN_W-1:0] in_re,
    input wire signed [IN_W-1:0] in_im,
    input wire                   in_valid,
    output wire                  in_ready,

    input wire start,

    output reg signed [OUT_W-1:0] out_re,
    output reg signed [OUT_W-1:0] out_im,
    output reg                    out_valid,
    output reg                    out_last,

    output reg                    busy,
    output reg                    done
);

    localparam integer N = 1024;

    localparam [1:0] S_LOAD    = 2'd0;
    localparam [1:0] S_PROCESS = 2'd1;
    localparam [1:0] S_OUTPUT  = 2'd2;

    reg [1:0] state;

    // ============================================================
    // INPUT MEMORY
    //
    // Stage-3 layout:
    //
    // address = 128*parent + 16*q1 + k
    //
    // parent = 0..7
    // q1     = 0..7
    // k      = 0..15
    //
    // We combine the 8 parent values for fixed q1,k.
    // ============================================================

    reg signed [IN_W-1:0] input_re [0:N-1];
    reg signed [IN_W-1:0] input_im [0:N-1];

    reg [10:0] load_count;

    assign in_ready =
        (state == S_LOAD) &&
        (load_count < N);

    // ============================================================
    // FINAL OUTPUT MEMORY
    //
    // Natural FFT-bin order:
    //
    // output address = 128*q0 + k_full
    //
    // where:
    //
    // k_full = 16*q1 + k
    // ============================================================

    reg signed [OUT_W-1:0] output_re_mem [0:N-1];
    reg signed [OUT_W-1:0] output_im_mem [0:N-1];

    // ============================================================
    // INDICES
    //
    // q1 = 0..7
    // k  = 0..15
    //
    // k_full = 16*q1 + k = 0..127
    // ============================================================

    reg [2:0] q1_index;
    reg [3:0] k_index;

    wire [6:0] k_full;

    assign k_full =
        (q1_index << 4) + k_index;

    // ============================================================
    // INPUTS FROM STAGE 3
    //
    // For m=0..7:
    //
    // t_m = stage3[m, q1, k]
    //
    // linear address = 128*m + k_full
    // ============================================================

    wire signed [IN_W-1:0] t0_re;
    wire signed [IN_W-1:0] t0_im;
    wire signed [IN_W-1:0] t1_re;
    wire signed [IN_W-1:0] t1_im;
    wire signed [IN_W-1:0] t2_re;
    wire signed [IN_W-1:0] t2_im;
    wire signed [IN_W-1:0] t3_re;
    wire signed [IN_W-1:0] t3_im;
    wire signed [IN_W-1:0] t4_re;
    wire signed [IN_W-1:0] t4_im;
    wire signed [IN_W-1:0] t5_re;
    wire signed [IN_W-1:0] t5_im;
    wire signed [IN_W-1:0] t6_re;
    wire signed [IN_W-1:0] t6_im;
    wire signed [IN_W-1:0] t7_re;
    wire signed [IN_W-1:0] t7_im;

    assign t0_re = input_re[128*0 + k_full];
    assign t0_im = input_im[128*0 + k_full];

    assign t1_re = input_re[128*1 + k_full];
    assign t1_im = input_im[128*1 + k_full];

    assign t2_re = input_re[128*2 + k_full];
    assign t2_im = input_im[128*2 + k_full];

    assign t3_re = input_re[128*3 + k_full];
    assign t3_im = input_im[128*3 + k_full];

    assign t4_re = input_re[128*4 + k_full];
    assign t4_im = input_im[128*4 + k_full];

    assign t5_re = input_re[128*5 + k_full];
    assign t5_im = input_im[128*5 + k_full];

    assign t6_re = input_re[128*6 + k_full];
    assign t6_im = input_im[128*6 + k_full];

    assign t7_re = input_re[128*7 + k_full];
    assign t7_im = input_im[128*7 + k_full];

    // ============================================================
    // TWIDDLE ROM
    //
    // W1024^p = exp(-j*2*pi*p/1024)
    // Q15
    // ============================================================

    reg signed [15:0] tw_re [0:1023];
    reg signed [15:0] tw_im [0:1023];

    initial begin

        $readmemh(
            "twiddle_re.mem",
            tw_re
        );

        $readmemh(
            "twiddle_im.mem",
            tw_im
        );

    end

    // ============================================================
    // TWIDDLE INDICES
    //
    // m*k_full
    // ============================================================

    wire [9:0] idx0;
    wire [9:0] idx1;
    wire [9:0] idx2;
    wire [9:0] idx3;
    wire [9:0] idx4;
    wire [9:0] idx5;
    wire [9:0] idx6;
    wire [9:0] idx7;

    assign idx0 = 10'd0;
    assign idx1 = k_full;
    assign idx2 = 2 * k_full;
    assign idx3 = 3 * k_full;
    assign idx4 = 4 * k_full;
    assign idx5 = 5 * k_full;
    assign idx6 = 6 * k_full;
    assign idx7 = 7 * k_full;

    // ============================================================
    // WIDENED COMPLEX MULTIPLIERS
    //
    // 23-bit value × 16-bit Q15 coefficient = 39 bits
    // ============================================================

    wire signed [38:0] m1_re_wide;
    wire signed [38:0] m1_im_wide;

    wire signed [38:0] m2_re_wide;
    wire signed [38:0] m2_im_wide;

    wire signed [38:0] m3_re_wide;
    wire signed [38:0] m3_im_wide;

    wire signed [38:0] m4_re_wide;
    wire signed [38:0] m4_im_wide;

    wire signed [38:0] m5_re_wide;
    wire signed [38:0] m5_im_wide;

    wire signed [38:0] m6_re_wide;
    wire signed [38:0] m6_im_wide;

    wire signed [38:0] m7_re_wide;
    wire signed [38:0] m7_im_wide;

    assign m1_re_wide =
        ($signed(t1_re) * $signed(tw_re[idx1]))
      - ($signed(t1_im) * $signed(tw_im[idx1]));

    assign m1_im_wide =
        ($signed(t1_re) * $signed(tw_im[idx1]))
      + ($signed(t1_im) * $signed(tw_re[idx1]));

    assign m2_re_wide =
        ($signed(t2_re) * $signed(tw_re[idx2]))
      - ($signed(t2_im) * $signed(tw_im[idx2]));

    assign m2_im_wide =
        ($signed(t2_re) * $signed(tw_im[idx2]))
      + ($signed(t2_im) * $signed(tw_re[idx2]));

    assign m3_re_wide =
        ($signed(t3_re) * $signed(tw_re[idx3]))
      - ($signed(t3_im) * $signed(tw_im[idx3]));

    assign m3_im_wide =
        ($signed(t3_re) * $signed(tw_im[idx3]))
      + ($signed(t3_im) * $signed(tw_re[idx3]));

    assign m4_re_wide =
        ($signed(t4_re) * $signed(tw_re[idx4]))
      - ($signed(t4_im) * $signed(tw_im[idx4]));

    assign m4_im_wide =
        ($signed(t4_re) * $signed(tw_im[idx4]))
      + ($signed(t4_im) * $signed(tw_re[idx4]));

    assign m5_re_wide =
        ($signed(t5_re) * $signed(tw_re[idx5]))
      - ($signed(t5_im) * $signed(tw_im[idx5]));

    assign m5_im_wide =
        ($signed(t5_re) * $signed(tw_im[idx5]))
      + ($signed(t5_im) * $signed(tw_re[idx5]));

    assign m6_re_wide =
        ($signed(t6_re) * $signed(tw_re[idx6]))
      - ($signed(t6_im) * $signed(tw_im[idx6]));

    assign m6_im_wide =
        ($signed(t6_re) * $signed(tw_im[idx6]))
      + ($signed(t6_im) * $signed(tw_re[idx6]));

    assign m7_re_wide =
        ($signed(t7_re) * $signed(tw_re[idx7]))
      - ($signed(t7_im) * $signed(tw_im[idx7]));

    assign m7_im_wide =
        ($signed(t7_re) * $signed(tw_im[idx7]))
      + ($signed(t7_im) * $signed(tw_re[idx7]));

    // ============================================================
    // TWIDDLED INPUTS
    // ============================================================

    wire signed [IN_W-1:0] w1_re;
    wire signed [IN_W-1:0] w1_im;
    wire signed [IN_W-1:0] w2_re;
    wire signed [IN_W-1:0] w2_im;
    wire signed [IN_W-1:0] w3_re;
    wire signed [IN_W-1:0] w3_im;
    wire signed [IN_W-1:0] w4_re;
    wire signed [IN_W-1:0] w4_im;
    wire signed [IN_W-1:0] w5_re;
    wire signed [IN_W-1:0] w5_im;
    wire signed [IN_W-1:0] w6_re;
    wire signed [IN_W-1:0] w6_im;
    wire signed [IN_W-1:0] w7_re;
    wire signed [IN_W-1:0] w7_im;

    assign w1_re = m1_re_wide >>> 15;
    assign w1_im = m1_im_wide >>> 15;

    assign w2_re = m2_re_wide >>> 15;
    assign w2_im = m2_im_wide >>> 15;

    assign w3_re = m3_re_wide >>> 15;
    assign w3_im = m3_im_wide >>> 15;

    assign w4_re = m4_re_wide >>> 15;
    assign w4_im = m4_im_wide >>> 15;

    assign w5_re = m5_re_wide >>> 15;
    assign w5_im = m5_im_wide >>> 15;

    assign w6_re = m6_re_wide >>> 15;
    assign w6_im = m6_im_wide >>> 15;

    assign w7_re = m7_re_wide >>> 15;
    assign w7_im = m7_im_wide >>> 15;

    // ============================================================
    // FINAL RADIX-8 BUTTERFLY
    // ============================================================

    wire signed [OUT_W-1:0] b0_re;
    wire signed [OUT_W-1:0] b0_im;
    wire signed [OUT_W-1:0] b1_re;
    wire signed [OUT_W-1:0] b1_im;
    wire signed [OUT_W-1:0] b2_re;
    wire signed [OUT_W-1:0] b2_im;
    wire signed [OUT_W-1:0] b3_re;
    wire signed [OUT_W-1:0] b3_im;
    wire signed [OUT_W-1:0] b4_re;
    wire signed [OUT_W-1:0] b4_im;
    wire signed [OUT_W-1:0] b5_re;
    wire signed [OUT_W-1:0] b5_im;
    wire signed [OUT_W-1:0] b6_re;
    wire signed [OUT_W-1:0] b6_im;
    wire signed [OUT_W-1:0] b7_re;
    wire signed [OUT_W-1:0] b7_im;

    radix8_butterfly #(
        .IN_W  (IN_W),
        .INT_W (OUT_W)
    ) u_radix8 (

        .x0_re(t0_re),
        .x0_im(t0_im),

        .x1_re(w1_re),
        .x1_im(w1_im),

        .x2_re(w2_re),
        .x2_im(w2_im),

        .x3_re(w3_re),
        .x3_im(w3_im),

        .x4_re(w4_re),
        .x4_im(w4_im),

        .x5_re(w5_re),
        .x5_im(w5_im),

        .x6_re(w6_re),
        .x6_im(w6_im),

        .x7_re(w7_re),
        .x7_im(w7_im),

        .X0_re(b0_re),
        .X0_im(b0_im),

        .X1_re(b1_re),
        .X1_im(b1_im),

        .X2_re(b2_re),
        .X2_im(b2_im),

        .X3_re(b3_re),
        .X3_im(b3_im),

        .X4_re(b4_re),
        .X4_im(b4_im),

        .X5_re(b5_re),
        .X5_im(b5_im),

        .X6_re(b6_re),
        .X6_im(b6_im),

        .X7_re(b7_re),
        .X7_im(b7_im)
    );

    // ============================================================
    // OUTPUT COUNTER
    // ============================================================

    reg [9:0] output_count;

    // ============================================================
    // FSM
    //
    // One radix-8 butterfly per clock:
    //
    // q1 = 0..7
    // k  = 0..15
    //
    // total = 128 butterflies
    // ============================================================

    always @(posedge clk) begin

        if (rst) begin

            state        <= S_LOAD;
            load_count   <= 11'd0;
            q1_index     <= 3'd0;
            k_index      <= 4'd0;
            output_count <= 10'd0;

            out_re       <= 'sd0;
            out_im       <= 'sd0;
            out_valid    <= 1'b0;
            out_last     <= 1'b0;

            busy         <= 1'b0;
            done         <= 1'b0;

        end
        else begin

            out_valid <= 1'b0;
            out_last  <= 1'b0;
            done      <= 1'b0;

            case (state)

                // =================================================
                // LOAD 1024 STAGE-3 OUTPUTS
                // =================================================

                S_LOAD: begin

                    busy <= 1'b0;

                    if (in_valid && in_ready) begin

                        input_re[load_count] <= $signed(in_re);
                        input_im[load_count] <= $signed(in_im);

                        load_count <= load_count + 11'd1;

                    end

                    if (start && (load_count == N)) begin

                        q1_index <= 3'd0;
                        k_index  <= 4'd0;

                        busy  <= 1'b1;
                        state <= S_PROCESS;

                    end

                end

                // =================================================
                // PROCESS ONE FINAL RADIX-8 BUTTERFLY
                // =================================================

                S_PROCESS: begin

                    busy <= 1'b1;

                    // Output q0 -> k_full
                    output_re_mem[
                        k_full + 128*0
                    ] <= b0_re;

                    output_im_mem[
                        k_full + 128*0
                    ] <= b0_im;

                    // Output q1
                    output_re_mem[
                        k_full + 128*1
                    ] <= b1_re;

                    output_im_mem[
                        k_full + 128*1
                    ] <= b1_im;

                    // Output q2
                    output_re_mem[
                        k_full + 128*2
                    ] <= b2_re;

                    output_im_mem[
                        k_full + 128*2
                    ] <= b2_im;

                    // Output q3
                    output_re_mem[
                        k_full + 128*3
                    ] <= b3_re;

                    output_im_mem[
                        k_full + 128*3
                    ] <= b3_im;

                    // Output q4
                    output_re_mem[
                        k_full + 128*4
                    ] <= b4_re;

                    output_im_mem[
                        k_full + 128*4
                    ] <= b4_im;

                    // Output q5
                    output_re_mem[
                        k_full + 128*5
                    ] <= b5_re;

                    output_im_mem[
                        k_full + 128*5
                    ] <= b5_im;

                    // Output q6
                    output_re_mem[
                        k_full + 128*6
                    ] <= b6_re;

                    output_im_mem[
                        k_full + 128*6
                    ] <= b6_im;

                    // Output q7
                    output_re_mem[
                        k_full + 128*7
                    ] <= b7_re;

                    output_im_mem[
                        k_full + 128*7
                    ] <= b7_im;

                    // ------------------------------------------------
                    // Advance
                    // ------------------------------------------------

                    if (k_index == 15) begin

                        k_index <= 4'd0;

                        if (q1_index == 7) begin

                            output_count <= 10'd0;
                            state <= S_OUTPUT;

                        end
                        else begin

                            q1_index <= q1_index + 3'd1;

                        end

                    end
                    else begin

                        k_index <= k_index + 4'd1;

                    end

                end

                // =================================================
                // STREAM FINAL 1024 FFT BINS
                // =================================================

                S_OUTPUT: begin

                    busy      <= 1'b1;
                    out_valid <= 1'b1;

                    out_re <= output_re_mem[output_count];
                    out_im <= output_im_mem[output_count];

                    if (output_count == N-1) begin

                        out_last <= 1'b1;
                        done     <= 1'b1;
                        busy     <= 1'b0;

                        load_count <= 11'd0;

                        state <= S_LOAD;

                    end
                    else begin

                        output_count <= output_count + 10'd1;

                    end

                end

                default: begin

                    state <= S_LOAD;
                    busy  <= 1'b0;

                end

            endcase

        end

    end

endmodule