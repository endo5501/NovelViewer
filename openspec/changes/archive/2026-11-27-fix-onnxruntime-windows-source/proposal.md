# Proposal

## Why

v2.5.0 の Release Windows Build（run 45189314178）が `Build Piper TTS DLL` で落ちた。
piper-plus の `cmake/find_onnxruntime_windows.cmake` は、`https://github.com/microsoft/onnxruntime/releases/download/v1.20.0/onnxruntime-win-x64-1.20.0.zip` から ONNX Runtime を取得する。
microsoft/onnxruntime リポジトリが非公開になったため、この取得が失敗する（`Failed to download ONNX Runtime`）。
いつ公開に戻るかわからないので、今も公開されている NuGet の `Microsoft.ML.OnnxRuntime` から同じ版を取ってビルドを通し、v2.5.1 を出す。

## What Changes

- 新規スクリプト `scripts/fetch_onnxruntime_windows.ps1` を追加する。
  - Piper の CMake が指定する ONNX Runtime の版（`ONNXRUNTIME_VERSION`）を読む。
  - NuGet から `Microsoft.ML.OnnxRuntime` の同じ版を取り、版ごとに固定した SHA256 と照合する。
  - win-x64 のヘッダー・`onnxruntime.lib`・`onnxruntime.dll`・`LICENSE` を、これまでの GitHub 版 zip と同じレイアウト（`onnxruntime-win-x64-<ver>/{include,lib,LICENSE}`）に組み直す。
  - 組み直したものを `third_party/piper-plus/build/onnxruntime/onnxruntime.zip` として置く。
- `scripts/build_piper_windows.bat` は、cmake の前にこのスクリプトを呼ぶ。zip が既にあると CMake はダウンロードを飛ばして展開だけを行うので、サブモジュールは書き換えない。
- `build_piper_windows.bat` は、ORT の取得、cmake configure、cmake build のどこかで失敗したら非0で止まるようにする。
- このスクリプトのテスト `scripts/test/fetch_onnxruntime_windows_test.ps1` を追加する。偽 nupkg を使い、ネットワークには出ない。
- `release.yml` のライセンスコピーと DLL 検証は、レイアウトが変わらないので変更しない。

## Capabilities

### New Capabilities

なし

### Modified Capabilities

- `ci-tts-dll-build`: Piper TTS DLL のビルドで、ONNX Runtime を NuGet から版とハッシュを固定して取得し、既存レイアウトで置く要件を追加する。
- `github-actions-release`: onnxruntime ライセンスの出所を、NuGet パッケージ同梱の `LICENSE` と明記する。

## Impact

- 変更するファイル
  - `scripts/build_piper_windows.bat`
  - `scripts/fetch_onnxruntime_windows.ps1`（新規）
  - `scripts/test/fetch_onnxruntime_windows_test.ps1`（新規）
  - `.claude/CLAUDE.md`（テスト実行コマンドの追記）
- 外部依存: ONNX Runtime の取得元が GitHub Releases から nuget.org に変わる。版は 1.20.0 のままとする。
- 対象外: `scripts/build_piper_macos.sh` と `scripts/build_piper_ios.sh` も GitHub から取得するので同じ障害を受けるが、Actions の対象外のため今回は扱わない。
