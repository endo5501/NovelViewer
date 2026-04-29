## Why

Sprint 2 は計画全体の "基盤" 層であり、後続 Sprint 3-5 が依存する型システムと DB ライフタイムの整備、および Sprint 1 で導入したロガーの実利用化を一括で行う。`TECH_DEBT_AUDIT.md` の指摘を整理すると次のようになる:

- **F007 (High, Type debt)**: `TtsAudioRepository` が `Map<String, Object?>` / `List<Map<String, Object?>>` を返し、6ファイル24+ 箇所で `row['id'] as int` といった unsafe cast が散在している。`tts-audio-storage` spec はすでに「`TtsEpisodeStatus` を返す」と書いているのに実装が Map のまま乖離している
- **F019/F020 (Medium, Performance)**: `directoryContentsProvider` や `_checkAudioState` が DB を毎回 open/close しており、Windows での `sqflite` 起動コストが UI スパイクとして可視化している
- **F003/F058 (Medium, Architectural / Open question)**: 4つの SQLite DB のうち3つは「open 失敗 → ファイル削除して再作成」のリトライをコピペで持ち、1つ (`NovelDatabase`) は意図的に持たない (はず)。ヘルパ抽出の機会と同時に F058 の「意図的な差分」を明示化する
- **F012-F052 (Various, Error handling)**: 沈黙する `catch (_) {}` が10箇所以上あり、Sprint 1 で追加したロガーを使って書き出すことでデバッグ可能性を上げる

これらをまとめて1つの change にする理由は、

- F007 と F019/F020 は同じ TTS 関連層に触る (片方ずつだと2回触ることになる)
- F003 のヘルパ抽出は F019/F020 の Riverpod 化の自然な隣接作業
- ロガー retrofit は型化と DB 整理に伴う変更箇所と重なるテストを共有できる

## What Changes

### Phase A — TTS DTO 型化
- 新規 `TtsEpisode` データクラス (id, fileName, sampleRate, status, refWavPath, textHash, createdAt, updatedAt)
- 新規 `TtsSegment` データクラス (id, episodeId, segmentIndex, text, textOffset, textLength, audioData, sampleCount, refWavPath, memo, createdAt)
- `TtsEpisodeStatus` enum を spec 通り実装に反映 (現行の `String?` → enum)
- `TtsAudioRepository` のメソッド戻り値を `TtsEpisode?` / `List<TtsSegment>` 等の型付き DTO に変更
- 6 consumer ファイル (`text_viewer_panel.dart`, `tts_streaming_controller.dart`, `tts_edit_controller.dart`, `tts_stored_player_controller.dart`, `tts_edit_dialog.dart`, `file_browser_providers.dart`) の cast を削除
- **F048**: `synthRefWavPath` の三状態 (null / '' / path) 解決を `TtsRefWavResolver` ヘルパに集約。`TtsStreamingController` (現行 ternary) と `TtsEditController` (現行 switch) を統一
- **F053**: `text_viewer_panel.dart:115,383` の site-level cast を DTO 経由読み出しに置換

### Phase B — DB ライフタイム & open ヘルパ
- 新規 `lib/shared/database/database_opener.dart` に `openOrResetDatabase({required path, required version, required onCreate, bool deleteOnFailure = false, ...})` を実装
- 3つの再現可能 DB (`TtsAudioDatabase`, `TtsDictionaryDatabase`, `EpisodeCacheDatabase`) は `deleteOnFailure: true` で呼ぶ。コピペ boilerplate を削除
- `NovelDatabase` (再現不可な metadata) は `deleteOnFailure: false` で呼ぶ。コメントで「ブックマーク等は再現不可なため自動削除しない」を明記 (**F058 決定**)
- 新規 Riverpod `Provider.family<TtsAudioDatabase, String>` (キー = フォルダパス、`ref.onDispose` で close)
- 同パターンを `TtsDictionaryDatabase`, `EpisodeCacheDatabase` にも適用
- `directoryContentsProvider` と `text_viewer_panel.dart` を family-cached DB 経由に変更
- 音声状態取得を新規 `FutureProvider.family<TtsAudioState, String>` (キー = ファイルパス) に移し、`text_viewer_panel.dart` の `_lastCheckedFileKey` ceremony を削除

### Phase C — ロガー retrofit (Sprint 1 の `Logger` を消費)
- **F012**: `download_service.dart:332` のエピソード単位失敗を `failedCount` で `DownloadResult` に集計、ログ出力。UI の SnackBar で「N件成功、M件失敗」と表示
- **F013**: `novel_library_service.dart:55` のマイグレーション失敗をログ。例外メッセージとフォルダ名を含める
- **F014**: `tts_streaming_controller.dart:439` の `stop()` cleanup を warning ログへ。状態クリアの finally が走った後でないと throw を再投げしない
- **F016**: `llm_summary_pipeline.dart:85` の `jsonDecode` 失敗をログ。プロンプト調整に使えるように decoder 入力長と先頭文字を含める
- **F052**: `file_browser_providers.dart:71-74` の DB 読み出し失敗をログ。「TTSステータス取得に失敗、UI badge は非表示で続行」を warning レベルで残す

## Capabilities

### New Capabilities
- `database-recovery`: `openOrResetDatabase` ヘルパの契約。再現可能 DB と再現不可 DB の挙動差を1箇所に書く

### Modified Capabilities
- `tts-audio-storage`: Repository の戻り値型を Map から DTO に変更。`findEpisodeByFileName` が `TtsEpisode?` を返すなど。DTO の取り扱いを scenario レベルで明示
- `file-browser`: TTS ステータス取得は family-cached DB 経由で行う (毎回 open/close しない)。ステータス取得失敗時の挙動を明記
- `text-viewer`: 音声状態は `FutureProvider.family<TtsAudioState, String>` 経由で取得し、ファイルパスをキーに自動キャッシュする
- `text-download`: `DownloadResult` に `failedCount` を追加。失敗したエピソードの件数を呼び出し側に伝える
- `novel-metadata-db`: 「open 失敗時の自動削除を行わない」要件を ADD (F058 の意図的差異を明文化)
- `llm-summary-pipeline`: JSON decode 失敗時のログ出力を要件として明記 (静かに raw text にフォールバックする現挙動は維持)

## Impact

- **Code (additions)**:
  - `lib/features/tts/domain/tts_episode.dart`
  - `lib/features/tts/domain/tts_segment.dart`
  - `lib/features/tts/domain/tts_episode_status.dart` (enum)
  - `lib/features/tts/domain/tts_ref_wav_resolver.dart` (F048)
  - `lib/shared/database/database_opener.dart` (F003)
  - `lib/features/tts/providers/tts_audio_database_provider.dart` (Riverpod family)
  - `lib/features/tts/providers/tts_audio_state_provider.dart` (FutureProvider.family)
- **Code (modifications)**:
  - `lib/features/tts/data/tts_audio_repository.dart` (DTO 戻り値)
  - `lib/features/tts/data/tts_audio_database.dart` (database_opener 利用)
  - `lib/features/tts/data/tts_dictionary_database.dart` (同上)
  - `lib/features/episode_cache/data/episode_cache_database.dart` (同上)
  - `lib/features/novel_metadata_db/data/novel_database.dart` (同上、`deleteOnFailure: false`)
  - 6 consumer files (cast 削除)
  - `lib/features/file_browser/providers/file_browser_providers.dart` (family DB 利用 + F052 ログ)
  - `lib/features/text_viewer/presentation/text_viewer_panel.dart` (FutureProvider 化)
  - `lib/features/text_download/data/download_service.dart` (F012)
  - `lib/features/text_download/data/novel_library_service.dart` (F013)
  - `lib/features/tts/data/tts_streaming_controller.dart` (F014)
  - `lib/features/llm_summary/data/llm_summary_pipeline.dart` (F016)
- **Tests**:
  - `TtsEpisode.fromRow` / `TtsSegment.fromRow` parsing happy path + 欠損列 + 不正型
  - 既存 `TtsAudioRepository` テストを DTO ベースに書き換え
  - `database_opener` ヘルパ: 正常 open / 破損 + `deleteOnFailure: true` / 破損 + `deleteOnFailure: false` (rethrow)
  - Riverpod family: 同フォルダで同じインスタンス、scope dispose で close 呼び出し
  - 各 catch retrofit: 既存挙動維持 + 期待 `LogRecord` (logger 名、level、message 部分一致) のキャプチャ
- **Dependencies**: 追加なし (Sprint 1 で `logging`, `collection` を追加済み前提)
- **BREAKING (内部 API)**: `TtsAudioRepository` の戻り値型変更。lib 内 consumer はすべて本 change 内で更新
- **Blast radius**: 8ファイル新規 + 約12ファイル修正。F007 関係が最大の触れ幅
- **Risk**: メタデータ DB の自動削除を行わない方針 (F058) は実装上「現状維持の明文化」のため挙動に変更はない。仮に metadata DB が破損したユーザーが既に居たら起動できない事象が発生するが、これは現行と同じ
