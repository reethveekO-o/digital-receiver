`timescale 1ns / 1ps

module tb_dds_fft_8192_system;

    reg clk;
    reg rst;
    reg enable;

    reg [31:0] phase_inc;

    wire signed [25:0] fft_out_re;
    wire signed [25:0] fft_out_im;

    wire fft_out_valid;
    wire fft_out_last;

    wire busy;
    wire done;

    integer output_index;
    integer output_file;

    // ============================================================
    // DUT
    // ============================================================

    dds_fft_8192_system dut (
        .clk(clk),
        .rst(rst),

        .enable(enable),
        .phase_inc(phase_inc),

        .fft_out_re(fft_out_re),
        .fft_out_im(fft_out_im),

        .fft_out_valid(fft_out_valid),
        .fft_out_last(fft_out_last),

        .busy(busy),
        .done(done)
    );

    // ============================================================
    // 100 MHz clock
    // ============================================================

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    // ============================================================
    // Test setup
    //
    // Fs = 5 GHz
    // Fout = 100 MHz
    //
    // FCW = 100e6 / 5e9 * 2^32
    //     ≈ 85899346
    // ============================================================

    initial begin

        rst       = 1'b1;
        enable    = 1'b0;
        phase_inc = 32'd85899346;

        output_index = 0;

        output_file = $fopen(
            "dds_fft_8192_output.txt",
            "w"
        );

        if (output_file == 0) begin
            $display("ERROR: cannot open output file");
            $finish;
        end

        $display("============================================");
        $display("DDS -> CUSTOM 8192 FFT SYSTEM");
        $display("============================================");
        $display("Sampling rate : 5 GSPS");
        $display("Tone          : 100 MHz");
        $display("Phase INC     : %0d", phase_inc);
        $display("============================================");

        #100;

        rst = 1'b0;

        #20;

        enable = 1'b1;

    end

    // ============================================================
    // Capture FFT outputs
    // ============================================================

    always @(posedge clk) begin

        #1;

        if (fft_out_valid) begin

            $fwrite(
                output_file,
                "%0d %0d %0d\n",
                output_index,
                fft_out_re,
                fft_out_im
            );

            if (output_index < 10) begin
                $display(
                    "FFT OUT [%0d] = %0d + j(%0d)",
                    output_index,
                    fft_out_re,
                    fft_out_im
                );
            end

            output_index = output_index + 1;

            if (fft_out_last) begin

                $display(
                    "FFT FRAME COMPLETE at output %0d",
                    output_index
                );

            end
        end

        if (done) begin

            $display("============================================");
            $display("DDS -> FFT SYSTEM COMPLETE");
            $display(
                "Total FFT outputs = %0d",
                output_index
            );
            $display("============================================");

            $fclose(output_file);

            #50;
            $finish;
        end

    end

    // ============================================================
    // Timeout
    // ============================================================

    initial begin

        #1000000;

        $display("============================================");
        $display("ERROR: DDS -> FFT TIMEOUT");
        $display(
            "FFT outputs received = %0d",
            output_index
        );
        $display("============================================");

        $fclose(output_file);
        $finish;

    end

endmodule