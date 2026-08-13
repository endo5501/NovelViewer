#!/usr/bin/env python3
"""Upstream (PyTorch) Irodori-TTS v4-Small sweep for the tail-artifact claim.

Mirrors the audio.cpp C++ sweep in ../run_sweep.ps1: same text, caption,
reference wav, seeds and num_inference_steps, so the two paths can be compared
mode-by-mode.

The runtime (model + codec) is loaded once and reused across all runs.
"""

from __future__ import annotations

import argparse
import csv
import time
from pathlib import Path

from irodori_tts.inference_runtime import (
    InferenceRuntime,
    RuntimeKey,
    SamplingRequest,
    download_hf_checkpoint,
    resolve_cfg_scales,
    save_wav,
)

TEXT = "どうしてもっと早く教えてくれなかったの？私、ずっと待ってたのに。"
CAPTION = "深く傷つき、今にも泣き出しそうな様子。声が震えており、悲痛なトーンで弱々しく話す。"

MODES = {
    # name            -> (uses reference, uses caption)
    "clone": (True, False),
    "clone_caption": (True, True),
    "caption": (False, True),
    "noref": (False, False),
}


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--hf-checkpoint", default="Aratako/Irodori-TTS-v4-Small")
    ap.add_argument("--ref", required=True)
    ap.add_argument("--out-dir", required=True)
    ap.add_argument("--modes", nargs="+", default=["clone", "clone_caption", "caption", "noref"])
    ap.add_argument("--seeds", type=int, default=10)
    ap.add_argument("--seed-start", type=int, default=1234)
    ap.add_argument("--steps", type=int, default=24)
    ap.add_argument("--device", default="cpu")
    ap.add_argument("--text", default=TEXT)
    ap.add_argument("--caption", default=CAPTION)
    ap.add_argument("--seconds", type=float, default=None)
    ap.add_argument("--duration-scale", type=float, default=1.0)
    ap.add_argument("--tag", default="")
    args = ap.parse_args()

    ref_path = str(Path(args.ref).resolve())
    out_dir = Path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)

    ckpt = download_hf_checkpoint(str(args.hf_checkpoint))
    print(f"[checkpoint] {ckpt}", flush=True)

    runtime = InferenceRuntime.from_key(
        RuntimeKey(
            checkpoint=str(ckpt),
            model_device=str(args.device),
            codec_device=str(args.device),
        )
    )
    print("[runtime] loaded", flush=True)

    csv_path = out_dir / "results.csv"
    fields = [
        "mode",
        "seed",
        "steps",
        "wall_sec",
        "audio_sec",
        "pred_frames_msg",
        "used_seed",
        "out_file",
    ]
    rows: list[dict[str, object]] = []

    for mode in args.modes:
        use_ref, use_caption = MODES[mode]
        for i in range(int(args.seeds)):
            seed = int(args.seed_start) + i
            name = f"v4py-{mode}-seed{seed}"
            if args.tag:
                name = f"{name}-{args.tag}"
            out_file = out_dir / f"{name}.wav"

            caption = args.caption if use_caption else None
            cfg_text, cfg_caption, cfg_speaker, msgs = resolve_cfg_scales(
                cfg_guidance_mode="independent",
                cfg_scale_text=3.0,
                cfg_scale_caption=3.0,
                cfg_scale_speaker=5.0,
                cfg_scale=None,
                use_caption_condition=bool(
                    runtime.model_cfg.use_caption_condition and caption is not None
                ),
                use_speaker_condition=bool(
                    runtime.model_cfg.use_speaker_condition_resolved and use_ref
                ),
            )
            for m in msgs:
                print(f"  {m}", flush=True)

            req = SamplingRequest(
                text=str(args.text),
                caption=caption,
                ref_wav=ref_path if use_ref else None,
                no_ref=not use_ref,
                num_steps=int(args.steps),
                seconds=args.seconds,
                duration_scale=float(args.duration_scale),
                cfg_scale_text=cfg_text,
                cfg_scale_caption=cfg_caption,
                cfg_scale_speaker=cfg_speaker,
                cfg_guidance_mode="independent",
                seed=seed,
            )

            print(f"[run] {name} ...", flush=True)
            t0 = time.perf_counter()
            result = runtime.synthesize(req, log_fn=None)
            wall = time.perf_counter() - t0
            save_wav(out_file, result.audio, result.sample_rate)
            audio_sec = result.audio.shape[-1] / float(result.sample_rate)
            pred_msg = next(
                (m for m in result.messages if m.startswith("info: predicted duration")),
                "",
            )
            print(
                f"      wall={wall:7.2f}s audio={audio_sec:6.2f}s  {pred_msg}",
                flush=True,
            )

            rows.append(
                {
                    "mode": mode,
                    "seed": seed,
                    "steps": int(args.steps),
                    "wall_sec": round(wall, 2),
                    "audio_sec": round(audio_sec, 3),
                    "pred_frames_msg": pred_msg,
                    "used_seed": result.used_seed,
                    "out_file": out_file.name,
                }
            )

            with csv_path.open("w", newline="", encoding="utf-8") as fh:
                writer = csv.DictWriter(fh, fieldnames=fields)
                writer.writeheader()
                writer.writerows(rows)

    print(f"CSV: {csv_path}", flush=True)


if __name__ == "__main__":
    main()
