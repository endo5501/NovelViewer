## 1. 失敗するテストを先に用意する（TDD）

- [x] 1.1 `test/features/text_viewer/presentation/vertical_swipe_hit_area_test.dart` を新規作成し、内容が短くて最終ページの左側に余白ができるドキュメントを縦書きビューアに表示するテストハーネスを用意する
- [x] 1.2 最終ページの「文字が描画されていない左側の領域」を起点に右スワイプ（次ページ相当）してもページが変わらないことを検証するテストを書き、**失敗すること**を確認する
- [x] 1.3 同じく余白を起点に左スワイプ（前ページ相当）でページが戻ることを検証するテストを追加し、失敗を確認する
- [x] 1.4 `VerticalTextPage` のレンダーボックスが、テキストの描画幅ではなく与えられた領域全面を占めることを検証するテストを追加し、失敗を確認する
- [x] 1.5 余白から始めた縦ドラッグで選択が開始されないこと、および余白タップで選択が解除されることを検証するテストを追加する（変更前は余白にイベントが届かないため、変更後の挙動を固定する回帰テストとして書く）
- [x] 1.6 ここまでのテストをコミットする（実装コードは含めない）

## 2. 当たり判定の拡張を実装する

- [x] 2.1 `lib/features/text_viewer/presentation/vertical_text_page.dart` の `build` で、`GestureDetector` の子として `Align(alignment: Alignment.topRight)` を追加し、`Directionality` > `Wrap` をその内側へ移す
- [x] 2.2 `lib/features/text_viewer/presentation/vertical_text_viewer.dart` の `incomingPage` から `Align(alignment: Alignment.topRight)` を除去する
- [x] 2.3 同ファイルのアニメーション用 outgoing ページ（`SlideTransition` の子）からも `Align(alignment: Alignment.topRight)` を除去する
- [x] 2.4 1 章のテストが全て通ることを確認する

## 3. 既存挙動の回帰確認

- [x] 3.1 `fvm flutter test test/features/text_viewer/` を実行し、縦書き関連テストの回帰を確認する
- [x] 3.2 文字上での選択・ホバー・コンテキストメニューが従来どおり動くことを、`vertical_selection_offset_test.dart` / `vertical_text_page_hover_test.dart` / `vertical_text_viewer_hover_test.dart` の通過で確認する
- [x] 3.3 `vertical_text_viewer_animation_test.dart` を実行し、ページ遷移アニメーションに回帰がないことを確認する
- [x] 3.4 ページ矩形サイズに依存して失敗するテストがあれば、意図した変更であることを確認したうえで期待値を更新する（テストの意図自体は変えない）
- [x] 3.5 macOS で実アプリを起動し、最終ページ左側の余白からのスワイプでページ送り・次話遷移が動作することを目視確認する

## 4. 最終確認

- [x] 4.1 code-reviewスキルを使用してコードレビューを実施
- [x] 4.2 codexスキルを使用して現在開発中のコードレビューを実施
- [x] 4.3 `fvm dart format .`でフォーマットを実行
- [x] 4.4 `fvm flutter analyze`でリントを実行
- [x] 4.5 `fvm flutter test`でテストを実行

## 5. スワイプによる選択解除の通知漏れを直す

- [x] 5.1 スワイプで選択が解除されたとき `onSelectionChanged(null)` が通知されることを検証するテストを `vertical_swipe_hit_area_test.dart` に追加し、**失敗すること**を確認する
- [x] 5.2 `_handleSwipeEnd` で、内部の選択状態を消したときに `onSelectionChanged(null)` を通知するよう修正する
- [x] 5.3 5.1 のテストが通ることを確認する
- [x] 5.4 `fvm flutter test test/features/text_viewer/` で回帰がないことを確認する

## 5b. 再レビュー指摘への対応

- [x] 5b.1 スワイプ時の解除通知を、実際に見えている選択（`_effectiveStart`/`_effectiveEnd`）が消えた場合だけに限定する
- [x] 5b.2 ページのサイズが変わったときに文字のヒット領域を作り直す（今回の変更で文字位置がページ幅依存になったため）
- [x] 5b.3 5b.1 / 5b.2 の失敗するテストを先に追加し、RED→GREEN を確認する
- [x] 5b.4 余白起点ドラッグの要件文を実装の挙動（anchor は pan 受理位置で解決）に合わせて修正する
- [x] 5b.5 リサイズ回帰テストが偽陽性だった件を修正（リサイズ前に選択を作らない形へ。ガードを外すと RED になることを実測で確認）
- [x] 5b.6 「owner 提供の選択がある間は通知しない」という再レビュー指摘は既存仕様（タップ・スワイプは *any active* な選択を解除する）と矛盾するため撤回し、通知条件を `_effectiveStart`/`_effectiveEnd` 基準に統一する

## 5c. 選択の起点を指を置いた位置にする

- [x] 5c.1 文字の中心からドラッグを始めたとき、その文字から選択が始まることを検証するテストを追加し、**失敗すること**を確認する
- [x] 5c.2 `_onPanDown` でポインタが降りたローカル座標を保持し、`_onPanStart` の anchor 解決にそれを使う
- [x] 5c.3 5c.1 のテストが通ることを確認する
- [x] 5c.4 余白起点ドラッグの要件文を「指を置いた位置で anchor を解決する」に更新する（5b.4 で緩めた記述を厳密化し直す）
- [x] 5c.5 `fvm flutter test` で回帰がないことを確認する
- [x] 5c.6 pan 受理時の move が選択範囲に反映されない件（down→1回 move→up で1文字しか選択されない）のテストを追加し RED を確認する
- [x] 5c.7 `_onPanStart` で selecting に決まった際、受理位置まで選択範囲を広げる
- [x] 5c.8 5c.6 のテストと全テストが通ることを確認する

## 6. 最終確認（再実行）

- [ ] 6.1 code-reviewスキルを使用してコードレビューを実施
- [ ] 6.2 codexスキルを使用して現在開発中のコードレビューを実施
- [x] 6.3 `fvm dart format .`でフォーマットを実行
- [x] 6.4 `fvm flutter analyze`でリントを実行
- [x] 6.5 `fvm flutter test`でテストを実行
