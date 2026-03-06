# コンテキストメニューから辞書追加 & 縦書きコンテキストメニュー対応

## 概要

テキスト選択→右クリックで「辞書追加」メニューを表示し、選択テキストを表記欄にプリセットした辞書ダイアログを開く。
また、縦書き表示でも右クリックコンテキストメニュー（コピー/辞書追加）を表示可能にする。

## 動機

- 現状、辞書登録はTTS編集画面からのみ。登録すべき文字列を覚えて画面遷移する必要がある
- 閲覧画面でテキスト選択→右クリック→辞書追加の導線があれば、ユーザの負担が大幅に軽減される
- 縦書き表示では右クリックコンテキストメニュー自体が未実装で、コピーすらできない

## スコープ

### 対象画面と変更内容

| 画面 | 表示モード | 現状 | 変更後 |
|------|-----------|------|--------|
| 閲覧画面 | 横書き | コピー/すべて選択（Flutter標準） | コピー/すべて選択/**辞書追加** |
| 閲覧画面 | 縦書き | メニューなし | **コピー/辞書追加** |
| 編集画面 | TextField | Flutter標準メニュー | 標準メニュー + **辞書追加** |

### 辞書ダイアログの変更

- `TtsDictionaryDialog` に `initialSurface` オプショナルパラメータを追加
- 渡された場合、表記欄にプリセット表示
- ダイアログを閉じると呼び出し元画面に戻る（既存動作と同じ）

## スコープ外

- 辞書ダイアログ自体のUI変更
- 辞書の読み自動推定
- 閲覧画面以外（ブックマーク一覧等）へのコンテキストメニュー追加

## 技術的アプローチ

### 横書き閲覧画面
- `SelectableText.rich` の `contextMenuBuilder` パラメータでカスタムメニューを構築
- Flutter標準の `AdaptiveTextSelectionToolbar` をベースに「辞書追加」ボタンを追加

### 縦書き閲覧画面
- `VerticalTextPage` の `GestureDetector` に `onSecondaryTapUp` を追加
- テキストが選択されている場合、`showMenu()` で「コピー」「辞書追加」を表示
- 既存パターン（bookmark_list_panel, file_browser_panel）と同じ `showMenu` 方式

### 編集画面（TtsEditDialog）
- 各 `TextField` に `contextMenuBuilder` でカスタムメニューを追加
- Flutter標準メニューに「辞書追加」を追加

### 辞書ダイアログへの初期値渡し
- `TtsDictionaryDialog` コンストラクタと `show()` メソッドに `initialSurface` を追加
- `_surfaceController` の初期値として設定

### 辞書リポジトリへのアクセス
- 閲覧画面: `TextViewerPanel` の `_streamingDictDb` から `TtsDictionaryRepository` を生成
  - ストリーミング未開始の場合は `currentDirectoryProvider` から新規作成
- 編集画面: 既存の `_dictRepository` を利用

## i18n

新規ローカライゼーションキー:
- `contextMenu_addToDictionary`: "辞書追加" / "Add to Dictionary" / "添加到词典"
