## 1. セグメント行ウィジェットの切り出し（挙動不変）

- [x] 1.1 `lib/features/tts/presentation/tts_edit_segment_row.dart` を新規作成し、`tts_edit_dialog.dart:452-699` の `_TtsEditSegmentRow` / `_TtsEditSegmentRowState` を `TtsEditSegmentRow` / `TtsEditSegmentRowState` として移動する（ロジックは一切変更しない）
- [x] 1.2 `tts_edit_dialog.dart` から移動元のクラス定義を削除し、新ファイルを import してビルダー内の参照を `TtsEditSegmentRow` に置き換える
- [x] 1.3 `fvm flutter analyze` と `fvm flutter test` を実行し、切り出し前と同じくグリーンであることを確認する
- [x] 1.4 切り出しのみをコミットする（レイアウト変更は含めない）

## 2. ダイアログ幅算出のTDD

- [x] 2.1 `test/features/tts/presentation/tts_edit_dialog_test.dart` を新規作成し、幅算出関数の境界値テストを書く（ウィンドウ幅 3440 → 1400、1720 → 1400、1200 → 1032、900 → 762）
- [x] 2.2 テストを実行し、関数が未実装であることによる失敗を確認する
- [x] 2.3 失敗するテストをコミットする
- [x] 2.4 `tts_edit_dialog.dart` に top-level 関数 `ttsEditDialogContentWidth(double windowWidth)` を実装する（`min(1400, windowWidth * 0.9 - 48)`。定数 48 が `AlertDialog` のデフォルト `contentPadding` 左右合計である旨をコメントで残す）
- [x] 2.5 テストが通ることを確認する

## 3. セグメント行レイアウトのTDD

- [x] 3.1 `test/features/tts/presentation/tts_edit_segment_row_test.dart` を新規作成し、以下を検証するウィジェットテストを書く
  - 本文欄とメモ欄がともに可変幅で、幅比が本文 5 : メモ 2 であること
  - 利用可能幅を増やすと本文欄・メモ欄の幅がいずれも増加すること
  - 利用可能幅を減らしたときメモ欄が下限で止まらずに縮むこと
  - メモ欄が1行に収まらない入力で2行に折り返すこと
  - メモが空の行ではメモ欄の高さが1行分のままであること
- [x] 3.2 テストを実行し、現在の実装（メモ `SizedBox(width: 100)` / `maxLines` 未指定 / 本文 `flex: 4`）では失敗することを確認する
- [x] 3.3 失敗するテストをコミットする
- [ ] 3.4 `tts_edit_segment_row.dart` を修正する
  - 本文 `Expanded(flex: 4)` → `Expanded(flex: 5)`
  - メモ `SizedBox(width: 100)` → `Expanded(flex: 2)`
  - メモの `TextField` に `maxLines: 2` を追加
- [ ] 3.5 テストが通ることを確認する

## 4. ダイアログへの適用

- [ ] 4.1 `tts_edit_dialog.dart:331` の `SizedBox(width: 800, height: 600)` を `width: ttsEditDialogContentWidth(MediaQuery.sizeOf(context).width)` に変更する（高さは 600 のまま据え置く）
- [ ] 4.2 `fvm flutter run` でアプリを起動し、読み上げ編集ダイアログを開いて次を目視確認する
  - 通常のウィンドウ幅でダイアログが従来より広く表示されること
  - メモ欄に30文字程度のキャプションを入力して全文が読めること
  - ウィンドウを狭くしてもダイアログが画面外にはみ出さないこと
- [ ] 4.3 レイアウト変更をコミットする

## 5. 最終確認

- [ ] 5.1 code-reviewスキルを使用してコードレビューを実施
- [ ] 5.2 codexスキルを使用して現在開発中のコードレビューを実施
- [ ] 5.3 `fvm flutter analyze`でリントを実行
- [ ] 5.4 `fvm flutter test`でテストを実行
