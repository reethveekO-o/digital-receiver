`timescale 1ns / 1ps

module custom_fft_1024 #(
    parameter IN_W  = 16,
    parameter R4_W  = 20,
    parameter R8_W1 = 23,
    parameter OUT_W = 26
)(
    input wire clk,
    input wire rst,

    // ============================================================
    // 1024-sample input stream
    // ============================================================

    input wire signed [IN_W-1:0] in_re,
    input wire signed [IN_W-1:0] in_im,
    input wire                   in_valid,
    output wire                  in_ready,

    // Pulse after the complete 1024-sample frame is loaded.
    input wire start,

    // ============================================================
    // Final FFT output stream
    // ============================================================

    output wire signed [OUT_W-1:0] out_re,
    output wire signed [OUT_W-1:0] out_im,
    output wire                    out_valid,
    output wire                    out_last,

    output wire                    busy,
    output wire                    done
);

    // ============================================================
    // STAGE 1
    // 16-bit -> 18-bit
    // ============================================================

    wire signed [R4_W-1:0] s1_re;
    wire signed [R4_W-1:0] s1_im;

    wire s1_valid;
    wire s1_last;
    wire s1_ready;

    wire s1_busy;
    wire s1_done;

    // ============================================================
    // STAGE 2
    // 20-bit -> 20-bit
    // ============================================================

    wire signed [R4_W-1:0] s2_re;
    wire signed [R4_W-1:0] s2_im;

    wire s2_valid;
    wire s2_last;
    wire s2_ready;

    wire s2_busy;
    wire s2_done;

    // ============================================================
    // STAGE 3
    // 20-bit -> 23-bit
    // ============================================================

    wire signed [R8_W1-1:0] s3_re;
    wire signed [R8_W1-1:0] s3_im;

    wire s3_valid;
    wire s3_last;
    wire s3_ready;

    wire s3_busy;
    wire s3_done;

    // ============================================================
    // STAGE 4
    // 23-bit -> 26-bit
    // ============================================================

    wire s4_ready;
    wire s4_busy;
    wire s4_done;

    // ============================================================
    // STAGE 1
    // ============================================================

    dit_stage1_radix4 #(
        .IN_W  (IN_W),
        .OUT_W (R4_W)
    ) u_stage1 (

        .clk       (clk),
        .rst       (rst),

        .in_re     (in_re),
        .in_im     (in_im),
        .in_valid  (in_valid),
        .in_ready  (in_ready),

        .start     (start),

        .out_re    (s1_re),
        .out_im    (s1_im),
        .out_valid (s1_valid),
        .out_last  (s1_last),

        .busy      (s1_busy),
        .done      (s1_done)
    );

    // ============================================================
    // STAGE 2
    //
    // Stage 2 starts after Stage 1 has produced all 1024 values.
    // ============================================================

    reg s2_start;

    dit_stage2_radix4 #(
        .IN_W  (R4_W),
        .OUT_W (R4_W)
    ) u_stage2 (

        .clk       (clk),
        .rst       (rst),

        .in_re     (s1_re),
        .in_im     (s1_im),
        .in_valid  (s1_valid),
        .in_ready  (s2_ready),

        .start     (s2_start),

        .out_re    (s2_re),
        .out_im    (s2_im),
        .out_valid (s2_valid),
        .out_last  (s2_last),

        .busy      (s2_busy),
        .done      (s2_done)
    );

    // ============================================================
    // STAGE 3
    // ============================================================

    reg s3_start;

    dit_stage3_radix8 #(
        .IN_W  (R4_W),
        .OUT_W (R8_W1)
    ) u_stage3 (

        .clk       (clk),
        .rst       (rst),

        .in_re     (s2_re),
        .in_im     (s2_im),
        .in_valid  (s2_valid),
        .in_ready  (s3_ready),

        .start     (s3_start),

        .out_re    (s3_re),
        .out_im    (s3_im),
        .out_valid (s3_valid),
        .out_last  (s3_last),

        .busy      (s3_busy),
        .done      (s3_done)
    );

    // ============================================================
    // STAGE 4
    // ============================================================

    reg s4_start;

    dit_stage4_radix8 #(
        .IN_W  (R8_W1),
        .OUT_W (OUT_W)
    ) u_stage4 (

        .clk       (clk),
        .rst       (rst),

        .in_re     (s3_re),
        .in_im     (s3_im),
        .in_valid  (s3_valid),
        .in_ready  (s4_ready),

        .start     (s4_start),

        .out_re    (out_re),
        .out_im    (out_im),
        .out_valid (out_valid),
        .out_last  (out_last),

        .busy      (s4_busy),
        .done      (s4_done)
    );

    assign busy =
        s1_busy |
        s2_busy |
        s3_busy |
        s4_busy;

    assign done = s4_done;

    // ============================================================
    // STAGE CONTROL
    // ============================================================

    localparam [2:0]
        C_WAIT_S1 = 3'd0,
        C_S2      = 3'd1,
        C_S3      = 3'd2,
        C_S4      = 3'd3;

    reg [2:0] control_state;

    always @(posedge clk) begin

        if (rst) begin

            control_state <= C_WAIT_S1;

            s2_start <= 1'b0;
            s3_start <= 1'b0;
            s4_start <= 1'b0;

        end
        else begin

            s2_start <= 1'b0;
            s3_start <= 1'b0;
            s4_start <= 1'b0;

            case (control_state)

                C_WAIT_S1: begin

                    if (s1_done) begin
                        s2_start <= 1'b1;
                        control_state <= C_S2;
                    end

                end

                C_S2: begin

                    if (s2_done) begin
                        s3_start <= 1'b1;
                        control_state <= C_S3;
                    end

                end

                C_S3: begin

                    if (s3_done) begin
                        s4_start <= 1'b1;
                        control_state <= C_S4;
                    end

                end

                C_S4: begin

                    if (s4_done) begin
                        control_state <= C_WAIT_S1;
                    end

                end

                default: begin
                    control_state <= C_WAIT_S1;
                end

            endcase

        end

    end

endmodule