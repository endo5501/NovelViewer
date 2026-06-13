## Why

Piper TTS が合成時に必ず失敗し、音声を再生できない。真因は **ダウンロードするモデルと、同梱する推論ランナーの世代不一致**である。`PiperModelDownloadService._baseUrl` が HuggingFace `ayousanz/piper-plus-tsukuyomi-chan` の `resolve/main`（バージョン無固定）からモデルをライブ取得しているため、上流が更新されると常に最新モデルを掴む。2026-05-03 のコミット `e22f5fe`（MB-iSTFT-VITS2 デコーダ刷新）で新モデルが `speaker_embedding_mask` という ONNX 入力を要求するようになったが、同梱の piper-plus C++ 推論ランナー（サブモジュール `123efd6`、2026-03-23 で凍結）はこの入力を供給できない。結果、モデルのロードは成功するが、合成時に `Non-zero status code ... GreaterOrEqual node ... Missing Input: speaker_embedding_mask` で失敗する（実機ログで確認済み）。

## What Changes

- `PiperModelDownloadService._baseUrl` を `resolve/main` から、破壊的変更の直前リビジョン **`eb9b882`（2026-03-18）** にピン留めする。これにより取得モデルが凍結ランナーと同一世代（`sid` ベースの話者条件付け）となり、合成が通る。モデルのファイル名は現行と同一（`tsukuyomi-chan-6lang-fp16.onnx`）のため、変更は基底 URL の 1 箇所のみ。
- 恒久方針として「**Piper モデルは推論ランナー（piper-plus サブモジュール）と互換なリビジョンに固定して取得する。`main` 等の可変参照からライブ取得しない**」という要件を spec に明文化する。
- 既に旧（非互換）モデルをダウンロード済みのユーザは、ディスク上に古いファイルが残り `areModelsDownloaded()` が `true` を返すため自動では再取得されない。利用者が限定的な現状では **手動削除での対応を許容**する旨を spec に記す（強制再取得の自動化は Non-Goal）。

## Capabilities

### New Capabilities
<!-- なし -->

### Modified Capabilities
- `piper-tts-model-download`: モデル取得元をバージョン可変な `main` から、推論ランナーと互換な固定リビジョンに変更する要件を追加（モデルと推論エンジンの世代結合）。あわせて、既存ダウンロード済みユーザの再取得は当面手動である旨の制約を明記。

## Impact

- **コード**: `lib/features/tts/data/piper_model_download_service.dart`（`_baseUrl` のリビジョンピン留め。既に作業ツリーに 1 行変更あり・未コミット）。
- **テスト**: `test/features/tts/` 配下に、`_baseUrl` が可変参照（`/resolve/main`）でなく固定リビジョンを指していることを検証する回帰テストを追加。
- **既存データ/ユーザ影響**: 旧モデルを取得済みのユーザは手動で `models/piper/` のモデルファイル（`*.onnx` / `*.onnx.json` / `.piper_models_complete`）を削除してから再ダウンロードが必要。`open_jtalk_dic/` は変更不要。
- **Non-Goal**: piper-plus サブモジュール自体のアップグレード（Option B）、onnxruntime の更新、強制再取得の自動化（モデルのハッシュ/リビジョン検証）、qwen3 側の DLL 同梱問題（これはデバッグ環境特有で本変更の対象外）。
- **依存/スキーマ**: 変更なし。
