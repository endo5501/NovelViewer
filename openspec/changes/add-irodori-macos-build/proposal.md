## Why

Windows 環境で追加した audio.cpp ベースの新 TTS エンジン (Irodori-TTS / `audiocpp_ffi`) を macOS でもビルドできるようにしたい。しかし現状 `scripts/build_irodori_macos.sh` は CMake の configure 段階で失敗し、一度も成功していない (スクリプト冒頭にも "Not tested on this project's CI yet." と明記されている)。

```
CMake Error at FindPackageHandleStandardArgs.cmake:227 (message):
  Could NOT find OpenMP_CXX (missing: OpenMP_CXX_FLAGS OpenMP_CXX_LIB_NAMES)
Call Stack: third_party/audio.cpp/CMakeLists.txt:109 (find_package)
```

原因は AppleClang が OpenMP を同梱せず、Homebrew の `libomp` が keg-only で CMake の自動探索に引っかからないこと。さらに調査の結果、configure を通しても (a) `libomp.dylib` への `.app` 外絶対パス依存が残る、(b) `libaudiocpp_ffi.dylib` が `.app` に同梱されず実行時に `DynamicLibrary.open` で確実に失敗する、という2つの後続問題が判明した。既存 spec `irodori-tts-native-engine` の「macOS で共有ライブラリをビルドする」シナリオが実質未達の状態である。

## What Changes

- `scripts/build_irodori_macos.sh` に Homebrew `libomp` の **静的ライブラリ** (`libomp.a`) を指す CMake 引数を追加し、OpenMP を有効に保ったままビルドを成功させる
- 同スクリプトに `libomp` 未導入時の事前チェックを追加し、`brew install libomp` を案内して早期終了する
- `macos/Runner.xcodeproj/project.pbxproj` の `Embed Native Libraries` ビルドフェーズに `libaudiocpp_ffi.dylib` を追加 (`inputPaths` / `outputPaths` / `shellScript` の3箇所)
- `AUDIOCPP_DEPLOYMENT_BUILD=ON` を指定し、model spec を共有ライブラリへコンパイル時埋め込みする (`.app` に置くのは dylib 1つだけになる。`Contents/Frameworks/` は codesign の封印対象であり、そこに非コードファイルを置くと署名が失敗するため)
- `README.md` の macOS ビルド手順に前提条件 (`brew install libomp`) を追記
- 実機での E2E 確認 (Metal バックエンドで実際に音声合成が成立するか)

破壊的変更なし。Windows ビルド経路には一切手を入れない。

## Capabilities

### New Capabilities
- `irodori-macos-build`: macOS 向け `audiocpp_ffi` 共有ライブラリのビルド構成 (Metal バックエンド / libomp 静的リンク / model spec 埋め込み / 外部依存ゼロ) と、`Runner.app` バンドルへの dylib 同梱を規定する

### Modified Capabilities
<!-- 既存 spec の要件文言は変更しない。irodori-tts-native-engine の macOS シナリオは
     本 change によって初めて実際に満たされるが、要求そのものは変わらないため delta 不要。 -->

## Impact

**変更ファイル**
- `scripts/build_irodori_macos.sh` — CMake 引数追加、前提チェック追加
- `macos/Runner.xcodeproj/project.pbxproj` — `Embed Native Libraries` フェーズ (396-421行付近) の3箇所
- `scripts/test/verify_irodori_macos.sh` — 新規。成果物の検証スクリプト
- `README.md` — macOS 前提条件の追記

**依存関係**
- 新規の開発時前提として Homebrew `libomp` が必要 (macOS ビルド時のみ)。成果物 `libaudiocpp_ffi.dylib` は静的リンクにより実行時の外部依存ゼロを維持する

**影響する既存機能**
- `lib/features/tts/data/audiocpp_native_bindings.dart` — 実装変更なし。dylib が `.app` に同梱されることで初めて `DynamicLibrary.open('libaudiocpp_ffi.dylib')` が成功する
- 既存の4つの dylib (qwen3 / lame / piper / onnxruntime) の同梱動作には影響しない

**スコープ外**
- macOS 版のバイナリ配布・コード署名・公証 (現時点で macOS は開発者自身のローカルビルド運用のみ)
- CI での macOS ビルド自動化
- Windows ビルド経路
