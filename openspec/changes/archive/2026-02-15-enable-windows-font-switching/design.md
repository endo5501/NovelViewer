## Context

NovelViewerのフォント設定機能は既に実装されているが、プラットフォームの違いを考慮していない。`FontFamily` enumに定義された5つのフォント（システムデフォルト、ヒラギノ明朝、ヒラギノ角ゴ、游明朝、游ゴシック）がすべてのプラットフォームで表示される。Windows上ではヒラギノフォントが存在しないため選択しても効果がなく、システムデフォルト選択時はSegoe UIからのCJKフォールバックにより縦書き句読点の位置が不正になる。

現在のコード構造:
- `FontFamily` enum: フォント名と表示名を保持
- `SettingsDialog`: `FontFamily.values` をそのままドロップダウンに表示
- `TextViewerPanel`: `fontFamily.fontFamilyName` をそのまま `TextStyle` に渡す（`null`時はFlutterデフォルト）

## Goals / Non-Goals

**Goals:**
- Windows上でシステムデフォルトフォント選択時にYu Minchoへ暗黙フォールバックし、縦書き句読点を正しく表示する
- フォントドロップダウンに現在のプラットフォームで利用可能なフォントのみを表示する

**Non-Goals:**
- フォントの存在チェック（実際にインストールされているかの動的検証）
- 新たなフォントの追加（Meiryo等）
- フォントバンドル（アプリにフォントファイルを同梱すること）

## Decisions

### 1. フォールバックロジックの配置場所

**決定**: `FontFamily` enumに `effectiveFontFamilyName` ゲッターを追加し、プラットフォーム判定を含むフォールバックロジックをそこに集約する。

**理由**: フォント名の解決ロジックを `FontFamily` に閉じ込めることで、`TextViewerPanel` や将来のフォント利用箇所が個別にプラットフォーム判定する必要がなくなる。`text_viewer_panel.dart` では `fontFamily.fontFamilyName` を `fontFamily.effectiveFontFamilyName` に変えるだけで済む。

**代替案**: `TextViewerPanel` 側でプラットフォーム判定してフォールバック → フォント利用箇所が増えた場合に同じロジックが散在するため不採用。

### 2. プラットフォーム別フォントフィルタリングの方法

**決定**: `FontFamily` enumに `supportedPlatforms` プロパティ（またはプラットフォーム判定メソッド）を追加し、各フォントが利用可能なプラットフォームを定義する。`SettingsDialog` はフィルタリング済みのリストを表示する。

**プラットフォーム分類**:
| フォント | macOS | Windows |
|---------|-------|---------|
| system | o | o |
| hiraginoMincho | o | x |
| hiraginoKaku | o | x |
| yumincho | o | o |
| yuGothic | o | o |

**代替案**: ドロップダウン側でハードコードフィルタリング → フォント追加時にフィルタリング箇所の更新忘れが起きやすいため不採用。

### 3. Windowsフォールバック先の固定

**決定**: Windows上のシステムデフォルトフォールバック先をYu Mincho（`'Yu Mincho'`）に固定する。フォールバックチェーン（Yu Mincho → Yu Gothic → MS Mincho等）は設けない。

**理由**: 個人利用ツールであり、Yu MinchoはWindows 8.1以降に標準搭載されているため。

### 4. Windows上のフォント名

**決定**: Windows上では `'Yu Mincho'` および `'Yu Gothic'` を使用する（macOS上の `'YuMincho'`/`'YuGothic'` とは異なる可能性に注意）。

**理由**: Windowsでのフォント名はスペース区切りが一般的。実際の動作確認で正しいフォント名を検証する。

## Risks / Trade-offs

- **[Risk]** Yu Minchoのフォント名がWindows上で `'Yu Mincho'` なのか `'YuMincho'` なのか未確定 → 実装時に動作確認で検証する。既に `'YuMincho'` で実験して正常動作を確認しているため、まずはこれを使用する。
- **[Risk]** 保存済みの設定がプラットフォーム非対応のフォントを指している場合（macOSでヒラギノを選択→Windowsで起動など） → 利用可能フォント一覧に含まれない場合はシステムデフォルトにフォールバックする。ただし、個人利用ツールのためクロスプラットフォーム設定共有の可能性は極めて低く、積極的な対処は不要。
