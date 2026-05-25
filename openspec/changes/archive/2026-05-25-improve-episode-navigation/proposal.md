## Why

複数話（100〜200話規模）の小説を開いたとき、ユーザーは「いま自分が何話目を読んでいるのか」を見失いやすい。AppBar には小説名しか出ず、ファイル一覧側の選択ハイライトは Material 3 の既定（薄い背景）に依存しており、特にダークモードではほぼ視認できない。リストが長くなると選択行が画面外にあることも多く、毎回スクロールして探す必要がある。

また、ある話を末尾まで読み切ったとき、次の話へ進むにはファイル一覧から手動で選び直す以外の方法がない。「ページを送り続ければ次の話が始まる」という、紙の本に近い連続読書体験ができない。

これらは読書体験の中核的な動線にあたるため、本変更で改善する。

## What Changes

- **AppBar タイトルの拡張**: 小説フォルダ配下を閲覧中の場合、現状の「小説名」表記を「小説名 — `ファイル名` (現在話/総話数)」形式に拡張する（例: `異世界転生 — 049-戦闘.txt (49/200)`）。ファイル未選択時およびライブラリルートでは現状の表示を維持する。
- **ファイル一覧の選択ハイライト強化**: 選択中の `ListTile` に Material 3 `secondaryContainer` ベースの薄塗り背景、太字、左 4px の primary 色アクセントバーを追加し、ライト／ダーク両モードで明確に判別可能にする。
- **ファイル一覧の自動スクロール**: 別のファイルが選択された時、ファイル一覧の `ListView` を選択行が見える位置までスクロールさせる（`Scrollable.ensureVisible` 等）。同一ファイルが再選択された場合や手動操作中のスクロール位置を意図せず奪わないようにする。
- **縦書きモード: 末尾ページでのページ送り → 次話遷移（2 段階確認）**: 最終ページで「次ページへ」操作（→キー／下スクロール／右スワイプ）を検知した際、ページ番号エリア（`N / M` を表示している場所）に「▶ 次話「次のファイル名」へ（もう一度）」のヒントを表示する。3〜5 秒以内にもう一度同じ方向の操作が行われたらファイルを切り替えて次話の冒頭ページから開始する。タイムアウト後は通常の最終ページ状態に戻る。
- **縦書きモード: 先頭ページでのページ戻し → 前話遷移（対称、最終ページから開始）**: 同様の仕組みで先頭ページから前話への移動を可能にする。前話に切り替わった時は、前話の **最終ページ** から開始する（連続読書時に読み終えた直後のページに戻れるようにする）。
- **横書きモード: 次話／前話ボタン**: テキスト表示領域の下部に「←前話」「次話→」のボタンを常時表示する（ヒント方式は使わない）。前話遷移時は前話のコンテンツ末尾までスクロールして開始する。
- **末端の no-op**: 最終話の末尾でさらに次話へ進もうとした場合、最初の話の冒頭でさらに前話へ戻ろうとした場合は何もしない（ヒントも表示しない）。
- **新規 capability `episode-navigation`**: 「現在開いているファイルの前後の話を導出するロジック」「ファイル切替時に開始位置ヒント（冒頭／末尾）を伝える Riverpod intent provider」を提供する。各 UI 層はこの capability を介して次／前話遷移と開始位置指定を行う。

## Capabilities

### New Capabilities
- `episode-navigation`: 同一ディレクトリ内のテキストファイル並びにおける「次のファイル」「前のファイル」の導出と、ファイル切替時の開始位置（冒頭 / 末尾）を伝える intent provider を提供する。

### Modified Capabilities
- `app-title-display`: AppBar タイトルに現在ファイル名と話数（現在/総数）を併記する要件を追加する。
- `file-browser`: 選択中ファイルの視覚的ハイライト強化（ダークモードでの視認性）と、選択変更時の自動スクロールに関する要件を追加する。
- `vertical-text-display`: 末尾ページでの「次ページ」入力／先頭ページでの「前ページ」入力に対する 2 段階確認の次話／前話遷移挙動、およびページ番号エリアでのヒント表示要件を追加する。また、ファイル切替時の `episode-navigation` intent に従った初期ページ選択（先頭または最終ページ）要件を追加する。
- `text-viewer`: 横書きモードにおける次話／前話ボタン UI と、前話遷移時に末尾までスクロールして開始する要件を追加する。

## Impact

**Affected code**
- `lib/home_screen.dart` — AppBar タイトル生成ロジック（ファイル名と進捗の合成）
- `lib/features/file_browser/presentation/file_browser_panel.dart` — `ListTile` の選択スタイル、`ListView` の自動スクロール
- `lib/features/file_browser/providers/file_browser_providers.dart` — 周辺ロジックの調整（必要に応じて next/prev 導出を新 provider と連携）
- `lib/features/text_viewer/presentation/vertical_text_viewer.dart` — `_changePage` の境界処理拡張、ヒント状態管理、`pendingFileEntryIntent` に基づく初期ページ選択
- `lib/features/text_viewer/presentation/widgets/text_content_renderer.dart` — 横書きモードへの次話／前話ボタン追加、前話遷移時の末尾スクロール
- 新規ファイル: `lib/features/episode_navigation/` 配下に provider と関連ロジック

**Affected APIs**
- 新 Riverpod provider: `adjacentFilesProvider`（同一ディレクトリ内の次／前 `FileEntry` 導出）、`pendingFileEntryIntentProvider`（次回ファイル切替時の開始位置ヒント）

**Affected dependencies**
- 追加なし。既存の `flutter_riverpod` / `path` / Material 3 のみで実現可能。

**Affected i18n**
- 「次話へ」「前話へ」「もう一度押すと次話へ」等のローカライズ文字列を `lib/l10n/` に追加（ja / en / zh）。

**Out of scope**
- TTS との連動（TTS が章末まで読み上げたら自動で次話へ遷移、等）
- ブックマーク連動の遷移挙動の変更
- 既存ページネーション／ハイライト／検索その他の改修
