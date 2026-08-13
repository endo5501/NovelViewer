#!/usr/bin/env python3
"""Speech-segment analysis for generated WAVs.

Port of ../analyze_tail.ps1 (20 ms window / 10 ms hop RMS, -35 dB relative to
the clip peak, segments split by >=0.20 s of silence) so C++ and PyTorch
outputs are scored by the same rule.

Total duration is fixed by the (deterministic) duration predictor, so the tail
artifact does not show up as a length outlier. It shows up as an extra speech
segment after a long gap, with the trailing silence eaten up.
"""

from __future__ import annotations

import argparse
import csv
import math
import re
from collections import Counter, defaultdict
from pathlib import Path

import numpy as np
import soundfile as sf


def frame_rms(x: np.ndarray, sr: int) -> tuple[np.ndarray, float]:
    win = int(sr * 0.020)
    hop = int(sr * 0.010)
    hop_sec = hop / sr
    if x.shape[0] < win:
        return np.zeros(0), hop_sec
    nf = 1 + (x.shape[0] - win) // hop
    idx = np.arange(win)[None, :] + hop * np.arange(nf)[:, None]
    frames = x[idx]
    return np.sqrt(np.mean(frames * frames, axis=1)), hop_sec


def segments(rms: np.ndarray, hop_sec: float, threshold_db: float, gap_sec: float):
    if rms.size == 0:
        return []
    peak = float(rms.max())
    if peak <= 0:
        return []
    thr = peak * (10.0 ** (threshold_db / 20.0))
    gap_frames = int(round(gap_sec / hop_sec))
    segs: list[tuple[int, int]] = []
    start = -1
    last_hot = -1
    for i, v in enumerate(rms):
        if v >= thr:
            if start < 0:
                start = i
            last_hot = i
        elif start >= 0 and (i - last_hot) > gap_frames:
            segs.append((start, last_hot))
            start = -1
    if start >= 0:
        segs.append((start, last_hot))
    return segs


def analyze(path: Path, threshold_db: float, gap_sec: float, min_seg_sec: float = 0.0) -> dict:
    data, sr = sf.read(str(path), dtype="float64", always_2d=True)
    x = data.mean(axis=1)
    rms, hop = frame_rms(x, sr)
    segs = segments(rms, hop, threshold_db, gap_sec)
    if min_seg_sec > 0.0:
        # Drop clicks / sub-phoneme transients so they are not counted as speech.
        segs = [s for s in segs if (s[1] - s[0]) * hop >= min_seg_sec]
    total = x.shape[0] / sr
    row = {
        "file": path.name,
        "path": str(path),
        "total_sec": round(total, 3),
        "n_seg": len(segs),
        "last_start": None,
        "last_dur": None,
        "gap_before": None,
        "trail_sil": None,
        # End of the k-th segment = where the requested text finishes. k depends on
        # how the text splits, so it is filled in by set_text_end() once the whole
        # directory is known. Anything after it is surplus room.
        "text_end": None,
        "surplus": None,
        "seg_ends": [round(e * hop, 3) for _, e in segs],
    }
    if segs:
        s, e = segs[-1]
        row["last_start"] = round(s * hop, 3)
        row["last_dur"] = round((e - s) * hop, 3)
        row["trail_sil"] = round(total - e * hop, 3)
        if len(segs) >= 2:
            row["gap_before"] = round((s - segs[-2][1]) * hop, 3)
    return row


def set_text_end(row: dict, text_segments: int) -> None:
    """Fill text_end / surplus given how many segments the input text splits into.

    Clips with fewer segments than expected have merged (not truncated) segments,
    so the last segment end is the best available estimate of the text end.
    """
    ends = row["seg_ends"]
    if not ends:
        return
    text_end = ends[text_segments - 1] if len(ends) >= text_segments else ends[-1]
    row["text_end"] = round(text_end, 3)
    row["surplus"] = round(row["total_sec"] - text_end, 3)


def mode_of(name: str) -> str:
    """Mode, with the run tag appended so tagged variants group separately.

    `v4py-clone_caption-seed1234-a070` -> `clone_caption@a070`. This lets one
    analysis cover a baseline directory and several tagged duration overrides at
    once (rglob recurses), instead of comparing runs across separate reports.
    """
    m = re.match(r"^v4py-([a-z_]+)-seed", name)
    if not m:
        return "?"
    mode = m.group(1)
    tag = re.search(r"-seed\d+-(.+)$", name)
    return f"{mode}@{tag.group(1)}" if tag else mode


def seed_of(name: str) -> int:
    m = re.search(r"seed(\d+)", name)
    return int(m.group(1)) if m else 0


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--dir", required=True)
    ap.add_argument("--threshold-db", type=float, default=-35.0)
    ap.add_argument("--gap-sec", type=float, default=0.20)
    ap.add_argument(
        "--min-seg-sec",
        type=float,
        default=0.15,
        help="Drop segments shorter than this (clicks). Set 0 to keep the raw PowerShell behaviour.",
    )
    ap.add_argument("--baseline", default="clone", help="mode used as the clean reference")
    ap.add_argument(
        "--text-segments",
        type=int,
        default=0,
        help="How many segments the input text splits into. 0 = derive from the "
        "baseline mode's modal segment count. Needed when the analysed directory "
        "has no baseline mode in it, or for texts that do not split into 3.",
    )
    args = ap.parse_args()

    root = Path(args.dir)
    files = sorted(root.rglob("*.wav"))
    if not files:
        raise SystemExit(f"no wav under {root}")

    rows = []
    for f in files:
        r = analyze(f, args.threshold_db, args.gap_sec, args.min_seg_sec)
        r["mode"] = mode_of(f.stem)
        r["seed"] = seed_of(f.stem)
        rows.append(r)

    by_mode: dict[str, list[dict]] = defaultdict(list)
    for r in rows:
        by_mode[r["mode"]].append(r)

    base = args.baseline
    if args.text_segments > 0:
        text_segments = args.text_segments
        seg_src = "指定"
    elif base in by_mode:
        text_segments = Counter(r["n_seg"] for r in by_mode[base]).most_common(1)[0][0]
        seg_src = f"基準 mode={base} の最頻区間数"
    else:
        text_segments = 3
        seg_src = f"既定 (基準 mode={base} がこのディレクトリに無い。--text-segments で指定を)"
    for r in rows:
        set_text_end(r, text_segments)

    print(f"解析対象: {len(rows)} 本 ({root})")
    print(
        f"設定: 発話閾値=ピーク{args.threshold_db}dB / 区間分割ギャップ={args.gap_sec}s"
        f" / 最小区間長={args.min_seg_sec}s"
    )
    print(f"本文の区間数: {text_segments} ({seg_src})")
    print()
    print(f"  {'mode':<16} {'n':<4} {'長さ(s)':<14} {'区間数':<24} {'本文終端':>8} {'余り':>7} 末尾無音")
    print("  " + "-" * 96)
    for mode in sorted(by_mode):
        g = by_mode[mode]
        tot = [r["total_sec"] for r in g]
        segc = Counter(r["n_seg"] for r in g)
        segs_txt = " ".join(f"{k}区間x{v}" for k, v in sorted(segc.items()))

        def avg(field: str) -> float:
            vals = [r[field] for r in g if r[field] is not None]
            return sum(vals) / len(vals) if vals else 0.0

        len_txt = f"{min(tot):.2f}-{max(tot):.2f}"
        print(
            f"  {mode:<16} {len(g):<4} {len_txt:<14} {segs_txt:<24}"
            f" {avg('text_end'):>8.2f} {avg('surplus'):>7.2f} {avg('trail_sil'):>8.2f}"
        )

    print()
    print(f"=== 余分な発話区間の発生率 (本文の区間数={text_segments}) ===")
    for mode in sorted(by_mode):
        g = by_mode[mode]
        hit = [r for r in g if r["n_seg"] > text_segments]
        # Fewer segments than expected means merged gaps, not truncation, but it
        # also means the artifact indicator is blind for that clip -> flag it.
        short = [r for r in g if r["n_seg"] < text_segments]
        mark = (
            "クリーン"
            if not hit
            else ("★ 全数で発生" if len(hit) == len(g) else "△ 断続的に発生")
        )
        if short:
            mark += f" (区間数が基準未満: {len(short)}本 ※要試聴)"
        print(f"  {mode:<16} {len(hit):2d}/{len(g):<3d} {mark}")
        for r in sorted(hit, key=lambda r: r["seed"]):
            print(
                f"      seed={r['seed']} {r['n_seg']}区間 "
                f"last_dur={r['last_dur']} gap={r['gap_before']} "
                f"trail_sil={r['trail_sil']}  {r['path']}"
            )

    out_csv = root / "tail_analysis_python.csv"
    with out_csv.open("w", newline="", encoding="utf-8") as fh:
        w = csv.DictWriter(
            fh,
            fieldnames=[
                "mode",
                "seed",
                "total_sec",
                "n_seg",
                "text_end",
                "surplus",
                "last_start",
                "last_dur",
                "gap_before",
                "trail_sil",
                "file",
                "path",
            ],
        )
        w.writeheader()
        for r in sorted(rows, key=lambda r: (r["mode"], r["seed"])):
            w.writerow({k: r[k] for k in w.fieldnames})
    print()
    print(f"CSV: {out_csv}")


if __name__ == "__main__":
    main()
