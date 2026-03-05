## Why

NovelViewerは現在UIが日本語のみでハードコードされており、日本語を読めないユーザーは利用できない。英語圏・中国語圏のWeb小説読者にもアプリを提供するため、国際化(i18n)対応を導入する。

## What Changes

- Flutter公式の `flutter_localizations` + `intl` パッケージによるi18nインフラを導入
- 約115個のハードコードされた日本語UI文字列を `.arb` リソースファイルに抽出
- 日本語(ja, デフォルト)、英語(en)、簡体字中国語(zh)の3言語をサポート
- 設定画面の一般タブに言語切り替えUIを追加
- 言語設定をSharedPreferencesに永続化
- 12個のプレゼンテーション層ファイルを `AppLocalizations.of(context)` 呼び出しに置換

## Capabilities

### New Capabilities
- `i18n-infrastructure`: Flutter i18nインフラの構築（l10n.yaml、ARBファイル、コード生成、MaterialAppへの統合）
- `language-settings`: アプリの表示言語を切り替える設定UI（設定画面への統合、SharedPreferencesへの永続化）

### Modified Capabilities
- `text-display-settings`: 設定ダイアログの一般タブに言語選択UIが追加される

## Impact

- **依存パッケージ**: `flutter_localizations` SDK、`intl` パッケージを追加
- **pubspec.yaml**: `generate: true` を追加
- **新規ファイル**: `l10n.yaml`、`lib/l10n/app_ja.arb`、`lib/l10n/app_en.arb`、`lib/l10n/app_zh.arb`
- **変更ファイル**: `lib/app.dart`（MaterialApp設定）、`lib/features/settings/` 配下（言語設定）、プレゼンテーション層12ファイル（文字列置換）
- **ビルド**: `flutter gen-l10n` でDartコードが自動生成される
- **既存機能への影響**: 表示テキストの変更のみ。ロジック層への影響なし。TTS言語設定とは独立
