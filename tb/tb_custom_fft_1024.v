`timescale 1ns / 1ps

module tb_custom_fft_1024;

    // ============================================================
    // CLOCK / RESET
    // ============================================================

    reg clk;
    reg rst;


    // ============================================================
    // INPUT STREAM
    // ============================================================

    reg signed [15:0] in_re;
    reg signed [15:0] in_im;
    reg               in_valid;
    wire              in_ready;

    reg               start;


    // ============================================================
    // FINAL OUTPUT STREAM
    // ============================================================

    wire signed [25:0] out_re;
    wire signed [25:0] out_im;
    wire                out_valid;
    wire                out_last;

    wire busy;
    wire done;


    // ============================================================
    // INPUT MEMORY
    //
    // File contains 8192 samples.
    // This test uses the first 1024 samples.
    // ============================================================

    reg [15:0] i_mem [0:8191];
    reg [15:0] q_mem [0:8191];


    integer sample_index;
    integer output_index;
    integer output_file;


    // ============================================================
    // DUT
    // ============================================================

    custom_fft_1024 dut (

        .clk(clk),
        .rst(rst),

        .in_re(in_re),
        .in_im(in_im),
        .in_valid(in_valid),
        .in_ready(in_ready),

        .start(start),

        .out_re(out_re),
        .out_im(out_im),
        .out_valid(out_valid),
        .out_last(out_last),

        .busy(busy),
        .done(done)
    );


    // ============================================================
    // CLOCK
    // ============================================================

    initial begin

        clk = 1'b0;

        forever #5 clk = ~clk;

    end


    // ============================================================
    // LOAD INPUT FILES
    // ============================================================

    initial begin

        $readmemh(
            "i_samples.mem",
            i_mem
        );

        $readmemh(
            "q_samples.mem",
            q_mem
        );

        $display("============================================");
        $display("CUSTOM 1024-POINT FFT TEST");
        $display("============================================");

        $display(
            "I[0] = %h   Q[0] = %h",
            i_mem[0],
            q_mem[0]
        );

        $display(
            "I[1] = %h   Q[1] = %h",
            i_mem[1],
            q_mem[1]
        );

        $display(
            "I[2] = %h   Q[2] = %h",
            i_mem[2],
            q_mem[2]
        );

        $display("============================================");

    end


    // ============================================================
    // DRIVE INPUT COMBINATIONALLY
    //
    // The current sample is already present before the handshake
    // clock edge, avoiding the one-cycle input shift we previously
    // encountered.
    // ============================================================

    always @(*) begin

        if (sample_index < 1024) begin

            in_re = $signed(i_mem[sample_index]);
            in_im = $signed(q_mem[sample_index]);

        end
        else begin

            in_re = 16'sd0;
            in_im = 16'sd0;

        end

    end


    // ============================================================
    // INITIAL CONDITIONS
    // ============================================================

    initial begin

        rst      = 1'b1;
        in_valid = 1'b0;
        start    = 1'b0;

        sample_index = 0;
        output_index = 0;

        output_file = $fopen(
            "custom_fft_1024_output.txt",
            "w"
        );

        if (output_file == 0) begin

            $display(
                "ERROR: could not open output file"
            );

            $finish;

        end


        // Reset
        #100;

        rst = 1'b0;

        // Begin input stream
        #10;

        in_valid = 1'b1;

    end


    // ============================================================
    // INPUT HANDSHAKE
    // ============================================================

    always @(posedge clk) begin

        if (rst) begin

            sample_index <= 0;
            in_valid     <= 0;
            start        <= 0;

        end
        else begin

            // Default: start is a one-cycle pulse
            start <= 0;


            // ----------------------------------------------------
            // Accept input sample
            // ----------------------------------------------------

            if (in_valid && in_ready) begin

                if (sample_index == 1023) begin

                    // Last sample accepted
                    sample_index <= 1024;
                    in_valid     <= 0;

                end
                else begin

                    sample_index <= sample_index + 1;

                end

            end


            // ----------------------------------------------------
            // Start the FFT after all 1024 samples have been loaded
            // ----------------------------------------------------

            if ((sample_index == 1024) && !busy) begin

                start <= 1;

            end

        end

    end


    // ============================================================
    // OUTPUT CAPTURE
    // ============================================================

    always @(posedge clk) begin

        #1;

        if (out_valid) begin

            $fwrite(
                output_file,
                "%0d %0d %0d\n",
                output_index,
                out_re,
                out_im
            );


            if (output_index < 10) begin

                $display(
                    "FFT OUT [%0d] = %0d + j(%0d)",
                    output_index,
                    out_re,
                    out_im
                );

            end


            output_index = output_index + 1;


            // ----------------------------------------------------
            // Last output
            // ----------------------------------------------------

            if (out_last) begin

                $display("============================================");
                $display("CUSTOM FFT COMPLETE");
                $display(
                    "Outputs = %0d",
                    output_index
                );
                $display("============================================");

                $fclose(output_file);

                #50;

                $finish;

            end

        end

    end


    // ============================================================
    // TIMEOUT
    // ============================================================

    initial begin

        #250000;

        $display("============================================");
        $display("ERROR: CUSTOM FFT TIMEOUT");
        $display(
            "Samples accepted = %0d",
            sample_index
        );
        $display(
            "Outputs received = %0d",
            output_index
        );
        $display("============================================");

        $fclose(output_file);

        $finish;

    end

endmodule