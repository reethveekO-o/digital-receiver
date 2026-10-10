"""Integer models of the Verilog, used by verify.py.

Each function does the same arithmetic as the module it mirrors, so the
simulated output can be checked value for value, not just approximately.
"""
from pathlib import Path

import numpy as np

MEM = Path(__file__).resolve().parent.parent / "mem"

N = 1024                 # FFT length
DECIM = 4                # FIR decimation factor
K = 23170                # round(2^15 / sqrt(2))
MAGIC = 0x44525831       # "DRX1"
PACKET_BYTES = 52


def read_mem(path):
    """A .mem file as signed 16-bit integers."""
    v = np.array([int(line, 16) for line in Path(path).read_text().split()], dtype=np.int64)
    return np.where(v >= 0x8000, v - 0x10000, v)


def write_mem(path, values):
    Path(path).write_text("".join(f"{int(v) & 0xFFFF:04X}\n" for v in values))


# ------------------------------------------------------------------ FFT

def q15(v, c):
    return (v * c) >> 15                    # >> on a Python int floors, like >>> in Verilog


def twiddle(z, m, k, n):
    """Branch m of a butterfly: z * exp(-j*2*pi*m*k/n) with a Q15 twiddle factor.
    Branch 0 is passed through untouched, as in the Verilog."""
    if m == 0:
        return z
    a, b = z
    ang = -2.0 * np.pi * ((m * k) % n) / n
    wr, wi = int(np.round(np.cos(ang) * 32767)), int(np.round(np.sin(ang) * 32767))
    return (a * wr - b * wi) >> 15, (a * wi + b * wr) >> 15


def radix4(x):
    (a0, b0), (a1, b1), (a2, b2), (a3, b3) = x
    return [(a0 + a1 + a2 + a3, b0 + b1 + b2 + b3),
            (a0 + b1 - a2 - b3, b0 - a1 - b2 + a3),
            (a0 - a1 + a2 - a3, b0 - b1 + b2 - b3),
            (a0 - b1 - a2 + b3, b0 + a1 - b2 - a3)]


def radix8(x):
    # Same order of operations as rtl/radix8_butterfly.v.
    A = [(x[n][0] + x[n + 4][0], x[n][1] + x[n + 4][1]) for n in range(4)]
    B = [(x[n][0] - x[n + 4][0], x[n][1] - x[n + 4][1]) for n in range(4)]
    c0 = B[0]
    c1 = (q15(B[1][0] + B[1][1], K), q15(B[1][1] - B[1][0], K))      # B1 * (1-j)/sqrt(2)
    c2 = (B[2][1], -B[2][0])                                         # B2 * (-j)
    c3 = (q15(-B[3][0] + B[3][1], K), q15(-B[3][0] - B[3][1], K))    # B3 * (-1-j)/sqrt(2)
    even = radix4(A)
    odd = radix4([c0, c1, c2, c3])
    return [even[0], odd[0], even[1], odd[1], even[2], odd[2], even[3], odd[3]]


def fft1024(x):
    """x: 1024 (re, im) integer pairs. Returns 1024 (re, im) pairs."""
    s1 = [None] * N                         # stage 1: 256 four-point DFTs
    for b in range(256):
        s1[4 * b:4 * b + 4] = radix4([x[b + 256 * m] for m in range(4)])
    s2 = [None] * N                         # stage 2: combine into 64 sixteen-point DFTs
    for p in range(64):
        for k in range(4):
            y = radix4([twiddle(s1[4 * (p + 64 * m) + k], m, k, 16) for m in range(4)])
            for q in range(4):
                s2[16 * p + 4 * q + k] = y[q]
    s3 = [None] * N                         # stage 3: combine into 8 128-point DFTs
    for p in range(8):
        for k in range(16):
            y = radix8([twiddle(s2[16 * (p + 8 * m) + k], m, k, 128) for m in range(8)])
            for q in range(8):
                s3[128 * p + 16 * q + k] = y[q]
    out = [None] * N                        # stage 4: combine into the 1024-point DFT
    for k in range(128):
        y = radix8([twiddle(s3[128 * m + k], m, k, 1024) for m in range(8)])
        for q in range(8):
            out[k + 128 * q] = y[q]
    return out


# ------------------------------------------------------------- receiver

def dds(phase_inc, count):
    """dds_iq_source: (cos, sin) for `count` consecutive samples from reset."""
    table = read_mem(MEM / "sine_lut.mem")
    phase = (np.arange(count, dtype=np.uint64) * np.uint64(phase_inc)) & np.uint64(0xFFFFFFFF)
    addr = (phase >> np.uint64(22)).astype(np.int64)
    return table[(addr + 256) & 1023], table[addr]


def adc(analog, bits=14):
    """tb/adc_model.v: keep the top `bits` bits of a 16-bit sample."""
    step = 1 << (16 - bits)
    return (np.asarray(analog, dtype=np.int64) // step) * step


def mixer(adc_samples, lo_phase_inc):
    """ddc_mixer: multiply by exp(-j*2*pi*f_lo*t)."""
    x = np.asarray(adc_samples, dtype=np.int64)
    cos, sin = dds(lo_phase_inc, len(x))
    return (x * cos) >> 15, (-(x * sin)) >> 15


def fir_decimate(x):
    """fir_decimator on one of I or Q: filter, keep every 4th result."""
    h = read_mem(MEM / "fir_coeffs.mem")
    y = np.convolve(np.asarray(x, dtype=np.int64), h)[DECIM - 1:len(x):DECIM]
    return np.clip((y + 16384) >> 15, -32768, 32767)


def window(re, im, use_window=True):
    """fft_frame_capture: multiply one 1024-sample frame by the Hann window."""
    if not use_window:
        return list(zip(map(int, re), map(int, im)))
    w = read_mem(MEM / "hann_window.mem")
    return list(zip(map(int, (re * w) >> 15), map(int, (im * w) >> 15)))


def peak(spectrum):
    """peak_detector: (bin, power, power of bin before, power of bin after)."""
    p = [a * a + b * b for a, b in spectrum]
    k = max(range(N), key=lambda i: (p[i], -i))         # first of the largest
    return k, p[k], (p[k - 1] if k > 0 else 0), (p[k + 1] if k < N - 1 else 0)


def packet(frame_number, timestamp, lo_phase_inc, flags, k, power, left, right):
    """result_packetizer: the 52 bytes of one packet."""
    body = b"".join([MAGIC.to_bytes(4, "big"), frame_number.to_bytes(4, "big"),
                     timestamp.to_bytes(8, "big"), lo_phase_inc.to_bytes(4, "big"),
                     flags.to_bytes(2, "big"), k.to_bytes(2, "big"),
                     power.to_bytes(8, "big"), left.to_bytes(8, "big"), right.to_bytes(8, "big")])
    checksum = sum(int.from_bytes(body[i:i + 4], "big") for i in range(0, 48, 4)) & 0xFFFFFFFF
    return body + checksum.to_bytes(4, "big")
