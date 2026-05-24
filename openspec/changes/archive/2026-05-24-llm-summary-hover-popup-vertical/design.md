## Context

ホバーポップアップは前回 change `llm-summary-hover-popup`（archived: 2026-05-24）で導入され、`HoverPopupNotifier` / `HoverPopupState` / `HoverPopupWidget` / `HoverPopupHost` / `hoverPopupCacheProvider` の5点で構成される。検出は `_applyLocalMarksToSpans` が生成する mark 付き `TextSpan` の `onEnter` / `onExit` で行うため、`SelectableText.rich` に乗っている横書きビューでのみ機能する。縦書きビュー `VerticalTextViewer` → `VerticalTextPage` は1文字＝1 `SizedBox(width: fontSize, child: Text(char))` を `Wrap(Axis.vertical, RTL)` で並べる構造で、mark 表示は `CustomPaint` foregroundPainter による側線描画。`TextSpan.onEnter/onExit` の系統がそもそも存在しないため、別検出機構が必要。

ただし `VerticalTextPage` には既に**選択用のヒット領域インフラ** `_hitRegions: List<VerticalHitRegion>` がある。各 `VerticalHitRegion` は `charIndex` と `Rect`（ページ-local 座標）を持ち、`_hitTest(Offset localPosition) -> int?` で逆引きできる。これは post-frame callback で各文字 widget の `GlobalKey.currentContext` から `RenderBox.localToGlobal` で構築される。再ビルド時は `_scheduleHitRegionRebuild` でフラグ立て→ post-frame で再構築。マウスホバーの逆引きもこのインフラを再利用するのが最も自然。

ポップアップ本体 (`HoverPopupWidget`) と状態 notifier (`hoverPopupProvider`) は表示モード非依存に設計されている。`HoverPopupNotifier.show()` は `(word, position, token)` を受け取るだけで、token の意味（horizontal: segment-global text range / vertical: page-local entry index range）には関与しない。同一 token なら state を書き換えないガードと、grace period 中の `hideIfShowing` 取り消し（pointer が popup に入ったら `onPopupEnter` でキャンセル）という仕組みもそのまま使える。

ホスト `HoverPopupHost` は現在 `displayModeProvider != horizontal` を見て (1) モード切替時に `hide()`、(2) OverlayEntry 挿入時にガード — の2箇所で縦書きを排除している。本 change ではこのガードを撤去し、加えて OverlayEntry の位置計算を mode 別に分岐させる。

## Goals / Non-Goals

**Goals:**
- 縦書きでも横書きと同等の体験（ホバー→ポップアップ→[なし|あり] 切替→マウス離脱）を提供する
- 検出インフラは縦書きビューが既に持っているもの（`_hitRegions`）を流用し、新規データ構造の追加を最小化する
- ポップアップ本体・notifier・grace period・cache provider には改修を入れない（既存 widget test が全て temselves と整合的なまま残る）
- `computeMarkedEntries` の戻り値や呼び出し側を破壊せず、必要な逆引きは並列に追加する（既存テスト無影響）
- 位置計算はモード分岐を `HoverPopupHost` 1箇所に閉じ、`VerticalTextPage` / `VerticalTextViewer` / `TextContentRenderer` は「pointer global position をそのまま渡す」責務だけに留める

**Non-Goals:**
- ホバー検出のタッチデバイス対応（Flutter の MouseRegion はマウスポインタ前提）
- 縦書き popup 内のテキスト選択 / コピー対応（履歴タブから対応）
- 解析開始メニューの縦書き再設計（前回 change で完了済み）
- ruby ベース文字以外（ruby 振り仮名そのもの）に独立した mark / popup を出すこと（既存 _hitRegions が ruby 範囲を base char に統合しているのを踏襲）
- 位置計算で popup 自身の実サイズを measure してからフリップを決定すること（OverlayEntry の builder では子の measure 前なので、近似サイズで判定する）

## Decisions

### D1. 検出方式：単一 `MouseRegion` + 既存 `_hitRegions` 逆引き
`VerticalTextPage.build` の `GestureDetector` を `MouseRegion` でラップし、`onHover(PointerHoverEvent)` で `event.localPosition` を取得 → `_hitTest(localPosition)` で `charIndex` を逆引き → `computeMarkedRanges` の戻り値で `(word, markStartEntry, markEndEntry)` を引く。差分管理用に State に `int? _lastHoverCharIndex` と `({int start, int end})? _lastHoverToken` を保持し、

- charIndex が前回と同じなら何もしない（pixel 単位の wobble を抑制）
- charIndex が変わり、新しい char が mark 範囲内なら `widget.onMarkEnter?.call(word, globalPosition, token)`
- charIndex が変わり、新しい char が mark 範囲外なら `widget.onMarkExit?.call(_lastHoverToken)`（前回 token がある時のみ）

`MouseRegion.onExit` でも `widget.onMarkExit?.call(_lastHoverToken)` を呼んでビュー外への退出を捕捉する。

`PointerHoverEvent.position` がグローバル座標、`event.localPosition` が `MouseRegion` 自身の座標系。`_hitRegions` は VerticalTextPage の `findRenderObject()` を ancestor とした座標で構築されているので、`MouseRegion` が VerticalTextPage の build ルート（GestureDetector ラップ位置）にあれば座標系は一致する。

**代替案：**
- **(a) marked char ごとに MouseRegion を被せる**：未mark文字には zero cost だが、1mark = N文字 = N回 onEnter 発火 → 同一 token coalesce ロジックは notifier 側で吸収済みなので機能はする。ただし `VerticalTextPage` のビルド構造（`_buildCharWidget` の戻り値を `KeyedSubtree` で包んで `children` 配列に積む）の中で個別ラップすると、`children` の数値オーバーヘッドが増え `_hitRegions` 再構築コストとの相乗で僅かに重い。検出責務を「ホバー検出は別構造」として分けたい
- **(c) Listener + MouseTrackerAnnotation を直接実装**：低レベル過ぎて Flutter 標準の MouseRegion で十分

→ **(B) を採用**。MouseRegion 1個、State に差分用変数2個、既存 `_hitTest` 流用、という最小構成。

**確認すべき動作（実装段階で）:**
- `MouseRegion.onHover` が `GestureDetector` の子孫として配置された場合に発火するか（Flutter 仕様上は MouseRegion は pointer hover 専用 / GestureDetector は button-down pan/tap 専用で衝突しない想定だが、実機でゼロ確認必要）
- pan 中（button down）で onHover が静止することを確認

### D2. `computeMarkedRanges` を `vertical_marked_ranges.dart` に新規追加
既存 `computeMarkedEntries(entries, markedWords) -> Map<int, MarkStyle>` は戻り値そのまま、呼び出し元（`VerticalTextPage.build`）と既存テストを無改修にする。並列で `computeMarkedRanges(entries, markedWords) -> Map<int, MarkInfo>` を追加：

```dart
class MarkInfo {
  const MarkInfo({required this.word, required this.startEntry, required this.endEntry});
  final String word;
  final int startEntry; // inclusive
  final int endEntry;   // exclusive
}

Map<int, MarkInfo> computeMarkedRanges({
  required List<VerticalCharEntry> entries,
  required Map<String, MarkStyle> markedWords,
}) { ... }
```

実装は `computeMarkedEntries` と同じ buffer/positionToEntry 走査 + `findMarks` を使い、結果を `Map<int, MarkInfo>` 形式に詰め替える。mark 範囲内の全 charIndex が同一 `MarkInfo` インスタンスを共有する（hover charIndex 差分が同一 mark 内なら参照等価で判別可能）。

**代替案：**
- **`computeMarkedEntries` の戻り値を record に拡張**：既存呼び出しと既存テストを書き換えることになる
- **MarkSpan のリストを VerticalTextPage に直接渡す**：lookup ごとに O(N) 走査が走る。1ページ ~200文字 × hover 頻度では計測上問題ないが、Map 引きの方が素直

→ **新関数追加**。既存テスト 0 改修、新規 unit test を `computeMarkedRanges` 単体で書ける。

### D3. HoverToken の意味は mode 別、`typedef` は共通
既存：
```dart
typedef HoverToken = ({int start, int end});
```
- 横書き：segment-global text range
- 縦書き：page-local `(startEntry, endEntry)`

`HoverPopupNotifier` は token を equality 比較しかしない（`state.hoverToken == token` で同一判定 → state 書き換え省略 / `hideIfShowing(token)` で対象判定）。意味は問わないので record 1種類で兼用可能。

**Trade-off:**
- ページ遷移で `_charEntries` がリビルドされると entry index の意味が変わる → mode 切替・ページ遷移時に必ず hide することで一意性は維持される
- 別ファイルの mark に同じ `(start, end)` がたまたま一致するケース → 同 token はそもそも別ページなので前段で hide される
- 仕様変更ではなく内部実装の解釈差。design.md 記載で他者の読み手にも明示する

### D4. `VerticalTextViewer` / `VerticalTextPage` の callback プロパティ拡張
hover の発生地点（`VerticalTextPage`）と notifier 操作地点（`TextContentRenderer._onMarkEnter` / `_onMarkExit`）の間で値を伝えるため、callback プロパティを次のように足す：

- `VerticalTextPage`:
  - `void Function(String word, Offset globalPosition, HoverToken token)? onMarkEnter`
  - `void Function(HoverToken token)? onMarkExit`
- `VerticalTextViewer`:
  - 上記2つを passthrough
  - 加えて `void Function()? onHoverHideRequest`（ページ遷移時の hide 発火用）
- `_changePage` で `widget.onHoverHideRequest?.call()` を `widget.onSelectionChanged?.call(null)` の直後に呼ぶ
- `_onPanDown` で `widget.onMarkExit?.call(currentToken)` を呼ぶ場合、現在の token が無いケースも考慮 → `onHoverHideRequest` 経由で notifier に直接 `hide()` を投げる方が単純

→ **`onMarkExit` を Page 内 hover 状態クリア用、`onHoverHideRequest` を「pageレベルの粗いリセット」用に分ける**。後者は `VerticalTextViewer._changePage` と `VerticalTextPage._onPanDown` 両方から発火させる。`TextContentRenderer` 側は `onHoverHideRequest: () => ref.read(hoverPopupProvider.notifier).hide()` を渡す。

### D5. `TextContentRenderer` の縦書き枝に hover 配線を追加
横書き枝が `_onMarkEnter` / `_onMarkExit` をすでに持っている（`_applyLocalMarksToSpans` 経由で配線済み）。縦書き枝でも同じ2関数を `VerticalTextViewer` に渡し、`VerticalTextPage` まで届ける：

```dart
return VerticalTextViewer(
  // ...existing args...
  onMarkEnter: _onMarkEnter,
  onMarkExit: _onMarkExit,
  onHoverHideRequest: () =>
      ref.read(hoverPopupProvider.notifier).hide(),
);
```

横書きと縦書きで同じ `_onMarkEnter` / `_onMarkExit` を共有することで、`HoverPopupNotifier` 側からは「どちらのモードから来た hover か」を意識しなくてよくなる。

### D6. ホスト `HoverPopupHost` の整理と位置計算分岐
2つの修正：

**(a) モードガード撤去**:
- `if (mode != TextDisplayMode.horizontal) { _removeEntry(); return; }` を削除
- `ref.listen<TextDisplayMode>` 内の `if (next != TextDisplayMode.horizontal)` 条件を撤去し、モード切替を検知したら常に `hide()` を呼ぶ（spec の "Popup hides on display mode switch" 要件を実現）

**(b) 位置計算分岐**:
OverlayEntry の builder 内で `MediaQuery.of(context).size` を取り、mode に応じて anchor を計算する。popup の実サイズは builder 時点で未確定なので、定数で近似する：

```dart
const _kPopupApproxWidth = 320.0;   // _Card の maxWidth 320
const _kPopupApproxHeight = 100.0;  // タイトル + 本文1〜2行 + (toggle/warning) の目安
const _kPopupGap = 16.0;
```

横書き：
```
left = position.dx + _kPopupGap
top  = position.dy + _kPopupGap
```

縦書き既定（右上）：
```
left = position.dx + _kPopupGap
top  = position.dy - _kPopupHeight - _kPopupGap
```

水平フリップ判定：`left + _kPopupApproxWidth > screenWidth` → `left = position.dx - _kPopupApproxWidth - _kPopupGap`

垂直フリップ判定：`top < 0` → `top = position.dy + _kPopupGap`

ホスト state の `_insertEntry` を mode 引数付きに拡張し、`Positioned(left, top, child: HoverPopupWidget(...))` を組み立てる。

**Trade-off**: 近似サイズで判定するため、実際の popup が想定より大きい場合に端でわずかにはみ出る可能性がある。許容（spec も「approximately」と表現）。

### D7. ホスト state へ `displayMode` を渡す責任分離
位置計算分岐はホストの実装詳細。`HoverPopupNotifier` / `HoverPopupWidget` には mode 概念を持ち込まない。ホスト state 内で `ref.read(displayModeProvider)` を popup 挿入時に読んで分岐する：

```dart
void _insertEntry({
  required Offset position,
  required String folder,
  required String word,
  required String? currentFileName,
  required TextDisplayMode mode,
}) { ... }
```

呼び出し側 `ref.listen<HoverPopupState>` 内で `final mode = ref.read(displayModeProvider);` してそのまま渡す（既に上で読んでいるので追加の I/O なし）。

### D8. ドラッグ選択中の onHover 抑制機構
MouseRegion.onHover は仕様上 button-down 中は発火しない（Flutter `_AnnotatedRegionBox` / `MouseTracker` の動作）。なので「pan 開始後の新規 hover」については追加ガード不要。ただし「**pan 開始時点で既に popup が visible だった**」場合は onExit が来ないまま残るリスクがある（ボタン押下で hover 状態がフリーズ、selecting 状態が始まる）。

→ `_onPanDown` で `widget.onHoverHideRequest?.call()` を呼ぶことで対処。spec の "Drag selection in vertical mode hides popup" を満たす。

### D9. ページ遷移時の hide
`VerticalTextViewer._changePage(delta)` 内、既存の `widget.onSelectionChanged?.call(null)` の直後に `widget.onHoverHideRequest?.call()` を追加。

spec の "Page transition in vertical mode hides popup" を満たす。アニメーション中の中間状態（`_outgoingSegments != null` の Stack 2枚並び）での hover も、開始時に hide することでクリーンに扱える。

## Risks / Trade-offs

- **R1**: `MouseRegion.onHover` が `GestureDetector` の子孫位置で期待通り発火するか → tasks 冒頭で spike 確認。発火しない場合は MouseRegion を GestureDetector の親に置く / Listener を併用 / Per-char MouseRegion (D1 案a) にフォールバック
- **R2**: `_hitRegions` は post-frame callback で構築されるため、初回ホバーが直後に来た場合は空 → `_hitTest` が null を返し、その回は no-op で問題なし（次の hover event で region がそろっていれば検出される）
- **R3**: ruby 文字（振り仮名）部分にホバーした際は `_hitRegions` の rect が ruby 領域まで含むよう拡張されているため、base char の charIndex に正しく解決される。base char に mark が付いていれば期待通り popup 表示
- **R4**: popup 位置のフリップ判定は近似サイズで行うため、特に上限ライン付近で実体サイズが見積もりを超えた場合に端でわずかに切れる。spec は "approximately" を許容するが、実装段階で popup の実際の最大ケース（要約3行 + toggle + warning）を 320×~140 と仮定して `_kPopupApproxHeight` を調整
- **R5**: 縦書きビューが page transition animation 中（`_outgoingSegments != null`）に hover が来うる。`_changePage` 開始時に hide させることで状態は閉じるが、`_lastHoverCharIndex` / `_lastHoverToken` が古いまま残る可能性 → `_onPanDown` 同様に、`didUpdateWidget` で `oldWidget.segments != widget.segments` の枝でも `_lastHoverCharIndex = null; _lastHoverToken = null;` をリセット
- **R6**: 横書きと縦書きで token のセマンティクスが異なる（segment-global text range vs page-local entry range）。同セッションでモード切替→片方の hover→もう片方の hover という遷移で token が衝突しないか → モード切替時に `hide()` が走るので state.hoverToken が null にリセットされ、次の `show()` で新たに採用されるため衝突なし
- **R7**: `TextContentRenderer` の現状実装は `_onMarkEnter` / `_onMarkExit` を横書き枝のクロージャ生成箇所からしか呼んでいない。縦書き枝への配線追加で、もし `TextContentRenderer` が unmount された後にコールバックが呼ばれると null deref の可能性 → `mounted` チェックは `ref.read` 側で自然に処理される（dispose 後の Provider read は Flutter Riverpod 側で例外を投げる仕様 → catch なし、開発時に気付ける）

## Migration Plan

ユーザは本人のみ、データ・キャッシュ不変、UI 差分のみ。

ロールアウト：
1. `computeMarkedRanges` の単体テストを書いて green 化（仕様の単純なバリエーション網羅）
2. R1 の spike：`VerticalTextPage` の build に `MouseRegion(onHover: print)` を一時的に入れて手動確認
3. `VerticalTextPage` の hover state（`_lastHoverCharIndex`、差分検出ロジック）を unit/widget test で TDD
4. `VerticalTextViewer` の `onHoverHideRequest` 配線と `_changePage` での発火、`_onPanDown` での発火を widget test で TDD
5. `TextContentRenderer` の縦書き枝への callback 配線
6. `HoverPopupHost` のモードガード撤去 + 位置計算分岐 + モード切替時の常時 hide
7. 既存スペック「Hover popup disabled in vertical mode」を削除した spec の整合性確認
8. 手動検証（縦書きで一連の操作、横書きで回帰なし、モード切替で popup が確実に消える）

ロールバック：本change は UI 差分のみ。git revert で戻る。データ非破壊。

## Open Questions

- popup の概算サイズ定数 `_kPopupApproxHeight` の値（80? 100? 140?）→ 実装段階で実物を見ながら決定（要約2行 + toggle + warning の最大ケース）
- 縦書きで popup が表示位置の左フリップした場合、popup の中身（テキスト行揃え等）はモード非依存のままで違和感なしか → 実物確認、必要なら微調整
- `_lastHoverCharIndex` / `_lastHoverToken` を `VerticalTextPage` の State インスタンスで持つことの是非（widget test の制御性 vs 単純性）→ 単純性を優先して State 内で持つ
