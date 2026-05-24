## Why

前回 change `llm-summary-hover-popup`（archived: 2026-05-24）でマーク済み語ホバーポップアップを導入したが、Flutter の `TextSpan.onEnter/onExit` を使うため横書き専用となり、縦書きモードは「mark側線は維持・ポップアップは出さない」明示的スコープ外として残された（spec: "Hover popup disabled in vertical mode"、design.md R2）。本change はその残件として、縦書きモードでもマーク済み文字にホバーするとポップアップが出るようにし、表示モードによる体験差を解消する。

## What Changes

- `VerticalTextPage` にマウスホバー検出機構を追加し、既存の `_hitRegions`（選択用ヒット領域）を逆引きしてポインタ下の文字インデックスを特定、マーク範囲内なら `hoverPopupProvider.show()`、範囲外/別マーク/MouseRegion外への遷移で `hideIfShowing()` を呼ぶ
- `vertical_marked_entries.dart` に並列する新ヘルパ `computeMarkedRanges` を追加し、charIndex → `(word, markStartEntry, markEndEntry)` を即時逆引きできるようにする（既存 `computeMarkedEntries` は無改変）
- `VerticalTextViewer._changePage` でページ遷移開始時にポップアップを hide させる導線を追加（callback 経由）
- `VerticalTextPage._onPanDown` でドラッグ選択開始時にポップアップを hide させる
- `HoverPopupHost` の表示モードガードを撤去し、縦書きモードでも OverlayEntry を挿入する。あわせて表示モード切替時には常に hide させる（位置計算ルールがモード間で異なるため）
- `HoverPopupHost` の OverlayEntry 位置計算を、横書きは現状の「右下 +16/+16」、縦書きは「右上 +16/-16」＋画面端での水平/垂直フリップに分岐させる
- 縦書きでも横書きと同じ `HoverPopupWidget` / `hoverPopupProvider` / grace period / [なし|あり] トグル / 参照ズレ警告 / ローディング表示が機能する（widget 本体・notifier は無改修）

## Capabilities

### New Capabilities
（なし）

### Modified Capabilities
- `llm-summary-hover-popup`:
  - **DELETE**: 「Hover popup disabled in vertical mode」要件を削除（縦書き抑制ルールの撤回）
  - **ADDED**: 「Hover popup on marked characters in vertical mode」要件を追加（縦書きでもマーク済み文字ホバーでポップアップを出す。範囲内移動で維持、範囲外/別マーク/MouseRegion 離脱で grace period 経由 hide、widget 内容は横書きと共通）
  - **ADDED**: 「Popup position adjusts for display mode」要件を追加（横書き＝右下+16/+16、縦書き＝右上+16/-16＋画面端フリップ）

## Impact

**コード**
- 改修: `lib/features/text_viewer/presentation/vertical_text_page.dart`（MouseRegion 追加、`onHover` 経由 hover 検出、charIndex 差分による show/hide 抑制、`_onPanDown` での明示 hide）
- 改修: `lib/features/text_viewer/presentation/vertical_text_viewer.dart`（`onHoverHideRequest` 相当の callback プロパティ追加、`_changePage` 開始時に hide を発火）
- 新規: `lib/features/text_viewer/data/vertical_marked_ranges.dart`（`computeMarkedRanges` 関数と `MarkInfo` 型）
- 改修: `lib/features/text_viewer/presentation/widgets/text_content_renderer.dart`（縦書き枝でも `_onMarkEnter` / `_onMarkExit` を `VerticalTextViewer` 経由で `VerticalTextPage` まで配線、hide 通知の受け取り）
- 改修: `lib/features/llm_summary/presentation/hover_popup_host.dart`（モード分岐ガードの撤去、表示モード切替時の常時 hide、縦書き向け位置計算ロジック追加）

**仕様/動作影響**
- 縦書きユーザがホバー機能を利用できるようになる（前回 change で R2 として残されていた制約の解消）
- 表示モード切替時にはポップアップが常に閉じる（モードに依存した位置計算結果を引きずらない）
- ドラッグ選択開始・ページ遷移時にポップアップが閉じる挙動が縦書きに追加（横書きは既存挙動から無変更）

**依存・データ**
- LLM パイプライン / キャッシュ / mark スキャン / `HoverPopupNotifier` / `HoverPopupWidget` 本体・状態モデル・grace period 仕様は変更なし
- l10n は新規メッセージなし（HoverPopupWidget 内容を再利用）

**Non-Goals**
- ホバー検出のタッチデバイス対応（マウスのみ）
- 縦書きで popup 内のテキスト選択 / コピー対応（横書きと同様に不可、コピーは履歴タブから）
- 解析開始メニュー（右クリック）の縦書き挙動変更（前回 change 完了済み）
