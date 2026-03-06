## Context

現在、TTS辞書の登録はTTS編集画面（`TtsEditDialog`）のツールバーボタンからのみ行える。ユーザは閲覧画面で見つけた難読漢字を覚え、編集画面に遷移してから辞書ダイアログを開いて登録する必要がある。

横書き表示では `SelectableText.rich` によりFlutter標準のコンテキストメニュー（コピー/すべて選択）が表示されるが、縦書き表示ではカスタムジェスチャー実装のためコンテキストメニューが存在しない。

## Goals / Non-Goals

**Goals:**
- 閲覧画面（横書き/縦書き）と編集画面でテキスト選択→右クリック→「辞書追加」の導線を追加
- 縦書き表示に右クリックコンテキストメニュー（コピー/辞書追加）を追加
- 辞書ダイアログに初期値（選択テキスト）を渡せるようにする

**Non-Goals:**
- 辞書ダイアログのUI変更
- 読みの自動推定
- 辞書登録後の自動適用（既存のTTS生成フローで適用される）

## Decisions

### 1. 横書き閲覧画面: `contextMenuBuilder` による拡張

**選択**: `SelectableText.rich` の `contextMenuBuilder` パラメータを使用してカスタムメニューを構築する。

**理由**: Flutter標準の方法であり、プラットフォームごとのメニュースタイルを維持しつつカスタムアクションを追加できる。`AdaptiveTextSelectionToolbar.buttonItems` に「辞書追加」ボタンを追加する形。

### 2. 縦書き閲覧画面: `showMenu()` によるポップアップ

**選択**: `VerticalTextPage` に `onSecondaryTapUp` を追加し、テキスト選択済みの場合に `showMenu()` で「コピー」「辞書追加」を表示する。

**理由**: 縦書きは自前のジェスチャー実装のため `contextMenuBuilder` が使えない。`showMenu()` は既にブックマーク一覧（`bookmark_list_panel.dart`）やファイルブラウザ（`file_browser_panel.dart`）で使用されており、コードベース内で一貫したパターン。

**代替案**: `Overlay` を使ったカスタムメニュー → 不採用。`showMenu()` で十分であり、既存パターンと統一できるため。

### 3. 編集画面: `contextMenuBuilder` による拡張

**選択**: `_TtsEditSegmentRow` の `TextField` に `contextMenuBuilder` を追加し、Flutter標準メニューに「辞書追加」を追加する。

**理由**: 横書き閲覧画面と同じアプローチで一貫性がある。全TextFieldに適用する。

### 4. 辞書ダイアログへの初期値渡し

**選択**: `TtsDictionaryDialog` と `TtsDictionaryDialog.show()` に `initialSurface` オプショナルパラメータを追加し、`_surfaceController` の初期値として設定する。

**理由**: 最小限の変更で目的を達成できる。既存の呼び出し箇所（TtsEditDialogのツールバー）は `initialSurface` を渡さないためデグレなし。

### 5. 辞書リポジトリのアクセス方法

**選択**: 閲覧画面では `currentDirectoryProvider` から `TtsDictionaryDatabase` → `TtsDictionaryRepository` を都度生成する。

**理由**: `_streamingDictDb` はTTSストリーミング中のみ存在するため、辞書追加はストリーミング非依存で動作すべき。`currentDirectoryProvider` は常に利用可能。

### 6. 縦書きコンテキストメニューのイベント処理

**選択**: `GestureDetector` に `onSecondaryTapUp` を追加。ただし `GestureDetector` は `onPan*` と `onSecondaryTapUp` を同時に認識できるため、競合しない。

**注意点**: `onSecondaryTapUp` は右クリック（マウスの第2ボタン）のみを検出する。縦書き表示の `onPanStart`/`onPanUpdate` は左クリック＋ドラッグなので干渉しない。

## Risks / Trade-offs

**[Risk] 縦書きでのGestureDetector競合** → `onSecondaryTapUp` は `onPan*` と独立して動作するため低リスク。テストで確認する。

**[Risk] 辞書DB接続の都度生成コスト** → SQLiteの接続は軽量。辞書追加は低頻度操作のため問題なし。

**[Trade-off] 横書きと縦書きで異なるメニュー実装** → Flutter標準の制約による。横書きは `contextMenuBuilder`（プラットフォームネイティブ風）、縦書きは `showMenu()`（Material風）で見た目が若干異なる。統一は困難だが、機能的には同等。
