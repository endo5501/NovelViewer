## Context

`llm_settings_test.dart` の "changing provider updates displayed fields" テストが `Bad state: No element` で失敗している。テスト出力に `warnIfMissed` 警告が出ていることから、85行目の `tester.tap(find.text('未設定'))` がヒットテストに失敗していることが判明。

設定ダイアログ（`SettingsDialog`）は `SingleChildScrollView` 内に複数のUIコンポーネントを持ち、LLMプロバイダのドロップダウンはダイアログの最下部に配置されている。テスト環境のデフォルトビューポート（800x600）ではこの要素が表示領域外にあるため、tap が物理的にヒットせず、結果としてドロップダウンが開かないため後続の `find.text('Ollama').last` で要素が見つからない。

## Goals / Non-Goals

**Goals:**
- "changing provider updates displayed fields" テストを Flutter 3.38.9 で正常に通るよう修正する
- 全515テスト（514 + 現在の1 failed）がパスする状態にする

**Non-Goals:**
- 設定ダイアログの機能変更やリデザイン
- 他のテストの修正（既に passing のテストは変更しない）
- DropdownButton から DropdownMenu への移行

## Decisions

### 1. `tester.ensureVisible()` を使用してスクロールしてからタップする

**選択**: tap の前に `await tester.ensureVisible(find.text('未設定'))` を呼び出し、ウィジェットを表示領域内にスクロールさせる。

**理由**: Flutter のテストフレームワークが提供する標準的なAPIであり、`SingleChildScrollView` 内のオフスクリーン要素を表示領域内に移動させるための公式な手法。

**代替案**:
- `tester.scrollUntilVisible()` — 表示されるまでスクロールする方法だが、`ensureVisible` の方がシンプル
- `tester.drag()` で手動スクロール — スクロール量の指定が必要でメンテナンスしにくい
- テストウィンドウサイズを拡大 — 他のテストに影響する可能性がある

### 2. ドロップダウンメニュー展開後も同様に `ensureVisible` または `.last` の前に存在確認を行う

ドロップダウンが正常に開けば、`find.text('Ollama').last` でメニューアイテムの選択が可能になるはず。もし展開後のメニューアイテムにもアクセスできない場合は、`find.widgetWithText(DropdownMenuItem, 'Ollama')` 等の代替ファインダーを検討する。

## Risks / Trade-offs

- **リスク**: `ensureVisible` だけでは不十分な場合がある → `pumpAndSettle` の追加や代替アプローチに切り替え
- **リスク**: ドロップダウンのオーバーレイ内のアイテムも表示領域外になる可能性 → その場合はオーバーレイ内のアイテムに対しても `ensureVisible` を適用
