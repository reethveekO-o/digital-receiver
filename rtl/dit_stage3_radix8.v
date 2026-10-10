`timescale 1ns / 1ps

module dit_stage3_radix8 #(
    parameter IN_W  = 20,
    parameter OUT_W = 23
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
    localparam integer PARENTS = 8;
    localparam integer KCOUNT = 16;

    localparam [1:0] S_LOAD    = 2'd0;
    localparam [1:0] S_PROCESS = 2'd1;
    localparam [1:0] S_OUTPUT  = 2'd2;

    reg [1:0] state;

    // ============================================================
    // INPUT MEMORY
    // ============================================================

    reg signed [IN_W-1:0] input_re [0:N-1];
    reg signed [IN_W-1:0] input_im [0:N-1];

    reg [10:0] load_count;

    assign in_ready =
        (state == S_LOAD) &&
        (load_count < N);

    // ============================================================
    // OUTPUT MEMORY
    // ============================================================

    reg signed [OUT_W-1:0] output_re_mem [0:N-1];
    reg signed [OUT_W-1:0] output_im_mem [0:N-1];

    // ============================================================
    // STAGE 3 INDICES
    //
    // parent = 0..7
    // k      = 0..15
    //
    // Each radix-8 butterfly uses:
    //
    // stage2[
    //   parent + 8*0
    // ]
    // stage2[
    //   parent + 8*1
    // ]
    // ...
    // stage2[
    //   parent + 8*7
    // ]
    //
    // with the same local k.
    // ============================================================

    reg [2:0] parent_index;
    reg [3:0] k_index;

    // ============================================================
    // TWIDDLE ROM
    //
    // W128^p = exp(-j*2*pi*p/128), Q15
    // ============================================================

    reg signed [15:0] tw_re [0:127];
    reg signed [15:0] tw_im [0:127];

    initial begin
        $readmemh("twiddle128_re.mem", tw_re);
        $readmemh("twiddle128_im.mem", tw_im);
    end

    // ============================================================
    // INPUT TWIDDLES
    //
    // Decimation in time: branch m of each butterfly is multiplied
    // by W128^(m*k) BEFORE the radix-8 butterfly.
    // Branch 0 needs no multiplication (W128^0 = 1).
    // ============================================================

    wire signed [IN_W-1:0] a1_re = input_re[16*(parent_index + 8*1) + k_index];
    wire signed [IN_W-1:0] a1_im = input_im[16*(parent_index + 8*1) + k_index];
    wire [6:0]             p1    = 1 * k_index;

    wire signed [IN_W+16:0] m1_re = a1_re * tw_re[p1] - a1_im * tw_im[p1];
    wire signed [IN_W+16:0] m1_im = a1_re * tw_im[p1] + a1_im * tw_re[p1];

    wire signed [IN_W-1:0] t1_re = m1_re >>> 15;
    wire signed [IN_W-1:0] t1_im = m1_im >>> 15;

    wire signed [IN_W-1:0] a2_re = input_re[16*(parent_index + 8*2) + k_index];
    wire signed [IN_W-1:0] a2_im = input_im[16*(parent_index + 8*2) + k_index];
    wire [6:0]             p2    = 2 * k_index;

    wire signed [IN_W+16:0] m2_re = a2_re * tw_re[p2] - a2_im * tw_im[p2];
    wire signed [IN_W+16:0] m2_im = a2_re * tw_im[p2] + a2_im * tw_re[p2];

    wire signed [IN_W-1:0] t2_re = m2_re >>> 15;
    wire signed [IN_W-1:0] t2_im = m2_im >>> 15;

    wire signed [IN_W-1:0] a3_re = input_re[16*(parent_index + 8*3) + k_index];
    wire signed [IN_W-1:0] a3_im = input_im[16*(parent_index + 8*3) + k_index];
    wire [6:0]             p3    = 3 * k_index;

    wire signed [IN_W+16:0] m3_re = a3_re * tw_re[p3] - a3_im * tw_im[p3];
    wire signed [IN_W+16:0] m3_im = a3_re * tw_im[p3] + a3_im * tw_re[p3];

    wire signed [IN_W-1:0] t3_re = m3_re >>> 15;
    wire signed [IN_W-1:0] t3_im = m3_im >>> 15;

    wire signed [IN_W-1:0] a4_re = input_re[16*(parent_index + 8*4) + k_index];
    wire signed [IN_W-1:0] a4_im = input_im[16*(parent_index + 8*4) + k_index];
    wire [6:0]             p4    = 4 * k_index;

    wire signed [IN_W+16:0] m4_re = a4_re * tw_re[p4] - a4_im * tw_im[p4];
    wire signed [IN_W+16:0] m4_im = a4_re * tw_im[p4] + a4_im * tw_re[p4];

    wire signed [IN_W-1:0] t4_re = m4_re >>> 15;
    wire signed [IN_W-1:0] t4_im = m4_im >>> 15;

    wire signed [IN_W-1:0] a5_re = input_re[16*(parent_index + 8*5) + k_index];
    wire signed [IN_W-1:0] a5_im = input_im[16*(parent_index + 8*5) + k_index];
    wire [6:0]             p5    = 5 * k_index;

    wire signed [IN_W+16:0] m5_re = a5_re * tw_re[p5] - a5_im * tw_im[p5];
    wire signed [IN_W+16:0] m5_im = a5_re * tw_im[p5] + a5_im * tw_re[p5];

    wire signed [IN_W-1:0] t5_re = m5_re >>> 15;
    wire signed [IN_W-1:0] t5_im = m5_im >>> 15;

    wire signed [IN_W-1:0] a6_re = input_re[16*(parent_index + 8*6) + k_index];
    wire signed [IN_W-1:0] a6_im = input_im[16*(parent_index + 8*6) + k_index];
    wire [6:0]             p6    = 6 * k_index;

    wire signed [IN_W+16:0] m6_re = a6_re * tw_re[p6] - a6_im * tw_im[p6];
    wire signed [IN_W+16:0] m6_im = a6_re * tw_im[p6] + a6_im * tw_re[p6];

    wire signed [IN_W-1:0] t6_re = m6_re >>> 15;
    wire signed [IN_W-1:0] t6_im = m6_im >>> 15;

    wire signed [IN_W-1:0] a7_re = input_re[16*(parent_index + 8*7) + k_index];
    wire signed [IN_W-1:0] a7_im = input_im[16*(parent_index + 8*7) + k_index];
    wire [6:0]             p7    = 7 * k_index;

    wire signed [IN_W+16:0] m7_re = a7_re * tw_re[p7] - a7_im * tw_im[p7];
    wire signed [IN_W+16:0] m7_im = a7_re * tw_im[p7] + a7_im * tw_re[p7];

    wire signed [IN_W-1:0] t7_re = m7_re >>> 15;
    wire signed [IN_W-1:0] t7_im = m7_im >>> 15;

    // ============================================================
    // RADIX-8 BUTTERFLY
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

        .x0_re(input_re[16*(parent_index + 8*0) + k_index]),
        .x0_im(input_im[16*(parent_index + 8*0) + k_index]),

        .x1_re(t1_re),
        .x1_im(t1_im),

        .x2_re(t2_re),
        .x2_im(t2_im),

        .x3_re(t3_re),
        .x3_im(t3_im),

        .x4_re(t4_re),
        .x4_im(t4_im),

        .x5_re(t5_re),
        .x5_im(t5_im),

        .x6_re(t6_re),
        .x6_im(t6_im),

        .x7_re(t7_re),
        .x7_im(t7_im),

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
    // ============================================================

    always @(posedge clk) begin

        if (rst) begin

            state          <= S_LOAD;
            load_count     <= 11'd0;
            parent_index   <= 3'd0;
            k_index        <= 4'd0;
            output_count   <= 10'd0;

            out_re         <= 'sd0;
            out_im         <= 'sd0;
            out_valid      <= 1'b0;
            out_last       <= 1'b0;

            busy           <= 1'b0;
            done           <= 1'b0;

        end
        else begin

            out_valid <= 1'b0;
            out_last  <= 1'b0;
            done      <= 1'b0;

            case (state)

                // =================================================
                // LOAD
                // =================================================

                S_LOAD: begin

                    busy <= 1'b0;

                    if (in_valid && in_ready) begin

                        input_re[load_count] <= $signed(in_re);
                        input_im[load_count] <= $signed(in_im);

                        load_count <= load_count + 11'd1;

                    end

                    if (start && (load_count == N)) begin

                        parent_index <= 3'd0;
                        k_index      <= 4'd0;

                        busy  <= 1'b1;
                        state <= S_PROCESS;

                    end

                end

                // =================================================
                // PROCESS
                //
                // 8 parents × 16 k values = 128 radix-8 butterflies
                // =================================================

                S_PROCESS: begin

                    busy <= 1'b1;

                    output_re_mem[128*parent_index + 16*0 + k_index] <= b0_re;
                    output_im_mem[128*parent_index + 16*0 + k_index] <= b0_im;

                    output_re_mem[128*parent_index + 16*1 + k_index] <= b1_re;
                    output_im_mem[128*parent_index + 16*1 + k_index] <= b1_im;

                    output_re_mem[128*parent_index + 16*2 + k_index] <= b2_re;
                    output_im_mem[128*parent_index + 16*2 + k_index] <= b2_im;

                    output_re_mem[128*parent_index + 16*3 + k_index] <= b3_re;
                    output_im_mem[128*parent_index + 16*3 + k_index] <= b3_im;

                    output_re_mem[128*parent_index + 16*4 + k_index] <= b4_re;
                    output_im_mem[128*parent_index + 16*4 + k_index] <= b4_im;

                    output_re_mem[128*parent_index + 16*5 + k_index] <= b5_re;
                    output_im_mem[128*parent_index + 16*5 + k_index] <= b5_im;

                    output_re_mem[128*parent_index + 16*6 + k_index] <= b6_re;
                    output_im_mem[128*parent_index + 16*6 + k_index] <= b6_im;

                    output_re_mem[128*parent_index + 16*7 + k_index] <= b7_re;
                    output_im_mem[128*parent_index + 16*7 + k_index] <= b7_im;

                    // ------------------------------------------------
                    // Advance indices
                    // ------------------------------------------------

                    if (k_index == 15) begin

                        k_index <= 0;

                        if (parent_index == PARENTS-1) begin

                            output_count <= 0;
                            state <= S_OUTPUT;

                        end
                        else begin

                            parent_index <= parent_index + 1;

                        end

                    end
                    else begin

                        k_index <= k_index + 1;

                    end

                end

                // =================================================
                // OUTPUT
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

                        load_count <= 0;

                        state <= S_LOAD;

                    end
                    else begin

                        output_count <= output_count + 1;

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