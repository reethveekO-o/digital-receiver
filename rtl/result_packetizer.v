`timescale 1ns / 1ps

// Packs one frame's result into a 52-byte packet and sends it one byte at a
// time (valid / ready / last handshake, the same convention as AXI4-Stream).
// This is the payload a UDP sender would carry to the host PC.
//
// Packet layout, most significant byte first:
//
//   bytes  0- 3   magic number "DRX1" (0x44525831)
//   bytes  4- 7   frame number
//   bytes  8-15   timestamp: index of the frame's first sample
//   bytes 16-19   local-oscillator phase increment
//   bytes 20-21   flags (bit 0: window applied)
//   bytes 22-23   peak bin (0..1023)
//   bytes 24-31   power of the peak bin
//   bytes 32-39   power of the bin before the peak
//   bytes 40-47   power of the bin after the peak
//   bytes 48-51   checksum: sum of the twelve 32-bit words above
//
// A result that arrives while a packet is still being sent is dropped.

module result_packetizer (
    input wire        clk,
    input wire        rst,

    input wire        result_valid,
    input wire [31:0] frame_number,
    input wire [63:0] frame_timestamp,
    input wire [31:0] lo_phase_inc,
    input wire [15:0] flags,
    input wire [9:0]  peak_bin,
    input wire [63:0] peak_power,
    input wire [63:0] left_power,
    input wire [63:0] right_power,

    output wire [7:0] m_tdata,
    output reg        m_tvalid,
    input wire        m_tready,
    output wire       m_tlast
);

    localparam [31:0] MAGIC  = 32'h44525831;
    localparam integer NBYTES = 52;

    wire [31:0] word5 = {flags, 6'd0, peak_bin};

    wire [31:0] checksum =
          MAGIC
        + frame_number
        + frame_timestamp[63:32] + frame_timestamp[31:0]
        + lo_phase_inc
        + word5
        + peak_power[63:32]  + peak_power[31:0]
        + left_power[63:32]  + left_power[31:0]
        + right_power[63:32] + right_power[31:0];

    reg [NBYTES*8-1:0] shift;
    reg [5:0]          count;

    assign m_tdata = shift[NBYTES*8-1 -: 8];
    assign m_tlast = m_tvalid && (count == NBYTES-1);

    always @(posedge clk) begin

        if (rst) begin
            shift    <= {NBYTES*8{1'b0}};
            count    <= 6'd0;
            m_tvalid <= 1'b0;
        end
        else if (!m_tvalid) begin

            if (result_valid) begin
                shift <= {
                    MAGIC,
                    frame_number,
                    frame_timestamp,
                    lo_phase_inc,
                    word5,
                    peak_power,
                    left_power,
                    right_power,
                    checksum
                };
                count    <= 6'd0;
                m_tvalid <= 1'b1;
            end

        end
        else if (m_tready) begin

            shift <= {shift[NBYTES*8-9:0], 8'd0};

            if (count == NBYTES-1) begin
                m_tvalid <= 1'b0;
            end
            else begin
                count <= count + 6'd1;
            end

        end

    end

endmodule
