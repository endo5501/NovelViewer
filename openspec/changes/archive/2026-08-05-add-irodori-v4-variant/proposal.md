## Why

audio.cpp 本家が release-0.5.1 (commit `238ab6a`) で Irodori-TTS v4 Small をサポートした。v4 は単一 GGUF に tokenizer まで同梱した新世代チェックポイントで、現行の v3 safetensors 構成 (4ファイル / 3ディレクトリ / 2.90GB) に対して大幅に扱いが簡単になる。

ただし本セッションの実測で、**v4 は参照音声と caption を同時に与えたときにのみ、クリップ末尾へテキストに存在しない発話を付加する**ことが判明した。本アプリの Irodori 利用は「参照音声 × caption」が主経路であり、v4 への単純な置き換えはできない。一方で参照音声のみの経路では v4 は完全にクリーンだった。

そこで v3 と v4 を選択可能にし、**v3 では caption を有効、v4 では caption を無効**とすることで、v4 の新しい音質と v3 の VoiceDesign 機能の双方を失わずに提供する。

### 実測の根拠

CPU プレビルド (`release-0.5.1` cpu-balance) で 2x2 の切り分け実験を実施した。各条件 10 seed、同一テキスト・同一参照音声・同一 caption で v3 をベースラインとしたペア比較 (発話区間数の差分) による。

| 条件 | task | 参照 | caption | v4 の結果 |
|---|---|---|---|---|
| noref | `tts` | なし | なし | 0/10 クリーン |
| caption | `vdes` | なし | あり | 0/10 クリーン |
| clone | `clon` | あり | なし | 0/10 クリーン |
| clone_vdes | `vdes` | あり | なし | 0/10 クリーン |
| **clone_caption** | `vdes` | **あり** | **あり** | **10/10 発生** |

- 参照音声と caption の**交互作用でのみ**発生する。単独要因では発生しない
- `vdes` タスク経路自体は無罪。caption が無ければ `clon` と `vdes` の出力はバイト単位で完全一致した
- 本家 docs は "occasionally" と記載しているが、この条件では 100%
- 生成音声を試聴し「意味のない音声が末尾に追加される」ことを確認済み

なお音声長は duration predictor が決定論的に決めるため seed で変化せず (幅 0.00s)、長さでは検出できない。判定は発話区間構造の解析による。

## What Changes

- **Irodori に v3 / v4 の variant 選択を追加**する。既定は v3 (既存ユーザーの挙動を変えない)
- **v4 選択時は caption を合成に渡さない**。ゲートは `TtsEngineConfig.captionFromMemo()` という既存の単一絞り込み点に置き、UI より下の層で閉じる
- **v4 選択時は caption 関連 UI (セグメントメモの caption 利用、caption guidance scale) を無効化し、理由を表示**する
- **モデル配布を GGUF 単一ファイルへ統一**する
  - v3: safetensors 4ファイル 2.90GB → 単一 GGUF (f16) 1.46GB
  - v4: 単一 GGUF (f16) 1.76GB
  - 精度は q8_0 ではなく **f16**。ggml の Vulkan バックエンドが q8_0 重みで出力を飽和させるため (design D7)
- **BREAKING**: 既存ユーザーは v3 モデルの再ダウンロードが必要になる。旧 safetensors 資産 (2.90GB) は孤児として残さず後始末する
- **`third_party/audio.cpp` を upstream/main へマージ**する (分岐点 `a0f3b4c` から約150コミット)。v4 対応コードは spec v1 基盤に依存しており、v4 コミット単体の cherry-pick では成立しないため

## Capabilities

### New Capabilities

- `irodori-model-variant`: Irodori の v3 / v4 選択、variant ごとの機能可否 (caption の有効/無効) の決定、および選択 UI と制約の提示

### Modified Capabilities

- `irodori-caption-synthesis`: caption の合成への伝搬が variant 依存になる。v4 では memo の有無にかかわらず caption を渡さない
- `irodori-tts-model-download`: 配布形式が safetensors 複数ファイルから variant ごとの単一 GGUF へ変わる。ダウンロード状態が variant 単位になり、旧 safetensors 資産の後始末を伴う
- `irodori-tts-native-engine`: audio.cpp フォークの参照先が upstream/main マージ後のコミットへ更新される。エンジンは variant ごとの GGUF ディレクトリを読み込む

## Impact

### アプリ側

- `lib/features/tts/domain/tts_engine_config.dart` — `IrodoriEngineConfig` に variant フィールド追加、`captionFromMemo()` にゲート追加
- `lib/features/tts/data/irodori_model_download_service.dart` — variant ごとの単一 GGUF ダウンロード、pin サイズ更新、旧資産の後始末
- `lib/features/tts/providers/irodori_model_download_providers.dart` — ダウンロード状態を variant 単位へ
- `lib/features/tts/providers/tts_model_readiness_provider.dart` — variant を考慮した準備完了判定
- `lib/features/settings/presentation/sections/irodori_settings_section.dart` — variant 選択 UI、v4 時の caption 系 UI 無効化と理由表示
- `lib/features/settings/data/settings_repository.dart` — variant の永続化
- `lib/l10n/` — variant 選択と v4 の caption 非対応を説明する文言 (ja / en / zh)

### ネイティブ側

- `third_party/audio.cpp` — upstream/main へマージ。衝突は 9 ファイル。真のリスクは衝突ではなく FFI シムのコンパイル可否と、weight context 既定値が 512/768/512 MB から一律 32MB へ変わっている点
- `scripts/build_irodori_windows.bat`, `scripts/build_irodori_macos.sh` — マージ後のビルド確認

### 外部依存 (前提作業)

Hugging Face `endo5501/audio.cpp` へ以下のミラーが必要。本家 `audio-cpp/audio.cpp-gguf` での実測サイズ:

| ファイル | バイト数 |
|---|---:|
| `Irodori-TTS-v4-Small-GGUF/irodori-tts-v4-small-f16.gguf` | 1,762,161,536 |
| `Irodori-TTS-600M-v3-VoiceDesign-GGUF/irodori-tts-600m-v3-voicedesign-f16.gguf` | 1,463,787,680 |

自前ミラー + サイズ pin を維持するのは、memory `project_piper_model_runner_mismatch` で記録した「HF main のモデルが凍結ランナーより新しくなって再生不能になる」事故の再発を防ぐため。
