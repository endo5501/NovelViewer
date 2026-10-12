# Proposal

## Why

小説の更新でエピソードファイルがリネームされると（総話数の桁上がり `9_x.txt` → `09_x.txt`、またはタイトル変更）、ファイル名をキーにしているアプリ内の状態がすべて古い名前を指したまま取り残される。実際に、9話を読んでいる最中に12話へ更新したところ、次話へ遷移できず、開き直しても前回の位置が復元されなかった。リネーム自体は F104（`migrateEpisodeFileNamePadding`）で導入された正しい挙動だが、「何を何にリネームしたか」が誰にも伝わらない。連載を追う限り 9→10、99→100 で必ず踏むため、今直す。

## What Changes

- エピソードファイル名の移行処理が、実際に行ったリネーム（および「正規名が既にあるため旧名を削除した」ケース）を **旧名→新名の対応表** として報告するようにする。
- ダウンロード処理は、その対応表を各話の取得ループに入る前に呼び出し側へ通知する。以降の取得がキャンセル・失敗で終わっても、リネーム済みの事実は失われない。
- ダウンロードを起動した側（`DownloadNotifier`）は、対応表を受け取ったら次の順でアプリ全体へ伝播させる。
  1. 読書位置の書き込み待ちを flush する
  2. ファイル名をキーに持つ保存先のキーを書き換える
  3. 表示中のエピソードがリネーム対象なら、選択を新しいパスへ付け替える（ファイルを開く操作としては扱わない）
- キーを書き換える保存先は次の6つ。
  - `reading_progress.file_name`（グローバル `novel_metadata.db`。本文内の読書位置も同じ行に入っている）
  - `bookmarks.file_name`（フォルダ別 `novel_data.db`）
  - `fact_cache.file_name`（同上。LLM要約の事実キャッシュ）
  - `word_summaries.source_file`（同上。LLM要約の履歴ジャンプ先）
  - `tts_episodes.file_name`（フォルダ別 `tts_audio.db`。子テーブル `tts_segments` は `episode_id` で紐づくので追従不要）
- 新しい名前に既に行がある場合は、新しい名前の行を残し、旧名の行は捨てる。この衝突方針はすべての保存先で共通とする。
- 伝播はベストエフォートで行う。保存先ごとの失敗は WARNING ログに残すだけで、ダウンロードも他の保存先の書き換えも止めない。

### Non-goals

- **既に切れてしまったデータの修復**（今回の不具合で旧名のまま残っている行の救済）は扱わない。対応表が残っていないため、別途判断する。
- ゼロ埋め幅の固定化など、リネームそのものをなくす変更は行わない。
- generic-web コレクションは固定幅のためリネームが起きず、対象外とする。
- `episode_cache.db` は URL がキーで、ファイル名を持たないため変更しない。

## Capabilities

### New Capabilities
- `episode-file-rename-propagation`: ダウンロード中に起きたエピソードファイルのリネームを、ファイル名をキーに持つ保存先と表示中の選択へ伝播させる仕組みを扱う。対象は伝播の順序、衝突方針、失敗時の振る舞い、適用経路（更新と再ダウンロード）。

### Modified Capabilities
- `text-download`: ファイル名移行の要件（Episode filename zero-pad width migration）に、行ったリネームを報告する義務を加える。報告は取得ループの前に行い、キャンセル・失敗時にも失われないものとする。
- `reading-context`: 表示中のエピソードが更新によってリネームされたとき、パスを付け替えることを要件に加える。付け替えはファイルを開く操作として扱わない。
- `reading-progress`: `file_name` のキーを旧名から新名へ書き換える操作を加える。本文内の位置は保持する。
- `bookmark-storage`: ブックマークの `file_name` を書き換える操作を加える。衝突時は新しい名前の行を優先する。
- `tts-audio-storage`: `tts_episodes.file_name` を書き換える操作を加える。衝突時は新しい名前のエピソードを優先し、旧名側はセグメントごと削除する。
- `llm-summary-fact-cache`: 事実キャッシュの `file_name` を書き換える操作を加える。
- `llm-summary-cache`: `word_summaries.source_file` を書き換える操作を加える。

## Impact

- 変更するコード
  - `lib/features/text_download/data/download_service.dart`（`migrateEpisodeFileNamePadding` の戻り値、`downloadNovel` / `_downloadEpisodes` の通知コールバック）
  - `lib/features/text_download/providers/text_download_providers.dart`（`startDownload` で伝播を起動）
- 新しく追加するコード
  - ファイル名リネームを伝播させる仕組み（`Ref` から各リポジトリへ書き換えを指示する）
- 書き換え操作を追加するリポジトリ
  - `ReadingProgressRepository`、`BookmarkRepository`、`FactCacheRepository`、`LlmSummaryRepository`、`TtsAudioRepository`
- 影響を受ける状態
  - `selectedFileProvider`（`rebase` を使う）
  - 話一覧、ブックマーク一覧、TTS状態の各 provider（無効化が必要）
- DBスキーマの変更、依存パッケージの追加、外部APIの変更はない。
