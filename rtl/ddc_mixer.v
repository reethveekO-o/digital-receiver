`timescale 1ns / 1ps

// Digital downconverter, mixing part.
//
// Multiplies the real ADC samples by a complex local oscillator
// exp(-j*2*pi*f_lo*t), which moves the band around f_lo down to 0 Hz:
//
//   bb_i =  adc * cos(lo phase)
//   bb_q = -adc * sin(lo phase)
//
// The result still contains an unwanted copy of the signal at -(f_rf + f_lo).
// The FIR filter that follows removes it.

module ddc_mixer (
    input wire               clk,
    input wire               rst,

    input wire signed [15:0] adc_data,
    input wire               adc_valid,

    input wire [31:0]        lo_phase_inc,      // f_lo / sample rate * 2^32

    output reg signed [15:0] bb_i,
    output reg signed [15:0] bb_q,
    output reg               bb_valid
);

    wire signed [15:0] lo_cos;
    wire signed [15:0] lo_sin;

    dds_iq_source u_lo (
        .clk       (clk),
        .rst       (rst),
        .enable    (adc_valid),
        .ready     (1'b1),
        .phase_inc (lo_phase_inc),
        .i_out     (lo_cos),
        .q_out     (lo_sin),
        .valid     ()
    );

    // 16-bit sample x 16-bit Q15 oscillator value = 32-bit product
    wire signed [31:0] prod_i = adc_data * lo_cos;
    wire signed [31:0] prod_q = -(adc_data * lo_sin);

    always @(posedge clk) begin
        if (rst) begin
            bb_i     <= 16'sd0;
            bb_q     <= 16'sd0;
            bb_valid <= 1'b0;
        end
        else begin
            bb_valid <= adc_valid;
            if (adc_valid) begin
                bb_i <= prod_i >>> 15;
                bb_q <= prod_q >>> 15;
            end
        end
    end

endmodule
