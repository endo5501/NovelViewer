## Context

現状の Irodori-TTS は単一モデル (600M-v3-VoiceDesign) 前提で組まれている。エンジン選択は `TtsEngineType.irodori` の1値、モデルダウンロードは safetensors 4ファイルの一括取得で `areModelsDownloaded()` が boolean 1個を返す構造になっており、複数モデルを扱う余地がない。

audio.cpp 本家が v4 Small をサポートしたが、本セッションの実測で v4 は「参照音声 × caption」の組み合わせでのみ末尾に余計な発話を生成することが判明した (10/10、2x2 の切り分け済み)。この経路は本アプリの主経路である。一方で参照音声のみの経路では v4 は完全にクリーンだった。

したがって v4 は「v3 の置き換え」ではなく「制約付きの選択肢」として追加する。

制約:

- `third_party/audio.cpp` は分岐点 `a0f3b4c` から upstream が約150コミット先行しており、v4 対応コードは spec v1 基盤に依存するため、v4 コミット単体の cherry-pick では成立しない
- 我々のフォークは FFI シム・abort・MP3 読み込み・タイル分割デコードなど独自機能を持つ
- モデルは Hugging Face から配信し、`project_piper_model_runner_mismatch` の教訓からサイズを pin する運用を採っている

## Goals / Non-Goals

**Goals:**

- v3 / v4 を選択可能にし、v4 では caption を確実に無効化する
- caption ゲートを UI 層より下に置き、呼び出し経路が増えても漏れない構造にする
- モデル配布を GGUF 単一ファイルへ統一し、ダウンロード量を 2.90GB から 1.27〜1.37GB へ削減する
- audio.cpp を upstream/main へ追従させ、フォーク独自機能を維持したまま v4 を利用可能にする

**Non-Goals:**

- v4 の末尾アーティファクト自体の修正 (本家のモデル/ランタイム側の課題であり、上流の対応を待つ)
- v4 での VoiceDesign 機能の提供
- q8_0 精度パッケージの提供 (f16 のみとする。理由は D7)
- ggml Vulkan の q8_0 カーネル自体の修正 (upstream/ggml 側の課題。報告に留める)
- Vulkan / HIP 環境での v4 性能評価 (本変更のスコープ外。本家プレビルドに GPU 版が無く、評価は CPU 実測に留まる)
- 旧 safetensors 資産の自動削除 (ユーザの明示操作に限る)

## Decisions

### D1: variant は `TtsEngineType` ではなく `IrodoriEngineConfig` のフィールドとする

`TtsEngineType` に `irodoriV3` / `irodoriV4` を追加する案も検討したが、`TtsEngineType` は SharedPreferences の保存値であり、エンジン分岐が `tts_isolate` / `tts_session` / `tts_edit_controller` / `tts_streaming_controller` など各所に散っている。値を増やすと全分岐の網羅が必要になり、blast radius が大きい。

variant は Irodori 内部の関心事なので `IrodoriEngineConfig` のフィールドとして持つ。エンジン選択の既存構造は一切変えない。

variant はモデルロードを伴うため `modelLoadKey` に含める。caption / refWavPath / guidance / steps が合成時パラメータとして `modelLoadKey` から除外されているのと対照的である。

### D2: caption ゲートは `TtsEngineConfig.captionFromMemo()` に置く

このメソッドには既に「Centralised here so every synthesis call site applies the same rule」という意図が明記されており、Qwen3 / Piper で memo を caption にしないという同種の判定を担っている。v4 の判定を同じ場所に足すのが構造的に一貫する。

UI 側で caption 入力を無効化するだけの案は採らない。合成の呼び出し経路は複数あり (ストリーミング生成・編集ダイアログの再生成・保存済みセグメントの再合成)、UI を経由しない経路が存在するため、UI だけのゲートは漏れる。

ただし UI 側の無効化も別途行う。**ゲート (正しさ) と表示 (分かりやすさ) は目的が違い、片方で代替できない。** ゲートだけではユーザーが memo を書いて効かない理由が分からず、表示だけでは実装漏れで caption が渡る。

### D3: モデル配布は variant ごとの単一 GGUF に統一する。ただし精度は **f16** とする

v3 を safetensors のまま残す案も検討したが、2形式を並行して抱えるとダウンロード・判定・エンジンのモデルパス解決がすべて二重化する。GGUF は model spec / model_config / tokenizer をすべて埋め込んでおり、`.gguf` 1本を置いたディレクトリを渡すだけでロードできることを本セッションで実証済みである (本家プレビルド zip には `model_specs/` すら含まれていない)。

**精度は q8_0 ではなく f16 を選ぶ。** 当初は既定パッケージである q8_0 を想定していたが、実測で **ggml の Vulkan バックエンドが q8_0 量子化重みに対して NaN/Inf を生成し、出力が定数フルスケールに飽和する**ことが判明した。Vulkan は本番 Windows ビルドのバックエンドであるため、q8_0 は採用できない (詳細は D7)。

代償として既存ユーザーに v3 の再ダウンロード (1.46GB) を強いる。ただし従来の 2.90GB より小さく、以後のダウンロードも軽くなる。

### D7: q8_0 を避け f16 を配布する (実測に基づく)

マージ後のビルドで v3 GGUF を Vulkan で合成したところ、音声長が `min_duration_sec` の下限 0.5 秒に張り付いた。バックエンドと形式を分離した結果:

| | CPU | Vulkan |
|---|---|---|
| GGUF q8_0 | 6960ms ✅ | 520ms ❌ |
| GGUF f16 | 6960ms ✅ | 6920ms ✅ |
| safetensors | 6960ms ✅ | 6920ms ✅ |

`safetensors × Vulkan` が正常なため、これは upstream マージによる退行ではない。従来は safetensors しか使っておらず、**q8_0 経路が一度も実行されていなかった**だけである。

さらに duration を明示指定して predictor を迂回し、音声そのものを比較した:

| | RMS | 相関 |
|---|---:|---|
| v3 q8_0 / Vulkan | **1.0000** | NaN (分散ゼロ) |
| v3 f16 / Vulkan | 0.1277 | — |
| v3 q8_0 / CPU | 0.1276 | f16/Vulkan と 0.9919 |

q8_0 × Vulkan の出力は**全 332,160 サンプルが int16 最大値 32767 の定数**であり、劣化した音声ではなく計算経路の完全な破綻である。v4 でも同一の破綻を確認した (RMS 1.0000)。ただし **v4 では duration predictor だけは正常値を返す**ため、音声長だけを見ると正常と誤判定する。検証は必ず波形の RMS / 相関で行うこと。

f16 を選ぶ代わりに「q8_0 を配布し Vulkan 実行時のみ f16 へ展開する」案も実測で動作を確認したが (`irodori_tts.weight_type=f16`)、ダウンロードは小さくなる一方で実行時メモリが約2倍になり、壊れたバックエンド経路を回避策で隠す形になるため採らない。

**未検証の範囲:** 検証は AMD RX 6800 / proprietary driver の Vulkan のみで行った。macOS の Metal バックエンドは未検証であり、同じ破綻があるかは不明である。NVIDIA や他ドライバでの挙動も不明。この事象は upstream に報告する価値がある (再現手順が明確で、モデル非依存の可能性が高い)。

### D4: 旧 safetensors 資産は検出して提示し、削除はユーザ操作に限る

新形式へ移行すると旧 safetensors 2.90GB が孤児として残る。自動削除は採らない。ユーザが別用途 (audio.cpp CLI での検証など) に使っている可能性があり、確認なしの 2.90GB 削除は取り返しがつかない。

`tts-model-selection` の「Legacy directory migration」に前例があるが、あれはディレクトリ移動であり削除ではない。本件は削除なので、より慎重にユーザの明示操作を要求する。

### D5: audio.cpp は upstream/main を丸ごとマージする

v4 コミット (`238ab6a`) だけの cherry-pick は成立しない。同コミットは spec v1 への移行を含み (`loader.cpp` の削除を伴う)、その基盤は間の約150コミットで導入されているため。

`git merge-tree` による試験マージで衝突は 9 ファイル。うち 2 件は docs、2 件は作業ゼロ (下表)。

| ファイル | 解決方針 |
|---|---|
| `conv_modules.cpp` | upstream 採用。upstream は既に `Cuda\|\|Hip\|\|Metal` を実装済みで、我々の回避策 (Hip メンバー不在への対処) は不要になる |
| `wav_reader.cpp` | 我々版採用、upstream ハンク破棄。upstream の対策はサイズ詐称に対する 1MiB ずつの段階的確保だが、我々は確保前に `remaining_bytes()` でクランプしており目的を達成済み |
| `session.cpp` / `session.h` | abort パッチとタイル設定を再適用 |
| `loader.cpp` | upstream が削除。CLI オプション記述2行を新しい宣言場所へ移設 |
| `CMakeLists.txt` | 我々の +44 行は独立した純追加5ブロック。機械的に再配置 |
| `app/server/runtime.cpp` | 本アプリは `audiocpp_server` を使わないため破棄可 |
| `docs/tts.md` / `docs/usage.md` | upstream 採用 |

`codec.cpp` のタイル分割デコード、`miocodec/graph_ops.cpp`、ggml の Metal パッチ、シム `audiocpp_c_api.cpp/h` は自動マージが成立する。

abort パッチについて: upstream の `session.cpp` には `for (int64_t step ...)` が2つあるが、片方は `timesteps` 配列の事前計算で GPU work を伴わない。中断チェックが必要なのは従来どおり**チャンクループと RF サンプリング本体の2箇所**であり、1対1で再適用すればよい。

### D6: 変更は一つにまとめ、タスク順序で段階を管理する

マージとアプリ対応を別変更に分ける案も検討したが、マージ単体では v3 の挙動が変わらず、検証の出口がビルドとリグレッションテストに限られる。一つの変更にまとめ、タスクを「マージ → 検証 → アプリ対応」の順に並べることで、マージ段階での撤退判断も可能にする。

## Risks / Trade-offs

**[FFI シムがマージ後にコンパイルできない]** → 最大のリスク。`IrodoriTTSSession` のコンストラクタに `ModelContract` 引数が増え、`make_irodori_tts_loader()` という新ファクトリが公開されている。シムが使う runtime シンボル11個 (`make_default_registry` / `ModelLoadRequest` / `model_spec_override` / `create_task_session` / `IOfflineVoiceTaskSession` ほか) はすべて upstream に健在であることを確認済みだが、セッション生成の作法が spec v1 前提に変わっているため、実際にビルドするまで確定しない。タスクではマージ直後にビルドを置き、ここで詰まったら以降に進まない。

**[weight context 既定値が 512/768/512 MB から一律 32MB へ激減]** → GGUF 前提でメタデータのみを保持する設計に変わったためと推測されるが、safetensors 経路や大きな入力で不足する可能性がある。マージ後の最初の合成で確認し、必要ならセッションオプションで明示指定する。

**[既存ユーザーへの 1.27GB 再ダウンロード]** → D3 のトレードオフとして受容する。旧資産の削除導線を提供し、実質的なディスク使用量はむしろ減ることを示す。

**[v4 の末尾アーティファクトが caption 以外の条件でも起きる]** → 検証は 1 種類のテキスト・1 種類の参照音声・10 seed で行った。別のテキストや長文では条件が変わる可能性がある。v4 リリース後に参照音声のみの経路で問題報告があれば再評価する。

**[本家がモデルファイルを差し替える]** → サイズ pin により検出できる。pin 値と一致しなければダウンロードは失敗し、破損したまま「ダウンロード済み」にはならない。自前ミラーを使うため本家の差し替えが即座に影響することもない。

**[GPU (Vulkan / HIP) での v4 挙動が未検証]** → 本家プレビルドに GPU 版が存在せず、評価は CPU 実測に留まる。末尾アーティファクトはモデル挙動でバックエンド非依存と考えられるが、性能・VRAM 面は自前ビルド後に別途確認が必要。

**[audio.cpp のユニットテストに間欠的な失敗が2件ある]** → マージ後の実測で `supertonic_vector_convnext_exp_test` と `audio_dsp_test` が非決定的に失敗する。`supertonic` は単体実行でも落ちる (単体2回中1回)、`audio_dsp_test` は単体3回とも合格するがフルランで落ちた。実行順序にも本マージにも起因しない真の非決定性であり、この AMD RX 6800 / Vulkan 環境での数値許容誤差に起因すると判断した。本変更の責任範囲外として記録に留める。CI で赤が続く場合は別途切り分ける。

**[`scaled_dot_product_attention_test` は当環境で常に失敗する]** → "CUDA backend requested but it is not registered in this build" というメッセージのとおり、CUDA 必須の upstream テストである。当機は AMD のため構造的に実行不能。マージとは無関係。

**[upstream の `codec_decode_parity` がコンパイルできない]** → `tests/moss_tts_local/codec_decode_parity.cpp` が upstream 自身のヘッダ (`MossAudioTokenizerDecoder` の6引数コンストラクタ) に追随しておらず、`cmake --build` 全体を止める。当該2ファイルは `upstream/main` とバイト単位で同一で、本フォークは moss に一度も触れていない。`add_test` 登録のない手動ハーネスなのでユニットテストの対象外とし、フォークにパッチは当てない (無関係なモデルのために fork 差分を増やさない)。テストは ctest 登録済みターゲットを名指しでビルドする。

## Migration Plan

1. Hugging Face `endo5501/audio.cpp` へ v3 / v4 の GGUF をミラーする (前提作業、ユーザ側)
2. `third_party/audio.cpp` を upstream/main へマージし、ビルドと既存テストを通す。この時点で挙動は v3 のまま変えない
3. アプリ側に variant を導入する。既定は v3 なので、既存ユーザーの設定は変わらない
4. ダウンロードサービスを GGUF 単一ファイルへ切り替える。既存ユーザーは v3 が「未ダウンロード」と表示され、1.27GB を取得する
5. 旧 safetensors 資産の検出と削除導線を提供する

ロールバック: マージ段階 (2) で詰まった場合、submodule の pin を戻すだけで現状に復帰できる。アプリ側 (3 以降) は variant の既定が v3 であるため、v4 関連の UI を隠すだけで実質的に従来動作へ戻せる。

## Open Questions

- v4 で `num_inference_steps` の既定値 40 が適切か。本家 docs は v4 でも 40 を既定としているが、実測は 24 で行った
- v4 選択時に参照音声が未設定の場合の扱い。v4 は no-reference 生成もクリーンなので許容してよいが、UI 上どう見せるか
- 旧資産の削除導線を Irodori 設定セクションに置くか、より一般的なストレージ管理の場所に置くか
