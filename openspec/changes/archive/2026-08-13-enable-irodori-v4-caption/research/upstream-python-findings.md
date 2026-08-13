# upstream Python 経路での末尾アーティファクト検証

audio.cpp の `docs/models/irodori_tts.md` にある

> This behavior is also reproducible in the upstream Python path with the same
> reference/text/seed, so it is treated as a current v4 model/runtime limitation
> rather than a GGUF-only issue.

という記述が本当かを、Irodori-TTS 本家 (PyTorch, `Aratako/Irodori-TTS`) で実測して確認する。

- 検証日: 2026-08-09
- 対象: `Aratako/Irodori-TTS-v4-Small` (safetensors, fp32, CPU)
- 比較対象: audio.cpp `release-0.5.1` CPU + `Irodori-TTS-v4-Small-GGUF` q8_0 の既存スイープ

**結論: 記述は正しい。** 参照音声 + caption を同時に有効にすると末尾に余計な発話が入る現象は
PyTorch 本家経路でも 9/10 seed で発生し、GGUF/C++ 固有の問題ではない。
原因は duration predictor が尺を与えすぎることで、`duration_sec` を縮めると消える。

---

## 0. 計測方法

発話区間は 20ms 窓 / 10ms ホップの RMS 包絡、クリップ内ピークから −35dB を閾値、
0.20s 以上の無音で分割 (`analyze_tail.ps1` と同一)。
0.15s 未満の微小区間はクリック等と区別できないため集計から除外する
(`analyze_tail.py --min-seg-sec 0.15`、既定値。`0` を渡すと PowerShell 版と同じ生の挙動になる)。

本文テキストは「どうしてもっと早く教えてくれなかったの？私、ずっと待ってたのに。」で、
自然に **3 区間**に分かれる。したがって:

- **本文終端** = 3 番目の区間の終了時刻 (区間が 3 未満なら最終区間の終了時刻)
- **余り** = 生成尺 − 本文終端 ← 埋めるべき空き時間
- **末尾無音** = 生成尺 − 最終区間の終了時刻 (余計な発話があるとここが潰れる)
- **余分な区間** = 区間数が 3 を超えた本数 ← 末尾アーティファクトの指標

生成尺は duration predictor が決定論的に決めるため seed に依存せず、10 本すべて同一秒数になる。
**末尾アーティファクトは「長さの外れ値」ではなく「区間数の増加」として現れる。**

## 1. この記述の出所

- 追加したのは audio.cpp の PR
  [#184 "Add Irodori-TTS v4 release support"](https://github.com/0xShug0/audio.cpp/pull/184)
  (2026-08-04, 0xShug0)。commit `238ab6a9`。PR 本文にも
  "document the upstream short trailing phrase limitation" とある。
- ただし PR の Validation 欄に挙がっているのは `audiocpp_cli` のパステストと WebUI テストのみで、
  **Python 経路を回した記録は PR にも commit メッセージにも残っていない**。

## 2. C++ (GGUF q8_0) 側の実測 — 既存データの再集計

`out/` 配下の既存スイープ (seed 1234-1243、text/caption/参照音声は全モード共通、steps=24)。

| mode | model | n | 生成尺 | 区間数 | 本文終端 | 余り | 末尾無音 | 余分な区間 |
|---|---|---:|---:|---|---:|---:|---:|---:|
| noref | v4 | 10 | 5.56 | 3区間×10 | 5.49 | 0.07 | 0.07 | 0/10 |
| caption のみ | v4 | 10 | 7.00 | 3区間×10 | 6.57 | 0.43 | 0.43 | 0/10 |
| 参照のみ (clone) | v4 | 10 | 7.52 | 3区間×10 | 6.37 | 1.15 | 1.15 | 0/10 |
| **参照+caption** | **v4** | 10 | **7.96** | **4区間×9, 5区間×1** | **5.37** | **2.59** | **0.43** | **10/10** |
| 参照+caption | v3 | 10 | 7.44 | 3区間×10 | 6.28 | 1.16 | 1.16 | 0/10 |
| 参照のみ | v3 | 10 | 6.96 | 3区間×10 | 5.82 | 1.14 | 1.14 | 0/10 |

- 参照のみを `--task vdes` で通した `clone_vdes` は `clone` と完全一致。
  つまりトリガは「vdes というタスク経路」ではなく **caption と参照の同時指定**。
- v3 は同条件でも 3 区間のまま。v4 固有。

## 3. Python (PyTorch) 側の実測

### 条件

- `Aratako/Irodori-TTS-v4-Small` (safetensors, fp32) / DACVAE `Aratako/Semantic-DACVAE-Japanese-32dim`
- CPU (model_device=codec_device=cpu)、`num_steps=24`、seed 1234-1243
- text / caption / 参照音声 (`ref/ref.wav`, 7.0s) は C++ スイープと同一
- CFG は `infer.py` 既定と同じ (text 3.0 / caption 3.0 / speaker 5.0, independent)
- スクリプト: `python/run_python_sweep.py` (ランタイムを 1 回だけロードして 40 本連続生成)
- 解析: `python/analyze_tail.py` — `analyze_tail.ps1` の**区間計測部**の移植。
  `--min-seg-sec 0` (PowerShell 版と同条件) で既存 C++ 出力 102 本を解析し、
  `total_sec` / `n_seg` / `last_dur` / `gap_before` / `trail_sil` の全列が一致することを確認済み
  (mismatch=0)。**判定ロジックは別物**で、PowerShell 版は v3/v4 の同一 seed ペア比較、
  Python 版は基準 mode (既定 `clone`) の最頻区間数との比較を使う。

### 結果

| mode | 予測duration | 生成尺 | 区間数 | 本文終端 | 余り | 末尾無音 | 余分な区間 |
|---|---:|---:|---|---:|---:|---:|---:|
| noref | 5.560s | 5.56 | 3区間×9, 2区間×1 | 5.49 | 0.07 | 0.07 | 0/10 |
| caption のみ | 6.960s | 6.96 | 3区間×10 | 6.62 | 0.34 | 0.34 | 0/10 |
| 参照のみ (clone) | 7.440s | 7.44 | 3区間×9, 4区間×1 | 6.15 | 1.29 | 1.09 | 1/10 |
| **参照+caption** | **7.960s** | 7.96 | **3区間×1, 4区間×8, 5区間×1** | **5.34** | **2.61** | **0.45** | **9/10** |

### C++ との対応

| mode | 予測duration Py | 同 C++ | 余り Py | 同 C++ | 余分な区間 Py | 同 C++ |
|---|---:|---:|---:|---:|---:|---:|
| noref | 5.560 | 5.56 | 0.06 | 0.07 | 0/10 | 0/10 |
| caption のみ | 6.960 | 7.00 | 0.34 | 0.43 | 0/10 | 0/10 |
| 参照のみ | 7.440 | 7.52 | 1.29 | 1.15 | 1/10 | 0/10 |
| 参照+caption | 7.960 | 7.96 | 2.61 | 2.59 | 9/10 | 10/10 |

予測 duration・余り時間・発生率のいずれも両実装でほぼ一致する。

なお「same reference/text/seed で再現」という表現は厳密には成立しない。C++ と PyTorch は
乱数生成器が異なるため同じ seed でも初期ノイズが違い、seed 単位の一致は原理的に取れない。
検証できるのは「同一の text/caption/参照音声で同程度の発生率で同じ現象が出るか」であり、
その意味では完全に再現している。

## 4. 発生機構

余り時間 (生成尺 − 本文終端) が発生率をそのまま決めている。

| mode (Python) | 生成尺 | 本文終端 | 余り | 余分な区間 |
|---|---:|---:|---:|---:|
| noref | 5.56 | 5.49 | 0.07 | 0/10 |
| caption のみ | 6.96 | 6.62 | 0.34 | 0/10 |
| 参照のみ | 7.44 | 6.15 | 1.29 | 1/10 |
| 参照+caption | 7.96 | 5.34 | **2.61** | 9/10 |

- duration predictor は参照ありで +1.9s、さらに caption ありで +0.5s と尺を伸ばす。
- ところが実際の RF 生成は、参照+caption だと本文を**より速く**読み終える (終端 6.15s → 5.34s)。
- 結果として 2.6s の空き時間が残り、そこにモデルが勝手な一言を生成して埋める。

典型例 (`out/python-sweep/v4py-clone_caption-seed1238.wav`, 7.96s):

```
  0.20 - 2.45  本文1
  3.14 - 3.53  本文2
  3.86 - 4.95  本文3
  6.34 - 7.52  ← 余計な発話 (1.18s、1.39s の間を空けて出現)
```

対照 (`out/python-sweep/v4py-clone-seed1238.wav`, 7.44s、クリーン):

```
  0.94 - 3.43  本文1
  4.16 - 4.66  本文2
  5.09 - 6.26  本文3
```

### 検証: 尺を縮めると消えるか

参照+caption のまま `--seconds` で尺だけを変えて 10 seed ずつ再生成。

| 設定 | 生成尺 | 区間数 | 本文終端 | 余り | 余分な区間 |
|---|---:|---|---:|---:|---:|
| 予測どおり | 7.96 | 3区間×1, 4区間×8, 5区間×1 | 5.34 | 2.61 | **9/10** |
| `--seconds 7.44` (参照のみの予測値) | 7.44 | 3区間×8, 4区間×2 | 6.00 | 1.44 | **2/10** |
| `--seconds 6.20` | 6.20 | 3区間×8, 2区間×2 | 5.35 | 0.85 | **0/10** |

尺を縮めるとモデルは**発話速度を落として尺に合わせる**ため本文が切れることはなく、
余計な発話だけが消える。**尺の与えすぎが直接の原因**であることが確定した。

実用的な回避策としては、参照+caption 時に `duration_sec` を参照のみのときの予測値
(このケースでは 7.44s ≒ `duration_scale` 0.93) に寄せるだけで 9/10 → 2/10 まで下がる。
audio.cpp のドキュメントが「try ... explicit `duration_sec`」と書いているのは正しい。

## 5. なぜ Irodori-TTS 側に Issue が無いのか

事実として確認できたこと (2026-08-09 時点):

| 調査先 | 結果 |
|---|---|
| `Aratako/Irodori-TTS` GitHub Issues (全 20 件, open/closed) | 末尾アーティファクトの報告は無し |
| `Aratako/Irodori-TTS-v4-Small` HF discussions | 1 件のみ (「large 版は出るのか」) |
| `0xShug0/audio.cpp` Issues | Irodori 関連は #6 / #188 / #192 のみ。いずれも Vulkan バックエンドの別問題 |
| audio.cpp PR #184 (記述の出典) | Validation は audiocpp_cli パステスト + WebUI テストのみ。Python 実行の記録なし |

補足:

- v4-Small のリリースは 2026-08-03〜04 (Irodori-TTS commit `d48dd92`、audio.cpp PR #184 が 08-04)。
  **本調査時点でリリースから 6 日**しか経っていない。
- 近い前例として Irodori-TTS Issue
  [#13 "Reading Hallucinations when hitting 30s inference"](https://github.com/Aratako/Irodori-TTS/issues/13)
  (v2/v3, closed) がある。「生成尺が余ると、繰り返し・意味不明な読み・雑音を吐く」という報告で、
  作者の回答は「学習データは全て 30 秒以下、30 秒近辺のデータも少ないので長文は苦手。句読点で
  チャンク分割してほしい」。**尺が余ると埋めるように喋る**という性質自体は既知。
- つまり「誰も報告していない」であって「報告したが否定された」ではない。

## 6. 本調査の限界

- **内容の文字起こし確認はしていない。** 判定は「発話区間数の増加 + 末尾無音の消失」という
  音響的プロキシ。余計な区間が実際に意味のある発話かどうかは試聴 (または ASR) が必要。
  分かりやすい例:
  - `out/python-sweep/v4py-clone_caption-seed1238.wav` (4区間、6.34-7.52s に 1.18s の余計な発話)
  - `out/python-sweep/v4py-clone_caption-seed1240.wav` (4区間、最終区間 1.32s)
  - 対照: `out/python-sweep/v4py-clone-seed1238.wav` (クリーン)
- 「same seed で再現」は実装間では成立しない (RNG が別)。発生率の比較のみが意味を持つ。
- 条件は text 1 種・参照音声 1 本・caption 1 種のみ。CPU fp32、`num_steps=24`
  (本番既定は 40)。他のテキスト/参照/caption で発生率が同じとは限らない。
- v3 の測定は C++/GGUF 経路のみ。Python では再実行していない。

## 7. 成果物

| ファイル | 内容 |
|---|---|
| `python/run_python_sweep.py` | PyTorch 経路のスイープ (ランタイム 1 回ロードで連続生成) |
| `python/analyze_tail.py` | 区間解析 (`analyze_tail.ps1` の移植、出力一致を検証済み) |
| `out/python-sweep/` | 本スイープ 40 本 + `results.csv` + `tail_analysis_python.csv` |
| `out/python-fixdur/`, `out/python-fixdur620/` | 尺固定の検証 各 10 本 (同じく両 CSV あり) |
| `issues/irodori-tts-tail-issue-draft.md` | Irodori-TTS 本家への Issue ドラフト (未提出) |

再現手順:

```bash
cd D:\Programs\NovelViewer\tmp\irodori-eval
$env:PYTHONPATH="D:\Programs\Irodori-TTS"
D:\Programs\Irodori-TTS\.venv\Scripts\python.exe python\run_python_sweep.py `
  --ref ref\ref.wav --out-dir out\python-sweep `
  --modes clone_caption clone caption noref --seeds 10 --steps 24
D:\Programs\Irodori-TTS\.venv\Scripts\python.exe python\analyze_tail.py --dir out\python-sweep
```

尺固定の検証:

```bash
# 参照のみのときの予測値 7.44s に合わせる
... run_python_sweep.py --ref ref\ref.wav --out-dir out\python-fixdur `
  --modes clone_caption --seeds 10 --steps 24 --seconds 7.44 --tag fixdur744
... analyze_tail.py --dir out\python-fixdur
```

`--min-seg-sec 0` を渡すと微小区間を除外しない生の数字 (PowerShell 版と同条件) が出る。
