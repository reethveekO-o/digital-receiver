`timescale 1ns / 1ps

module tb_custom_fft_8192_wrapper;

    reg clk;
    reg rst;

    reg signed [15:0] in_re;
    reg signed [15:0] in_im;
    reg                in_valid;
    wire               in_ready;

    wire signed [25:0] out_re;
    wire signed [25:0] out_im;
    wire                out_valid;
    wire                out_last;

    wire busy;
    wire done;

    reg [15:0] i_mem [0:8191];
    reg [15:0] q_mem [0:8191];

    integer input_index;
    integer output_index;
    integer output_file;

    // ============================================================
    // DUT
    // ============================================================

    custom_fft_8192_wrapper dut (

        .clk(clk),
        .rst(rst),

        .in_re(in_re),
        .in_im(in_im),
        .in_valid(in_valid),
        .in_ready(in_ready),

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
    // LOAD 8192 INPUT SAMPLES
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
        $display("CUSTOM 8192-SAMPLE FFT TEST");
        $display("============================================");

        $display(
            "I[0] = %h  Q[0] = %h",
            i_mem[0],
            q_mem[0]
        );

        $display(
            "I[1] = %h  Q[1] = %h",
            i_mem[1],
            q_mem[1]
        );

        $display(
            "I[8191] = %h  Q[8191] = %h",
            i_mem[8191],
            q_mem[8191]
        );

        $display("============================================");

    end

    // ============================================================
    // COMBINATIONAL INPUT
    // ============================================================

    always @(*) begin

        if (input_index < 8192) begin

            in_re = $signed(i_mem[input_index]);
            in_im = $signed(q_mem[input_index]);

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

        rst = 1'b1;
        in_valid = 1'b0;

        input_index  = 0;
        output_index = 0;

        output_file = $fopen(
            "custom_fft_8192_output.txt",
            "w"
        );

        if (output_file == 0) begin
            $display("ERROR: could not open output file");
            $finish;
        end

        #100;

        rst = 1'b0;

        #10;

        in_valid = 1'b1;

    end

    // ============================================================
    // INPUT HANDSHAKE
    // ============================================================

    always @(posedge clk) begin

        if (rst) begin
            input_index <= 0;
            in_valid    <= 0;
        end
        else begin

            if (in_valid && in_ready) begin

                if (input_index == 8191) begin

                    input_index <= 8192;
                    in_valid    <= 1'b0;

                    $display(
                        "All 8192 input samples accepted."
                    );

                end
                else begin

                    input_index <= input_index + 1;

                end

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

            if (out_last) begin

                $display(
                "FFT OUTPUT FRAME BOUNDARY: output %0d",
                output_index
              );

            end

        end

    end

    // ============================================================
    // DONE
    // ============================================================

    always @(posedge clk) begin

        #1;

        if (done) begin

            $display(
                "CUSTOM 8192-SAMPLE PROCESSING COMPLETE"
            );

            $display(
                "Total outputs received = %0d",
                output_index
            );

            $fclose(output_file);

            #50;
            $finish;

        end

    end

    // ============================================================
    // TIMEOUT
    // ============================================================

    initial begin

        #1000000;

        $display("============================================");
        $display("ERROR: 8192 FFT TIMEOUT");
        $display(
            "Inputs accepted = %0d",
            input_index
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