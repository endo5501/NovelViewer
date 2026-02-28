## Context

`TtsStreamingController`（閲覧画面）と`TtsEditController`（編集画面）は同じ`tts_episodes`/`tts_segments`テーブルを共有している。`TtsStreamingController.start()`はエピソードの`text_hash`を検証し、不一致または`null`の場合はエピソード全体を削除して再作成する。

DBの`ref_wav_path`カラムの保存ルールは以下の通り:
- `NULL` → グローバル設定を使用（「設定値」）
- `''` → リファレンスなし（「なし」）
- `filename.wav` → 特定のボイスファイル（ファイル名のみ）

編集画面はこのルールに従ってファイル名のみを保存するが、ストリーミングコントローラはフルパスを保存していた。また、DBから読んだファイル名をフルパスに解決せずに合成に渡していた。

## Goals / Non-Goals

**Goals:**
- 編集画面で作成されたエピソードが閲覧画面のハッシュ検証を通過し、既存の生成済み音声が保持されるようにする
- `ref_wav_path`の保存ルール（ファイル名のみ）を閲覧画面のストリーミングコントローラでも統一する
- DBから読んだ`ref_wav_path`（ファイル名）を合成前にフルパスに解決する

**Non-Goals:**
- `TtsStreamingController`のハッシュ検証ロジック自体の変更
- 編集画面と閲覧画面のTTS生成フローの統合・リファクタリング

## Decisions

### 1. `loadSegments`でテキストハッシュを計算・保存する

**選択**: `loadSegments()`呼び出し時にSHA-256テキストハッシュを計算し、インスタンス変数`_textHash`に保持する。`_ensureEpisodeExists()`はこの値を使ってエピソードを作成する。

**理由**: `loadSegments()`は`text`パラメータを受け取る唯一のエントリポイントであり、`TtsStreamingController`と同じ`sha256.convert(utf8.encode(text))`を使用することでハッシュの一貫性が保証される。

### 2. 既存エピソードにもtext_hashを設定する

**選択**: `loadSegments()`で既存エピソードを見つけた場合、そのエピソードの`text_hash`が`null`であれば更新する。

**理由**: この修正以前に編集画面で作成されたエピソード（`text_hash = NULL`）も、次回`loadSegments()`が呼ばれた際に修正される。

### 3. `ref_wav_path`のパス解決にコールバックを使用する

**選択**: `TtsStreamingController.start()`に`String Function(String)? resolveRefWavPath`コールバックを追加し、DBから読んだファイル名をフルパスに解決する。`TtsEditController.generateAllUngenerated()`と同じパターン。

**理由**: ストリーミングコントローラは`VoiceReferenceService`に依存しないため、呼び出し元（`text_viewer_panel.dart`）がパス解決を提供する。既存の`TtsEditController`と同じコールバックパターンを使うことで一貫性を保つ。

### 4. 新規セグメント挿入時にref_wav_pathをNULLで保存する

**選択**: `_startPlayback`の`insertSegment`呼び出しで`refWavPath`を渡さない（NULL）。

**理由**: ストリーミングコントローラがグローバル設定で生成したセグメントは「設定値」であるべき。フルパスを保存すると編集画面でファイル名リストと照合できず「なし」と表示される。`NULL`は「設定値」を意味し、DB保存ルールに準拠する。

## Risks / Trade-offs

- **既存エピソードの一度限りのデータ損失**: この修正以前に編集画面で作成された`text_hash = NULL`のエピソードが、修正後に閲覧画面から先にアクセスされた場合は再作成される → 編集画面を先に開けば回避可能。頻度が低く許容範囲。
- **既存のフルパス保存データ**: 修正前にストリーミングコントローラが保存したフルパスは編集画面で「なし」と表示される → 再生成すれば修正される。
