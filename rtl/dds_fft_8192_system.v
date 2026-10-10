`timescale 1ns / 1ps

module dds_fft_8192_system #(
    parameter PHASE_W = 32,
    parameter DATA_W  = 16,
    parameter FFT_W   = 26
)(
    input wire clk,
    input wire rst,

    input wire                   enable,
    input wire [PHASE_W-1:0]    phase_inc,

    output wire signed [FFT_W-1:0] fft_out_re,
    output wire signed [FFT_W-1:0] fft_out_im,
    output wire                    fft_out_valid,
    output wire                    fft_out_last,

    output wire                    busy,
    output wire                    done
);

    // ============================================================
    // DDS
    // ============================================================

    wire signed [DATA_W-1:0] dds_i;
    wire signed [DATA_W-1:0] dds_q;
    wire                     dds_valid;

    dds_iq_source #(
        .PHASE_W(PHASE_W),
        .DATA_W (DATA_W)
    ) u_dds (
        .clk       (clk),
        .rst       (rst),
        .enable    (enable),
        .phase_inc (phase_inc),
        .i_out     (dds_i),
        .q_out     (dds_q),
        .valid     (dds_valid)
    );

    // ============================================================
    // CUSTOM 8192 FFT
    // ============================================================

    wire fft_in_ready;

    custom_fft_8192_wrapper #(
        .IN_W  (DATA_W),
        .OUT_W (FFT_W)
    ) u_fft8192 (
        .clk       (clk),
        .rst       (rst),

        .in_re     (dds_i),
        .in_im     (dds_q),

        .in_valid  (dds_valid),
        .in_ready  (fft_in_ready),

        .out_re    (fft_out_re),
        .out_im    (fft_out_im),
        .out_valid (fft_out_valid),
        .out_last  (fft_out_last),

        .busy      (busy),
        .done      (done)
    );

endmodule
