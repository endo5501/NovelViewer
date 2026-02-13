## Context

現在、横書きモードでは `SelectableText.rich` を使用してテキスト選択が可能だが、縦書きモードでは `Wrap` ウィジェット内に1文字ずつ個別の `Text` ウィジェットを配置する方式のため、`SelectableText` が使用できずテキスト選択ができない。

縦書きモードの現在の文字レイアウトは以下の特性を持つ:
- `Directionality(textDirection: TextDirection.rtl)` で右から左の列方向
- `Wrap(direction: Axis.vertical)` で上から下の文字方向
- フォントサイズ・`_kRunSpacing`・`_kTextHeight` からレイアウトが計算可能
- ページネーションにより表示範囲が制限される（1ページ = maxColumnsPerPage 列分）
- 検索ハイライト機能が `_CharEntry` のインデックスベースで動作中

## Goals / Non-Goals

**Goals:**
- 縦書きモードでドラッグによるテキスト範囲選択を可能にする
- 選択テキストを `selectedTextProvider` に反映し、横書きモードと同等の操作を実現する
- ルビ付きテキストの選択時にベーステキスト（漢字等）を取得する
- 検索ハイライト（黄色）と選択ハイライト（青系）を視覚的に区別する

**Non-Goals:**
- テキスト編集機能
- 選択範囲のページ跨ぎ（現在表示中のページ内のみ）
- コンテキストメニューのカスタマイズ
- カーソル表示やキーボードによる選択範囲操作

## Decisions

### Decision 1: カスタムジェスチャーベースの選択方式を採用

**選択肢:**
- **A: Flutter の `SelectionArea` ラッパー** — `Wrap` を `SelectionArea` で囲む
- **B: カスタム `GestureDetector` + 位置計算** — ドラッグ座標から文字インデックスを算出
- **C: `CustomPainter` による描画** — 文字レンダリング自体を独自実装

**採用: B（カスタム GestureDetector + 位置計算）**

**理由:**
- `SelectionArea`（選択肢A）は `mapToVerticalChar` で変換済みの文字（例: `︒`）がクリップボードにコピーされる問題がある。逆変換マップの管理が煩雑になる
- `SelectionArea` ではルビの `Stack` 内の複数 `Text` が同時に選択される可能性があり制御が困難
- `CustomPainter`（選択肢C）は縦書きレイアウト全体の再実装が必要で過剰
- カスタムジェスチャー方式は既存の `_CharEntry` インデックスシステムと検索ハイライト機構をそのまま活用でき、原文テキストの取得が容易

### Decision 2: 座標→文字インデックスの位置計算方式

ページネーション計算で使用している同じレイアウト定数（`_kRunSpacing`, `_kTextHeight`, `fontSize`）を用いて、ポインタ座標から文字インデックスを算出する。

```
columnIndex = (availableWidth - localX) / columnWidth   // RTL: 右から左
rowIndex    = localY / charHeight
charIndex   = columnIndex * charsPerColumn + rowIndex
```

**理由:** `GlobalKey` を全文字に割り当てる方式はメモリ・パフォーマンスの問題があるが、レイアウトが固定グリッドであるため位置計算で正確に特定可能。ページネーション計算と同じ定数を使うため整合性が保たれる。

### Decision 3: 選択状態の管理場所

`VerticalTextPage` に選択状態（`selectionStart`, `selectionEnd`）をコールバック経由で管理する。

- `VerticalTextPage`: `GestureDetector` を配置し、ドラッグイベントを処理。選択範囲の文字ハイライトを描画
- `VerticalTextViewer`: `onSelectionChanged` コールバックを受け取り、`selectedTextProvider` を更新
- `TextViewerPanel`: Riverpod を通じて選択テキストを利用

**理由:** `VerticalTextPage` はレイアウト定数とセグメントデータの両方を保持しているため、座標→文字インデックス変換と選択テキスト抽出の両方を効率的に実行できる。

### Decision 4: 選択テキストの抽出方法

`_CharEntry` リストから選択範囲のインデックスに対応する**原文テキスト**を抽出する。

- `PlainTextSegment`: `entry.text`（変換前の原文文字）を使用
- `RubyTextSegment`: `entry.text`（ベーステキスト＝漢字等）を使用
- 改行エントリ: `\n` として含める

**理由:** 既存の `_CharEntry` は原文テキストを保持しており（`mapToVerticalChar` は描画時のみ適用）、追加の逆変換処理が不要。

### Decision 5: 選択ハイライトの視覚デザイン

- 選択ハイライト: `Colors.blue.withOpacity(0.3)` の背景色
- 検索ハイライト: 既存の `Colors.yellow`（変更なし）
- 両方が重なる文字: 検索ハイライトを優先（検索ハイライトが表示される）

**理由:** 検索ハイライトはユーザが明示的に検索した結果であり、優先度が高い。青系の選択色はOS標準のテキスト選択色に近く、直感的。

## Risks / Trade-offs

**[リスク] 位置計算の精度** — ルビ付き文字は通常文字より高さが異なる可能性がある
→ 緩和策: ルビウィジェットは `Stack` でオーバーレイされているため、ベーステキスト部分の高さは通常文字と同じ。`_kTextHeight` ベースの計算で十分な精度を確保できる

**[リスク] ページ切り替え時の選択状態** — ページを移動すると選択が無効になる
→ 緩和策: ページ切り替え時に選択をクリアする。これは横書きモードでスクロール時に選択が維持されない場合と同等の挙動

**[トレードオフ] ドラッグジェスチャーとページ操作の競合** — 現在キーボード（←→）でページ操作しているため、ドラッグとの競合はない

**[リスク] パディング・マージンのオフセット** — `VerticalTextPage` の外側の `Padding` や `Align` がポインタ座標に影響する
→ 緩和策: `GestureDetector` を `Wrap` の直接の親に配置し、`localPosition` を使用することでオフセットを正確に算出
