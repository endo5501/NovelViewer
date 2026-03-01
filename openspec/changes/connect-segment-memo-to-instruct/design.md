## Context

`tts_segments.memo` カラムは「future control instruction support」として既に存在し、UI（TtsEditDialog）から編集・DB保存が可能。一方、TTS生成パイプラインは Settings UI からのグローバル instruct のみを受け付け、セグメント単位の memo を無視している。

下流（TtsEngine → C API → qwen3-tts.cpp）の instruct 経路は `add-customvoice-instruct` change で完成済み。本 change は上流の接続（DB memo → Controller → Engine）のみを対象とする。

## Goals / Non-Goals

**Goals:**

- セグメントの `memo` を `instruct` として TTS エンジンに渡す
- 優先度ロジック: `segment.memo` > `global instruct` > なし
- 3つの生成経路すべて（ストリーミング、バッチ、編集画面）で一貫した動作

**Non-Goals:**

- DB スキーマの変更（memo カラムは既存）
- C++ / FFI レイヤーの変更（instruct 経路は完成済み）
- memo 編集 UI の変更（既に動作している）
- memo の自動生成や AI 推定

## Decisions

### 1. memo をそのまま instruct として使用する

memo フィールドの値をそのまま instruct テキストとして TTS エンジンに渡す。変換や前処理は行わない。

**理由**: memo カラムの仕様上の目的が「control instruction support」であり、ユーザーが直接 instruct テキストを入力する設計。中間変換を入れると複雑になるだけ。

### 2. 優先度ロジックは呼び出し側で解決する

各 Controller の合成呼び出し箇所で `segment.memo ?? globalInstruct` を計算し、単一の `instruct` 値として下流に渡す。

**代替案**: TtsEngine 内部で複数の instruct ソースを受け取り優先度判定 → 却下。Engine は「渡された instruct を使う」という単純な責務に留めるべき。

### 3. 各 Controller への接続方法

```
┌──────────────────────────────────────────────────────────┐
│ TtsStreamingController._startPlayback()                  │
│                                                          │
│  dbRow = dbSegmentMap[i]                                 │
│  dbMemo = dbRow?['memo'] as String?                      │
│  effectiveInstruct = dbMemo ?? globalInstruct             │
│  _synthesize(text, refWavPath, instruct: effectiveInstruct)│
└──────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────┐
│ TtsGenerationController.start()                          │
│                                                          │
│  グローバル instruct のみ使用（バッチ生成時は DB に       │
│  memo がまだ存在しないため）                               │
│  insertSegment に memo パラメータを追加し、               │
│  使用した instruct を memo として保存                      │
└──────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────┐
│ TtsEditController.generateSegment()                      │
│                                                          │
│  segment = _segments[segmentIndex]                       │
│  effectiveInstruct = segment.memo ?? globalInstruct       │
│  _synthesize(text, refWavPath, instruct: effectiveInstruct)│
└──────────────────────────────────────────────────────────┘
```

### 4. TtsEditController に globalInstruct パラメータを追加

`generateSegment` メソッドに `instruct` パラメータを追加し、呼び出し側からグローバル instruct を渡す。Controller 内部で `segment.memo ?? instruct` を計算する。

**理由**: TtsEditController は現在 Settings にアクセスしておらず、依存を増やすよりパラメータとして受け取る方がテスタブル。

### 5. insertSegment に memo パラメータを追加

`TtsAudioRepository.insertSegment` に `String? memo` パラメータを追加し、新規セグメント挿入時に memo を DB に保存できるようにする。

**使用場面**:
- TtsGenerationController: バッチ生成時にグローバル instruct を memo として保存（ユーザーが後から確認・編集可能）
- TtsStreamingController: オンデマンド生成時に使用した instruct を memo として保存
- TtsEditController: 既にセグメントの memo は DB に保存済みのため、insertSegment 時に反映

## Risks / Trade-offs

- **[バッチ生成で memo 上書き]** → バッチ生成時に既存の memo を上書きする可能性。ただし TtsGenerationController は新規エピソードを対象とするため、既存 memo との競合は発生しない。
- **[memo と instruct の混同]** → ユーザーが memo をメモ用途で使っていた場合、それが instruct として解釈される。→ 仕様上 memo は instruct 用途として定義済みのため許容。UI のヒントテキストを明確にすることで対応可能（本 change のスコープ外）。
