`timescale 1ns / 1ps

// Testbench for the whole receiver.
//
// Two sources of ADC samples:
//
//   default              read from adc_samples.mem (written by verify.py)
//   `define DDS_SOURCE   a DDS generates an RF tone, adc_model quantises it
//
// Writes:
//
//   rx_fft_output.txt    frame number, real, imaginary: one line per bin
//   rx_packets.txt       one line of 104 hex digits per result packet
//
// The run ends after NFRAMES packets.

module tb_digital_receiver;

    parameter integer NFRAMES     = 4;
    parameter integer MAX_SAMPLES = 65536;

    parameter [31:0] LO_INC = 32'd858993459;    // 1000 MHz at 5 GSPS
    parameter [31:0] RF_INC = 32'd944892805;    // 1100 MHz at 5 GSPS

    reg clk;
    reg rst;
    reg run;

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    // ============================================================
    // ADC SAMPLE SOURCE
    // ============================================================

    wire signed [15:0] adc_data;

`ifdef DDS_SOURCE

    wire signed [15:0] rf_tone;

    dds_iq_source u_rf (
        .clk       (clk),
        .rst       (rst),
        .enable    (run),
        .ready     (1'b1),
        .phase_inc (RF_INC),
        .i_out     (rf_tone),
        .q_out     (),
        .valid     ()
    );

    adc_model #(
        .BITS (14)
    ) u_adc (
        .analog_in (rf_tone),
        .adc_data  (adc_data)
    );

`else

    reg signed [15:0] samples [0:MAX_SAMPLES-1];
    integer sample_number;

    initial begin
        $readmemh("adc_samples.mem", samples);
        sample_number = 0;
    end

    assign adc_data = samples[sample_number];

    always @(posedge clk) begin
        if (run) begin
            sample_number <= sample_number + 1;
            if (sample_number == MAX_SAMPLES-1) begin
                $display("ERROR: ran out of ADC samples");
                $finish;
            end
        end
    end

`endif

    // ============================================================
    // RECEIVER
    // ============================================================

    wire signed [25:0] spec_re;
    wire signed [25:0] spec_im;
    wire               spec_valid;
    wire               spec_last;
    wire [31:0]        spec_frame_number;

    wire [7:0] m_tdata;
    wire       m_tvalid;
    wire       m_tlast;
    reg        m_tready;

    digital_receiver dut (
        .clk               (clk),
        .rst               (rst),
        .adc_data          (adc_data),
        .adc_valid         (run),
        .lo_phase_inc      (LO_INC),
        .spec_re           (spec_re),
        .spec_im           (spec_im),
        .spec_valid        (spec_valid),
        .spec_last         (spec_last),
        .spec_frame_number (spec_frame_number),
        .m_tdata           (m_tdata),
        .m_tvalid          (m_tvalid),
        .m_tready          (m_tready),
        .m_tlast           (m_tlast)
    );

    // ============================================================
    // RUN
    // ============================================================

    integer fft_file;
    integer packet_file;
    integer packets;
    integer stall;

    initial begin

        fft_file    = $fopen("rx_fft_output.txt", "w");
        packet_file = $fopen("rx_packets.txt", "w");
        packets     = 0;
        stall       = 0;

        rst      = 1'b1;
        run      = 1'b0;
        m_tready = 1'b0;

        repeat (10) @(posedge clk);
        rst <= 1'b0;
        repeat (4) @(posedge clk);
        run <= 1'b1;

    end

    // The packet receiver is not ready one cycle in every three, to
    // exercise the handshake.
    always @(posedge clk) begin
        stall    <= (stall == 2) ? 0 : stall + 1;
        m_tready <= (stall != 2);
    end

    always @(posedge clk) begin

        if (spec_valid) begin
            $fwrite(fft_file, "%0d %0d %0d\n", spec_frame_number, spec_re, spec_im);
        end

        if (m_tvalid && m_tready) begin

            $fwrite(packet_file, "%02x", m_tdata);

            if (m_tlast) begin

                $fwrite(packet_file, "\n");
                packets = packets + 1;

                if (packets == NFRAMES) begin
                    $fclose(fft_file);
                    $fclose(packet_file);
                    $display("RECEIVER TEST COMPLETE: %0d packets", packets);
                    $finish;
                end

            end

        end

    end

    initial begin
        #20000000;
        $display("ERROR: receiver test timed out");
        $finish;
    end

endmodule
