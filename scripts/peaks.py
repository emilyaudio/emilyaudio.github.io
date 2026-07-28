#!/usr/bin/env python3
"""Generate vo/peaks.json -- the real amplitude envelope of each demo reel.

The /vo waveforms used to be procedural sine shapes: they claimed to depict the
audio and didn't. These are measured from the files.

Two modes:

    peaks.py --check    exit 0 if peaks.json matches the audio, 1 if stale
    peaks.py            (re)generate peaks.json

--check hashes the mp3s and compares against the hashes stored alongside each
envelope, so it catches a file replaced under the same name -- the case a
filename-only comparison misses. It needs no ffmpeg, which is why the deploy
workflow runs it first and installs ffmpeg only on a stale result.

The browser never sees a hash. It looks each reel up by filename, and the
lookup is safe because peaks.json and the audio ship in the same Pages
artifact, regenerated together.
"""

import array
import hashlib
import json
import math
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
AUDIO_DIR = REPO / "vo" / "audio"
OUT = REPO / "vo" / "peaks.json"

# One bar per column in the /vo reel waveform. Must match BARS in vo/index.html;
# --check treats a mismatch as stale, so changing it here regenerates.
BARS = 64

# Decode to 22.05 kHz mono. The rate does NOT set the time resolution -- 64
# buckets over a two-minute reel is one bar per two seconds either way -- it
# sets the BANDWIDTH the RMS sees, and energy above the Nyquist limit is simply
# absent from the measurement. Checked against ffmpeg's own astats at the
# native rate: at 8 kHz a bright, sibilant bucket read 2.27 dB (~23%) quiet
# while steadier buckets were within 0.3 dB, which is a visibly wrong bar. At
# 22.05 kHz the worst bucket is within 0.17 dB and all five files analyse in
# about a second, so there is nothing to buy by going lower.
RATE = 22050

# Floor the normalised value so a near-silent bucket still draws something --
# a zero-height bar reads as a rendering fault rather than as quiet.
FLOOR = 0.06


def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def decode(path):
    """Raw mono 16-bit samples, via ffmpeg."""
    out = subprocess.run(
        [
            "ffmpeg", "-v", "error", "-i", str(path),
            "-ac", "1", "-ar", str(RATE), "-f", "s16le", "-",
        ],
        check=True,
        stdout=subprocess.PIPE,
    ).stdout
    samples = array.array("h")
    samples.frombytes(out[: len(out) - len(out) % samples.itemsize])
    return samples


def envelope(samples):
    """BARS buckets of RMS amplitude, normalised to the loudest bucket.

    RMS rather than true peak: it tracks perceived loudness, so speech reads as
    a steady band with phrasing visible in it. True peak on a normalised voice
    reel is close to a rectangle -- accurate and uninformative.
    """
    if not samples:
        return [FLOOR] * BARS
    size = len(samples) / BARS
    buckets = []
    for i in range(BARS):
        lo, hi = int(i * size), int((i + 1) * size)
        window = samples[lo:hi] or samples[lo : lo + 1]
        total = sum(s * s for s in window)
        buckets.append(math.sqrt(total / len(window)))
    loudest = max(buckets)
    if loudest == 0:
        return [FLOOR] * BARS
    return [
        round(FLOOR + (1 - FLOOR) * (b / loudest), 4) for b in buckets
    ]


def audio_files():
    return sorted(AUDIO_DIR.glob("*.mp3"))


def load():
    try:
        with open(OUT) as f:
            return json.load(f)
    except (OSError, ValueError):
        return None


def stale_reason(data, files):
    """Why peaks.json needs regenerating, or None if it is current."""
    if data is None:
        return f"{OUT.name} is missing or unreadable"
    if data.get("bars") != BARS:
        return f"bar count changed: {data.get('bars')} -> {BARS}"
    stored = data.get("files", {})
    names = {p.name for p in files}
    if names != set(stored):
        added = ", ".join(sorted(names - set(stored)))
        removed = ", ".join(sorted(set(stored) - names))
        return "audio set changed" + (
            f" (added: {added})" if added else ""
        ) + (f" (removed: {removed})" if removed else "")
    for path in files:
        if stored[path.name].get("sha256") != sha256(path):
            return f"{path.name} changed"
    return None


def main():
    files = audio_files()
    reason = stale_reason(load(), files)

    if "--check" in sys.argv:
        if reason:
            print(f"stale: {reason}")
            return 1
        print(f"current: {len(files)} file(s)")
        return 0

    if not files:
        print(f"no audio in {AUDIO_DIR}", file=sys.stderr)
        return 1

    data = {"bars": BARS, "files": {}}
    for path in files:
        data["files"][path.name] = {
            "sha256": sha256(path),
            "peaks": envelope(decode(path)),
        }
        print(f"analysed {path.name}")

    with open(OUT, "w") as f:
        json.dump(data, f, indent=1, sort_keys=True)
        f.write("\n")
    print(f"wrote {OUT.relative_to(REPO)} ({len(files)} file(s))")
    return 0


if __name__ == "__main__":
    sys.exit(main())
