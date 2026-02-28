## Context

`TtsStreamingController`（閲覧画面）と`TtsEditController`（編集画面）は同じ`tts_episodes`/`tts_segments`テーブルを共有している。`TtsStreamingController.start()`はエピソードの`text_hash`を検証し、不一致または`null`の場合はエピソード全体を削除して再作成する。

現在`TtsEditController._ensureEpisodeExists()`はエピソード作成時に`text_hash`を設定していない。そのため、編集画面で作成されたエピソードは`text_hash = NULL`を持ち、閲覧画面のハッシュ検証で常に不一致と判定されてエピソードが削除される。

## Goals / Non-Goals

**Goals:**
- 編集画面で作成されたエピソードが閲覧画面のハッシュ検証を通過し、既存の生成済み音声が保持されるようにする
- `TtsStreamingController`の既存ロジックに変更を加えずに問題を解決する

**Non-Goals:**
- `TtsStreamingController`のハッシュ検証ロジック自体の変更
- 編集画面と閲覧画面のTTS生成フローの統合・リファクタリング
- 既存の`text_hash = NULL`のエピソードのマイグレーション（次回閲覧画面アクセス時に自動修正される）

## Decisions

### 1. `loadSegments`でテキストハッシュを計算・保存する

**選択**: `loadSegments()`呼び出し時にSHA-256テキストハッシュを計算し、インスタンス変数`_textHash`に保持する。`_ensureEpisodeExists()`はこの値を使ってエピソードを作成する。

**理由**: `loadSegments()`は`text`パラメータを受け取る唯一のエントリポイントであり、`TtsStreamingController`と同じ`sha256.convert(utf8.encode(text))`を使用することでハッシュの一貫性が保証される。

**代替案**:
- `_ensureEpisodeExists()`にtextパラメータを追加する → 呼び出し元すべてにtextの受け渡しが必要になり、変更範囲が広がる
- `TtsStreamingController`側でtext_hash=nullを許容する → ストリーミング側にnull処理の複雑さが加わり、テキスト変更時の検出が不正確になる

### 2. 既存エピソードにもtext_hashを設定する

**選択**: `loadSegments()`で既存エピソードを見つけた場合、そのエピソードの`text_hash`が`null`であれば更新する。

**理由**: この修正以前に編集画面で作成されたエピソード（`text_hash = NULL`）も、次回`loadSegments()`が呼ばれた際に修正される。閲覧画面で先にアクセスされた場合はエピソードが再作成されるが、データ損失は一度限りであり許容範囲。

## Risks / Trade-offs

- **既存エピソードの一度限りのデータ損失**: この修正以前に編集画面で作成された`text_hash = NULL`のエピソードが、修正後に閲覧画面から先にアクセスされた場合は再作成される → 編集画面を先に開けば`text_hash`が設定されて回避可能。頻度が低く許容範囲。
- **ハッシュ計算のオーバーヘッド**: `loadSegments()`呼び出しごとにSHA-256計算が行われる → テキストサイズに対して無視できるレベル。
