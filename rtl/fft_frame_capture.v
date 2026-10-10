`timescale 1ns / 1ps

// Takes 1024 consecutive samples from a continuous stream, applies a window,
// runs the 1024-point FFT on them, and repeats.
//
// Samples that arrive while the FFT is busy are not used. Every sample is
// still counted, so frame_timestamp tells exactly which samples a frame holds.
//
// Window: hann_window.mem, 1024 Q15 values (python/generate_tables.py).
// Set USE_WINDOW = 0 to pass the samples through unchanged.

module fft_frame_capture #(
    parameter USE_WINDOW = 1
)(
    input wire               clk,
    input wire               rst,

    input wire signed [15:0] in_re,
    input wire signed [15:0] in_im,
    input wire               in_valid,

    // Spectrum of the captured frame, bin 0 first
    output wire signed [25:0] out_re,
    output wire signed [25:0] out_im,
    output wire               out_valid,
    output wire               out_last,

    // Information about the frame whose spectrum is being sent.
    // Stable from the end of its capture until the next capture ends.
    output reg [31:0]         frame_number,
    output reg [63:0]         frame_timestamp    // index of its first sample
);

    localparam integer N = 1024;

    localparam [1:0]
        S_CAPTURE = 2'd0,
        S_FEED    = 2'd1,
        S_START   = 2'd2,
        S_WAIT    = 2'd3;

    reg [1:0] state;

    // ============================================================
    // WINDOW
    // ============================================================

    reg signed [15:0] window [0:N-1];

    initial begin
        $readmemh("hann_window.mem", window);
    end

    reg [10:0] capture_count;

    wire signed [31:0] win_re = in_re * window[capture_count[9:0]];
    wire signed [31:0] win_im = in_im * window[capture_count[9:0]];

    wire signed [15:0] store_re = USE_WINDOW ? (win_re >>> 15) : in_re;
    wire signed [15:0] store_im = USE_WINDOW ? (win_im >>> 15) : in_im;

    // ============================================================
    // FRAME MEMORY
    // ============================================================

    reg signed [15:0] frame_re [0:N-1];
    reg signed [15:0] frame_im [0:N-1];

    reg [63:0] sample_index;        // counts every input sample since reset
    reg [63:0] first_index;         // sample_index of the frame being captured
    reg [31:0] frames_captured;

    // ============================================================
    // FFT
    // ============================================================

    reg [10:0] feed_index;
    reg        fft_in_valid;
    reg        fft_start;

    wire       fft_in_ready;
    wire       fft_busy;
    wire       fft_done;

    custom_fft_1024 u_fft (
        .clk       (clk),
        .rst       (rst),

        .in_re     (frame_re[feed_index[9:0]]),
        .in_im     (frame_im[feed_index[9:0]]),
        .in_valid  (fft_in_valid),
        .in_ready  (fft_in_ready),

        .start     (fft_start),

        .out_re    (out_re),
        .out_im    (out_im),
        .out_valid (out_valid),
        .out_last  (out_last),

        .busy      (fft_busy),
        .done      (fft_done)
    );

    // ============================================================
    // CONTROL
    // ============================================================

    always @(posedge clk) begin

        if (rst) begin

            state           <= S_CAPTURE;
            capture_count   <= 11'd0;
            feed_index      <= 11'd0;
            fft_in_valid    <= 1'b0;
            fft_start       <= 1'b0;

            sample_index    <= 64'd0;
            first_index     <= 64'd0;
            frames_captured <= 32'd0;

            frame_number    <= 32'd0;
            frame_timestamp <= 64'd0;

        end
        else begin

            fft_start <= 1'b0;

            if (in_valid) begin
                sample_index <= sample_index + 64'd1;
            end

            case (state)

                // Store 1024 windowed samples.
                S_CAPTURE: begin

                    if (in_valid) begin

                        frame_re[capture_count[9:0]] <= store_re;
                        frame_im[capture_count[9:0]] <= store_im;

                        if (capture_count == 11'd0) begin
                            first_index <= sample_index;
                        end

                        if (capture_count == N-1) begin

                            capture_count   <= 11'd0;
                            feed_index      <= 11'd0;

                            frame_number    <= frames_captured;
                            frame_timestamp <= first_index;
                            frames_captured <= frames_captured + 32'd1;

                            state <= S_FEED;

                        end
                        else begin
                            capture_count <= capture_count + 11'd1;
                        end

                    end

                end

                // Hand the 1024 samples to the FFT.
                S_FEED: begin

                    fft_in_valid <= 1'b1;

                    if (fft_in_valid && fft_in_ready) begin

                        if (feed_index == N-1) begin
                            feed_index   <= 11'd0;
                            fft_in_valid <= 1'b0;
                            state        <= S_START;
                        end
                        else begin
                            feed_index <= feed_index + 11'd1;
                        end

                    end

                end

                // The FFT must hold all 1024 samples before start.
                S_START: begin

                    if (!fft_busy) begin
                        fft_start <= 1'b1;
                        state     <= S_WAIT;
                    end

                end

                // Wait until the last spectrum value has been sent.
                S_WAIT: begin

                    if (fft_done) begin
                        state <= S_CAPTURE;
                    end

                end

                default: begin
                    state <= S_CAPTURE;
                end

            endcase

        end

    end

endmodule
