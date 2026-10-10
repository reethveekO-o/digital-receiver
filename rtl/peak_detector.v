`timescale 1ns / 1ps

// Finds the strongest bin of each spectrum as it streams past.
//
// For every bin it computes the power re^2 + im^2 and remembers the largest
// one, together with the power of the bin just before and just after it.
// The host uses those two neighbours to estimate the frequency more finely
// than one bin.
//
// The neighbours do not wrap around: the bin before bin 0 and the bin after
// bin 1023 are reported as 0.

module peak_detector (
    input wire               clk,
    input wire               rst,

    input wire signed [25:0] in_re,
    input wire signed [25:0] in_im,
    input wire               in_valid,
    input wire               in_last,

    output reg [9:0]         peak_bin,
    output reg [63:0]        peak_power,
    output reg [63:0]        left_power,     // bin peak_bin - 1
    output reg [63:0]        right_power,    // bin peak_bin + 1
    output reg               peak_valid      // one-cycle pulse per frame
);

    wire signed [63:0] re_wide = in_re;
    wire signed [63:0] im_wide = in_im;

    wire [63:0] power = re_wide * re_wide + im_wide * im_wide;

    reg [9:0]  bin;
    reg [63:0] previous_power;
    reg        want_right;          // the next bin is the peak's right neighbour

    reg [9:0]  best_bin;
    reg [63:0] best_power;
    reg [63:0] best_left;
    reg [63:0] best_right;

    reg        frame_end;

    always @(posedge clk) begin

        if (rst) begin

            bin            <= 10'd0;
            previous_power <= 64'd0;
            want_right     <= 1'b0;

            best_bin       <= 10'd0;
            best_power     <= 64'd0;
            best_left      <= 64'd0;
            best_right     <= 64'd0;

            frame_end      <= 1'b0;

            peak_bin       <= 10'd0;
            peak_power     <= 64'd0;
            left_power     <= 64'd0;
            right_power    <= 64'd0;
            peak_valid     <= 1'b0;

        end
        else begin

            peak_valid <= 1'b0;
            frame_end  <= 1'b0;

            if (in_valid) begin

                if (bin == 10'd0 || power > best_power) begin
                    // New largest value (bin 0 always starts a new search).
                    best_bin   <= bin;
                    best_power <= power;
                    best_left  <= (bin == 10'd0) ? 64'd0 : previous_power;
                    best_right <= 64'd0;
                    want_right <= 1'b1;
                end
                else if (want_right) begin
                    best_right <= power;
                    want_right <= 1'b0;
                end

                previous_power <= power;

                if (in_last) begin
                    bin       <= 10'd0;
                    frame_end <= 1'b1;
                end
                else begin
                    bin <= bin + 10'd1;
                end

            end

            // One cycle after the last bin the search result is complete.
            if (frame_end) begin
                peak_bin    <= best_bin;
                peak_power  <= best_power;
                left_power  <= best_left;
                right_power <= best_right;
                peak_valid  <= 1'b1;
            end

        end

    end

endmodule
