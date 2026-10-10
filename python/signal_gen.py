from pathlib import Path

import numpy as np
import matplotlib.pyplot as plt

MEM = Path(__file__).resolve().parent.parent / "mem"

# -----------------------------
# Parameters
# -----------------------------
Fs = 5e9          # 5 GSPS
Fc = 100e6        # 100 MHz
N = 8192          # samples

# -----------------------------
# Generate complex I/Q signal
# -----------------------------
n = np.arange(N)

x = np.exp(1j * 2 * np.pi * Fc * n / Fs)

I = np.real(x)
Q = np.imag(x)

# -----------------------------
# Convert to signed 16-bit
# -----------------------------
scale = 32767

I_int = np.round(I * scale).astype(np.int16)
Q_int = np.round(Q * scale).astype(np.int16)

# -----------------------------
# Print first few samples
# -----------------------------
print("First 10 samples:")
for i in range(10):
    print(f"{i}: I={I_int[i]}, Q={Q_int[i]}")

# Save separate hexadecimal memory files for the testbenches
with open(MEM / "i_samples.mem", "w") as f:
    for value in I_int:
        f.write(f"{int(value) & 0xFFFF:04X}\n")

with open(MEM / "q_samples.mem", "w") as f:
    for value in Q_int:
        f.write(f"{int(value) & 0xFFFF:04X}\n")

print("Saved i_samples.mem")
print("Saved q_samples.mem")

# -----------------------------
# FFT
# -----------------------------
X = np.fft.fft(x)
freq = np.fft.fftfreq(N, 1/Fs)

# Shift zero frequency to center
X_shifted = np.fft.fftshift(X)
freq_shifted = np.fft.fftshift(freq)

magnitude = np.abs(X_shifted)

# -----------------------------
# Plot
# -----------------------------
plt.figure(figsize=(10, 5))
plt.plot(freq_shifted / 1e6, magnitude)
plt.xlabel("Frequency (MHz)")
plt.ylabel("Magnitude")
plt.title("8192-point FFT of 100 MHz Complex Signal")
plt.grid()
plt.xlim(0, 200)
plt.show()
