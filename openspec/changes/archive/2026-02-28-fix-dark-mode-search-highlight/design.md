## Context

テキスト検索のハイライトは3箇所で `Colors.yellow` をハードコードしている:

1. `vertical_text_page.dart` の `_createTextStyle()` — 縦書きプレーンテキスト
2. `vertical_ruby_text_widget.dart` の `_buildBaseText()` — 縦書きルビテキスト
3. `ruby_text_builder.dart` の `_buildHighlightedPlainSpans()` — 横書きテキスト

ライトモードではテキスト色が黒のため問題ないが、ダークモードではテキスト色が白になり、黄色背景との組み合わせでコントラストが不足して文字が読めなくなる。

3箇所のうちWidget（1, 2）は `BuildContext` にアクセスできるが、`_buildHighlightedPlainSpans()`（3）はトップレベル関数のため `BuildContext` を持たない。

## Goals / Non-Goals

**Goals:**
- ダークモードでの検索ハイライトの視認性を確保する
- ライトモードでは現行の見た目を維持する
- テーマに応じたハイライト色を3箇所すべてで統一的に適用する

**Non-Goals:**
- TTSハイライト（緑）や選択ハイライト（青）の色変更
- ハイライト色のユーザーカスタマイズ機能
- WCAGアクセシビリティ基準への完全準拠

## Decisions

### Decision 1: ダークモードのハイライト色

ダークモードでは背景色を `Colors.amber.shade700`（暗めのアンバー）、テキスト色を `Colors.black` にする。

ライトモードでは現行通り `Colors.yellow` を使用し、テキスト色は変更しない（既存の黒テキストでコントラスト十分）。

**理由**: アンバー系は黄色の印象を保ちつつ、ダーク背景上でも目立ち、黒テキストとのコントラストが確保できる。

**代替案**:
- `Colors.yellow` のまま `foregroundColor: Colors.black` を追加 → 背景が暗い中で黄色が明るすぎて目立ちすぎる
- `Colors.orange` → 黄色ハイライトの印象から離れすぎる

### Decision 2: テーマ検出方法 — `Brightness` パラメータの追加

`_buildHighlightedPlainSpans()` はトップレベル関数のため `BuildContext` にアクセスできない。呼び出し元から `Brightness` を引数として渡す。

Widget内のメソッド（`_createTextStyle()`, `_buildBaseText()`）は `Theme.of(context).brightness` を使用する。

**理由**: 最小限の変更で済む。`BuildContext` をトップレベル関数に渡すと関数シグネチャが過度に複雑になる。

### Decision 3: ハイライト色定義の一元化

検索ハイライトの色定義をヘルパー関数として `ruby_text_builder.dart` に配置する。3箇所すべてからこの関数を呼び出して色を統一する。

```dart
Color searchHighlightBackground(Brightness brightness) =>
    brightness == Brightness.dark ? Colors.amber.shade700 : Colors.yellow;

Color? searchHighlightForeground(Brightness brightness) =>
    brightness == Brightness.dark ? Colors.black : null;
```

**理由**: 色定義を1箇所にまとめることで、将来の調整が容易になる。

## Risks / Trade-offs

- **テストへの影響** → 既存テストが `Colors.yellow` を期待値にしている。テーマ対応後はテストもライト/ダーク両方のケースを検証する必要がある。
- **`Brightness` パラメータの追加** → `buildRubyTextSpans()` の公開APIに `Brightness` パラメータが追加される。呼び出し元の変更が必要だが、影響は限定的。
