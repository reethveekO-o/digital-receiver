`timescale 1ns / 1ps

// Simulation model of the ADC's digital side.
//
// Takes an ideal 16-bit sample and keeps only the top BITS bits, the way an
// RF data converter delivers a 14-bit result in the upper bits of a 16-bit
// word. Not for synthesis: on a board this is the real ADC.

module adc_model #(
    parameter BITS = 14
)(
    input wire signed [15:0]  analog_in,
    output wire signed [15:0] adc_data
);

    wire [15:0] mask = {16{1'b1}} << (16 - BITS);

    assign adc_data = analog_in & mask;

endmodule
