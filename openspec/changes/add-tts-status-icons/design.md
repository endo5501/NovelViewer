## Context

ファイルブラウザ（`FileBrowserPanel`）はエピソード一覧をプレーンな `ListTile` で表示しており、TTS読み上げデータの生成状態を示す視覚的情報がない。TTS状態は `tts_audio.db` の `tts_episodes.status` カラムに格納されているが、テキストビューアでファイルを開くまで確認できない。

現在の `DirectoryContents` はファイル一覧とサブディレクトリ一覧のみを保持し、TTS関連情報を含んでいない。`directoryContentsProvider` はディレクトリ変更時にファイル情報を取得する既存のフローを持つ。

## Goals / Non-Goals

**Goals:**
- エピソード一覧でTTS状態（生成済み / 一部生成 / 未生成）を一目で判別可能にする
- 既存の `directoryContentsProvider` の取得フローにTTS状態取得を統合する
- TTS未使用のフォルダでは追加の視覚ノイズを発生させない

**Non-Goals:**
- ライブラリルートの小説フォルダ一覧へのTTS状態サマリー表示
- TTS生成中のリアルタイム進捗表示（既存のテキストビューアで対応済み）
- セグメント単位の詳細な生成状況表示

## Decisions

### Decision 1: TtsEpisodeStatus enum の導入

DB の status 文字列（`generating`, `partial`, `completed`）をアプリ層で扱う `TtsEpisodeStatus` enum に変換する。

- `none` — DBにレコードなし（TTS未使用）
- `partial` — DB status が `generating` または `partial`（生成途中）
- `completed` — DB status が `completed`

**理由**: DB の `generating` と `partial` はUI上の意味が同じ（全セグメント生成されていない）ため、UIでは `partial` に統合する。`none` は DB未登録を表し、DB status とは別概念のためenumで明示する。

**定義場所**: `lib/features/tts/data/tts_audio_repository.dart` に `TtsEpisodeStatus` enum を定義する。TTS データ層の概念であり、リポジトリと同じファイルに配置するのが自然。

### Decision 2: 一括クエリによる状態取得

`TtsAudioRepository` に `getAllEpisodeStatuses()` メソッドを追加し、`SELECT file_name, status FROM tts_episodes` で全エピソードを一括取得する。

**代替案**: エピソードごとに `findEpisodeByFileName()` を呼ぶ方法。N回のクエリが必要になり、エピソード数が多い小説（数百話）では非効率。

**理由**: 1回のSQLiteクエリで全情報を取得でき、パフォーマンスが安定する。

### Decision 3: DirectoryContents への統合

`DirectoryContents` に `ttsStatuses` フィールド（`Map<String, TtsEpisodeStatus>`）を追加する。key は `file_name`。

**代替案**: 独立した `ttsStatusMapProvider` を作る方法。ディレクトリ変更への追従やProvider間同期が必要になり複雑。

**理由**: ファイル一覧とTTS状態は同じタイミングで取得・表示されるため、`DirectoryContents` に含めるのが最もシンプル。

### Decision 4: DB存在チェックとフォールバック

`directoryContentsProvider` 内で `tts_audio.db` のファイル存在チェックを行い、存在する場合のみDBを開いて状態を取得する。存在しない場合は空マップを返す。

**理由**: TTS機能を一度も使用していないフォルダでDB作成や接続を行うのは不要。`File.existsSync()` でチェックし、フォールバックする。

### Decision 5: アイコンデザイン

| 状態 | アイコン | 色 | 表示 |
|---|---|---|---|
| `completed` | `Icons.check_circle` | `Colors.green` | 表示 |
| `partial` | `Icons.pie_chart` | `Colors.orange` | 表示 |
| `none` | — | — | 非表示 |

**理由**: TTS編集ダイアログのセグメント行と同じアイコンスタイルを採用し一貫性を保つ。`none` を非表示にすることで、TTS未使用のフォルダでは従来と同じ見た目を維持する。

### Decision 6: 状態更新のタイミング

TTS生成完了後に `directoryContentsProvider` を `ref.invalidate()` で再取得させる。TextViewerPanel内のTTS生成処理完了時にinvalidateを呼ぶ。

**理由**: リアルタイム更新は Non-Goal であり、生成完了時の再取得で十分。既存の `ref.invalidate()` パターンを流用しシンプルに保つ。

## Risks / Trade-offs

- **[DB接続の管理]** → `directoryContentsProvider` 内で一時的にDBを開閉する。既存の `TtsAudioDatabase` クラスのインスタンスを使い捨てで作成するため、生成中にDBロックが競合する可能性がある。→ SQLiteのWALモードにより読み取りは書き込みと競合しないため、ミティゲーション不要。
- **[ファイル一覧再取得のコスト]** → TTS状態更新のために `directoryContentsProvider` をinvalidateするとファイル一覧も再取得される。→ ローカルファイルシステムの一覧取得は高速であり、実用上問題なし。
