## Context

現在のTTSは2つの独立したコントローラーで構成されている：

- `TtsGenerationController`: テキスト全文をセグメント化し、順次合成→DB保存。キャンセル時は全データ削除
- `TtsStoredPlayerController`: DB上の完成済みエピソードからセグメントを順次再生

この2段階フローでは、生成完了まで音声を聴けず、途中キャンセルでデータが失われる。

## Goals / Non-Goals

**Goals:**

- 生成したセグメントを即座に再生し、次のセグメントを先行生成するパイプラインを実現
- 途中停止時に生成済みデータを保持し、次回は保存済み分の再生→未生成分の生成+再生を継続
- テキスト変更時に既存データを自動無効化

**Non-Goals:**

- 複数セグメントの並列生成（TTS Isolateは1つのみ、順次生成のまま）
- 音声品質や生成速度の改善
- refWavPath変更時のデータ再生成（混在を許容）
- 既存の `TtsGenerationController` / `TtsStoredPlayerController` の削除（新コントローラーで置き換えるが、既存コードの段階的移行）

## Decisions

### 1. 統合コントローラー `TtsStreamingController` を新設

**決定**: 生成と再生を1つのコントローラーで管理する

**理由**: 生成と再生の協調制御（再生が生成に追いついた時の待機、セグメント完了→次セグメント再生のタイミング制御）は、2つのコントローラー間のメッセージングよりも1つのコントローラー内のロジックとして管理する方がシンプル

**代替案**:
- コーディネーターパターン（既存2コントローラーを調整する第3のコントローラー）→ 既存コントローラーの修正も必要で、結局3クラスの変更になり複雑
- イベントバスで疎結合 → 状態同期が複雑化し、デバッグが困難

**構造**:
```
TtsStreamingController
├── TtsIsolate (生成)
├── TtsAudioPlayer (再生)
├── TtsAudioRepository (DB)
├── TextSegmenter (テキスト分割)
└── 内部状態
    ├── _segments: List<TextSegment> (全セグメント情報)
    ├── _storedSegmentCount: int (DB上の保存済みセグメント数)
    ├── _currentPlayIndex: int (再生中のセグメントインデックス)
    ├── _generatedUpTo: int (生成完了済みの最大インデックス)
    └── _segmentReadyCompleters: Map<int, Completer> (生成待ちの通知用)
```

### 2. Producer-Consumer パターンで生成と再生を協調

**決定**: 生成ループと再生ループを並行実行し、Completer で同期する

**理由**: 非同期の2つのループをシンプルに協調させるメカニズムとして、Dart の Completer が最も自然

```
生成ループ (Producer):                   再生ループ (Consumer):
  for i in [startGen..totalSegments]:      for i in [0..totalSegments]:
    if i < storedCount: skip                 if i < storedCount:
    synthesize(segments[i])                    load from DB → play
    store to DB                              else:
    _generatedUpTo = i                         await _waitForSegment(i)
    complete(_segmentReadyCompleters[i])        load from DB → play
                                             await playback completion
```

**待機メカニズム**:
- 再生側がセグメント `i` を必要とした時、`i <= _generatedUpTo` なら即座にDB読み込み
- `i > _generatedUpTo` なら `Completer` を作成して待機
- 生成側がセグメント `i` を保存した時、対応する `Completer` を complete

### 3. テキストハッシュによるデータ無効化

**決定**: `tts_episodes` テーブルに `text_hash TEXT` カラムを追加し、SHA-256ハッシュで比較

**理由**: テキスト全文の比較は非効率。ハッシュは高速で衝突リスクも実用上無視できる

**フロー**:
```
start() 時:
  currentHash = sha256(text)
  existing = findEpisodeByFileName(fileName)
  if existing != null:
    if existing.text_hash != currentHash:
      deleteEpisode(existing.id)  // テキスト変更 → 破棄
      existing = null
  if existing != null && existing.status in ['partial', 'completed']:
    storedSegmentCount = getSegmentCount(existing.id)
    // 既存データを活用して再開
  else:
    // 新規生成
```

### 4. キャンセル時のデータ保持とステータス管理

**決定**: キャンセル時にエピソードを削除せず、ステータスを `partial` に更新

**DB ステータスの遷移**:
```
新規生成開始 → status='generating'
  ├─ 全セグメント完了 → status='completed'
  ├─ ユーザー停止 → status='partial'
  └─ エラー → status='partial' (生成済み分は保持)
```

**UI状態マッピング**:
- DB `generating` (プロセス稼働中) → `TtsAudioState.generating`
- DB `partial` (中断済み、データあり) → `TtsAudioState.ready`
- DB `completed` (全完了) → `TtsAudioState.ready`
- エピソードなし → `TtsAudioState.none`

### 5. 再生が生成に追いついた時のUX

**決定**: `TtsPlaybackState` に `waiting` 状態を追加し、ローディング表示

**理由**: ユーザーに「生成中で一時待ち」を明示することで、アプリがフリーズしたと思われない

```dart
enum TtsPlaybackState { stopped, playing, paused, waiting }
```

**UIでの表現**: 再生中のハイライトは維持しつつ、プログレスインジケーター等で待機中を表示

### 6. DBマイグレーション

**決定**: `tts_episodes` テーブルに `text_hash TEXT` カラムを追加。マイグレーションは `ALTER TABLE` で対応

**理由**: 既存テーブルにカラムを追加するだけで、デフォルト値は NULL で問題ない（text_hash が NULL のエピソードは、次回アクセス時にハッシュ不一致で再生成される）

### 7. 起動フローの統一

**決定**: UIからは「再生/生成」の区別なく `TtsStreamingController.start()` を呼び出す

**理由**: ユーザーにとって「再生」と「生成」は同じ体験であるべき。コントローラー内部で状態を判断し、保存済みセグメントの再生 or 新規生成+再生を自動切り替え

**UIフロー**:
```
ボタン押下 (TtsAudioState に応じて):
  none → start() → 最初から生成+再生
  ready → start() → 保存済み再生 (+ 必要なら生成継続)
```

## Risks / Trade-offs

**[再生が生成に頻繁に追いつく] → 短い文が多いテキストでは待機が頻発する可能性**
- 緩和策: 生成を1セグメント先行させるバッファリング（再生が始まる前に最初のセグメントを生成完了してから再生開始）
- 最初のセグメント生成完了後に再生を開始し、以降は再生中に次を生成

**[DB ステータスの不整合] → アプリがクラッシュした場合、`generating` ステータスのまま残る**
- 緩和策: `generating` ステータスのエピソードは `partial` と同じ扱いにする（保存済みセグメントがあれば利用可能）

**[テキストセグメント境界の一貫性] → 部分保存後にTextSegmenterのロジックが変わるとオフセットがずれる**
- 緩和策: text_hash比較で検出可能。TextSegmenterは決定的であり、同じ入力には同じ出力を返す

**[メモリ使用] → 大量のセグメントのCompleter をMapに保持**
- 実用上問題なし。Completerは軽量オブジェクトで、complete後にMapから削除すればメモリリークもない
