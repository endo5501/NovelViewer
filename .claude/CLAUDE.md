# NovelViewer 開発ガイド

NovelViewerはWeb小説サイト（なろう、カクヨム）から小説をダウンロードし、ローカルで閲覧するためのFlutterデスクトップアプリケーション。

## 開発コマンド

 - `scripts/build_tts_macos.sh` - TTSエンジンビルド(mac)
 - `scripts/build_irodori_macos.sh` - Irodori-TTSエンジンビルド(mac、要 `brew install libomp`)
 - `scripts/test/verify_irodori_macos.sh` - Irodori-TTSビルド成果物の検証(mac)
 - `scripts/build_lame_macos.sh` - LAMEビルド(mac)
 - `fvm flutter build macos` - 本番ビルド(mac)
 - `scripts/build_tts_windows.bat` - TTSエンジンビルド(windows)
 - `scripts/build_lame_windows.bat` - LAMEビルド(windows)
 - `fvm flutter build windows` - 本番ビルド(windows)
 - `fvm flutter test` - テスト実行
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
- [ ] X.3 `fvm flutter analyze`でリントを実行
- [ ] X.4 `fvm flutter test`でテストを実行
```
