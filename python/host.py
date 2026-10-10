"""The host PC's side: decode a result packet and estimate the frequency.

    from host import decode
    result = decode(packet_bytes, sample_rate_hz=5e9)

Can also be run on a file of packets written by the testbench:

    python python/host.py build/rx_dds/rx_packets.txt
"""
import math
import sys

MAGIC = 0x44525831
N = 1024
DECIM = 4


def decode(data, sample_rate_hz=5e9):
    """data: the 52 bytes of one packet. Returns a dict, or raises ValueError."""
    if len(data) != 52:
        raise ValueError(f"packet is {len(data)} bytes, expected 52")
    words = [int.from_bytes(data[i:i + 4], "big") for i in range(0, 52, 4)]
    if words[0] != MAGIC:
        raise ValueError("bad magic number")
    if sum(words[:12]) & 0xFFFFFFFF != words[12]:
        raise ValueError("bad checksum")

    flags = words[5] >> 16
    k = words[5] & 0xFFFF
    power, left, right = (int.from_bytes(data[i:i + 8], "big") for i in (24, 32, 40))

    # Bins 512..1023 are the negative frequencies.
    signed_bin = k - N if k >= N // 2 else k

    # The true peak usually lies between two bins. The ratio of the peak to
    # its larger neighbour says how far it is from the centre of the peak bin.
    if right >= left:
        ratio, direction = math.sqrt(right / power), 1.0
    else:
        ratio, direction = math.sqrt(left / power), -1.0
    if flags & 1:
        offset = direction * (2 * ratio - 1) / (ratio + 1)      # Hann window
    else:
        offset = direction * ratio / (ratio + 1)                # no window
    offset = max(-0.5, min(0.5, offset))

    bin_hz = sample_rate_hz / DECIM / N
    lo_hz = words[4] / 2**32 * sample_rate_hz

    return {
        "frame": words[1],
        "timestamp": int.from_bytes(data[8:16], "big"),
        "lo_hz": lo_hz,
        "window": bool(flags & 1),
        "peak_bin": k,
        "peak_power": power,
        "baseband_hz": (signed_bin + offset) * bin_hz,
        "rf_hz": lo_hz + (signed_bin + offset) * bin_hz,
        "bin_centre_rf_hz": lo_hz + signed_bin * bin_hz,
    }


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    for line in open(sys.argv[1]):
        r = decode(bytes.fromhex(line.strip()))
        print(f"frame {r['frame']}: first sample {r['timestamp']:6d}, peak bin {r['peak_bin']:4d}, "
              f"RF frequency {r['rf_hz'] / 1e6:.3f} MHz")
