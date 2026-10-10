"""Writes the lookup tables in mem/ that the Verilog reads with $readmemh.

  sine_lut.mem        1024-entry sine table for the DDS
  twiddle128_*.mem    W128^k  = exp(-j*2*pi*k/128)   (FFT stage 3)
  twiddle_*.mem       W1024^k = exp(-j*2*pi*k/1024)  (FFT stage 4)
  hann_window.mem     1024-point Hann window
  fir_coeffs.mem      48-tap low-pass filter for the decimate-by-4 stage

Every line is one 16-bit two's-complement value in hexadecimal. All values
are Q15 fractions (32767 stands for just under 1.0).
"""
from pathlib import Path

import numpy as np

MEM = Path(__file__).resolve().parent.parent / "mem"

FIR_TAPS = 48
FIR_CUTOFF = 0.110       # -6 dB point, as a fraction of the input sample rate
FIR_KAISER_BETA = 7.0


def sine_table():
    return np.round(32767 * np.sin(2 * np.pi * np.arange(1024) / 1024)).astype(int)


def twiddles(n):
    angle = -2 * np.pi * np.arange(n) / n
    return (np.round(np.cos(angle) * 32767).astype(int),
            np.round(np.sin(angle) * 32767).astype(int))


def hann_window():
    return np.round(32767 * 0.5 * (1 - np.cos(2 * np.pi * np.arange(1024) / 1024))).astype(int)


def fir_coefficients():
    """Windowed-sinc low-pass filter. The coefficients add up to exactly 32768 (1.0)."""
    n = np.arange(FIR_TAPS) - (FIR_TAPS - 1) / 2
    h = 2 * FIR_CUTOFF * np.sinc(2 * FIR_CUTOFF * n) * np.kaiser(FIR_TAPS, FIR_KAISER_BETA)
    c = np.round(h / h.sum() * 32768).astype(int)
    c[FIR_TAPS // 2 - 1] += (32768 - c.sum()) // 2      # put any rounding remainder
    c[FIR_TAPS // 2] += 32768 - c.sum()                 # on the two centre taps
    return c


def write(name, values):
    (MEM / name).write_text("".join(f"{int(v) & 0xFFFF:04X}\n" for v in values))
    print(f"wrote mem/{name} ({len(values)} values)")


if __name__ == "__main__":
    write("sine_lut.mem", sine_table())
    for n, stem in ((128, "twiddle128"), (1024, "twiddle")):
        re, im = twiddles(n)
        write(f"{stem}_re.mem", re)
        write(f"{stem}_im.mem", im)
    write("hann_window.mem", hann_window())
    write("fir_coeffs.mem", fir_coefficients())
