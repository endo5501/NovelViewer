## 1. 準備・調査

- [x] 1.1 `text_content_renderer.dart` の `_pageScroll` / エッジフラグ（`_atScrollTop` / `_atScrollBottom`）/ `Stack` 内のボタン描画箇所を再確認し、フック地点を特定する
- [x] 1.2 `adjacentFilesProvider` と `episodeNavigationControllerProvider`（`navigateToNext` / `navigateToPrevious`）の呼び出し方を確認する
- [x] 1.3 `EpisodeNavigationButtons` の他参照（横書きビューア以外での使用有無）を grep で確認し、削除可否を判断する

## 2. テスト作成（失敗を確認 → コミット）

- [x] 2.1 カーソルキー境界ナビのウィジェットテストを追加：末尾で下キー→次話遷移（`navigateToNext` 呼び出し）、先頭で上キー→前話遷移（`navigateToPrevious` 呼び出し）
- [x] 2.2 ホイール境界ナビのウィジェットテストを追加：末尾で下方向ホイール→次話、先頭で上方向ホイール→前話
- [x] 2.3 中間位置では話送りせずファイル内スクロールのみ、を検証するテストを追加
- [x] 2.4 隣接ファイルが無い方向の境界操作が no-op になるテストを追加（最初／最後のファイル）
- [x] 2.5 暴発防止クールダウンのテストを追加：ホイール連打／キーリピートで 1 話のみ遷移、クールダウン明け後は再遷移可能
- [x] 2.6 短い（1 画面 / `maxScrollExtent == 0`）エピソードへ遷移後、クールダウン中は連続暴走しないテストを追加
- [x] 2.7 フォーカスがファイルブラウザにあるときキー操作で境界遷移しないテストを追加
- [x] 2.8 ボタン撤去に伴う既存テスト（`EpisodeNavigationButtons` 表示/押下系）を削除または境界ナビ用に置換
- [x] 2.9 `fvm flutter test` を実行し、新規テストが期待どおり失敗することを確認してコミット

## 3. 実装（テストをパスさせる）

- [ ] 3.1 境界遷移の共通ハンドラを追加（方向を受け取り、エッジフラグ＋`adjacentFilesProvider` を確認して `navigateToNext` / `navigateToPrevious` を呼ぶ。隣接無しは no-op）
- [ ] 3.2 暴発防止クールダウン（Timer ベースのフラグ）を追加し、共通ハンドラの先頭でガードする
- [ ] 3.3 カーソルキー経路：`_pageScroll` のクランプ地点（`target == position.pixels`）で early return せず、境界方向に応じて共通ハンドラへルーティングする
- [ ] 3.4 ホイール経路：`SingleChildScrollView` を `Listener` でラップし、`onPointerSignal` の `PointerScrollEvent` をエッジフラグで条件分岐して共通ハンドラへ渡す（境界以外はネイティブスクロールに委ねる）
- [ ] 3.5 横書きビューアの `Stack` から `EpisodeNavigationButtons` を撤去し、表示制御（`showEdgeButtons` 等）に伴う不要コードを除去する
- [ ] 3.6 参照が無くなった `episode_navigation_buttons.dart` を削除（他参照があれば残置し未使用化のみ）
- [ ] 3.7 TTS オートスクロール経路（`_isTtsScrolling`）から境界遷移が発火しないこと（ユーザ入力起点限定）を実装上担保する
- [ ] 3.8 `fvm flutter test` を実行し、2 章のテストが全てパスすることを確認してコミット

## 4. 仕上げ・整合

- [ ] 4.1 前話遷移後の末尾開始スクロール（`fromEnd` → `_jumpToEndPending`）が境界ナビ経由でも機能することを手動／テストで確認
- [ ] 4.2 関連コメント・ドキュメント（`TextViewerPanel` / `TextContentRenderer` のクラスコメント中のボタン言及）を更新する

## 5. 最終確認

- [ ] 5.1 code-reviewスキルを使用してコードレビューを実施
- [ ] 5.2 codexスキルを使用して現在開発中のコードレビューを実施
- [ ] 5.3 `fvm flutter analyze`でリントを実行
- [ ] 5.4 `fvm flutter test`でテストを実行
