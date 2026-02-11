## Context

NovelViewerは3カラム構成のFlutterデスクトップアプリで、左辺にファイルブラウザ、中央にテキストビューア、右辺に検索・要約パネルを持つ。現在、中央カラムの`SelectableText`でテキスト選択は可能だが、選択テキストの追跡やキーボードショートカットは未実装。右辺カラムはプレースホルダーのみ。状態管理にはFlutter Riverpodを使用している。

## Goals / Non-Goals

**Goals:**

- テキストビューアで選択した文字列をCmd+F / Ctrl+Fで検索できるようにする
- 現在のディレクトリ内の全テキストファイルを対象に全文検索を実行する
- 検索結果を右辺カラム下段に、ファイル名と該当箇所のコンテキスト付きで表示する
- 右辺カラムを上段（LLM要約エリア）・下段（検索結果）の2段構成にする
- 検索結果のファイル名クリックで該当ファイルを開けるようにする

**Non-Goals:**

- LLM要約機能の実装（上段はプレースホルダーのみ、別変更で実装予定）
- 正規表現検索や高度な検索オプション
- 検索インデックスの構築やキャッシュ機構
- 検索結果内のハイライト表示

## Decisions

### 1. テキスト選択状態の管理方式

**決定**: `selectedTextProvider`（StateProvider<String?>）を`text_viewer`のprovidersに追加し、`SelectableText`の`onSelectionChanged`コールバックで選択テキストを更新する。

**理由**: Riverpodの既存パターンに合致し、検索機能から選択テキストにリアクティブにアクセスできる。`TextEditingController`を使う方法もあるが、選択テキストの共有が目的であり、StateProviderの方がシンプル。

### 2. キーボードショートカットの実装方式

**決定**: Flutterの`Shortcuts` + `Actions`ウィジェットを使用し、`HomeScreen`レベルでCmd+F / Ctrl+Fをインターセプトする。

**理由**: Flutterの公式推奨パターンであり、プラットフォーム差異（macOS: meta+F, Windows/Linux: control+F）を`SingleActivator`で簡潔に扱える。`RawKeyboardListener`よりも宣言的で保守性が高い。ショートカット発火時に`selectedTextProvider`の値を読み取り、検索を実行する。

### 3. 検索サービスの設計

**決定**: `TextSearchService`クラスを新規作成し、ディレクトリパスと検索語を受け取り、検索結果のリストを返す純粋なサービスとして実装する。

**理由**: UIから独立したサービスとして設計することで、テスタビリティが高くなる。既存の`TextFileReader`を内部で再利用してファイル読み込みを行う。検索はシンプルな文字列マッチ（大文字小文字区別なし）とし、各マッチに対して前後の文字列をコンテキストとして抽出する。

### 4. 検索結果のデータモデル

**決定**: `SearchResult`（ファイル名、ファイルパス、マッチリスト）と`SearchMatch`（行番号、マッチ前後のコンテキストテキスト）の2クラスで構成する。

**理由**: ファイル単位でグループ化することで、UIでの表示が自然になる。コンテキストテキストを保持することで、検索結果の前後関係をユーザーに提示できる。

### 5. 検索状態の管理

**決定**: `searchQueryProvider`（StateProvider<String?>）で検索語を、`searchResultsProvider`（FutureProvider）で検索結果を管理する。`searchResultsProvider`は`searchQueryProvider`と`currentDirectoryProvider`をwatchし、いずれかの変更で再検索する。

**理由**: Riverpodのリアクティブな依存関係により、検索語やディレクトリの変更に自動で追従できる。FutureProviderを使うことで、ローディング状態やエラー状態もAsyncValueで自然に扱える。

### 6. 右辺カラムのレイアウト構成

**決定**: `SearchSummaryPanel`を上段・下段の2段構成に変更する。上段はLLM要約のプレースホルダー（`Expanded(flex: 1)`）、下段は検索結果パネル（`Expanded(flex: 2)`）とし、`Column`と`Divider`で分割する。

**理由**: proposalの要件に従い、将来のLLM要約機能の統合を見据えた構成。flex比率で自然な領域分割を実現する。

### 7. 検索結果からのファイル遷移

**決定**: 検索結果のファイル名をタップすると、`selectedFileProvider`を更新して該当ファイルをテキストビューアで開く。

**理由**: 既存の`selectedFileProvider`の仕組みを再利用でき、新しいナビゲーション機構を追加する必要がない。

## Risks / Trade-offs

- **大量ファイルでの検索パフォーマンス**: 数百ファイル以上のディレクトリでは検索に時間がかかる可能性がある → 初期実装ではシンプルな逐次検索とし、ローディングインジケータを表示する。パフォーマンス問題が顕在化した場合にIsolateによる並列処理を検討する。
- **SelectableTextのonSelectionChanged制約**: Flutterの`SelectableText`はプラットフォームによって`onSelectionChanged`の挙動が異なる場合がある → テストで各プラットフォームの挙動を確認し、必要に応じてフォールバック実装を検討する。
- **ブラウザのCmd+F / Ctrl+Fとの競合**: デスクトップアプリのためブラウザとの競合はないが、macOSのシステムショートカットとの競合可能性がある → `Shortcuts`ウィジェットはアプリ内のみで動作するため、問題にならない見込み。
