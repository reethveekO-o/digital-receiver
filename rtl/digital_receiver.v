`timescale 1ns / 1ps

// Digital receiver, from ADC samples to result packets.
//
//   ADC samples (real, 16-bit)
//      -> ddc_mixer          shift the band around f_lo down to 0 Hz
//      -> fir_decimator      low-pass filter, keep 1 sample in 4
//      -> fft_frame_capture  window 1024 samples, 1024-point FFT
//      -> peak_detector      strongest bin and its two neighbours
//      -> result_packetizer  52-byte packet for the host
//
// The spectrum itself is also available on the spec_* outputs.

module digital_receiver #(
    parameter USE_WINDOW = 1
)(
    input wire               clk,
    input wire               rst,

    // From the ADC: one sample per clock when adc_valid is high.
    input wire signed [15:0] adc_data,
    input wire               adc_valid,

    // Tuning: f_lo / ADC sample rate * 2^32
    input wire [31:0]        lo_phase_inc,

    // Spectrum of each frame, bin 0 first
    output wire signed [25:0] spec_re,
    output wire signed [25:0] spec_im,
    output wire               spec_valid,
    output wire               spec_last,
    output wire [31:0]        spec_frame_number,

    // Result packets, one byte at a time
    output wire [7:0]         m_tdata,
    output wire               m_tvalid,
    input wire                m_tready,
    output wire               m_tlast
);

    // ------------------------------------------------------------
    // Downconversion
    // ------------------------------------------------------------

    wire signed [15:0] bb_i;
    wire signed [15:0] bb_q;
    wire               bb_valid;

    ddc_mixer u_mixer (
        .clk          (clk),
        .rst          (rst),
        .adc_data     (adc_data),
        .adc_valid    (adc_valid),
        .lo_phase_inc (lo_phase_inc),
        .bb_i         (bb_i),
        .bb_q         (bb_q),
        .bb_valid     (bb_valid)
    );

    // ------------------------------------------------------------
    // Filtering and decimation by 4
    // ------------------------------------------------------------

    wire signed [15:0] dec_i;
    wire signed [15:0] dec_q;
    wire               dec_valid;

    fir_decimator #(
        .NTAPS (48),
        .DECIM (4)
    ) u_fir (
        .clk       (clk),
        .rst       (rst),
        .in_re     (bb_i),
        .in_im     (bb_q),
        .in_valid  (bb_valid),
        .out_re    (dec_i),
        .out_im    (dec_q),
        .out_valid (dec_valid)
    );

    // ------------------------------------------------------------
    // Framing, window and FFT
    // ------------------------------------------------------------

    wire [63:0] frame_timestamp;

    fft_frame_capture #(
        .USE_WINDOW (USE_WINDOW)
    ) u_capture (
        .clk             (clk),
        .rst             (rst),
        .in_re           (dec_i),
        .in_im           (dec_q),
        .in_valid        (dec_valid),
        .out_re          (spec_re),
        .out_im          (spec_im),
        .out_valid       (spec_valid),
        .out_last        (spec_last),
        .frame_number    (spec_frame_number),
        .frame_timestamp (frame_timestamp)
    );

    // ------------------------------------------------------------
    // Peak search
    // ------------------------------------------------------------

    wire [9:0]  peak_bin;
    wire [63:0] peak_power;
    wire [63:0] left_power;
    wire [63:0] right_power;
    wire        peak_valid;

    peak_detector u_peak (
        .clk         (clk),
        .rst         (rst),
        .in_re       (spec_re),
        .in_im       (spec_im),
        .in_valid    (spec_valid),
        .in_last     (spec_last),
        .peak_bin    (peak_bin),
        .peak_power  (peak_power),
        .left_power  (left_power),
        .right_power (right_power),
        .peak_valid  (peak_valid)
    );

    // ------------------------------------------------------------
    // Result packet
    // ------------------------------------------------------------

    wire [15:0] flags = USE_WINDOW ? 16'd1 : 16'd0;

    result_packetizer u_packet (
        .clk             (clk),
        .rst             (rst),
        .result_valid    (peak_valid),
        .frame_number    (spec_frame_number),
        .frame_timestamp (frame_timestamp),
        .lo_phase_inc    (lo_phase_inc),
        .flags           (flags),
        .peak_bin        (peak_bin),
        .peak_power      (peak_power),
        .left_power      (left_power),
        .right_power     (right_power),
        .m_tdata         (m_tdata),
        .m_tvalid        (m_tvalid),
        .m_tready        (m_tready),
        .m_tlast         (m_tlast)
    );

endmodule
