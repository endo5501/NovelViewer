# Tasks

## 1. ヘルパのテスト作成 (TDD: RED)

- [x] 1.1 `test/shared/utils/temp_directory_utils_test.dart` を作成。`setUp`/`tearDown` で `Directory.systemTemp.createTemp()` による隔離領域を確保
- [x] 1.2 「ディレクトリ不存在」シナリオ: `provider` に不存在パスを渡し、呼び出し後 `exists()` が `true` を検証
- [x] 1.3 「既存ディレクトリ」シナリオ: 事前に `create()` したパスを渡し、エラーなく返ることを検証
- [x] 1.4 「ネストした親が不存在」シナリオ: `a/b/c` のネストパスを渡し、中間階層も含めて作成されることを検証
- [x] 1.5 `fvm flutter test test/shared/utils/temp_directory_utils_test.dart` でコンパイルエラー（実装未作成）を確認 (RED)

## 2. ヘルパの実装 (TDD: GREEN)

- [x] 2.1 `lib/shared/utils/temp_directory_utils.dart` を作成。`ensureTemporaryDirectory({Future<Directory> Function() provider = getTemporaryDirectory})` を実装
- [x] 2.2 `provider()` を `await` した後、`create(recursive: true)` を呼び、その `Directory` を返す
- [x] 2.3 bundle-id サブフォルダが生成されない `path_provider` の挙動について、WHY を 1〜2 行のdoc commentで明記
- [x] 2.4 `fvm flutter test test/shared/utils/temp_directory_utils_test.dart` で3シナリオ全て通過を確認 (GREEN)

## 3. 呼び出し箇所の置換

- [x] 3.1 `lib/features/text_viewer/presentation/text_viewer_panel.dart` の `final tempDir = await getTemporaryDirectory();` を `ensureTemporaryDirectory()` に置換し、import 追加
- [x] 3.2 `lib/features/tts/presentation/tts_edit_dialog.dart` の `final tempDir = await getTemporaryDirectory();` を `ensureTemporaryDirectory()` に置換し、import 調整
- [x] 3.3 `lib/features/tts/presentation/voice_recording_dialog.dart` の `final tempDir = await getTemporaryDirectory();` を `ensureTemporaryDirectory()` に置換し、import 調整

## 4. 診断コードの撤去

- [x] 4.1 `text_viewer_panel.dart` の `catch (e, st) { debugPrint('[TTS][_startStreaming] error: ...'); ... }` を元の `catch (_) { ... }` に戻す（本change開始前に調査用として入れたもの。エラー可視化は別changeで扱う）

## 5. 手動動作確認

- [x] 5.1 サンドボックスの `Library/Caches/com.endo5501.novelViewer/` を削除して再現環境を作る（`rm -rf /Users/endo5501/Library/Containers/com.endo5501.novelViewer/Data/Library/Caches/com.endo5501.novelViewer` ※ユーザーに実施依頼）
- [x] 5.2 アプリをビルドして起動し、既存の音声で ▶ 再生が動作することを確認
- [x] 5.3 編集ダイアログを開いて、セグメント単位の ▶ が動作することを確認
- [x] 5.4 音声録音ダイアログを開いて、録音開始〜停止が動作することを確認

## 6. 最終確認

- [x] 6.1 simplifyスキルを使用してコードレビューを実施（docstring短縮、test 3のsetup-stateアサート削除）
- [x] 6.2 codexスキルを使用して現在開発中のコードレビューを実施（design.md mitigation記述を実装に合わせて修正、provider例外伝播テスト追加）
- [x] 6.3 `fvm flutter analyze`でリントを実行
- [x] 6.4 `fvm flutter test`でテストを実行
