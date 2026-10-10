import numpy as np
import matplotlib
matplotlib.use("Agg")          # write image files without opening windows
import matplotlib.pyplot as plt
from pathlib import Path

# ============================================================
# DDS -> CUSTOM FFT : REPORT PLOTS
# ============================================================

ROOT = Path(__file__).resolve().parent.parent
FILE = ROOT / "build" / "dds_fft" / "dds_fft_8192_output.txt"
DOCS = ROOT / "docs"

N = 1024
FRAMES = 8
FS = 5e9

# ------------------------------------------------------------
# Load RTL FFT output
# ------------------------------------------------------------

data = np.loadtxt(FILE, dtype=np.int64)

if len(data) != N * FRAMES:
    raise ValueError(
        f"Expected {N * FRAMES} outputs, got {len(data)}"
    )

rtl = data[:, 1] + 1j * data[:, 2]

# Frequency axis for one 1024-point FFT
freq_mhz = np.arange(N) * FS / N / 1e6

# ============================================================
# FRAME 0
# ============================================================

x = rtl[:N]
mag = np.abs(x)

peak_bin = int(np.argmax(mag))
peak_freq = peak_bin * FS / N / 1e6

print("=" * 72)
print("DDS -> CUSTOM FFT PLOT RESULTS")
print("=" * 72)
print(f"Peak bin       : {peak_bin}")
print(f"Peak frequency : {peak_freq:.6f} MHz")
print(f"Peak magnitude : {mag[peak_bin]:.3f}")

# ------------------------------------------------------------
# 1. Linear magnitude spectrum
# ------------------------------------------------------------

plt.figure(figsize=(10, 5))
plt.plot(freq_mhz, mag)

plt.xlabel("Frequency (MHz)")
plt.ylabel("Magnitude")
plt.title("1024-Point Custom FFT Spectrum - Frame 0")
plt.grid(True)
plt.tight_layout()

plt.savefig(
    DOCS / "fft_spectrum_frame0.png",
    dpi=200
)

# ------------------------------------------------------------
# 2. dB spectrum
# ------------------------------------------------------------

mag_db = 20 * np.log10(
    np.maximum(mag, 1e-12)
)

plt.figure(figsize=(10, 5))
plt.plot(freq_mhz, mag_db)

plt.xlabel("Frequency (MHz)")
plt.ylabel("Magnitude (dB)")
plt.title("1024-Point Custom FFT Spectrum - Frame 0")
plt.grid(True)
plt.tight_layout()

plt.savefig(
    DOCS / "fft_spectrum_frame0_db.png",
    dpi=200
)

# ------------------------------------------------------------
# 3. Zoom around expected tone
# ------------------------------------------------------------

lo = max(0, peak_bin - 10)
hi = min(N, peak_bin + 11)

plt.figure(figsize=(10, 5))
plt.plot(
    freq_mhz[lo:hi],
    mag[lo:hi],
    marker="o"
)

plt.xlabel("Frequency (MHz)")
plt.ylabel("Magnitude")
plt.title("FFT Peak Region")
plt.grid(True)
plt.tight_layout()

plt.savefig(
    DOCS / "fft_peak_zoom.png",
    dpi=200
)

# ============================================================
# ALL 8 FRAMES
# ============================================================

peak_bins = []
peak_freqs = []
peak_mags = []

for frame in range(FRAMES):

    frame_data = rtl[
        frame * N:(frame + 1) * N
    ]

    frame_mag = np.abs(frame_data)

    k = int(np.argmax(frame_mag))

    peak_bins.append(k)
    peak_freqs.append(
        k * FS / N / 1e6
    )
    peak_mags.append(
        frame_mag[k]
    )

# ------------------------------------------------------------
# 4. Peak frequency vs frame
# ------------------------------------------------------------

frames = np.arange(FRAMES)

plt.figure(figsize=(9, 5))
plt.plot(
    frames,
    peak_freqs,
    marker="o"
)

plt.axhline(
    100.0,
    linestyle="--"
)

plt.xlabel("Frame")
plt.ylabel("Peak Frequency (MHz)")
plt.title("Detected FFT Peak Frequency Across 8 Frames")
plt.xticks(frames)
plt.grid(True)
plt.tight_layout()

plt.savefig(
    DOCS / "peak_frequency_vs_frame.png",
    dpi=200
)

# ------------------------------------------------------------
# 5. Peak magnitude vs frame
# ------------------------------------------------------------

plt.figure(figsize=(9, 5))
plt.plot(
    frames,
    peak_mags,
    marker="o"
)

plt.xlabel("Frame")
plt.ylabel("Peak Magnitude")
plt.title("FFT Peak Magnitude Across 8 Frames")
plt.xticks(frames)
plt.grid(True)
plt.tight_layout()

plt.savefig(
    DOCS / "peak_magnitude_vs_frame.png",
    dpi=200
)

# ============================================================
# PRINT FRAME RESULTS
# ============================================================

print()
print("Frame results:")
print("-" * 72)

for f in range(FRAMES):

    print(
        f"Frame {f}: "
        f"bin={peak_bins[f]:3d}, "
        f"frequency={peak_freqs[f]:.6f} MHz, "
        f"magnitude={peak_mags[f]:.3f}"
    )

print()
print("Plots saved:")
print(DOCS / "fft_spectrum_frame0.png")
print(DOCS / "fft_spectrum_frame0_db.png")
print(DOCS / "fft_peak_zoom.png")
print(DOCS / "peak_frequency_vs_frame.png")
print(DOCS / "peak_magnitude_vs_frame.png")