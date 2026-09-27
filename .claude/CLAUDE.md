# NovelViewer 開発ガイド

NovelViewerはWeb小説サイト（なろう、カクヨム）から小説をダウンロードし、ローカルで閲覧するためのFlutterデスクトップアプリケーション。

## 開発コマンド

 - `scripts/build_tts_macos.sh` - TTSエンジンビルド(mac)
 - `scripts/build_irodori_macos.sh` - Irodori-TTSエンジンビルド(mac、要 `brew install libomp`)
 - `scripts/test/verify_irodori_macos.sh` - Irodori-TTSビルド成果物の検証(mac)
 - `scripts/build_lame_macos.sh` - LAMEビルド(mac)
 - `scripts/build_app.sh macos` - 本番ビルド(mac)。commit ハッシュを `--dart-define=BUILD_COMMIT` で注入し、障害レポートの app version に載せる。素の `fvm flutter build macos` でも動くが、レポートは `commit unknown` になる
 - `scripts/build_tts_windows.bat` - TTSエンジンビルド(windows)
 - `scripts/build_lame_windows.bat` - LAMEビルド(windows)
 - `scripts\build_app.bat windows` - 本番ビルド(windows)。commit ハッシュの注入は mac と同じ
 - `scripts/build_app.sh ios` - ビルド(iPad。commit ハッシュの注入は mac と同じ。ビューア機能のみでTTS/LLMは非対応。Xcodeのplatform componentと`ios/Flutter/Local.xcconfig`のDEVELOPMENT_TEAMが必要。詳細は`docs/ipad.md`参照)
 - `fvm flutter test` - テスト実行
 - `bash scripts/test/build_app_test.sh` - `build_app.sh` のテスト(スタブの fvm / git で実行し、実ビルドはしない)
 - `powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/test/build_app_test.ps1` - `build_app.bat` のテスト(windows。同上)
 - `swift test --package-path packages/foundation_models_llm/darwin/wire_code_tests` - オンデバイスLLMプラグインのエラー写像テスト(mac。プラグイン本体はFlutterビルド外で走らないため写像だけを独立パッケージで実行)
 - `fvm dart format .` - フォーマット実行(lib/とtest/が対象)
 - `fvm flutter analyze` - リント実行
 - `fvm flutter pub get` - 依存パッケージ取得
 - `scripts/benchmark_tts.sh --model-dir <dir> --max-tokens 200` - TTSベンチマーク実行（結果はbenchmarks/に保存）
 - `scripts/release.ps1 <X.Y.Z>` / `scripts/release.sh <X.Y.Z>` - リリース実行(windows/unix)。pubspec.yamlのversionを`X.Y.Z+(N+1)`に更新→commit→`vX.Y.Z`タグ付け→pushを一括実行（事前検証込み）。手動の`git tag`は使わずこのスクリプト経由でリリースする

## 必須ルール(MUST)

1. TDD厳守: テストファースト開発を必ず実施→ `/test-driven-development` スキルを使用
2. デバッグ: デバッグ時、 `/systematic-debugging` スキルを使用
3. OpenSpecで`/opsx:archive`の際は、必ず同期してからアーカイブをしてください

## tasks.md作成時の注意

OpenSpecのスキルでtasks.mdを作成する際、最終確認のため以下の項目を追加してください

```md
## X. 最終確認

- [ ] X.1 code-reviewスキルを使用してコードレビューを実施
- [ ] X.2 codexスキルを使用して現在開発中のコードレビューを実施
- [ ] X.3 `fvm dart format .`でフォーマットを実行
- [ ] X.4 `fvm flutter analyze`でリントを実行
- [ ] X.5 `fvm flutter test`でテストを実行
```
