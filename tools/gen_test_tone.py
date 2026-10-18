#!/usr/bin/env python3
"""Generate a license-clear beat test tone and matching chart notes.

The audio is original sine clicks (public domain / CC0). It is not a
recording of anyone's music. Re-run from the repo root:

    python3 tools/gen_test_tone.py
"""

from __future__ import annotations

import json
import math
import struct
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RATE = 22050
BPM = 120
BEAT = 60.0 / BPM
DURATION = 60.0

BGM_PATH = ROOT / "assets" / "audio" / "bgm" / "song_01_test.wav"
SFX_DIR = ROOT / "assets" / "audio" / "sfx"
CHART_PATH = ROOT / "charts" / "song_01.json"


def _add_tone(samples: list[float], t: float, freq: float, amp: float, length: float, decay: float) -> None:
    start = int(t * RATE)
    count = int(length * RATE)
    for i in range(count):
        idx = start + i
        if idx < 0 or idx >= len(samples):
            break
        env = math.exp(-i / decay)
        samples[idx] += math.sin(2.0 * math.pi * freq * (i / RATE)) * amp * env


def _write_wav(path: Path, samples: list[float]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    frames = bytearray()
    for sample in samples:
        value = max(-1.0, min(1.0, sample))
        frames += struct.pack("<h", int(value * 32767.0))
    with wave.open(str(path), "wb") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(RATE)
        handle.writeframes(frames)


def _silence(seconds: float) -> list[float]:
    return [0.0] * int(RATE * seconds)


def build_bgm() -> list[float]:
    samples = _silence(DURATION)
    clicks = int(DURATION / BEAT)
    for i in range(clicks):
        t = i * BEAT
        if i % 4 == 0:
            _add_tone(samples, t, 660.0, 0.42, 0.05, 55.0)
            _add_tone(samples, t, 990.0, 0.22, 0.04, 40.0)
        else:
            _add_tone(samples, t, 880.0, 0.30, 0.04, 36.0)
    return samples


def build_sfx(kind: str) -> list[float]:
    if kind == "perfect":
        samples = _silence(0.16)
        _add_tone(samples, 0.0, 1320.0, 0.45, 0.07, 30.0)
        _add_tone(samples, 0.07, 1760.0, 0.40, 0.08, 28.0)
        return samples
    if kind == "good":
        samples = _silence(0.12)
        _add_tone(samples, 0.0, 880.0, 0.40, 0.10, 34.0)
        return samples
    if kind == "kiss":
        samples = _silence(0.28)
        _add_tone(samples, 0.0, 740.0, 0.28, 0.08, 40.0)
        _add_tone(samples, 0.09, 988.0, 0.32, 0.12, 50.0)
        _add_tone(samples, 0.16, 1318.0, 0.18, 0.10, 40.0)
        return samples
    samples = _silence(0.16)
    _add_tone(samples, 0.0, 150.0, 0.50, 0.14, 22.0)
    _add_tone(samples, 0.0, 90.0, 0.25, 0.12, 18.0)
    return samples


def _former_block(index: int, t: float) -> bool:
    """Slots that used to be lane-dodge blocks, before the single-lane chart."""
    cycle = ["jump", "slide", "block", "jump", "slide", "jump"]
    on_bar = t >= 8.0 and abs(t - round(t)) < 1e-6 and int(round(t)) % 8 == 0
    return on_bar or cycle[index % len(cycle)] == "block"


def build_notes() -> list[dict]:
    # Single lane. Former block slots alternate jump / slide by the order they appear.
    cycle = ["jump", "slide", "block", "jump", "slide", "jump"]
    notes: list[dict] = []
    t = 2.0
    index = 0
    block_alt = 0
    while t <= 58.0 + 1e-6:
        rounded = round(t, 3)
        if _former_block(index, rounded):
            note_type = "jump" if block_alt % 2 == 0 else "slide"
            block_alt += 1
        else:
            note_type = cycle[index % len(cycle)]
            if index % 16 == 15 and note_type == "jump":
                note_type = "hold"
        note = {"t": rounded, "type": note_type}
        if note_type == "hold":
            note["duration"] = 0.5
        notes.append(note)
        index += 1
        t = 2.0 + index * BEAT
    # 布布落在障碍空档里，靠近前后 1.6 秒不再排障碍。
    buddy_times = [10.0, 22.0, 36.0, 50.0]
    gap = 1.6
    notes = [n for n in notes if all(abs(n["t"] - b) >= gap - 1e-6 for b in buddy_times)]
    for hit in buddy_times:
        notes.append({"t": hit, "type": "buddy"})
    notes.sort(key=lambda n: n["t"])
    _assert_playable(notes, buddy_times, gap)
    return notes


def _assert_playable(notes: list[dict], buddy_times: list[float], gap: float) -> None:
    seen: set[float] = set()
    for note in notes:
        if note["type"] == "block":
            raise SystemExit(f"block left at t={note['t']}")
        if "lane" in note:
            raise SystemExit(f"lane left at t={note['t']}")
        if note["t"] in seen:
            raise SystemExit(f"duplicate t={note['t']}")
        seen.add(note["t"])
        if note["type"] == "buddy":
            continue
        for hit in buddy_times:
            if abs(note["t"] - hit) < gap - 1e-6:
                raise SystemExit(f"buddy gap {note['t']} vs {hit}")


def main() -> None:
    _write_wav(BGM_PATH, build_bgm())
    for name in ("perfect", "good", "miss", "kiss"):
        _write_wav(SFX_DIR / f"{name}.wav", build_sfx(name))
    notes = build_notes()
    chart = {
        "schemaVersion": 2,
        "songId": "song_01",
        "title": "Beat Test",
        "artist": "Generated test tone",
        "audio": "res://assets/audio/bgm/song_01_test.wav",
        "bpm": BPM,
        "offsetMs": 0,
        "durationSec": DURATION,
        "approachSec": 1.5,
        "windowsMs": {"perfect": 50, "good": 100, "buddy": 250},
        "notes": notes,
    }
    CHART_PATH.write_text(json.dumps(chart, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"wrote {BGM_PATH} ({BGM_PATH.stat().st_size} bytes)")
    print(f"notes {len(notes)} last {notes[-1]['t']} duration {DURATION}")


if __name__ == "__main__":
    main()
