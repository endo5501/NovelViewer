## Context

現在のTTSシステムは以下の構造:

- `TextSegmenter` が原文を句読点・改行で文単位に分割
- `TtsGenerationController` がIsolate+FFIで全セグメントを順次生成し、WAVバイト列をDBに保存
- `TtsStreamingController` が生成と再生を並行実行（プロデューサー/コンシューマーパターン）
- `tts_segments` テーブルは音声生成時にのみレコードが作成される（`audio_data` NOT NULL）
- セグメントは連続的に生成される前提（index 0から順次）

読み上げ編集画面の導入により、セグメントが非連続的な生成状態を持つケース（一部だけ生成済み、一部は編集済みだが未生成）が発生する。

## Goals / Non-Goals

**Goals:**

- エピソード単位でTTSセグメントのテキスト・リファレンス音声・メモを編集できるダイアログを提供する
- セグメント単位の音声再生成とプレビュー再生を可能にする
- 既存の通常再生フローが、編集済みテキストと部分的な生成状態に対応する
- DBスキーマを最小限の変更で拡張する

**Non-Goals:**

- セグメントの分割・結合機能
- 原文テキストファイルの変更
- 複数エピソードの一括編集
- リアルタイムのテキスト差分表示（オリジナルとの比較）

## Decisions

### 1. DBマイグレーション方式

**決定**: テーブル再作成方式（version 2 → 3）

SQLiteの`ALTER TABLE`はカラムのNOT NULL制約を変更できないため、`tts_segments`テーブルを再作成する。

```
1. tts_segments_new を新スキーマで作成
2. 既存データをコピー
3. 旧テーブルを削除
4. リネーム + インデックス再作成
```

**代替案**: 新テーブル（`tts_segment_edits`）に編集情報を分離する → 却下。`text`フィールドをそのまま編集する方がシンプルで、既存の生成・再生フローの変更が少ない。

### 2. セグメント単位の生成: 新コントローラ `TtsEditController`

**決定**: 編集画面専用の `TtsEditController` を新規作成する

理由:
- 既存の `TtsGenerationController` は全セグメント順次生成に特化しており、モデルのロード→全生成→Isolate破棄というライフサイクルが組み込まれている
- 編集画面では「1セグメントだけ再生成」「全未生成セグメントをまとめて生成」「プレビュー再生」といった操作が必要
- ユーザーが複数セグメントを続けて再生成する場合、モデルを毎回ロードし直すのは非効率

`TtsEditController` の責務:
- TtsIsolateのライフサイクル管理（ダイアログ開閉に連動）
- 単一セグメント生成（`generateSegment(index)`）
- 一括生成（`generateAllUngenerated()`）
- プレビュー再生（`playSegment(index)`, `playAll()`）

```
┌─────────────────────────────────────────┐
│ TtsEditController                       │
│                                         │
│  TtsIsolate (ダイアログ中はロード維持)     │
│  TtsAudioPlayer (プレビュー用)            │
│  TtsAudioRepository (DB操作)             │
│                                         │
│  generateSegment(index)                 │
│  generateAllUngenerated()               │
│  playSegment(index)                     │
│  playAll()                              │
│  stop()                                 │
│  resetSegment(index)                    │
│  resetAll()                             │
└─────────────────────────────────────────┘
```

**代替案**: `TtsGenerationController` に `generateSingleSegment()` を追加する → 却下。既存コントローラのライフサイクル（毎回Isolate生成・破棄）が単一セグメント操作に不向き。プレビュー再生の責務も混在する。

### 3. 編集画面のデータフロー

**決定**: メモリ上のセグメントリストとDBの遅延書き込みの組み合わせ

```
ダイアログ起動時:
  原文 → TextSegmenter → オリジナルセグメントリスト
  DB → 既存セグメントレコード (segment_indexで照合)
  マージ → List<TtsEditSegment> (メモリ上のUI状態)

TtsEditSegment:
  segmentIndex: int
  originalText: String     // TextSegmenterから (リセット時に使用)
  text: String             // 現在のテキスト (編集可能)
  textOffset: int
  textLength: int
  hasAudio: bool           // audio_dataの有無
  refWavPath: String?      // セグメント単位のリファレンス音声
  memo: String?
  dbRecordExists: bool     // DBにレコードがあるか

DB書き込みタイミング:
  - テキスト編集確定時 (onSubmitted/onFocusLost)
    → レコードなければINSERT (audio_data=NULL), あればUPDATE
    → 既存audio_dataを削除
  - ref_wav_path変更時 → 即座にDB更新
  - memo変更時 → onSubmitted/onFocusLost時にDB更新
  - 音声生成完了時 → audio_dataをDB更新
```

### 4. 通常再生フローの変更

**決定**: `TtsStreamingController` をセグメント単位の生成判定に対応させる

現在の前提「セグメントはindex 0から連続的に生成される」を緩和し、セグメントごとにaudio_dataの有無を確認する。

```
変更前:
  storedSegmentCount = count(tts_segments)
  未生成セグメント = storedSegmentCountから末尾まで (連続)

変更後:
  各セグメントの再生時:
    DB上にaudio_dataあり → そのまま再生
    DB上にaudio_dataなし → DB上のtext(編集済みかも)で生成 → 再生
    DB上にレコードなし → TextSegmenterの原文で生成 → 再生
```

`TtsStreamingController._startPlayback` のループを修正し、セグメントごとに生成状態を確認してからload/play する。生成が必要なセグメントに遭遇した場合、その場で生成してから再生する（オンデマンド生成）。

### 5. ダイアログUI構成

**決定**: `showDialog` で全画面に近いサイズのダイアログを表示

```
TtsEditDialog (StatefulWidget + ConsumerWidget)
├── 上部ツールバー: [全再生] [全生成] [全消去]
└── ListView.builder
    └── 各行: TtsEditSegmentRow
        ├── 状態アイコン (未生成/生成済み/生成中)
        ├── TextField (テキスト編集)
        ├── DropdownButton (リファレンス音声)
        ├── TextField (メモ)
        ├── IconButton (再生)
        ├── IconButton (再生成)
        └── IconButton (リセット)
```

導線: `TextViewerPanel` のTTSコントロール部分に編集ボタンを追加。TTSモデルが設定済みの場合のみ表示。

### 6. Isolateのライフサイクル管理

**決定**: モデルは初回の生成操作時にロードし、ダイアログが閉じるまで保持

- ダイアログを開いただけではモデルをロードしない（テキスト編集やプレビュー再生だけなら不要）
- 最初の「再生成」操作時にIsolateを起動しモデルをロード
- 以降の再生成操作ではロード済みモデルを再利用
- ダイアログ閉鎖時にIsolateを破棄

## Risks / Trade-offs

**[非連続生成状態の複雑性]** → 通常再生フローのセグメント単位判定によるコード複雑度の増加。ただし、オンデマンド生成パターンにすることで、「連続生成」も「部分生成」も統一的に扱える。

**[DBレコードの不整合]** → 原文が更新された場合（`text_hash`変更）、編集済みセグメントは従来通り全破棄される。ユーザーの編集作業は失われるが、原文構造が変わっている以上、マージは信頼性が低い。

**[Isolateメモリ消費]** → 編集ダイアログ中はTTSモデルがメモリに常駐する可能性がある（初回生成操作後）。ただし通常再生中もモデルはロードされるため、許容範囲。

**[テキスト編集時の即時音声削除]** → ユーザーが意図せずテキストを変更した場合、生成済み音声が即座に失われる。リスクは低いが、将来的にundo機能を検討する余地はある。
