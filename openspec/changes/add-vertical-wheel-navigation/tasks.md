## 1. テスト作成（TDD: Red phase）

- [ ] 1.1 `test/features/text_viewer/presentation/vertical_text_viewer_wheel_test.dart` を作成し、ホイール下スクロールで次ページに遷移するテストを記述
- [ ] 1.2 ホイール上スクロールで前ページに遷移するテストを記述
- [ ] 1.3 最終ページでホイール下スクロールしてもページが変わらないテストを記述
- [ ] 1.4 最初のページでホイール上スクロールしてもページが変わらないテストを記述
- [ ] 1.5 アニメーション中のホイールイベントが無視されるテストを記述
- [ ] 1.6 `PointerScrollEvent` 以外のポインタシグナルイベントが無視されるテストを記述
- [ ] 1.7 テストを実行し、すべて失敗することを確認（Red）

## 2. 実装（TDD: Green phase）

- [ ] 2.1 `vertical_text_viewer.dart` の `_VerticalTextViewerState` に `_handlePointerSignal(PointerSignalEvent event)` メソッドを追加
- [ ] 2.2 `_handlePointerSignal` 内で `PointerScrollEvent` 以外のイベントを早期リターンで無視する処理を実装
- [ ] 2.3 `_animationController.isAnimating` チェックによるアニメーション中ガードを実装
- [ ] 2.4 `scrollDelta.dy` の正負に基づいて `_nextPage()` / `_previousPage()` を呼び出す方向マッピングを実装
- [ ] 2.5 `Listener` ウィジェットの `onPointerSignal` に `_handlePointerSignal` を接続
- [ ] 2.6 テストを実行し、すべて通過することを確認（Green）

## 3. 最終確認

- [ ] 3.1 code-simplifierエージェントを使用してコードをよりシンプルにできないか確認
- [ ] 3.2 codexスキルを使用して現在開発中のコードレビューを実施
- [ ] 3.3 `fvm flutter analyze`でリントを実行
- [ ] 3.4 `fvm flutter test`でテストを実行
