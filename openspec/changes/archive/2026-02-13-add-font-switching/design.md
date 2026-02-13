## Context

NovelViewerのテキスト表示は現在、フォントサイズ14.0px固定、フォント種別はFlutterデフォルトにハードコードされている。設定機能は既にSharedPreferences + Riverpod Notifierパターンで実装されており（表示モード切替）、このパターンを踏襲してフォント設定を追加する。

現在の設定フロー:
1. `SettingsRepository` がSharedPreferencesを操作
2. `NotifierProvider` が状態管理とUI通知を担当
3. `SettingsDialog` がConsumerWidgetとしてproviderをwatch
4. `TextViewerPanel` がproviderをwatchし、子ウィジェットにTextStyleを渡す

## Goals / Non-Goals

**Goals:**
- ユーザーがフォントサイズを10〜32pxの範囲で変更できる
- ユーザーがフォント種別をプリセットリストから選択できる
- 設定がアプリ再起動後も永続化される
- 横書き・縦書き両モードに即座に反映される
- 既存のSettingsRepository / Notifierパターンに一貫して従う

**Non-Goals:**
- カスタムフォントのインポート・バンドル（システムフォントのみ）
- 行間・字間の調整（将来的に追加可能だが今回はスコープ外）
- フォントウェイト（太さ）の調整
- テーマ全体のフォント変更（テキスト表示領域のみ対象）

## Decisions

### 1. データモデル: 個別プロバイダー vs 統合モデル

**決定**: フォントサイズとフォント種別をそれぞれ個別のNotifierProviderで管理する。

**理由**: 既存の`displayModeProvider`が単一値のNotifierProviderパターンを使用しており、同じパターンに統一することで学習コストとコードの一貫性を維持できる。`fontSizeProvider`と`fontFamilyProvider`をそれぞれ独立して定義する。

**代替案**: `FontSettings`クラスに統合 → パターンの一貫性が崩れ、一方のみ変更する際にも両方の値を扱う必要がある。

### 2. フォントサイズの永続化: double値のSharedPreferences保存

**決定**: `SharedPreferences.setDouble` / `getDouble`で直接保存する。

**理由**: SharedPreferencesはdouble型をネイティブサポートしており、シリアライズ不要。キーは`font_size`、デフォルト値は14.0（現在のハードコード値と同一）。

### 3. フォント種別の永続化と選択肢

**決定**: フォント種別をenum `FontFamily`で定義し、`.name`で文字列保存する。キーは`font_family`。

選択可能なフォント:
| Enum値 | 表示名 | fontFamily値 |
|--------|--------|-------------|
| `system` | システムデフォルト | `null`（Flutterデフォルト） |
| `hiraginoMincho` | ヒラギノ明朝 | `Hiragino Mincho ProN` |
| `hiraginoKaku` | ヒラギノ角ゴ | `Hiragino Kaku Gothic ProN` |
| `yumincho` | 游明朝 | `YuMincho` |
| `yuGothic` | 游ゴシック | `YuGothic` |

**理由**: macOSデスクトップアプリのため、macOSに標準搭載されている日本語フォントを選択肢とする。明朝体とゴシック体の両系統を提供することで、小説閲覧に適したフォント選択が可能になる。enumで管理することで型安全性を確保する。

**代替案**: 文字列リストで管理 → 型安全性が低く、存在しないフォント名の混入リスクがある。

### 4. テキスト表示への反映方法

**決定**: `TextViewerPanel`で`fontSizeProvider`と`fontFamilyProvider`をwatchし、`TextStyle`を構築して子ウィジェット（`VerticalTextViewer`、横書き`SelectableText.rich`）に渡す。

```
fontSizeProvider + fontFamilyProvider
  → TextViewerPanel (TextStyle構築)
    → VerticalTextViewer.baseStyle
    → SelectableText.rich style
```

**理由**: 現在の`TextViewerPanel`が既にテキストスタイルの起点になっており（`Theme.of(context).textTheme.bodyMedium`）、ここでフォント設定を統合するのが自然。子ウィジェットは既に`baseStyle`パラメータを受け取る設計になっている。

### 5. 設定UIの配置

**決定**: 既存の`SettingsDialog`内に、表示モードの下にフォントサイズ用`Slider`とフォント種別用`DropdownButton`を追加する。

**理由**: 設定画面が一箇所に集約され、ユーザーが設定項目を見つけやすい。新しいダイアログやタブは現時点では不要。

### 6. 縦書きページネーションの文字寸法計算: TextPainterによる実測

**問題**: フォントサイズ・フォント種別を変更すると、縦書きモードで以下の不具合が発生する。
1. テキストが左パネルまでオーバーフローする
2. カラム内の改行位置が正しく更新されない

**原因**: `_paginateLines()`で使用するカラム幅（`columnWidth = fontSize + _kRunSpacing`）と文字高さ（`charHeight = fontSize * _kTextHeight`）が推定値であり、実際のレンダリング寸法と一致しない。フォントメトリクス（グリフ幅、行高さ）はフォント種別やサイズによって異なるため、推定値ベースの計算では`maxColumnsPerPage`や`charsPerColumn`が実際のレンダリング結果と乖離する。結果として`Wrap`ウィジェットが想定と異なるカラムブレイクを発生させる。

**決定**: `TextPainter`で代表文字（'あ'）を実測し、その結果をページネーション計算に使用する。

```
// Before (推定値)
final charHeight = fontSize * _kTextHeight;
final columnWidth = fontSize + _kRunSpacing;

// After (実測値)
final painter = TextPainter(
  text: TextSpan(text: 'あ', style: baseStyle?.copyWith(height: _kTextHeight)),
  textDirection: TextDirection.ltr,
)..layout();
final charHeight = painter.height;
final columnWidth = painter.width + _kRunSpacing;
```

**理由**: CJK文字のグリフ寸法はフォントごとに異なり、`fontSize`は論理サイズであって実際のレンダリング寸法ではない。`TextPainter.layout()`により現在のフォント設定での実寸法を取得でき、ページネーション計算と`Wrap`ウィジェットのレンダリングが一致する。

**代替案**: 安全マージンを加算（`fontSize * 1.2`等） → フォントごとの差を吸収しきれず、余白が大きくなりすぎるケースもある。実測が最も正確かつ汎用的。

## Risks / Trade-offs

- **[フォントの可用性]** macOS以外のプラットフォーム（将来対応する場合）では指定フォントが存在しない可能性がある → `FontFamily.system`がデフォルトのため、フォールバックは安全。将来のクロスプラットフォーム対応時にプラットフォーム別フォントリストを検討する。

- **[レイアウト再計算コスト]** フォントサイズ変更時に縦書きページネーション全体の再計算が走る → 既存の`didUpdateWidget`で対応済み。`TextPainter`による計測はページネーション呼び出し毎に1回のみで軽量。極端に大きなテキストでのパフォーマンスは許容範囲内と想定（必要に応じてプロファイリング）。

- **[設定ダイアログの肥大化]** 設定項目が増えると1画面に収まらなくなる → 現時点では3項目（表示モード、フォントサイズ、フォント種別）のため問題なし。将来的に設定がさらに増えた場合はタブ化やセクション分けを検討する。
