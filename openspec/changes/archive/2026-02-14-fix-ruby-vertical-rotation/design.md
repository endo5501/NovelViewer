## Context

`VerticalRubyTextWidget` は縦書きモードでルビ付きテキストをレンダリングするウィジェット。現在、親文字（base text）には `mapToVerticalChar()` を適用して縦書き用文字に変換しているが、ルビテキストには変換を行っていない。

該当箇所は `vertical_ruby_text_widget.dart` の29行目:
```dart
final rubyChars =
    rubyText.runes.map((r) => String.fromCharCode(r)).toList();
```

一方、親文字は26行目で変換済み:
```dart
final baseChars = base.runes
    .map((r) => mapToVerticalChar(String.fromCharCode(r)))
    .toList();
```

## Goals / Non-Goals

**Goals:**
- ルビテキストに含まれる文字にも `mapToVerticalChar()` を適用し、縦書き時の文字マッピングを統一する

**Non-Goals:**
- `verticalCharMap` のマッピングテーブル自体の変更や拡張
- ルビテキストのレイアウト・配置ロジックの変更
- 横書きモードのルビ表示への影響

## Decisions

### ルビ文字の変換箇所

**決定**: `VerticalRubyTextWidget.build()` 内のルビ文字リスト構築時に `mapToVerticalChar()` を追加する。

**理由**: 親文字と同じパターンを踏襲し、変更箇所を最小限にする。修正は1行のみで、既存の `mapToVerticalChar()` 関数をそのまま再利用できる。

**変更前**:
```dart
final rubyChars =
    rubyText.runes.map((r) => String.fromCharCode(r)).toList();
```

**変更後**:
```dart
final rubyChars = rubyText.runes
    .map((r) => mapToVerticalChar(String.fromCharCode(r)))
    .toList();
```

## Risks / Trade-offs

- **リスク**: ルビテキストは通常ひらがな・カタカナであり、`verticalCharMap` に含まれないため、多くの場合は変換結果が変わらない → ルビに括弧や記号が含まれるケースでのみ効果を発揮するが、副作用はない
