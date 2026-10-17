# Proposal

## Why

Piper TTS エンジンは、piper-plus v1.8.0 に独自の C API ラッパー 1 コミットを足したフォーク(`endo5501/piper-plus`)を使っている。本家 `ayutaz/piper-plus` は v2.0.2 に到達し、公式の C API(`piper_plus.h`、`PIPER_PLUS_API_VERSION 1`)と共有ライブラリビルド(`PIPER_PLUS_BUILD_SHARED`)を提供するようになった。フォークを維持し続ける理由はなくなっている。また v1.8.0 には、末尾音節の二重化(EOS trim)や `speaker_embedding_mask` 非対応など、本家で修正済みの不具合が残ったままである。本家の公式 API に乗り換えれば、フォーク保守が不要になり、今後の追従はサブモジュールのタグを付け替えるだけで済む。

## What Changes

- **BREAKING**(ビルド成果物): `third_party/piper-plus` サブモジュールの参照先を、フォーク `endo5501/piper-plus`(v1.8.0 + 独自 C API)から本家 `ayutaz/piper-plus` のタグ `v2.0.2` に切り替える。フォーク独自の `piper_tts_c_api.{h,cpp}` と `PIPER_TTS_BUILD_SHARED` は使わなくなる。
- **BREAKING**(ネイティブライブラリ名): ネイティブライブラリを `libpiper_tts_ffi.dylib` / `piper_tts_ffi.dll` から本家の `libpiper_plus.dylib` / `piper_plus.dll` に置き換える。
- Dart FFI バインディング(`PiperNativeBindings`)を `piper_plus_*` 関数群に書き換える。`PiperPlusConfig` / `PiperPlusSynthOptions` を構造体として扱い、合成結果のバッファは呼び出し側が `piper_plus_free_audio` で解放する、という所有権モデルに合わせる。
- `PiperTtsEngine` の公開 API(`loadModel` / `synthesize` / `setLengthScale` / `setNoiseScale` / `setNoiseW` / `dispose` / `isLoaded`)はそのまま保つ。合成パラメータは Dart 側で保持し、合成のたびにオプション構造体で渡す。
- 合成言語は、従来の v1.8 と同じく日本語(モデルの `language_id_map` にある `ja`)を明示的に指定する。v2 の既定である言語自動判定は使わない。
- ビルドスクリプト(`scripts/build_piper_macos.sh` / `scripts/build_piper_windows.bat`)、リリースワークフロー(`.github/workflows/release.yml`)、同梱検証スクリプト(`scripts/test/verify_macos_bundle.sh`)を新しいライブラリ名とビルドオプションに合わせる。
- 依存する ONNX Runtime は本家 CMake の指定どおり 1.14.1 から 1.20.0 に上がる。
- Piper モデルは現行のピン留めリビジョン `eb9b882` のまま変えない。v2.0.2 ランタイムで合成できることは探索段階で実測確認済み。

### 非ゴール(別の change で扱う)

- Piper モデルの更新(e22f5fe 以降、36b59c8、zs-v1)
- 本家 C API のストリーミング合成(`piper_plus_synth_start/next`、callback)の採用
- 本家 C API のユーザー辞書(`piper_plus_load_custom_dict` 等)の採用
- iPad(iOS)での Piper 対応

## Capabilities

### New Capabilities

(なし)

### Modified Capabilities

- `piper-tts-native-engine`: ネイティブライブラリの出所(フォーク → 本家 v2.0.2)、ライブラリ名、C API(独自 `piper_tts_*` → 公式 `piper_plus_*`)、合成バッファの所有権、合成パラメータの受け渡し方、合成言語の指定方法についての要件を変える。
- `macos-native-library-embedding`: 同梱される dylib の期待集合のうち、`libpiper_tts_ffi.dylib` を `libpiper_plus.dylib` に置き換える。
- `ci-tts-dll-build`: CI でビルド・検証する Piper DLL を `piper_tts_ffi.dll` から `piper_plus.dll` に置き換える。
- `github-actions-release`: リリース ZIP に含まれる DLL のうち、`piper_tts_ffi.dll` を `piper_plus.dll` に置き換える。

## Impact

- **コード**: `lib/features/tts/data/piper_native_bindings.dart`(全面的に書き換え)、`lib/features/tts/data/piper_tts_engine.dart`(内部実装)、`test/features/tts/data/piper_tts_engine_test.dart`(モックの更新)。`lib/features/tts/data/piper_model_download_service.dart` は、ピン留め理由を書いたコメントのうちランナーに触れている記述だけを更新する。
- **ビルド/CI**: `.gitmodules`、`third_party/piper-plus` サブモジュール、`scripts/build_piper_macos.sh`、`scripts/build_piper_windows.bat`、`scripts/test/verify_macos_bundle.sh`、`.github/workflows/release.yml`、README のビルド手順。
- **依存関係**: piper-plus 1.8.0 → 2.0.2、ONNX Runtime 1.14.1 → 1.20.0。
- **ユーザーへの影響**: 同じモデルでも、末尾の EOS trim 修正などにより合成音声の末尾や長さが少し変わる。設定値(lengthScale / noiseScale / noiseW)とダウンロード済みのモデル・辞書はそのまま使える。
- **開発環境**: 既存の `third_party/piper-plus/build` は古い CMake キャッシュを含むため、クリーンビルドが必要になる。
