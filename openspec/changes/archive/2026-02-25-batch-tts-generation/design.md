## Context

現在のTTS機能はリアルタイム合成+再生方式で、`TtsPlaybackController` が文分割→Isolate合成→一時WAVファイル書き込み→再生をprefetch付きで逐次実行する。qwen3-tts.cppの合成速度は再生速度に追いつかず、待ち時間が発生する。

小説データは `{library}/{folder_name}/` 配下にテキストファイルとして保存され、エピソード情報は同フォルダ内の `episode_cache.db` に格納されている。既存のDBパターン（`EpisodeCacheDatabase`）に倣い、小説フォルダ内に専用DBを配置する。

## Goals / Non-Goals

**Goals:**
- 事前バッチ生成方式への完全移行（リアルタイム合成+再生の削除）
- 文単位の音声をSQLite BLOBとして永続保存
- 進捗バー付きのバッチ生成UI
- 一時停止/再開、テキスト位置指定再生
- 生成中のキャンセル対応
- 生成済み音声の削除機能

**Non-Goals:**
- 登場人物ごとの声色変更（将来の開発）
- 1文単位の部分再生成・編集モード（将来の開発）
- 途中までの生成データの保持（キャンセル時は破棄）
- ページ離脱時のバックグラウンド生成続行

## Decisions

### 1. DB配置: 小説フォルダ内に `tts_audio.db` を新設

**選択**: `{novel_folder}/tts_audio.db` として小説フォルダ内に配置

**代替案**:
- episode_cache.db にテーブル追加 → 音声BLOBで肥大化し、軽量なエピソードキャッシュに影響
- novel_metadata.db に集約 → 全小説の音声が1ファイルに集中し、GB単位になりうる

**理由**: `EpisodeCacheDatabase` と同じパターンで、小説単位でDBを分離。音声データの削除も `tts_audio.db` ファイル削除で完結。

### 2. 音声保存形式: WAVヘッダ付きBLOB

**選択**: 文単位でWAVヘッダ付き16bit PCMをBLOBに格納

**代替案**:
- Raw PCM → 再生時にWAVヘッダ構築が毎回必要
- 1ファイル結合WAV → 部分再生成が困難（将来の拡張に不利）

**理由**: 既存の `WavWriter` でFloat32→WAV変換済みのバイト列をそのまま保存。再生時はBLOBを一時ファイルに書き出して `just_audio` に渡す。

### 3. 再生方式: 文単位の逐次再生（DBから取得）

**選択**: `tts_segments` から `segment_index` 順にWAV BLOBを取得し、1文ずつ再生

**代替案**:
- 全音声を結合して1つのWAVとして再生 → シークは楽だがDB保存と矛盾、部分再生成に不利

**理由**: 文単位のDB保存設計と整合。再生時は現在のセグメントのWAV BLOBを一時ファイルに書き出し、`just_audio` で再生。次のセグメントはバッファリング（再生中に次のBLOBを読み込んでおく）で隙間を最小化。合成ではなくDB読み込みなので十分高速。

### 4. 生成と再生の責務分離

**選択**: `TtsGenerationController`（生成専用）と `TtsStoredPlayerController`（再生専用）に分離

**代替案**:
- 1つのコントローラで両方管理 → 状態管理が複雑化

**理由**: 生成と再生は同時に行わない。生成はIsolateとDB書き込みを管理、再生はDB読み込みとAudioPlayerを管理。関心の分離により、テストも容易。

### 5. 状態管理: 既存プロバイダの拡張

```
TtsAudioState (新設: エピソードの音声生成状態)
├── none        ← 音声なし
├── generating  ← 生成中 (progress: 3/15)
└── ready       ← 生成済み

TtsPlaybackState (変更: 再生状態)
├── stopped     ← 停止中
├── playing     ← 再生中
└── paused      ← 一時停止中 (新設)
```

`loading` 状態は不要になる（事前生成済みのため再生開始時の待ちなし）。

### 6. テキスト位置→セグメント特定

SQLクエリで直接マッピング:
```sql
SELECT * FROM tts_segments
WHERE episode_id = ? AND text_offset <= ?
ORDER BY text_offset DESC LIMIT 1
```

テキスト選択位置のoffsetから該当セグメントを特定し、そのsegment_indexから再生を開始する。

### 7. 一時停止/再開の実装

`just_audio` の `pause()` / `play()` をそのまま活用。一時停止→再開でセグメント途中から継続。`TtsAudioPlayer` 抽象に `pause()` メソッドを追加。

### 8. エピソード識別: file_name ベース

`tts_episodes` テーブルで `file_name`（例: `0001_プロローグ.txt`）をユニークキーとして使用。現在表示中のファイル名から音声データの有無を判定。

## アーキテクチャ

```
┌──────────────────────────────────────────────────────────┐
│ UI Layer                                                 │
│                                                          │
│ TextViewerPanel                                          │
│ ├─ watches: ttsAudioStateProvider (none/generating/ready)│
│ ├─ watches: ttsPlaybackStateProvider (stopped/playing/   │
│ │           paused)                                      │
│ ├─ watches: ttsHighlightRangeProvider                    │
│ ├─ watches: ttsGenerationProgressProvider (3/15)         │
│ └─ ボタン表示ロジック:                                     │
│    none       → [🔊 音声生成]                             │
│    generating → 進捗バー + [✕ キャンセル]                   │
│    ready      → [▶ 再生] [🗑 削除]                        │
│    playing    → [⏸ 一時停止] [⏹ 停止]                    │
│    paused     → [▶ 再開] [⏹ 停止]                        │
└────────────┬───────────────────────────────┬─────────────┘
             │                               │
    ┌────────▼─────────┐          ┌──────────▼───────────┐
    │ TtsGeneration     │          │ TtsStoredPlayer      │
    │ Controller        │          │ Controller           │
    │                   │          │                      │
    │ TextSegmenter     │          │ DB → WAV BLOB取得    │
    │ ↓                 │          │ ↓                    │
    │ TtsIsolate        │          │ 一時ファイル書き出し   │
    │ (文ごと合成)       │          │ ↓                    │
    │ ↓                 │          │ JustAudioPlayer      │
    │ WavWriter→bytes   │          │ (play/pause/stop)    │
    │ ↓                 │          │ ↓                    │
    │ DB保存            │          │ ハイライト更新        │
    │ ↓                 │          │ 自動ページ送り        │
    │ 進捗通知           │          │                      │
    └────────┬─────────┘          └──────────┬───────────┘
             │                               │
    ┌────────▼───────────────────────────────▼───────────┐
    │ TtsAudioDatabase + TtsAudioRepository              │
    │                                                    │
    │ tts_episodes: エピソード単位の生成状態               │
    │ tts_segments: 文単位のWAV BLOB + メタデータ          │
    └────────────────────────────────────────────────────┘
```

## Risks / Trade-offs

**[DB肥大化]** 音声BLOBにより `tts_audio.db` が数百MBになる可能性
→ 小説フォルダ内に隔離しているため他のDBに影響なし。削除ボタンで容量回収可能。

**[一時ファイル書き出しのオーバーヘッド]** 再生ごとにBLOBを一時ファイルに書く必要がある
→ 1文あたり数十KB〜数百KBで、SSD上では数ms。次セグメントの先読みで隙間を最小化。

**[テキスト変更時の音声不整合]** 小説更新でテキストが変わると、保存済み音声のoffsetがずれる
→ 今回はスコープ外。将来的にはテキストハッシュで検知し再生成を促す仕組みが必要。

**[キャンセル時のデータ破棄]** 長時間生成後のキャンセルで全データを失う
→ 今回の開発方針として許容。生成開始時に既存データを削除し、最初からやり直す。将来的に途中保存対応を検討。
