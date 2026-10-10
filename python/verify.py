"""Simulates the design with Icarus Verilog and checks the results.

Run from anywhere:   python python/verify.py

FFT on its own
  fft tone     8 frames of the 100 MHz test tone
  fft random   8 frames of random I/Q samples
               The output must equal the integer model in model.py exactly,
               and is also compared with numpy.fft.fft.
  dds to fft   DDS feeding the FFT: the peak must be in bin 20 in every frame.

Whole receiver (ADC samples in, result packets out)
  rx dds       a DDS produces a 1100 MHz tone, a 14-bit ADC model quantises it
  rx file      ADC samples from a file: 1100 MHz tone, a tone 40 dB weaker at
               1230 MHz, and noise
               Every spectrum value and every packet byte must equal the model,
               and the frequency the host works out must be right.

Needs: iverilog and vvp on the PATH, and NumPy.
"""
import shutil
import subprocess
import sys
from pathlib import Path

import numpy as np

import host
import model
from model import N

ROOT = Path(__file__).resolve().parent.parent
RTL = sorted(str(p) for p in (ROOT / "rtl").glob("*.v"))
BUILD = ROOT / "build"

FRAMES = 8                      # FFT-only tests
FS = 5e9                        # ADC sample rate the test data represents
LO_INC = 858993459              # 1000 MHz
RF_INC = 944892805              # 1100 MHz
RX_FRAMES = 4
RX_SAMPLES = 65536


def simulate(top, workdir, extra_sources=(), defines=()):
    """Compile testbench `top` and run it inside `workdir`."""
    workdir.mkdir(parents=True, exist_ok=True)
    for f in (ROOT / "mem").glob("*.mem"):
        if not (workdir / f.name).exists():
            shutil.copy(f, workdir)
    compile_cmd = ["iverilog", "-g2012", *[f"-D{d}" for d in defines], "-s", top, "-o", "sim.vvp",
                   str(ROOT / "tb" / f"{top}.v"), *[str(ROOT / s) for s in extra_sources], *RTL]
    for cmd in (compile_cmd, ["vvp", "-n", "sim.vvp"]):
        r = subprocess.run(cmd, cwd=workdir, capture_output=True, text=True)
        if r.returncode != 0 or "ERROR" in r.stdout:
            sys.exit(f"{cmd[0]} failed for {top}:\n{r.stdout}{r.stderr}")


def snr_db(reference, actual):
    return 20 * np.log10(np.linalg.norm(reference) / np.linalg.norm(actual - reference))


def report(name, text, ok):
    print(f"{name:11s} {text}   {'PASS' if ok else 'FAIL'}")
    return ok


# ------------------------------------------------------------ FFT only

def check_fft(name, i, q):
    work = BUILD / name.replace(" ", "_")
    work.mkdir(parents=True, exist_ok=True)
    model.write_mem(work / "i_samples.mem", i)
    model.write_mem(work / "q_samples.mem", q)
    simulate("tb_custom_fft_8192_wrapper", work)
    d = np.loadtxt(work / "custom_fft_8192_output.txt", dtype=np.int64)

    exact, worst = True, np.inf
    for f in range(FRAMES):
        s = slice(f * N, (f + 1) * N)
        expected = model.fft1024([(int(a), int(b)) for a, b in zip(i[s], q[s])])
        exact &= expected == [(int(a), int(b)) for a, b in d[s, 1:3]]
        worst = min(worst, snr_db(np.fft.fft(i[s] + 1j * q[s]), d[s, 1] + 1j * d[s, 2]))
    return report(name, f"equals the model: {exact}   vs numpy.fft: {worst:.1f} dB", exact and worst > 70)


def check_dds_fft():
    work = BUILD / "dds_fft"
    simulate("tb_dds_fft_8192_system", work)
    d = np.loadtxt(work / "dds_fft_8192_output.txt", dtype=np.int64)
    peaks = [int(np.argmax(np.hypot(d[f * N:(f + 1) * N, 1], d[f * N:(f + 1) * N, 2]))) for f in range(FRAMES)]
    return report("dds to fft", f"peak bin per frame: {peaks}", peaks == [20] * FRAMES)


# ------------------------------------------------------- whole receiver

def check_receiver(name, adc_samples, true_rf_hz, defines=()):
    work = BUILD / name.replace(" ", "_")
    work.mkdir(parents=True, exist_ok=True)
    model.write_mem(work / "adc_samples.mem", adc_samples)
    simulate("tb_digital_receiver", work, extra_sources=["tb/adc_model.v"], defines=defines)

    spectra = np.loadtxt(work / "rx_fft_output.txt", dtype=np.int64)
    packets = [bytes.fromhex(line) for line in (work / "rx_packets.txt").read_text().split()]

    # The model of everything up to the frame capture.
    bb_i, bb_q = model.mixer(adc_samples, LO_INC)
    dec_i, dec_q = model.fir_decimate(bb_i), model.fir_decimate(bb_q)

    exact = len(packets) == RX_FRAMES
    worst_error_hz, start = 0.0, -1
    for f, pkt in enumerate(packets):
        r = host.decode(pkt, FS)
        t = r["timestamp"]
        exact &= r["frame"] == f and t > start and (f > 0 or t == 0)
        start = t

        frame = model.window(dec_i[t:t + N], dec_q[t:t + N])
        expected = model.fft1024(frame)
        rows = spectra[spectra[:, 0] == f]
        exact &= expected == [(int(a), int(b)) for a, b in rows[:, 1:3]]
        exact &= pkt == model.packet(f, t, LO_INC, 1, *model.peak(expected))

        worst_error_hz = max(worst_error_hz, abs(r["rf_hz"] - true_rf_hz))

    ok = exact and worst_error_hz < 0.1e6
    return report(name, f"equals the model: {exact}   "
                        f"frequency {r['rf_hz'] / 1e6:.3f} MHz, worst error {worst_error_hz:.0f} Hz", ok)


def file_test_signal():
    """What a 14-bit ADC would deliver for two tones plus noise."""
    rng = np.random.default_rng(7)
    t = np.arange(RX_SAMPLES) / FS
    strong = 0.5 * np.cos(2 * np.pi * 1100e6 * t)
    weak = 0.005 * np.cos(2 * np.pi * 1230e6 * t + 1.0)         # 40 dB below
    noise = rng.normal(0, 16 / 32768, RX_SAMPLES)
    ideal = np.round((strong + weak + noise) * 32767).astype(np.int64)
    return model.adc(np.clip(ideal, -32768, 32767))


if __name__ == "__main__":
    if not shutil.which("iverilog"):
        sys.exit("iverilog was not found on the PATH (install Icarus Verilog).")

    rng = np.random.default_rng(1)
    rf_tone, _ = model.dds(RF_INC, RX_SAMPLES)
    results = [
        check_fft("fft tone", model.read_mem(ROOT / "mem" / "i_samples.mem"),
                  model.read_mem(ROOT / "mem" / "q_samples.mem")),
        check_fft("fft random", rng.integers(-20000, 20001, N * FRAMES), rng.integers(-20000, 20001, N * FRAMES)),
        check_dds_fft(),
        check_receiver("rx dds", model.adc(rf_tone), RF_INC / 2**32 * FS, defines=["DDS_SOURCE"]),
        check_receiver("rx file", file_test_signal(), 1100e6),
    ]
    sys.exit(0 if all(results) else 1)
