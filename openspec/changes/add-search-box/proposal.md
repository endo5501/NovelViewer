## Why

現在の検索機能はテキストを選択した状態でCtrl+F（macOSではCmd+F）を押すことでのみ発動する。任意の文字列を自由に検索したい場合、まず該当テキストを画面上で見つけて選択する必要があり、本末転倒である。テキスト未選択時にCtrl+Fで検索ボックスを表示し、任意の文字列を入力して検索できるようにする。

## What Changes

- テキスト未選択時にCtrl+F/Cmd+Fを押すと、検索ボックス（テキスト入力フィールド）を表示する
- 検索ボックスに文字列を入力しEnterまたはリアルタイムで検索を実行する
- テキスト選択済みの場合は従来通り選択テキストで即座に検索を実行する（既存動作を維持）
- Escキーで検索ボックスを閉じる
- 検索ボックスの表示/非表示状態を管理する

## Capabilities

### New Capabilities

- `search-box`: 検索ボックスUIの表示・非表示制御、テキスト入力による任意文字列検索機能

### Modified Capabilities

- `text-search`: Ctrl+F/Cmd+Fの動作分岐（テキスト選択の有無による検索ボックス表示 vs 即時検索）の要件を追加

## Impact

- `lib/home_screen.dart` — キーボードショートカットハンドラの分岐ロジック変更
- `lib/features/text_search/` — 検索ボックスウィジェットの追加、検索状態管理の拡張
- `lib/shared/widgets/search_summary_panel.dart` — 検索ボックスの配置検討
