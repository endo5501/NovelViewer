## Context

NovelViewerは3カラムレイアウトのFlutterデスクトップアプリで、右辺カラムは上段（LLM要約）と下段（検索結果）に分かれている。現在、上段はプレースホルダー（`search_summary_panel.dart`の`llm_summary_section`）のみ。

既存アーキテクチャ:
- 状態管理: Riverpod（NotifierProvider パターン）
- DB: SQLite（`sqflite_common_ffi`）。`NovelDatabase`クラスで管理、現在version 1
- 設定: `SharedPreferences` + `SettingsRepository`
- 検索: `TextSearchService`がディレクトリ内の.txtファイルを全検索、結果は`SearchResult`/`SearchMatch`モデル
- テキスト選択: `selectedTextProvider`で選択中テキストを管理、Ctrl+Fで検索クエリに連動

参考実装としてGenGlossaryプロジェクトがあり、Ollama/OpenAI互換APIへのLLMクライアント実装、用語検索・要約プロンプトが存在する。

## Goals / Non-Goals

**Goals:**
- 選択した単語のLLM要約を「ネタバレあり」「ネタバレなし」タブで表示する
- LLM設定（プロバイダ選択、接続情報）を設定画面で管理できるようにする
- 解析結果をDBにキャッシュし、再選択時に即表示する
- 「解析開始」ボタンで明示的に解析を実行し、再解析でキャッシュを更新する

**Non-Goals:**
- 形態素解析による自動用語抽出（GenGlossaryのSudachiPy相当）は対象外。ユーザーが手動で選択した単語のみ対象
- 用語集の一括生成・レビュー・リファインメント（GenGlossaryの4段階パイプライン）は対象外
- LLMのストリーミングレスポンス表示（将来的な拡張として残す）

## Decisions

### 1. Feature構成: `llm_summary`フィーチャーの新設

`lib/features/llm_summary/`に以下の構造で新規フィーチャーを作成する。

```
lib/features/llm_summary/
├── data/
│   ├── llm_client.dart           # LLMクライアント抽象クラス
│   ├── ollama_client.dart        # Ollama実装
│   ├── openai_compatible_client.dart  # OpenAI互換API実装
│   ├── llm_summary_service.dart  # 要約ビジネスロジック
│   ├── llm_summary_repository.dart   # DBキャッシュ操作
│   └── llm_prompt_builder.dart   # プロンプト生成
├── domain/
│   ├── llm_config.dart           # LLM設定モデル
│   └── llm_summary_result.dart   # 要約結果モデル
├── presentation/
│   └── llm_summary_panel.dart    # 要約表示UI（タブ、解析ボタン）
└── providers/
    └── llm_summary_providers.dart
```

**理由**: 既存のfeatureディレクトリ構造（data/domain/presentation/providers）に従い、一貫性を保つ。

### 2. LLMクライアント設計: 抽象クラス + プロバイダ切り替え

```dart
abstract class LlmClient {
  Future<String> generate(String prompt);
}

class OllamaClient implements LlmClient { ... }
class OpenAiCompatibleClient implements LlmClient { ... }
```

`http`パッケージ（既に依存に含まれる）を使用してHTTPリクエストを送信する。

**Ollamaエンドポイント**: `POST {baseUrl}/api/generate`（非ストリーミング、`stream: false`）
**OpenAI互換エンドポイント**: `POST {baseUrl}/chat/completions`

**理由**: GenGlossaryと同じ抽象化パターンを採用。既存の`http`パッケージで十分であり、追加依存は不要。

### 3. LLM設定の永続化: SharedPreferences

LLM設定は既存の`SettingsRepository`を拡張して`SharedPreferences`に保存する。

保存キー:
- `llm_provider`: `'ollama'` | `'openai'`
- `llm_ollama_base_url`: デフォルト `http://localhost:11434`
- `llm_ollama_model`: モデル名
- `llm_openai_base_url`: エンドポイントURL
- `llm_openai_api_key`: APIキー
- `llm_openai_model`: モデル名

**理由**: 既存設定（displayMode, fontSize, fontFamily）と同じパターンを踏襲。設定項目が少なく、DBに別テーブルを作るほどの複雑さはない。APIキーについてはデスクトップアプリでありローカル保存で十分。

### 4. 要約キャッシュDB: `word_summaries`テーブル追加

`NovelDatabase`のバージョンを2に上げ、`onUpgrade`で新テーブルを作成する。

```sql
CREATE TABLE word_summaries (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  folder_name TEXT NOT NULL,
  word TEXT NOT NULL,
  summary_type TEXT NOT NULL,  -- 'spoiler' | 'no_spoiler'
  summary TEXT NOT NULL,
  source_file TEXT,            -- ネタバレなし時の基準ファイル名
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);
CREATE UNIQUE INDEX idx_word_summaries_unique
  ON word_summaries(folder_name, word, summary_type);
```

**理由**: `folder_name` + `word` + `summary_type`の組み合わせで一意にキャッシュを管理。ネタバレなしの場合は`source_file`で基準位置を記録し、同じファイル位置から再度選択した場合にキャッシュヒットさせる。

### 5. ネタバレあり/なしの検索範囲制御

既存の`TextSearchService.search()`の結果を活用し、要約サービスで範囲をフィルタリングする。

- **ネタバレあり**: `TextSearchService`の検索結果をそのまま全件使用
- **ネタバレなし**: 検索結果のうち、現在閲覧中のファイル（`selectedFileProvider`）のファイル名番号以下のものだけを使用

各検索マッチの`contextText`（マッチ行）に加え、前後の行も含めたコンテキストを取得する拡張を行う。`TextSearchService`に`searchWithContext(directoryPath, query, {contextLines: 2})`メソッドを追加する。

**理由**: 既存の検索サービスを拡張することで、検索結果パネルとLLM要約で同じ検索ロジックを共有する。

### 6. プロンプト設計

GenGlossaryの`glossary_generator.py`のプロンプトを参考に、以下の構造で要約プロンプトを生成する。

```
あなたは小説の用語を解説するアシスタントです。
以下の<term>タグ内の用語について、<context>タグ内の文脈情報を元に
1〜2文で簡潔に説明してください。

<term>{選択した単語}</term>

<context>
{検索結果近傍テキスト（最大件数制限付き）}
</context>

JSON形式で回答してください: {"summary": "..."}
```

ネタバレなしの場合はプロンプトに「この用語についてここまでの情報のみから説明してください。今後の展開についてのネタバレは含めないでください」を追加する。

**理由**: GenGlossaryのXMLタグによるプロンプトインジェクション対策パターンを踏襲。JSON出力で解析を容易にする。

### 7. UI構成: タブ + 解析ボタン + 状態表示

`LlmSummaryPanel`ウィジェットで`search_summary_panel.dart`の上段プレースホルダーを置き換える。

```
┌─────────────────────────┐
│ [ネタバレなし][ネタバレあり]  │  ← TabBar
├─────────────────────────┤
│                         │
│   要約テキスト表示エリア    │  ← キャッシュがあれば表示
│                         │
├─────────────────────────┤
│      [解析開始]           │  ← ボタン（解析中はローディング表示）
└─────────────────────────┘
```

状態遷移:
1. 単語未選択 → 「単語を選択してください」表示
2. 単語選択済み・キャッシュなし → 空 + 「解析開始」ボタン
3. 単語選択済み・キャッシュあり → キャッシュ結果表示 + 「解析開始」ボタン（再解析用）
4. 解析中 → ローディングインジケータ + 中止不可
5. 解析完了 → 結果表示 + 「解析開始」ボタン
6. LLM未設定 → 「設定画面でLLMを設定してください」表示

**理由**: 明示的な「解析開始」ボタンにより、ユーザーが意図したタイミングでのみLLMリクエストが発生する。自動解析はAPIコスト・レスポンス時間の観点から避ける。

### 8. データフロー全体像

```
ユーザーが単語選択
  → selectedTextProvider 更新
  → Ctrl+F で searchQueryProvider 更新
  → searchResultsProvider が検索実行
  → LlmSummaryPanel が selectedTextProvider を watch
    → DBキャッシュを検索
    → キャッシュあり → 表示
    → キャッシュなし → 「解析開始」ボタン待ち

「解析開始」押下
  → searchResultsProvider の結果を取得
  → ネタバレなし/ありに応じて範囲フィルタ
  → searchWithContext() でコンテキスト付き検索結果取得
  → LlmPromptBuilder でプロンプト生成
  → LlmClient.generate() で要約取得
  → LlmSummaryRepository でDBにキャッシュ保存
  → UI更新
```

## Risks / Trade-offs

- **[LLMレスポンス時間]** → ローディングインジケータで明示。将来的にストリーミング対応も可能だが初期実装ではスコープ外
- **[APIキーのローカル保存]** → デスクトップアプリの用途上、SharedPreferencesでの保存で十分。プラットフォームのキーチェーン統合は将来課題
- **[コンテキスト長制限]** → 検索結果が多い場合、プロンプトに含めるコンテキストの上限を設ける（最大10件程度）。超過分は切り捨て
- **[ネタバレなしキャッシュの位置依存]** → 読み進めた後に同じ単語を検索すると、以前のキャッシュが表示される。`source_file`をキーに含めることで、位置が変わった場合は再解析を促すUXとする（キャッシュは残すが「基準位置が異なります。再解析しますか？」と表示）
- **[DBマイグレーション]** → version 1→2のマイグレーション。`onUpgrade`でCREATE TABLEのみなので既存データへの影響なし
