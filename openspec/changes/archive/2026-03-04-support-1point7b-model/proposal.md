## Why

現在 qwen3-tts.cpp は 0.6B モデル (`qwen3-tts-0.6b-f16.gguf`) のみをサポートしている。Qwen3-TTS には 1.7B モデル (`Qwen3-TTS-12Hz-1.7B-Base`) が存在し、より高品質な音声合成が期待できる。1.7B モデルは 0.6B と同じアーキテクチャ (Qwen2ベースTalker) だが、hidden_size が 1024→2048 に拡大されており、Code Predictor への入力を 2048→1024 にダウンプロジェクションする `small_to_mtp_projection` 層が追加されている。この層が C++ 推論エンジンに未実装であるため、1.7B モデルの GGUF 変換はできても推論が正しく動作しない。

## What Changes

- GGUF 変換スクリプト (`convert_tts_to_gguf.py`) に `small_to_mtp_projection` テンソルのマッピングを追加
- C++ 推論エンジン (`tts_transformer.cpp/h`) に `small_to_mtp_projection` 層の読み込みと適用を実装
- GGUF メタデータにプロジェクション層の有無を示すフラグまたは次元情報を追加
- モデルファイル名のハードコード (`qwen3-tts-0.6b-f16.gguf`) を動的に解決する仕組みに変更
- 0.6B モデルとの後方互換性を維持（プロジェクション層が無い場合はスキップ）

## Capabilities

### New Capabilities
- `tts-mtp-projection`: Talker hidden_size と Code Predictor hidden_size が異なるモデルで、small_to_mtp_projection 線形層による次元変換を行う機能

### Modified Capabilities
- `tts-native-engine`: モデルファイル名の動的解決と、異なるモデルサイズへの対応

## Impact

- `third_party/qwen3-tts.cpp/scripts/convert_tts_to_gguf.py`: テンソルマッピング追加
- `third_party/qwen3-tts.cpp/src/tts_transformer.h`: プロジェクション層のテンソル追加
- `third_party/qwen3-tts.cpp/src/tts_transformer.cpp`: プロジェクション層の読み込み・適用ロジック
- `third_party/qwen3-tts.cpp/src/qwen3_tts.cpp`: モデルファイル名の動的解決
- 動作確認は qwen3-tts-cli で実施（NovelViewer 側の変更は本 change のスコープ外）
