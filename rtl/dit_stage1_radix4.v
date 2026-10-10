`timescale 1ns / 1ps

module dit_stage1_radix4 #(
    parameter IN_W  = 16,
    parameter OUT_W = 18
)(
    input wire clk,
    input wire rst,

    // Input sample stream
    input wire signed [IN_W-1:0] in_re,
    input wire signed [IN_W-1:0] in_im,
    input wire                    in_valid,
    output wire                    in_ready,

    // Assert for one cycle after all 1024 inputs are loaded
    input wire                    start,

    // Output stream
    output reg signed [OUT_W-1:0] out_re,
    output reg signed [OUT_W-1:0] out_im,
    output reg                    out_valid,
    output reg                    out_last,

    output reg                    busy,
    output reg                    done
);

    localparam integer N  = 1024;
    localparam integer NB = 256;
    localparam integer STRIDE = 256;

    localparam [1:0] S_LOAD    = 2'd0;
    localparam [1:0] S_PROCESS = 2'd1;
    localparam [1:0] S_OUTPUT  = 2'd2;

    reg [1:0] state;

    // ============================================================
    // Input memory
    // ============================================================

    reg signed [IN_W-1:0] input_re [0:N-1];
    reg signed [IN_W-1:0] input_im [0:N-1];

    reg [10:0] load_count;

    assign in_ready =
        (state == S_LOAD) &&
        (load_count < N);

    // ============================================================
    // Stage-1 output memory
    //
    // 256 butterflies × 4 outputs
    //
    // Address:
    //     butterfly_index * 4 + branch
    // ============================================================

    reg signed [OUT_W-1:0] output_re_mem [0:N-1];
    reg signed [OUT_W-1:0] output_im_mem [0:N-1];

    // ============================================================
    // Current butterfly
    //
    // For b = 0..255:
    //
    // x[b]
    // x[b+256]
    // x[b+512]
    // x[b+768]
    // ============================================================

    reg [7:0] butterfly_index;

    wire signed [OUT_W-1:0] X0_re;
    wire signed [OUT_W-1:0] X0_im;
    wire signed [OUT_W-1:0] X1_re;
    wire signed [OUT_W-1:0] X1_im;
    wire signed [OUT_W-1:0] X2_re;
    wire signed [OUT_W-1:0] X2_im;
    wire signed [OUT_W-1:0] X3_re;
    wire signed [OUT_W-1:0] X3_im;

    // ============================================================
    // Radix-4 butterfly
    // ============================================================

    radix4_butterfly #(
        .IN_W  (IN_W),
        .OUT_W (OUT_W)
    ) u_radix4 (

        .x0_re(input_re[butterfly_index + 0*STRIDE]),
        .x0_im(input_im[butterfly_index + 0*STRIDE]),

        .x1_re(input_re[butterfly_index + 1*STRIDE]),
        .x1_im(input_im[butterfly_index + 1*STRIDE]),

        .x2_re(input_re[butterfly_index + 2*STRIDE]),
        .x2_im(input_im[butterfly_index + 2*STRIDE]),

        .x3_re(input_re[butterfly_index + 3*STRIDE]),
        .x3_im(input_im[butterfly_index + 3*STRIDE]),

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
    // Output counter
    // ============================================================

    reg [9:0] output_count;

    // ============================================================
    // FSM
    // ============================================================

    always @(posedge clk) begin

        if (rst) begin

            state           <= S_LOAD;
            load_count      <= 11'd0;
            butterfly_index <= 8'd0;
            output_count    <= 10'd0;

            out_re          <= 'sd0;
            out_im          <= 'sd0;
            out_valid       <= 1'b0;
            out_last        <= 1'b0;

            busy            <= 1'b0;
            done            <= 1'b0;

        end else begin

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

                        butterfly_index <= 8'd0;
                        busy            <= 1'b1;

                        state <= S_PROCESS;

                    end

                end

                // =================================================
                // PROCESS 256 RADIX-4 BUTTERFLIES
                // =================================================

                S_PROCESS: begin

                    busy <= 1'b1;

                    output_re_mem[4*butterfly_index + 0] <= X0_re;
                    output_im_mem[4*butterfly_index + 0] <= X0_im;

                    output_re_mem[4*butterfly_index + 1] <= X1_re;
                    output_im_mem[4*butterfly_index + 1] <= X1_im;

                    output_re_mem[4*butterfly_index + 2] <= X2_re;
                    output_im_mem[4*butterfly_index + 2] <= X2_im;

                    output_re_mem[4*butterfly_index + 3] <= X3_re;
                    output_im_mem[4*butterfly_index + 3] <= X3_im;

                    if (butterfly_index == NB-1) begin

                        output_count <= 10'd0;
                        state        <= S_OUTPUT;

                    end else begin

                        butterfly_index <= butterfly_index + 8'd1;

                    end

                end

                // =================================================
                // STREAM 1024 STAGE-1 RESULTS
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

                    end else begin

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