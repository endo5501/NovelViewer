# Tasks

## 1. 狭い幅の縦並びフォーム（TDD）

- [x] 1.1 `tts_dictionary_dialog_test.dart` に次のテストを追加する。(a) 393×852 で「読み」欄の上端が「表記」欄の下端以上にあり、両方の欄が hit-testable。(b) 393×852 で表記を入力し「読み上げしない」にチェックして追加すると、読みなしエントリが一覧に出る。(c) 800×600 で表記欄・読み欄・チェックボックス・追加ボタンの縦方向の中心がそろう。`fvm flutter test test/features/tts/presentation/tts_dictionary_dialog_test.dart` で (a) が失敗し、(b)(c) と既存テストが通ることを確かめてからコミットする
- [x] 1.2 `tts_dictionary_dialog.dart` の追加フォームを `LayoutBuilder` で切り替える。判定は `_kSingleLineFormMinWidth = 400` 以上（`>=`）なら従来の1行、未満なら表記・読み・チェックボックスと追加ボタンの3行。1.1 のテストを変えずに、同ファイルの全テストが通ることを確認する

## 2. キーボード表示中のオーバーフロー対策（TDD）

- [x] 2.1 `FakeViewPadding(bottom: 336 × devicePixelRatio)` で viewInsets を与えるテストを追加する。393×852 と 375×667 の両方で、エントリなしとエントリ多数（例: 30件）のそれぞれについて `tester.takeException()` が null で、表記欄と読み欄に到達できる（必要なら `ensureVisible` 後に hit-testable）ことを確かめる。失敗を確認してコミットする
- [x] 2.2 狭い幅の内容を `CustomScrollView` に置き換える。フォームとエラー文は `SliverToBoxAdapter`、エントリは `SliverList`、空の案内文は `SliverFillRemaining(hasScrollBody: false)` に入れる。広い幅は従来の `Column` と `Expanded` の一覧のままにする。2.1 と 1.1 のテストが通ることを確認する

## 3. ブレークポイントをまたぐ状態の引き継ぎ（TDD）

- [x] 3.1 800×600 で表記欄と読み欄に入力し、表記欄にフォーカスしたまま surface size を 393×852 に変えるテストを追加する。入力内容が残っていることと、表記欄がフォーカスを保っていることを確かめる。フォーカスの確認が失敗することを確かめてコミットする
- [x] 3.2 表記欄・読み欄・チェックボックスに `GlobalKey` を付け、1行と3行の両方の木で使う。切り替えのきっかけが回転とウィンドウのリサイズであることをコメントに書き、3.1 のテストが通ることを確認する

## 4. 実機確認

- [ ] 4.1 `scripts/install_ios.sh --backup` で iPhone に入れ、辞書ダイアログでキーボードの表示ありとなしの両方について、表記と読みの入力内容が読めること、オーバーフロー表示がないこと、追加と削除ができることを確認する。macOS 版でダイアログの見た目が従来の1行のままであることも確認する

## 5. 最終確認

- [x] 5.1 code-reviewスキルを使用してコードレビューを実施
- [x] 5.2 codexスキルを使用して現在開発中のコードレビューを実施
- [x] 5.3 `fvm dart format lib test`でフォーマットを実行
- [x] 5.4 `fvm flutter analyze`でリントを実行
- [x] 5.5 `fvm flutter test`でテストを実行
