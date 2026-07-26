## 1. セグメント行ウィジェットの切り出し（挙動不変）

- [x] 1.1 `lib/features/tts/presentation/tts_edit_segment_row.dart` を新規作成し、`tts_edit_dialog.dart:452-699` の `_TtsEditSegmentRow` / `_TtsEditSegmentRowState` を `TtsEditSegmentRow` / `TtsEditSegmentRowState` として移動する（ロジックは一切変更しない）
- [x] 1.2 `tts_edit_dialog.dart` から移動元のクラス定義を削除し、新ファイルを import してビルダー内の参照を `TtsEditSegmentRow` に置き換える
- [x] 1.3 `fvm flutter analyze` と `fvm flutter test` を実行し、切り出し前と同じくグリーンであることを確認する
- [x] 1.4 切り出しのみをコミットする（レイアウト変更は含めない）

## 2. ダイアログ幅算出のTDD（レビューを受けて撤回）

当初は `ttsEditDialogContentWidth(windowWidth) = min(1400, windowWidth * 0.9 - 48)` をTDDで実装した（2.1〜2.5 は一度完了）。しかし最終確認のコードレビューで前提の誤りが判明し、撤回した。

`AlertDialog` は `insetPadding`（左右40px）で既にウィンドウ内に収まり、content の `SizedBox` は親の制約でクランプされる。実測（window 700/900/1200/1720/3440）でオーバーフローが起きないことを確認済み。式が生む差は最大40pxにすぎず、`MediaQuery` 購読・公開関数・`AlertDialog` の内部デフォルトへの依存に見合わなかった。

- [x] 2.1 幅算出を `_kTtsEditDialogMaxContentWidth = 1400` の定数のみに簡素化し、`ttsEditDialogContentWidth` と `test/features/tts/presentation/tts_edit_dialog_test.dart` を削除する
- [x] 2.2 design.md D1 / D6、spec、proposal を実装に合わせて訂正する

## 3. セグメント行レイアウトのTDD

- [x] 3.1 `test/features/tts/presentation/tts_edit_segment_row_test.dart` を新規作成し、以下を検証するウィジェットテストを書く
  - 本文欄とメモ欄がともに可変幅で、幅比が本文 5 : メモ 2 であること
  - 利用可能幅を増やすと本文欄・メモ欄の幅がいずれも増加すること
  - 利用可能幅を減らしたときメモ欄が下限で止まらずに縮むこと
  - メモ欄が1行に収まらない入力で2行に折り返すこと
  - メモが空の行ではメモ欄の高さが1行分のままであること
- [x] 3.2 テストを実行し、現在の実装（メモ `SizedBox(width: 100)` / `maxLines` 未指定 / 本文 `flex: 4`）では失敗することを確認する
- [x] 3.3 失敗するテストをコミットする
- [x] 3.4 `tts_edit_segment_row.dart` を修正する
  - 本文 `Expanded(flex: 4)` → `Expanded(flex: 5)`
  - メモ `SizedBox(width: 100)` → `Expanded(flex: 2)`
  - メモの `TextField` に `minLines: 1` と `maxLines: 2` を追加（`maxLines` 単独では高さが2行で固定されるため `minLines` が必須）
- [x] 3.5 テストが通ることを確認する

## 4. ダイアログへの適用

- [x] 4.1 `tts_edit_dialog.dart:331` の `SizedBox(width: 800, height: 600)` を `width: _kTtsEditDialogMaxContentWidth`（=1400）に変更する（高さは 600 のまま据え置く）
- [x] 4.2 アプリを起動し、読み上げ編集ダイアログを開いて次を目視確認する（**ユーザ確認済み: 問題なし**）
  - 通常のウィンドウ幅でダイアログが従来より広く表示されること
  - メモ欄に30文字程度のキャプションを入力して全文が読めること
  - ウィンドウを狭くしてもダイアログが画面外にはみ出さないこと

  実施済み: `fvm flutter build windows --debug` でビルドが通り、起動してウィンドウが立ち上がることを確認。加えてプロダクションの行ウィジェットを実寸で描画し、ウィンドウ幅1720→content 1400（本文777px / メモ311px、20文字が1行に収まる）、ウィンドウ幅1100→content 942（メモ180px、24文字が2行に折り返し、空メモの行は1行のまま）を実測。ダイアログを開くまでのクリック操作は自動化できないため、実画面での最終確認はユーザに委ねる
- [x] 4.3 レイアウト変更をコミットする

## 5. 最終確認

- [x] 5.1 code-reviewスキルを使用してコードレビューを実施
- [x] 5.2 codexスキルを使用して現在開発中のコードレビューを実施
  - 指摘反映: メモ欄の複数行化により Enter が改行になり `onSubmitted` が発火しなくなる回帰を検出。`textInputAction: TextInputAction.done` を指定して既存要件「Enter でメモを永続化」を維持し、リグレッションテストを追加
  - 指摘反映: 公開ウィジェット `TtsEditSegmentRow` に有限幅の親を要する旨の doc コメントを追加
  - 見送り: ダイアログ幅1400のクランプを検証する統合テスト（D1の通りフレームワーク挙動であり実測済み。`TtsEditDialog` は pump できないため統合テストは書けない）
- [x] 5.3 `fvm flutter analyze`でリントを実行
- [x] 5.4 `fvm flutter test`でテストを実行
