`timescale 1ns / 1ps

module tb_dds_iq_source;

    reg clk;
    reg rst;
    reg enable;

    reg [31:0] phase_inc;

    wire signed [15:0] i_out;
    wire signed [15:0] q_out;
    wire valid;

    integer sample_count;

    dds_iq_source dut (

        .clk(clk),
        .rst(rst),

        .enable(enable),
        .phase_inc(phase_inc),

        .i_out(i_out),
        .q_out(q_out),
        .valid(valid)
    );


    // ============================================================
    // 100 MHz clock
    // ============================================================

    initial begin

        clk = 0;

        forever #5 clk = ~clk;

    end


    // ============================================================
    // Test
    // ============================================================

    initial begin

        rst = 1;
        enable = 0;

        phase_inc = 32'd85899346;

        sample_count = 0;

        #100;

        rst = 0;

        #20;

        enable = 1;

    end


    // ============================================================
    // Capture samples
    // ============================================================

    always @(posedge clk) begin

        #1;

        if (valid) begin

            if (sample_count < 20) begin

                $display(
                    "DDS [%0d] = I=%0d Q=%0d",
                    sample_count,
                    i_out,
                    q_out
                );

            end

            sample_count = sample_count + 1;

        end

        if (sample_count == 1024) begin

            $display("============================================");
            $display("DDS TEST COMPLETE");
            $display("Samples generated = %0d", sample_count);
            $display("============================================");

            $finish;

        end

    end

endmodule