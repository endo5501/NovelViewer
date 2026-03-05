## 1. i18nインフラ構築

- [x] 1.1 `pubspec.yaml` に `flutter_localizations` (sdk: flutter)、`intl` パッケージを追加し、`flutter` セクションに `generate: true` を追加
- [x] 1.2 プロジェクトルートに `l10n.yaml` を作成（arb-dir: lib/l10n, template-arb-file: app_ja.arb, output-localization-file: app_localizations.dart）
- [x] 1.3 `lib/l10n/app_ja.arb` を作成し、全UIの文字列キーと日本語テキストを定義（プレースホルダ付きキーには `@` メタデータを含む）
- [x] 1.4 `lib/l10n/app_en.arb` を作成し、英語翻訳を記述
- [x] 1.5 `lib/l10n/app_zh.arb` を作成し、簡体字中国語翻訳を記述
- [x] 1.6 `fvm flutter gen-l10n` を実行してコード生成を確認

## 2. MaterialApp統合

- [x] 2.1 `lib/app.dart` の `MaterialApp` に `localizationsDelegates`（AppLocalizations.delegate, GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate）を追加
- [x] 2.2 `MaterialApp` に `supportedLocales`（ja, en, zh）を追加
- [x] 2.3 `MaterialApp` の `locale` プロパティを Riverpod の locale プロバイダにバインド

## 3. 言語設定の永続化とプロバイダ

- [x] 3.1 `SettingsRepository` に `getLocale()` / `setLocale()` メソッドを追加（SharedPreferences の `locale` キーで永続化、デフォルト: `ja`）
- [x] 3.2 `settings_providers.dart` に `localeProvider`（StateNotifierProvider）を追加し、SettingsRepository と連携
- [x] 3.3 locale プロバイダの単体テストを作成・実行

## 4. 設定画面の言語選択UI

- [x] 4.1 `settings_dialog.dart` の一般タブ最上部に言語DropdownButtonを追加（日本語 / English / 中文）
- [x] 4.2 言語選択時に `localeProvider` を更新し、即時反映を確認

## 5. プレゼンテーション層の文字列置換

- [x] 5.1 `settings_dialog.dart` のハードコード文字列を `AppLocalizations.of(context)` に置換
- [x] 5.2 `voice_recording_dialog.dart` のハードコード文字列を置換
- [x] 5.3 `file_browser_panel.dart` のハードコード文字列を置換
- [x] 5.4 `tts_edit_dialog.dart` のハードコード文字列を置換
- [x] 5.5 `text_viewer_panel.dart` のハードコード文字列を置換
- [x] 5.6 `download_dialog.dart` のハードコード文字列を置換
- [x] 5.7 `tts_dictionary_dialog.dart` のハードコード文字列を置換
- [x] 5.8 `llm_summary_panel.dart` のハードコード文字列を置換
- [x] 5.9 `bookmark_list_panel.dart` のハードコード文字列を置換
- [x] 5.10 `search_results_panel.dart` のハードコード文字列を置換
- [x] 5.11 `rename_title_dialog.dart` のハードコード文字列を置換
- [x] 5.12 `home_screen.dart` のハードコード文字列を置換
- [x] 5.13 `search_summary_panel.dart` のハードコード文字列を置換（該当する場合）
- [x] 5.14 `left_column_panel.dart` のハードコード文字列を置換（該当する場合）

## 6. 最終確認

- [x] 6.1 simplifyスキルを使用してコードレビューを実施
- [x] 6.2 codexスキルを使用して現在開発中のコードレビューを実施
- [x] 6.3 `fvm flutter analyze`でリントを実行
- [x] 6.4 `fvm flutter test`でテストを実行
