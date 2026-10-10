`timescale 1ns / 1ps

module dit_stage2_radix4 #(
    parameter IN_W  = 18,
    parameter OUT_W = 20
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
    localparam integer PARENTS = 64;

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
    //
    // address:
    //   parent*16 + q*4 + k3
    // ============================================================

    reg signed [OUT_W-1:0] output_re_mem [0:N-1];
    reg signed [OUT_W-1:0] output_im_mem [0:N-1];

    // ============================================================
    // CURRENT STAGE-2 INDICES
    //
    // parent = 0..63
    // k3     = 0..3
    //
    // Stage-1 addresses:
    //
    // 4*(parent + 64*m2) + k3
    // ============================================================

    reg [5:0] parent_index;
    reg [1:0] k3_index;

    // ============================================================
    // INPUT TWIDDLES
    //
    // Decimation in time: branch m of each butterfly is multiplied
    // by W16^(m*k3) BEFORE the radix-4 butterfly.
    // Branch 0 needs no multiplication (W16^0 = 1).
    // ============================================================

    wire signed [IN_W-1:0] a1_re = input_re[4*(parent_index + 64*1) + k3_index];
    wire signed [IN_W-1:0] a1_im = input_im[4*(parent_index + 64*1) + k3_index];
    wire [3:0]             p1    = 1 * k3_index;

    wire signed [IN_W+16:0] m1_re = a1_re * tw_re16(p1) - a1_im * tw_im16(p1);
    wire signed [IN_W+16:0] m1_im = a1_re * tw_im16(p1) + a1_im * tw_re16(p1);

    wire signed [IN_W-1:0] t1_re = m1_re >>> 15;
    wire signed [IN_W-1:0] t1_im = m1_im >>> 15;

    wire signed [IN_W-1:0] a2_re = input_re[4*(parent_index + 64*2) + k3_index];
    wire signed [IN_W-1:0] a2_im = input_im[4*(parent_index + 64*2) + k3_index];
    wire [3:0]             p2    = 2 * k3_index;

    wire signed [IN_W+16:0] m2_re = a2_re * tw_re16(p2) - a2_im * tw_im16(p2);
    wire signed [IN_W+16:0] m2_im = a2_re * tw_im16(p2) + a2_im * tw_re16(p2);

    wire signed [IN_W-1:0] t2_re = m2_re >>> 15;
    wire signed [IN_W-1:0] t2_im = m2_im >>> 15;

    wire signed [IN_W-1:0] a3_re = input_re[4*(parent_index + 64*3) + k3_index];
    wire signed [IN_W-1:0] a3_im = input_im[4*(parent_index + 64*3) + k3_index];
    wire [3:0]             p3    = 3 * k3_index;

    wire signed [IN_W+16:0] m3_re = a3_re * tw_re16(p3) - a3_im * tw_im16(p3);
    wire signed [IN_W+16:0] m3_im = a3_re * tw_im16(p3) + a3_im * tw_re16(p3);

    wire signed [IN_W-1:0] t3_re = m3_re >>> 15;
    wire signed [IN_W-1:0] t3_im = m3_im >>> 15;

    // ============================================================
    // RADIX-4 BUTTERFLY OUTPUT
    // ============================================================

    wire signed [OUT_W-1:0] X0_re;
    wire signed [OUT_W-1:0] X0_im;
    wire signed [OUT_W-1:0] X1_re;
    wire signed [OUT_W-1:0] X1_im;
    wire signed [OUT_W-1:0] X2_re;
    wire signed [OUT_W-1:0] X2_im;
    wire signed [OUT_W-1:0] X3_re;
    wire signed [OUT_W-1:0] X3_im;

    radix4_butterfly #(
        .IN_W  (IN_W),
        .OUT_W (OUT_W)
    ) u_radix4 (

        .x0_re(input_re[4*(parent_index + 64*0) + k3_index]),
        .x0_im(input_im[4*(parent_index + 64*0) + k3_index]),

        .x1_re(t1_re),
        .x1_im(t1_im),

        .x2_re(t2_re),
        .x2_im(t2_im),

        .x3_re(t3_re),
        .x3_im(t3_im),

        .X0_re(X0_re),
        .X0_im(X0_im),

        .X1_re(X1_re),
        .X1_im(X1_im),

        .X2_re(X2_re),
        .X2_im(X2_im),

        .X3_re(X3_re),
        .X3_im(X3_im)
    );

    // ============================================================
    // W16 TWIDDLES
    //
    // W16^p = exp(-j*2*pi*p/16)
    // Q15
    //
    // p = 0..15
    // ============================================================

    function signed [15:0] tw_re16;
        input integer idx;

        begin
            case (idx & 15)
                0:  tw_re16 =  16'sd32767;
                1:  tw_re16 =  16'sd30273;
                2:  tw_re16 =  16'sd23170;
                3:  tw_re16 =  16'sd12539;
                4:  tw_re16 =  16'sd0;
                5:  tw_re16 = -16'sd12539;
                6:  tw_re16 = -16'sd23170;
                7:  tw_re16 = -16'sd30273;
                8:  tw_re16 = -16'sd32767;
                9:  tw_re16 = -16'sd30273;
                10: tw_re16 = -16'sd23170;
                11: tw_re16 = -16'sd12539;
                12: tw_re16 =  16'sd0;
                13: tw_re16 =  16'sd12539;
                14: tw_re16 =  16'sd23170;
                15: tw_re16 =  16'sd30273;
                default: tw_re16 = 16'sd0;
            endcase
        end
    endfunction

    function signed [15:0] tw_im16;
        input integer idx;

        begin
            case (idx & 15)
                0:  tw_im16 =  16'sd0;
                1:  tw_im16 = -16'sd12539;
                2:  tw_im16 = -16'sd23170;
                3:  tw_im16 = -16'sd30273;
                4:  tw_im16 = -16'sd32767;
                5:  tw_im16 = -16'sd30273;
                6:  tw_im16 = -16'sd23170;
                7:  tw_im16 = -16'sd12539;
                8:  tw_im16 =  16'sd0;
                9:  tw_im16 =  16'sd12539;
                10: tw_im16 =  16'sd23170;
                11: tw_im16 =  16'sd30273;
                12: tw_im16 =  16'sd32767;
                13: tw_im16 =  16'sd30273;
                14: tw_im16 =  16'sd23170;
                15: tw_im16 =  16'sd12539;
                default: tw_im16 = 16'sd0;
            endcase
        end
    endfunction

    // ============================================================
    // OUTPUT COUNTER
    // ============================================================

    reg [9:0] output_count;

    // ============================================================
    // FSM
    // ============================================================

    always @(posedge clk) begin

        if (rst) begin

            state         <= S_LOAD;
            load_count    <= 11'd0;
            parent_index  <= 6'd0;
            k3_index      <= 2'd0;
            output_count  <= 10'd0;

            out_re        <= 'sd0;
            out_im        <= 'sd0;
            out_valid     <= 1'b0;
            out_last      <= 1'b0;

            busy          <= 1'b0;
            done          <= 1'b0;

        end else begin

            out_valid <= 1'b0;
            out_last  <= 1'b0;
            done      <= 1'b0;

            case (state)

                // =================================================
                // LOAD STAGE-1 OUTPUTS
                // =================================================

                S_LOAD: begin

                    busy <= 1'b0;

                    if (in_valid && in_ready) begin

                        input_re[load_count] <= $signed(in_re);
                        input_im[load_count] <= $signed(in_im);

                        load_count <= load_count + 11'd1;

                    end

                    if (start && (load_count == N)) begin

                        parent_index <= 6'd0;
                        k3_index     <= 2'd0;

                        busy  <= 1'b1;
                        state <= S_PROCESS;

                    end

                end

                // =================================================
                // PROCESS
                //
                // 64 parents × 4 k3 values
                // = 256 radix-4 butterflies
                // =================================================

                S_PROCESS: begin

                    busy <= 1'b1;

                    // ------------------------------------------------
                    // q=0
                    // W16^(0*k3) = 1
                    // ------------------------------------------------

                    output_re_mem[
                        16*parent_index +
                        4*0 +
                        k3_index
                    ] <= X0_re;

                    output_im_mem[
                        16*parent_index +
                        4*0 +
                        k3_index
                    ] <= X0_im;

                    // ------------------------------------------------
                    // q=1
                    // (twiddles were applied to the inputs)
                    // ------------------------------------------------

// branch outputs are stored directly

                    output_re_mem[
                        16*parent_index +
                        4*1 +
                        k3_index
                    ] <= X1_re;

                    output_im_mem[
                        16*parent_index +
                        4*1 +
                        k3_index
                    ] <= X1_im;

                    // ------------------------------------------------
                    // q=2
                    // (twiddles were applied to the inputs)
                    // ------------------------------------------------

// branch outputs are stored directly

                    output_re_mem[
                        16*parent_index +
                        4*2 +
                        k3_index
                    ] <= X2_re;

                    output_im_mem[
                        16*parent_index +
                        4*2 +
                        k3_index
                    ] <= X2_im;

                    // ------------------------------------------------
                    // q=3
                    // (twiddles were applied to the inputs)
                    // ------------------------------------------------

// branch outputs are stored directly

                    output_re_mem[
                        16*parent_index +
                        4*3 +
                        k3_index
                    ] <= X3_re;

                    output_im_mem[
                        16*parent_index +
                        4*3 +
                        k3_index
                    ] <= X3_im;

                    // ------------------------------------------------
                    // Advance
                    // ------------------------------------------------

                    if (k3_index == 3) begin

                        k3_index <= 0;

                        if (parent_index == PARENTS-1) begin

                            output_count <= 10'd0;
                            state <= S_OUTPUT;

                        end else begin

                            parent_index <= parent_index + 1;

                        end

                    end else begin

                        k3_index <= k3_index + 1;

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

                    end else begin

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