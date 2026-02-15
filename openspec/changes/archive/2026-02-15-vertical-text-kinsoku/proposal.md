## Why

縦書き表示で句読点（`。`、`、`）や閉じ括弧などが列頭（行頭）に来てしまう問題がある。日本語組版の禁則処理が実装されていないため、可読性が低下している。現在の `_splitLineIntoColumns` は文字数のみでカラムを分割しており、禁則文字の位置を考慮していない。

## What Changes

- 行頭禁則文字（`。`、`、`、`）`、`」`、`！`、`？` など）が列の先頭に来ないようにする禁則処理を追加
- 行末禁則文字（`（`、`「`、`『` など）が列の末尾に来ないようにする禁則処理を追加
- 禁則処理方式として「追い出し」を採用：禁則文字を前の列に含めて列の文字数を1文字増やす（ぶら下げ）
- カラム分割ロジック（`_splitLineIntoColumns`、`_addPlainTextToColumns`、`_addRubyTextToColumns`）に禁則判定を組み込む

## Capabilities

### New Capabilities

（なし）

### Modified Capabilities

- `vertical-text-display`: カラム分割時に禁則処理（行頭禁止文字の追い出し、行末禁止文字の追い出し）を追加。カラムあたりの文字数が禁則処理により1文字前後する場合がある。

## Impact

- `lib/features/text_viewer/presentation/vertical_text_viewer.dart`: `_splitLineIntoColumns`、`_addPlainTextToColumns`、`_addRubyTextToColumns` のカラム分割ロジックを修正
- 禁則文字の定義と判定ロジックを新規追加（データレイヤーに配置）
- ページネーション（`_groupColumnsIntoPages`）は文字幅ベースのため影響は限定的だが、カラムあたりの文字数が変動することへの対応が必要
- 既存テスト（`vertical_text_viewer_test.dart`）の期待値調整が必要になる可能性がある
