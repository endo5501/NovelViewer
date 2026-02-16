## Context

現在の `HomeScreen` は3カラム構成（左: FileBrowserPanel 250px、中央: TextViewerPanel Expanded、右: SearchSummaryPanel 300px）を `Row` ウィジェットで実装している。右カラムは常に表示されており、閲覧時に本文領域が狭くなる問題がある。

状態管理には Riverpod を使用しており、`HomeScreen` は `ConsumerWidget` として実装されている。AppBar には既にダウンロードボタンと設定ボタンが配置されている。

## Goals / Non-Goals

**Goals:**

- 右カラム（SearchSummaryPanel）の表示・非表示をワンクリックで切り替えられるようにする
- 非表示時に中央カラムが全幅に拡張される
- トグル状態が直感的にわかるUIを提供する

**Non-Goals:**

- 左カラム（FileBrowserPanel）のトグルは対象外
- カラム幅のリサイズ機能は対象外
- トグル状態の永続化（アプリ再起動後の復元）は対象外
- アニメーション付きの表示・非表示切り替えは対象外（シンプルな即時切り替えとする）

## Decisions

### 1. 状態管理: Riverpod StateProvider を使用

右カラムの表示・非表示状態を `StateProvider<bool>` で管理する。

**理由**: プロジェクト全体で Riverpod を使用しており、単純な bool 値の管理には `StateProvider` が最適。`StateNotifierProvider` や `NotifierProvider` は過剰。

**代替案**:
- `StatefulWidget` に変換 → プロジェクトの方針と合わない。他のウィジェットから状態を参照できない
- `ValueNotifier` → Riverpod 管理下にない状態が増え一貫性が失われる

### 2. トグルボタンの配置: AppBar の actions に追加

既存のダウンロード・設定ボタンの前（左側）にトグルボタンを配置する。

**理由**: AppBar は常に見える場所であり、既にアクションボタンが配置されているため自然な位置。レイアウト制御のボタンとして直感的。

**代替案**:
- 右カラムとの境界にトグルアイコンを配置 → 右カラム非表示時にトグルボタンも消えてしまうため不適切
- キーボードショートカットのみ → 発見しにくく、初見ユーザーに不親切

### 3. レイアウト実装: 条件付きレンダリング

`Row` 内で `if` 文を使い、右カラムと `VerticalDivider` を条件付きで表示する。`Row` の `const` 修飾は削除する（状態依存のため）。

**理由**: 最もシンプルで Flutter の標準的なパターン。アニメーションが不要なため、`AnimatedContainer` や `Visibility` は不要。

**代替案**:
- `Visibility(visible: ..., maintainSize: true)` → 非表示時もスペースを占有するため目的に合わない
- `AnimatedContainer(width: isVisible ? 300 : 0)` → 要件外のアニメーションが入り複雑化する

### 4. アイコン: 状態に応じた切り替えアイコン

表示時は `Icons.vertical_split`（パネル分割表示）、非表示時は `Icons.view_sidebar`（サイドバー復元）を使用する。

**理由**: Material Icons で利用可能なアイコンから、パネルの表示・非表示を直感的に表すものを選択。

## Risks / Trade-offs

- **`const Row` の削除** → 状態に応じた条件付きレンダリングのため `const` を外す必要がある。微小なパフォーマンス影響があるが、実質的に問題にならない
- **状態の非永続化** → アプリ再起動時にリセットされる。ユーザーが毎回トグルする手間があるが、シンプルさを優先。将来的に永続化が必要になれば `SharedPreferences` で対応可能
