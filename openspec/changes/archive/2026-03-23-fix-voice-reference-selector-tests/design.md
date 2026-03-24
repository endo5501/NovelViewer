## Context

`voice_reference_selector_test.dart` は `SettingsDialog` 全体をレンダリングし、TTSタブに遷移してVoice Reference Selectorをテストしている。piper-plus TTSエンジン追加でTTSタブにエンジン選択UI等が追加され、Voice Reference Selectorが `AlertDialog(height: 500)` 内の `SingleChildScrollView` の下部に押し出された。テストの `physicalSize(1200, 900)` ではこのウィジェットが画面外となり、`tap()` が正しくヒットしない。

## Goals / Non-Goals

**Goals:**
- 8件の失敗テストをすべてグリーンにする
- UIレイアウト変更に対してより堅牢なテストにする
- 非同期ファイル読み込みのタイミング問題を解消する

**Non-Goals:**
- 実装コード（`settings_dialog.dart` 等）の変更
- テストカバレッジの追加
- テスト構造の大幅なリファクタリング

## Decisions

### 1. `ensureVisible` でスクロールしてからインタラクション

Voice Reference Selectorの `DropdownButtonFormField` や各ボタンにアクセスする前に、`tester.ensureVisible()` でウィジェットを可視領域にスクロールする。

**理由**: `scrollUntilVisible` はスクロール対象の `Scrollable` を指定する必要があり、SettingsDialogの構造（AlertDialog → TabBarView → SingleChildScrollView）では指定が複雑。`ensureVisible` はウィジェット自身の `RenderObject.showOnScreen()` を呼ぶため、ネストされたスクロール構造でもシンプルに動作する。

### 2. `_loadVoiceFiles` の完了を `runAsync` + `pumpAndSettle` で待機

`navigateToTtsTab` 内で `runAsync` を使ってウィジェット構築を行っているが、`_loadVoiceFiles()` の非同期I/Oが完了する前に `pumpAndSettle` が終わる可能性がある。ファイルが存在するテストケースでは、`navigateToTtsTab` 後に追加の `runAsync` + `pumpAndSettle` を入れて非同期ロードの完了を確実にする。

## Risks / Trade-offs

- `ensureVisible` は内部的に `RenderObject.showOnScreen()` を使うため、将来Flutterのバージョンアップで挙動が変わる可能性がある → 標準APIなのでリスクは低い
- テストに `ensureVisible` を追加することでテストコードが若干冗長になる → ヘルパー関数に集約して軽減
