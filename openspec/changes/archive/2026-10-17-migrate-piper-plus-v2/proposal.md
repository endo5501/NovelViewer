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
- Piper モデルのピン留めリビジョンを `eb9b882`(2026-03-18)から `36b59c8`(2026-06-13、main 直下の `tsukuyomi-chan-6lang-fp16`)に更新する。当初はモデルを据え置く予定だった。しかし実機確認で、v2.0.2 ランタイムの EOS trim(Issue #499)が旧モデルの最終母音を削ることが分かった(「彼はそういった」→「かれはそういっ」)。そのため、ランタイムの前提に合うモデルへの更新をこの change に取り込む。ファイル名と取得パスは変わらない。既存ユーザーは、完了マーカーの不一致により再ダウンロードを促される。

- かなを含まない漢字だけの日本語の文(「多分。」など)を日本語として読むようにする。本家の言語判定は、かながない漢字を中国語と判定する。エンジンには、`language_id_map` から `zh` を除いた config を渡す(実装中に判明。v1.8 では無音、v2.0.2 ではエラー)。
- 発音できる音素が 1 つもない文(記号だけの行、英語辞書がない状態での英語だけの文など)は、エラーにせず 0.2 秒の無音を返す。v2.0.2 は空の入力で推論してエラーになり、再生が止まっていた(実装中に判明)。

### 非ゴール(別の change で扱う)

- zs-v1 モデルへの更新(パス・ファイル名・推論の既定値が変わるため)
- 本家 C API のストリーミング合成(`piper_plus_synth_start/next`、callback)の採用
- 本家 C API のユーザー辞書(`piper_plus_load_custom_dict` 等)の採用
- iPad(iOS)での Piper 対応

## Capabilities

### New Capabilities

(なし)

### Modified Capabilities

- `piper-tts-native-engine`: 漢字だけの文を日本語として音素化すること、発音できない文で無音を返すことを要件に加える。ネイティブライブラリの出所(フォーク → 本家 v2.0.2)、ライブラリ名、C API(独自 `piper_tts_*` → 公式 `piper_plus_*`)、合成バッファの所有権、合成パラメータの受け渡し方、合成言語の指定方法についての要件を変える。
- `macos-native-library-embedding`: 同梱される dylib の期待集合のうち、`libpiper_tts_ffi.dylib` を `libpiper_plus.dylib` に置き換える。
- `ci-tts-dll-build`: CI でビルド・検証する Piper DLL を `piper_tts_ffi.dll` から `piper_plus.dll` に置き換える。
- `piper-tts-model-download`: モデルとランナーの「互換」に、ランナーの後処理で末尾音節が欠落しないことを含める。旧リビジョンで取得済みのモデルが再取得の対象になることを明記する。
- `irodori-macos-build`: 「既存ライブラリの同梱に影響しない」シナリオに書かれた Piper の dylib 名を `libpiper_plus.dylib` に直す(アーカイブ時の同期で見つかった記述漏れ)。
- `github-actions-release`: リリース ZIP に含まれる DLL のうち、`piper_tts_ffi.dll` を `piper_plus.dll` に置き換える。

## Impact

- **コード**: `lib/features/tts/data/piper_native_bindings.dart`(全面的に書き換え)、`lib/features/tts/data/piper_tts_engine.dart`(内部実装)、`test/features/tts/data/piper_tts_engine_test.dart`(モックの更新)。`lib/features/tts/data/piper_model_download_service.dart` はピン留めリビジョンとその理由のコメントを更新し、`test/features/tts/data/piper_model_download_service_test.dart` もそれに合わせる。
- **ビルド/CI**: `.gitmodules`、`third_party/piper-plus` サブモジュール、`scripts/build_piper_macos.sh`、`scripts/build_piper_windows.bat`、`scripts/test/verify_macos_bundle.sh`、`.github/workflows/release.yml`、README のビルド手順。
- **依存関係**: piper-plus 1.8.0 → 2.0.2、ONNX Runtime 1.14.1 → 1.20.0。
- **ユーザーへの影響**: Piper の声質が新しいモデル(MB-iSTFT-VITS2 デコーダ)のものに変わる。既存ユーザーは Piper モデル(約 40MB)の再ダウンロードが必要になる(アプリが促す)。設定値(lengthScale / noiseScale / noiseW)と OpenJTalk 辞書はそのまま使える。
- **開発環境**: 既存の `third_party/piper-plus/build` は古い CMake キャッシュを含むため、クリーンビルドが必要になる。
