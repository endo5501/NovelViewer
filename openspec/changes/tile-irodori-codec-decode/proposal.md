## Why

Irodori-TTS で**改行を含まない長い一文**を合成すると、必ず次のエラーで失敗する。

```
WARNING tts.session Synthesis failed: TtsEngineException:
  Irodori synthesis failed: failed to allocate Irodori-TTS codec graph
```

再現例 (116 文字の日本語一文、約 17〜20 秒):

> 壮二君が思いついたわなというのは、去年でしたか、…よくおぼえていたからです。

### 真因

`third_party/audio.cpp/src/models/irodori_tts/codec.cpp:739-741` の `ggml_gallocr_reserve()` が false を返している。これは**バックエンドのバッファ確保失敗**を意味する (`external/ggml/src/ggml-alloc.c:938-941`)。

VRAM 枯渇ではない。開発機の AMD Radeon RX 6800 (VRAM 16GB) は `vulkaninfo` 実測で

```
maxMemoryAllocationSize = 0x80000000   (2 GiB)
maxBufferSize           = 0x80000000   (2 GiB)
```

であり、**VRAM がいくらあっても Vulkan バッファ 1 個は 2 GiB を超えられない**。ggml-vulkan はこの上限を確保前にチェックして即座に例外を投げる (`ggml-vulkan.cpp:2666`) ため、VRAM 使用量は 1 バイトも増えないまま失敗する。パフォーマンスモニタ上「GPU メモリに余裕がある」ように見えるので VRAM 枯渇と誤診しやすい。

DACVAE デコーダの block3 / block4 にある `Conv1d(k=7)` は ggml で im2col + mul_mat に展開され、その im2col テンソルが単一で

```
1,290,240 要素 × latent_steps × 4 バイト (f32)  =  129 MB / 音声 1 秒
→ 2 GiB を超えるのは 16.6 秒
```

に達する。**閾値はテキストの内容ではなく発話長で決まる**ため、同じ文を 2 つに割ると通る (実測で確認済み)。

### なぜ今の構造では直らないか

`IrodoriCodec::Impl::decode()` は latent 全体に対して**単一のグラフ**を構築する。したがって必要メモリは発話長に線形比例し、どれだけ VRAM を積んでも 16.6 秒で頭打ちになる。上限を上げるのではなく、**発話長からメモリ量を切り離す**必要がある。

## What Changes

`IrodoriCodec::Impl::decode()` を、latent フレーム軸のオーバーラップ付きタイル分割に置き換える。既存の `src/models/ace_step/vae_decoder.cpp:821-888` と同一のパターンを採る。

```
latent F フレーム
  ├─ F ≤ tile        → 直接復号 (現状のまま。オーバーヘッド完全にゼロ)
  └─ F >  tile        → タイル分割
                          window = [core_start - overlap, core_end + overlap)
                          各タイルを復号 → overlap 分をトリム → 連結
```

既定の tile はバックエンド別とする (根拠は design.md D2)。overlap は一律 16。両者は `irodori_tts.codec_decode_tile_frames` / `irodori_tts.codec_decode_overlap_frames` で上書きできる。

| バックエンド | 既定 tile | 無変更で通る発話長 | 単一テンソル |
|---|---:|---:|---:|
| Vulkan | 256 | ≤ 10.24 秒 | 1.32 GB (2 GiB 壁の 61%) |
| Metal / CUDA / CPU | 512 | ≤ 20.48 秒 | 2.64 GB (単一バッファ上限なし) |

### この不具合は AMD 固有ではない

「16.6 秒ちょうどで必ず落ちる」という**固定の壁は Vulkan/AMD 固有**である。他バックエンドには単一バッファの上限が無い (CUDA / CPU は `get_max_size = NULL` → `SIZE_MAX`、Metal は超過分をビュー分割で吸収する)。

しかし**メモリ消費が発話長に線形比例すること自体は全バックエンド共通**であり、壁の無い環境では「総メモリが尽きるまで落ちない」だけである。30 秒の発話は compute buffer 約 6 GB + 常駐重み 2.9 GB ≈ 9 GB を要求するため、**8 GB クラスの NVIDIA カードや Apple Silicon では総メモリ枯渇という別の顔で同じ失敗が起きる**。本 change はそれらにも効く。

### 分割が厳密である根拠

このデコーダの構成要素は **Snake1d (要素毎) / Conv1d / ConvTranspose1d / Slice / Add のみ**で、GroupNorm も LayerNorm も Attention も無い。したがって出力の各サンプルは有限の入力窓にしか依存せず、受容野は片側 **8 latent フレーム** (内訳は design.md D1)。overlap = 16 はその 2 倍であり、残す中央部分はフル復号と一致する。近似ではない。

## Capabilities

### New Capabilities

なし。

### Modified Capabilities

- `irodori-tts-native-engine`: codec デコードの要求に「発話長に依存しない有界なメモリで復号すること」および「タイル分割時の出力がフル復号と一致すること」を追加する。

## Impact

### 変更されるファイル

| ファイル | 内容 |
|---|---|
| `third_party/audio.cpp/src/models/irodori_tts/codec.cpp` | `Impl::decode()` のタイル分割、タイル設定の受け取りと検証 |
| `third_party/audio.cpp/include/engine/models/irodori_tts/codec.h` | `IrodoriCodec` コンストラクタにタイル設定を追加 |
| `third_party/audio.cpp/src/models/irodori_tts/session.cpp` | `irodori_tts.codec_decode_*` オプションのパースと引き渡し |
| `third_party/audio.cpp/include/engine/models/irodori_tts/session.h` | 既定値フィールドの追加 |
| `third_party/audio.cpp/tests/unittests/test_codec_tiled_decode.cpp` (新規) | タイル分割の一致テストと境界計算テスト |
| `third_party/audio.cpp/tests/CMakeLists.txt` | 新規テストの登録 |
| `third_party/audio.cpp` (submodule pointer) | 上記コミットを指す |

### 影響を受けないもの

- **Flutter 側 (`lib/`) は一切変更しない。** C API (`audiocpp_c_api.h`) のシグネチャも不変。
- **短い文の挙動は完全に不変。** tile 以下 (Vulkan 10.24 秒 / Metal 20.48 秒) は従来どおり直接復号を通り、命令列が 1 つも変わらない。小説の一文は通常 5〜7 秒なので、大多数のケースは無影響である。
- 参照音声のエンコード経路 (`EncodeGraph`) は変更しない (下記リスク参照)。
- RF-DiT サンプリング、condition encoder、トークナイザは無関係。

### 性能への影響

tile を超える発話でのみオーバーラップ分の再計算が発生する。

| バックエンド | オーバーヘッドが出る発話長 | 演算量の増分 |
|---|---|---:|
| Vulkan | > 10.24 秒 | +14% (stride 224 / tile 256) |
| Metal / CUDA / CPU | > 20.48 秒 | +7% (stride 480 / tile 512) |

**実測値は上表より大きい。** Vulkan で 19.92 秒の発話を測ったところ、演算量の増分は
+12.9% (実測 562 フレーム / 498 フレーム) と見積りどおりだったが、グラフ再構築が
1 回あたり 70〜95 ms かかり 3 回発生するため、**実効オーバーヘッドは +21%** だった
(詳細は design.md「実測結果」)。比較対象が「合成失敗」である以上この差は判断を変えないが、
数値としては実効値を採る。

この値が無視できない点は明記しておく。アーカイブ済みの実測 (`openspec/changes/archive/2026-08-02-speed-up-irodori-metal-decode/design.md`) では `codec_decode_ms / session.wall_ms` が macOS/Metal の最適化**前** 80.8%、**後**でも 43.1% であり、Windows/Vulkan には当該最適化が入っていない (`is_conv_transpose1d_col2im_fast_path_eligible()` は Cuda/Metal のみ) ため、Windows では decode が支配的と見られる。

ただし比較対象は「+14%」ではない。**現在これらの長文は音が一切出ていない**ので、比較は「失敗 vs +14% で成功」である。tile 以下は 0% である。

Metal については、既定 512 により影響範囲が 20.48〜30 秒の稀な発話に限定される (E2E 換算で +3% 程度)。この範囲は 8 GB クラスの Apple Silicon では現状そもそも総メモリ枯渇で失敗しうる領域である。

### リスク

| リスク | 評価 |
|---|---|
| タイル境界に不連続が出る | 受容野 8 に対し overlap 16。ユニットテストで直接経路との一致を検証するため、実機聴取に依存しない |
| グラフ再構築回数が増える | 1 回の `decode()` 内で最大 3 種のウィンドウ長が発生しうる。現状も文ごとに毎回再構築しているため悪化ではないが、実測して design.md に記録する (D4) |
| エンコード側に同じ壁が残る | **本 change の範囲外。** 参照 wav 約 24 秒で `failed to allocate Irodori-TTS codec encode graph` に到達する。参照音声キャッシュが効くため発生頻度は低い。別 change で扱う |
| `max_seconds=30` による切り捨て | 別の既存問題。Dart 側は 200 文字まで許すため 30 秒を超えうるが、その場合エラーにならず音声が途中で切れる。**本 change の範囲外**だが、タイル分割が入れば上限を安全に緩められるようになる |
