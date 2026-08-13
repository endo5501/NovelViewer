# Issue draft — Aratako/Irodori-TTS

> Draft only. Not filed.

---

**Title:**

`v4-Small: reference + caption over-predicts duration, and the model fills the surplus with an extra unrequested phrase (9/10 seeds)`

---

## Summary

With `Irodori-TTS-v4-Small`, passing **both** a reference wav and a caption makes the duration
predictor ask for more time than the RF body needs for the text. The surplus is not left as
silence — in 9 of 10 seeds an extra phrase that is not in the input text appears at the end
of the clip. Reference-only and caption-only are clean at this rate.

## Reproduction

```bash
uv run --no-sync python infer.py \
  --hf-checkpoint Aratako/Irodori-TTS-v4-Small \
  --text "どうしてもっと早く教えてくれなかったの？私、ずっと待ってたのに。" \
  --caption "深く傷つき、今にも泣き出しそうな様子。声が震えており、悲痛なトーンで弱々しく話す。" \
  --ref-wav reference.wav \
  --num-steps 24 --seed 1234 \
  --output-wav out.wav
```

Reference: a 7.0 s single-speaker Japanese clip. Seeds 1234–1243, CPU, fp32, `infer.py`
defaults except `--num-steps 24` (chosen to keep the CPU sweep affordable).

## Measurements

Speech segments from a 20 ms/10 ms RMS envelope, −35 dB relative to the clip peak, split on
≥0.20 s of silence, segments <0.15 s dropped as clicks. The input text yields three segments,
so a 4th one is the artifact. "Text ends" is the end of the 3rd segment.

| condition | predicted duration | segments | text ends | surplus | extra segment |
|---|---:|---|---:|---:|---:|
| no reference, no caption | 5.560 s | 3×9, 2×1 | 5.49 | 0.07 | 0/10 |
| caption only (`--no-ref`) | 6.960 s | 3×10 | 6.62 | 0.34 | 0/10 |
| reference only | 7.440 s | 3×9, 4×1 | 6.15 | 1.29 | 1/10 |
| **reference + caption** | **7.960 s** | **3×1, 4×8, 5×1** | **5.34** | **2.61** | **9/10** |

The length is fixed by the duration predictor and does not vary with the seed, so this never
shows up as a length outlier — only as an extra segment. Typical failure (`seed=1238`):

```
0.20 – 2.45   text 1
3.14 – 3.53   text 2
3.86 – 4.95   text 3
6.34 – 7.52   <- extra phrase, after a 1.39 s gap
```

## Mechanism

The surplus column above tracks the failure rate. A reference adds ~1.9 s to the predicted
duration and a caption ~0.5 s more, yet with both active the RF body renders the same text
**faster** (5.34 s instead of 6.15 s). ~2.6 s of room is left over, and the model speaks into it.

Overriding only `--seconds`, same text/caption/reference:

| `--seconds` | segments | text ends | surplus | extra segment |
|---:|---|---:|---:|---:|
| (predicted 7.96) | 3×1, 4×8, 5×1 | 5.34 | 2.61 | 9/10 |
| 7.44 | 3×8, 4×2 | 6.00 | 1.44 | 2/10 |
| 6.20 | 3×8, 2×2 | 5.35 | 0.85 | 0/10 |

Shortening the target does not truncate the text — the model slows down to fit. This points at
duration-predictor calibration for the `speaker + caption` case rather than a defect in the RF
body, though I have not verified that directly. It is also consistent with #13, where excess
generation length produced repeated or incoherent reading.

## Workaround

Setting `--seconds` to what the reference-only path predicts (7.44 s here, i.e.
`--duration-scale 0.93`) drops the rate from 9/10 to 2/10 without shortening the text.

## Limitations

- Judged acoustically from segment structure, not transcribed — I have not confirmed by ASR
  that the extra segment is meaningful speech. Audio samples can be provided.
- One text, one caption, one reference clip, n=10 per condition. The rate for other inputs is
  unknown.
