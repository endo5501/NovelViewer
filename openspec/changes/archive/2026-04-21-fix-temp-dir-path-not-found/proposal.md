## Why

macOSサンドボックス環境では、`path_provider.getTemporaryDirectory()` が返すbundle-idサブフォルダ (`Library/Containers/<bundle>/Data/Library/Caches/<bundle>/`) が存在しないまま返されるケースがある。この状態で `File.writeAsBytes()` を呼ぶと `PathNotFoundException: Cannot open file ... No such file or directory` で失敗する。現在、TTS音声再生（本体ビューア・編集ダイアログ）、音声録音の3経路すべてがこの前提を満たしておらず、ggmlアップグレードより前に生成した既存音声すら再生できない回帰となっている。ユーザーは `ggml v0.9.11` アップグレードを疑ったが、実際は独立した問題である。

## What Changes

- 新規ユーティリティ `ensureTemporaryDirectory()` を `lib/shared/utils/temp_directory_utils.dart` に追加。`getTemporaryDirectory()` 呼び出し後に `create(recursive: true)` で存在保証する
- ユニットテストで「ディレクトリ不存在」「既存」「ネスト」の3シナリオを検証（テスト用プロバイダ注入で `path_provider` の platform channel に依存せず実行可能にする）
- 既存の `getTemporaryDirectory()` 呼び出し3箇所を `ensureTemporaryDirectory()` に置換
  - `lib/features/text_viewer/presentation/text_viewer_panel.dart` (本体再生パス)
  - `lib/features/tts/presentation/tts_edit_dialog.dart` (編集ダイアログ再生)
  - `lib/features/tts/presentation/voice_recording_dialog.dart` (音声録音)
- 診断用 `debugPrint` (`text_viewer_panel.dart` の `catch` 句) を削除し元のコードに戻す

## Capabilities

### New Capabilities

- `temp-directory-provisioning`: アプリ内で `path_provider` 経由の一時ディレクトリに書き込む前に、当該ディレクトリの存在を保証するインフラ要件

### Modified Capabilities

なし（横断的な不変条件として新規capabilityで扱う。既存のTTS/録音各specは書き込み先の存在を前提としていたが、その前提を明文化した既存要件が無かった）

## Impact

**影響コード**:
- 新規: `lib/shared/utils/temp_directory_utils.dart`、`test/shared/utils/temp_directory_utils_test.dart`
- 変更: `lib/features/text_viewer/presentation/text_viewer_panel.dart`、`lib/features/tts/presentation/tts_edit_dialog.dart`、`lib/features/tts/presentation/voice_recording_dialog.dart`

**依存パッケージ**: 既存の `path_provider ^2.1.0`、`path ^1.9.1` を使用。新規追加なし。

**プラットフォーム**: macOSで確認された現象だが、修正自体は全プラットフォーム共通（冪等なディレクトリ作成）。

**リスク**: 低。冪等なIO処理のみ、ロジック変更なし。3箇所の置換はシンボル一対一。
