`timescale 1ns / 1ps

module custom_fft_8192_wrapper #(
    parameter IN_W  = 16,
    parameter OUT_W = 26
)(
    input wire clk,
    input wire rst,

    input wire signed [IN_W-1:0] in_re,
    input wire signed [IN_W-1:0] in_im,
    input wire                   in_valid,
    output wire                  in_ready,

    output wire signed [OUT_W-1:0] out_re,
    output wire signed [OUT_W-1:0] out_im,
    output wire                    out_valid,
    output wire                    out_last,

    output wire busy,
    output reg  done
);

    localparam integer N_FRAME  = 1024;
    localparam integer N_FRAMES = 8;

    localparam [2:0]
        S_LOAD_FRAME = 3'd0,
        S_FEED_FFT   = 3'd1,
        S_START_FFT  = 3'd2,
        S_WAIT_FFT   = 3'd3;

    reg [2:0] state;

    // ============================================================
    // CURRENT 1024-SAMPLE FRAME
    // ============================================================

    reg signed [15:0] frame_re [0:N_FRAME-1];
    reg signed [15:0] frame_im [0:N_FRAME-1];

    reg [10:0] frame_load_count;

    // ============================================================
    // INPUT SIDE
    // ============================================================

    assign in_ready =
        (state == S_LOAD_FRAME) &&
        (frame_load_count < N_FRAME);

    // ============================================================
    // CUSTOM FFT INTERFACE
    // ============================================================

    reg signed [15:0] fft_in_re;
    reg signed [15:0] fft_in_im;
    reg               fft_in_valid;
    wire              fft_in_ready;

    reg               fft_start;

    wire signed [OUT_W-1:0] fft_out_re;
    wire signed [OUT_W-1:0] fft_out_im;
    wire                    fft_out_valid;
    wire                    fft_out_last;
    wire                    fft_busy;
    wire                    fft_done;

    custom_fft_1024 #(
        .IN_W  (16),
        .R4_W  (20),
        .R8_W1 (23),
        .OUT_W (OUT_W)
    ) u_fft (

        .clk       (clk),
        .rst       (rst),

        .in_re     (fft_in_re),
        .in_im     (fft_in_im),
        .in_valid  (fft_in_valid),
        .in_ready  (fft_in_ready),

        .start     (fft_start),

        .out_re    (fft_out_re),
        .out_im    (fft_out_im),
        .out_valid (fft_out_valid),
        .out_last  (fft_out_last),

        .busy      (fft_busy),
        .done      (fft_done)
    );

    assign out_re    = fft_out_re;
    assign out_im    = fft_out_im;
    assign out_valid = fft_out_valid;
    assign out_last  = fft_out_last;

    assign busy =
        (state != S_LOAD_FRAME) |
        fft_busy;

    // ============================================================
    // FRAME NUMBER
    // ============================================================

    reg [2:0] frame_number;

    // ============================================================
    // FFT INPUT INDEX
    // ============================================================

    reg [10:0] fft_input_index;

    // ============================================================
    // COMBINATIONAL FFT INPUT
    // ============================================================

    always @(*) begin

        if (fft_input_index < N_FRAME) begin

            fft_in_re = frame_re[fft_input_index];
            fft_in_im = frame_im[fft_input_index];

        end
        else begin

            fft_in_re = 16'sd0;
            fft_in_im = 16'sd0;

        end

    end

    // ============================================================
    // FSM
    // ============================================================

    always @(posedge clk) begin

        if (rst) begin

            state            <= S_LOAD_FRAME;

            frame_number     <= 3'd0;
            frame_load_count <= 11'd0;
            fft_input_index  <= 11'd0;

            fft_in_valid     <= 1'b0;
            fft_start        <= 1'b0;

            done             <= 1'b0;

        end
        else begin

            // one-cycle pulses
            fft_start <= 1'b0;
            done      <= 1'b0;

            case (state)

                // =================================================
                // LOAD ONE 1024-SAMPLE FRAME INTO FRAME BUFFER
                // =================================================

                S_LOAD_FRAME: begin

                    fft_in_valid <= 1'b0;

                    if (in_valid && in_ready) begin

                        frame_re[frame_load_count] <= $signed(in_re);
                        frame_im[frame_load_count] <= $signed(in_im);

                        if (frame_load_count == N_FRAME-1) begin

                            frame_load_count <= 11'd0;
                            fft_input_index  <= 11'd0;

                            state <= S_FEED_FFT;

                        end
                        else begin

                            frame_load_count <=
                                frame_load_count + 11'd1;

                        end

                    end

                end

                // =================================================
                // FEED ALL 1024 SAMPLES INTO CUSTOM FFT
                //
                // IMPORTANT:
                // custom_fft_1024 must receive all 1024 samples
                // BEFORE start is asserted.
                // =================================================

                S_FEED_FFT: begin

                    fft_in_valid <= 1'b1;

                    if (fft_in_valid && fft_in_ready) begin

                        if (fft_input_index == N_FRAME-1) begin

                            fft_input_index <= 11'd0;
                            fft_in_valid    <= 1'b0;

                            state <= S_START_FFT;

                        end
                        else begin

                            fft_input_index <=
                                fft_input_index + 11'd1;

                        end

                    end

                end

                // =================================================
                // NOW PULSE START
                // =================================================

                S_START_FFT: begin

                    if (!fft_busy) begin

                        fft_start <= 1'b1;

                        state <= S_WAIT_FFT;

                    end

                end

                // =================================================
                // WAIT FOR FINAL 1024 FFT OUTPUTS
                // =================================================

                S_WAIT_FFT: begin

                    if (fft_done) begin

                        if (frame_number == N_FRAMES-1) begin

                            // All 8 frames complete
                            frame_number     <= 3'd0;
                            frame_load_count <= 11'd0;

                            done <= 1'b1;

                            state <= S_LOAD_FRAME;

                        end
                        else begin

                            frame_number <=
                                frame_number + 3'd1;

                            frame_load_count <= 11'd0;

                            state <= S_LOAD_FRAME;

                        end

                    end

                end

                default: begin

                    state <= S_LOAD_FRAME;

                end

            endcase

        end

    end

endmodule 