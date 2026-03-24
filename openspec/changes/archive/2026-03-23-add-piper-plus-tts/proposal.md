## Why

現在のTTSエンジン（qwen3-tts）は高品質だが、モデルサイズが大きく（1.7GB〜3.6GB）推論速度が遅いため、リアルタイムでの読み上げ開始までに待ち時間が発生する。piper-plus（VITS系軽量TTS）を追加エンジンとして統合することで、CPU上でも高速な音声合成を実現し、ユーザーが品質と速度のトレードオフを選択できるようにする。

## What Changes

- piper-plusのC++ライブラリをフォーク（https://github.com/endo5501/piper-plus）し、FFI用C APIラッパーを追加して共有ライブラリとしてビルド
- piper-plus用のDart FFIバインディングとエンジンラッパーを新規作成
- TtsIsolateにエンジン種別による分岐を追加し、qwen3-ttsとpiper-plusの両方に対応
- 設定画面のTTSタブにエンジン選択UI（SegmentedButton）を追加し、選択に応じてqwen3-tts設定またはpiper-plus設定を表示
- piper-plus用の設定項目を追加：モデル選択、速度（lengthScale）、抑揚（noiseScale）、ノイズ（noiseW）のスライダー
- piper-plusモデル（ONNX + JSON）およびOpenJTalk辞書のダウンロード機能を追加
- macOS/Windows用のpiper-plusビルドスクリプトを追加

## Capabilities

### New Capabilities
- `piper-tts-native-engine`: piper-plusのC APIラッパー、共有ライブラリビルド、Dart FFIバインディング
- `piper-tts-model-download`: piper-plusモデル（ONNX + JSON）およびOpenJTalk辞書のHuggingFaceからのダウンロード
- `piper-tts-synthesis-params`: piper-plus固有の合成パラメータ（lengthScale、noiseScale、noiseW）の管理とUI
- `tts-engine-selection`: TTSエンジン（qwen3-tts / piper-plus）の選択、永続化、UIによる切り替え

### Modified Capabilities
- `tts-streaming-pipeline`: TtsIsolateがエンジン種別に応じてqwen3-ttsまたはpiper-plusを使い分ける
- `tts-settings`: TTSタブにエンジン選択UIを追加し、選択に応じた設定パネルの出し分け

## Impact

- **C++/ネイティブ**: `third_party/piper-plus/` にフォークを配置、C APIラッパー（`piper_tts_c_api.h/cpp`）を追加、CMakeLists.txtに共有ライブラリビルドオプションを追加
- **ビルドスクリプト**: `scripts/build_piper_macos.sh`、`scripts/build_piper_windows.bat` を新規作成
- **依存ライブラリ同梱**: ONNX Runtime（CPU版、~30MB）、OpenJTalk辞書（~50MB）をアプリにバンドルまたはダウンロード
- **Dart層**: `lib/features/tts/data/` に `piper_native_bindings.dart`、`piper_tts_engine.dart` を追加、`tts_isolate.dart` を修正
- **Provider層**: エンジン種別、piperモデル選択、合成パラメータ用のproviderを追加
- **UI層**: `settings_dialog.dart` のTTSタブを大幅改修
- **設定永続化**: SharedPreferencesにエンジン種別、piperモデルパス、合成パラメータの各キーを追加
