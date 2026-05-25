## 1. episode-navigation capability の土台

- [x] 1.1 `lib/features/episode_navigation/domain/file_entry_start_intent.dart` を作成し、列挙型 `FileEntryStartIntent { fromStart, fromEnd }` を定義する
- [x] 1.2 `test/features/episode_navigation/providers/adjacent_files_provider_test.dart` を作成し、隣接ファイル導出の全 Scenario（中間／先頭／末尾／単独／未選択／一覧外）を Riverpod `ProviderContainer` で TDD で先に書く
- [x] 1.3 `lib/features/episode_navigation/providers/adjacent_files_provider.dart` を実装し、`AdjacentFiles { next, prev }` 形式の不変オブジェクトと `Provider<AdjacentFiles>` を提供する（テストをグリーンにする）
- [x] 1.4 `test/features/episode_navigation/providers/pending_file_entry_intent_provider_test.dart` を作成し、初期値・set・clear・上書きの Scenario を TDD で先に書く
- [x] 1.5 `lib/features/episode_navigation/providers/pending_file_entry_intent_provider.dart` を実装し、`NotifierProvider<..., FileEntryStartIntent?>` を提供する（テストをグリーンにする）
- [x] 1.6 `test/features/episode_navigation/providers/episode_navigation_controller_test.dart` を作成し、「次話遷移操作で intent が `fromStart` にセットされてから `selectedFileProvider` が切り替わる」「前話遷移操作で intent が `fromEnd` にセットされる」「隣接ファイルが無いとき no-op」の Scenario を TDD で先に書く
- [x] 1.7 `lib/features/episode_navigation/providers/episode_navigation_controller.dart` を実装し、`navigateToNextEpisode()` / `navigateToPreviousEpisode()` を提供する（intent セット → selectedFile 更新の順序を担保）

## 2. AppBar タイトル拡張 (app-title-display)

- [x] 2.1 `test/app/selected_file_progress_title_provider_test.dart` を作成し、`Provider` 単体テストとして「小説フォルダ内 + ファイル選択時の `小説名 — ファイル名 (N/M)` 組み立て」「ファイル未選択時はベース名のみ」「ライブラリルートでは `NovelViewer`」「メタデータ未登録フォルダ」「一覧空のケース」を TDD で先に書く
- [x] 2.2 `lib/features/file_browser/providers/file_browser_providers.dart`（あるいは `lib/app/selected_file_progress_title_provider.dart` 新規ファイル）に `selectedFileProgressTitleProvider` を実装する
- [x] 2.3 `lib/home_screen.dart` の `AppBar(title: Text(...))` を `selectedFileProgressTitleProvider` を watch する形に差し替え、`overflow: TextOverflow.ellipsis`、`maxLines: 1` を指定する
- [x] 2.4 widget test: 「ライブラリルートでは NovelViewer 表示」「ファイル選択時は `N/M` 形式で表示」「タイトル超過時 ellipsis 表示」を確認する

## 3. ファイル一覧の選択ハイライト強化 + 自動スクロール (file-browser)

- [x] 3.1 widget test: ファイル選択時の `ListTile` 装飾が「secondaryContainer 背景 + primary 4px 左ボーダー + bold タイトル」になることを TDD で先に書く
- [x] 3.2 `lib/features/file_browser/presentation/file_browser_panel.dart` の `_buildFileList` を修正し、選択中ファイルの `ListTile` を `Container(decoration: BoxDecoration(color, border))` でラップして装飾を適用、`title` の `TextStyle.fontWeight` を `w600` にする
- [x] 3.3 ダークモード／ライトモード双方の widget test を追加し、装飾色が `colorScheme` から正しく解決されることを確認する
- [x] 3.4 自動スクロールの widget test を作成：「200 行ある一覧で 150 番目を選択 → 150 番目が viewport に入る」「同一ファイル再選択は no-op」を TDD で先に書く（GlobalKey ベースは ListView 遅延ビルドと噛み合わなかったため、設計を `itemExtent` + index ベース ScrollController.animateTo に変更）
- [x] 3.5 `FileBrowserPanel` を `ConsumerStatefulWidget` 化し、`ScrollController` を保持する（GlobalKey マップは廃止：`itemExtent` 固定で index→offset を算出するため不要）
- [x] 3.6 `initState` で `ref.listenManual(selectedFileProvider, ...)` を設定し、選択変化時に index ベースで targetOffset を計算 → `ScrollController.animateTo(..., duration: 250ms, curve: Curves.easeInOut)` を post-frame で呼ぶ
- [x] 3.7 同一ファイル再選択／未選択遷移／一覧外ファイル指定のガードを実装する

## 4. 縦書きモード: 2 段階確認による次話/前話遷移 (vertical-text-display)

- [x] 4.1 i18n キー追加: `lib/l10n/app_en.arb` / `app_ja.arb` / `app_zh.arb` に `verticalText_nextEpisodePrompt(name)`, `verticalText_prevEpisodePrompt(name)` を追加し、`flutter gen-l10n` を実行する
- [x] 4.2 `test/features/text_viewer/presentation/vertical_text_viewer_episode_nav_test.dart` を新設し、Scenario（次：プロンプト表示／確定／タイムアウト／最終話末尾 no-op、前：対称、最初話冒頭 no-op）を TDD で先に書く
- [x] 4.3 `_VerticalTextViewerState` に `_pendingNextFilePrompt` / `_pendingPrevFilePrompt` / `_promptTimeoutTimer` を追加し、定数 `_kFileNavigationPromptTimeout = Duration(seconds: 4)` を定義する
- [x] 4.4 `_changePage(int delta)` を拡張し、最終ページで `delta > 0` の時の 2 段階確認分岐、先頭ページで `delta < 0` の時の対称分岐を実装する（隣接ファイル存在チェックは `adjacentFilesProvider` を参照）
- [x] 4.5 タイマー満了時の prompt クリア、ページ内移動時の prompt クリア、`didUpdateWidget` での segments 変化時の prompt リセット、`dispose` でのタイマー解放を実装する
- [x] 4.6 ページ番号領域の `Text` ウィジェットを差し替え、prompt 状態に応じて「N / M」「▶ 次話「name」へ（もう一度）」「◀ 前話「name」へ（もう一度）」を切替表示する
- [x] 4.7 ファイル遷移確定時は `episode-navigation` の `EpisodeNavigationController.navigateToNext()` / `navigateToPrevious()` を呼ぶ
- [x] 4.8 `VerticalTextViewer` を `ConsumerStatefulWidget` 化し、Riverpod 連携の API 整合を取る

## 5. 縦書きモード: ファイル切替時の初期ページ選択 (vertical-text-display)

- [x] 5.1 widget test を追加：`test/features/text_viewer/presentation/vertical_text_viewer_initial_page_test.dart` で fromStart/fromEnd/null/再消費なし の 4 ケースを TDD で先に書く
- [x] 5.2 `_VerticalTextViewerState.initState`（および `didUpdateWidget` の segments 変化時）で `pendingFileEntryIntentProvider` を 1 度だけ読み取り、`fromEnd` の場合 `_jumpToLastPagePending` フラグを立てる
- [x] 5.3 build 内で `_jumpToLastPagePending && totalPages > 0` を検知して post-frame で `_currentPage = totalPages - 1` を設定するロジックを追加（既存の `_pendingTtsOffset` と同じパターン）
- [x] 5.4 intent 値の読み取り直後に `Future.microtask` 経由で `pendingFileEntryIntentProvider.notifier.clear()` を呼ぶ（Riverpod 3.x はライフサイクル内での mutation を禁止しているため）

## 6. 横書きモード: 次話/前話ボタン + 末尾スクロール (text-viewer)

- [x] 6.1 i18n キー追加: `textViewer_nextEpisodeButton`, `textViewer_prevEpisodeButton` を 3 言語分追加し `flutter gen-l10n` を実行する
- [x] 6.2 widget test を追加：`test/features/text_viewer/presentation/widgets/episode_navigation_buttons_test.dart` で「中間ファイル：両ボタン enabled」「最初／最後ファイル：片方 disabled」「次／前ボタン押下で intent + 選択が更新される」の 5 ケースを TDD で先に書く
- [x] 6.3 `lib/features/text_viewer/presentation/widgets/episode_navigation_buttons.dart` を新設し、`adjacentFilesProvider` を watch する `ConsumerWidget` として「← 前話」「次話 →」を `Row` で並べた `OutlinedButton` バー UI を実装する
- [x] 6.4 `TextViewerPanel` の build 結果に `Positioned(left: 8, bottom: 8, child: EpisodeNavigationButtons())` を追加し、`displayMode == horizontal` の時だけ表示する
- [x] 6.5 各ボタン押下時に `EpisodeNavigationController.navigateToNext()` / `navigateToPrevious()` を呼ぶ
- [x] 6.6 widget test を追加：`test/features/text_viewer/presentation/widgets/text_content_renderer_intent_test.dart` で「fromStart はオフセット 0」「null はオフセット 0」「fromEnd は maxScrollExtent」を TDD で先に書く
- [x] 6.7 `TextContentRenderer._TextContentRendererState` に `_consumeFileEntryIntent` を追加し、initState / didUpdateWidget で読み取り、`fromEnd` 時は build 内 post-frame で `_scrollController.jumpTo(maxScrollExtent)` を実行（intent クリアは `Future.microtask` 経由）

## 7. 統合確認と既存テストへの影響回避

- [x] 7.1 既存 `vertical_text_viewer_*` テスト群を `ProviderScope` でラップし、ConsumerStatefulWidget 化への追従を完了する（境界 Scenario はファイルが存在しない条件のままで意味的に整合）
- [x] 7.2 既存の `file_browser_panel_test.dart` は `selected: true` の汎用 assertion を保持しつつ、新スタイル（secondaryContainer / accent bar / bold）を追加検証する
- [x] 7.3 既存の `home_screen_test.dart` AppBar タイトルテストを、`selectedFileProgressTitleProvider` のオーバーライドで `(N/M)` 形式・ellipsis を追加検証する
- [x] 7.4 統合シナリオ手動確認: 200 話のサンプル小説で「ファイル選択 → AppBar とハイライトが追従」「最終ページ 2 回送り → 次話」「先頭ページ 2 回戻し → 前話の末尾」「横書きボタン → 次/前話遷移」「最終話・最初話の端では何も起きない」を順に確認する（実機確認 — ユーザー実行）
- [x] 7.5 ダークモード手動確認: テーマをダークに切替えて 3.1〜3.3 と 4.6 の視認性を実機で確認する（実機確認 — ユーザー実行）

## 8. 最終確認

- [x] 8.1 code-review スキルを使用してコードレビューを実施
- [x] 8.2 codex スキルを使用して現在開発中のコードレビューを実施
- [x] 8.3 `fvm flutter analyze` でリントを実行
- [x] 8.4 `fvm flutter test` でテストを実行
