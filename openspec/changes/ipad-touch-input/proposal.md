## Why

iPad 版はビューアとして完成した（`ios-build-bootstrap` / `platform-capabilities` / `ipad-adaptive-shell`）が、**コンテキストメニューを開く手段が一つも無い**。アプリ内のコンテキストメニューは 4 箇所すべてが `onSecondaryTapUp`（右クリック）でしか開かず、`lib` 全体に `onLongPress` は 1 つも存在しない。

そのため iPad では次の操作に到達できない。

| 到達不能な操作 | 代替手段 |
|---|---|
| 小説の**更新**（再ダウンロード） | **無い** |
| 小説のタイトル変更・フォルダ名変更・移動・削除 | Files アプリ経由で一応可能（更新は不可） |
| ブックマークの削除 | その行へ移動して AppBar のしおりボタンを再押下 |
| 縦書きモードでの選択テキストのコピー | 無い（選択語検索は AppBar の 🔍 で可能） |

とくに「更新」は iPad 上でも実際に行う操作であり、代替経路が存在しない。

## What Changes

- ファイルブラウザの小説／フォルダタイルを**長押し**するとコンテキストメニューが開く。項目・並び・動作は右クリック時と完全に同一。
- ブックマーク一覧の項目を**長押し**するとコンテキストメニューが開く。同上。
- 上記の長押しはポインタ種別で分岐しない。マウスでも長押しでメニューが開く（右クリックは従来どおり）。
- ファイルブラウザのタイトルに付いている `Tooltip` を `TooltipTriggerMode.manual` にする。Flutter の `Tooltip` はタッチ時に自前の `LongPressGestureRecognizer` を arena に登録し、より内側にあるため長押しを横取りしてしまうため。ホバーによるツールチップ表示は `MouseRegion` 側の経路なので影響を受けない。
- 縦書きビューアで、**選択範囲の内側を指でタップ**すると選択メニュー（iPad では「コピー」1 項目）が開く。範囲の外をタップした場合は従来どおり選択解除。
- 縦書きのタップ分岐は `TapUpDetails.kind == PointerDeviceKind.touch` のときのみ有効にする。タップには「選択解除」という既存の意味があるため、マウス操作の挙動は変更しない。
- 縦書きビューアの `GestureDetector` の recognizer 構成は変更しない。ドラッグによる範囲選択とスワイプによるページ送りの調停には一切手を入れない。

**BREAKING なし。** 既存の右クリック経路・キーボード経路はすべて維持される。

## Capabilities

### New Capabilities

- `touch-context-menu-trigger`: マウスの副ボタンを持たない環境からコンテキストメニューへ到達する手段。リスト項目の長押し、縦書き選択範囲内のタップ、ポインタ種別による分岐の方針、および長押しが他の recognizer に横取りされないことを定める。

### Modified Capabilities

- `novel-delete`: 小説フォルダのコンテキストメニューを開く操作に長押しを加える（`Context menu on novel folder`）。
- `bookmark-ui`: ブックマーク項目のコンテキストメニューを開く操作に長押しを加える（`Delete bookmark from list`）。
- `file-browser`: フルネームのホバーツールチップに「タッチの長押しでは表示されない」制約を加える（`フルネームのホバーツールチップ`）。
- `vertical-text-selection`: コンテキストメニューを開く操作に選択範囲内のタップを加え、「タップは選択を解除する」シナリオをタップ位置とポインタ種別で条件付ける（`縦書き表示のコンテキストメニュー` / `Vertical text selection by drag`）。

## Impact

コード:

- `lib/features/file_browser/presentation/file_browser_panel.dart` — `_buildDirectoryTile` の `GestureDetector` に `onLongPressStart`、タイトルの `Tooltip` に `triggerMode`
- `lib/features/bookmark/presentation/bookmark_list_panel.dart` — 項目の `GestureDetector` に `onLongPressStart`
- `lib/features/text_viewer/presentation/vertical_text_page.dart` — `onTap` を `onTapUp` に差し替え、既存の `_hitTest` / `_isInSelection` / `_onSecondaryTapUp` の本体を再利用

対象外:

- 解析済み語のホバーポップアップ（`llm-summary-hover-popup`）はタッチで到達できないままとする。LLM 機能全体の検討時にまとめて扱う。
- 横書きモードは `SelectableText.rich` が Flutter 標準の長押しツールバーを提供しているため変更不要。

依存関係の追加なし。プラットフォーム判定（`dart:io` の `Platform`）の追加なし。
