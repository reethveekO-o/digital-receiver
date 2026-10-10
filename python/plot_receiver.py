"""Draws the receiver plots in docs/ from the last run of verify.py.

  receiver_spectrum.png   spectrum the receiver computed for the "rx file" test
  fir_response.png        frequency response of the decimation filter
"""
from pathlib import Path

import matplotlib
matplotlib.use("Agg")          # write image files without opening windows
import matplotlib.pyplot as plt
import numpy as np

import model

ROOT = Path(__file__).resolve().parent.parent
DOCS = ROOT / "docs"
FS = 5e9
F_LO = 1000e6
N = 1024

# ------------------------------------------------------------
# Receiver spectrum, frame 0
# ------------------------------------------------------------

d = np.loadtxt(ROOT / "build" / "rx_file" / "rx_fft_output.txt", dtype=np.int64)
d = d[d[:, 0] == 0]
power = d[:, 1].astype(float) ** 2 + d[:, 2].astype(float) ** 2
db = 10 * np.log10(np.fft.fftshift(power) / power.max() + 1e-30)
rf_mhz = (F_LO + (np.arange(N) - N // 2) * FS / 4 / N) / 1e6

plt.figure(figsize=(10, 5))
plt.plot(rf_mhz, db)
plt.axvline(1100, color="gray", linestyle=":", linewidth=1)
plt.axvline(1230, color="gray", linestyle=":", linewidth=1)
plt.text(1105, -8, "1100 MHz tone")
plt.text(1235, -48, "1230 MHz tone,\n40 dB weaker")
plt.xlabel("RF frequency (MHz)")
plt.ylabel("Power relative to the peak (dB)")
plt.title("Receiver output: 1024-point spectrum after downconversion and decimation by 4")
plt.ylim(-110, 5)
plt.grid(True)
plt.tight_layout()
plt.savefig(DOCS / "receiver_spectrum.png", dpi=200)
plt.close()

# ------------------------------------------------------------
# Decimation filter
# ------------------------------------------------------------

h = model.read_mem(ROOT / "mem" / "fir_coeffs.mem") / 32768
H = np.abs(np.fft.rfft(h, 8192))
f_mhz = np.arange(len(H)) * FS / 8192 / 1e6

plt.figure(figsize=(10, 5))
plt.plot(f_mhz, 20 * np.log10(np.maximum(H, 1e-9)))
plt.axvspan(0, 400, color="green", alpha=0.08, label="wanted band, up to 400 MHz")
plt.axvspan(850, 2500, color="red", alpha=0.06, label="would fold onto the wanted band")
plt.xlabel("Frequency offset from the local oscillator (MHz)")
plt.ylabel("Gain (dB)")
plt.title("48-tap decimation filter (16-bit coefficients)")
plt.ylim(-110, 5)
plt.legend(loc="upper right")
plt.grid(True)
plt.tight_layout()
plt.savefig(DOCS / "fir_response.png", dpi=200)
plt.close()

print("wrote docs/receiver_spectrum.png and docs/fir_response.png")
