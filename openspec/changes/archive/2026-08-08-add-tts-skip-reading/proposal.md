## Why

小説本文には、読み上げる必要のない記号列（`――‐`、`◆◇◆`、`※` など）や、音声化したくない1文（作者コメント等）が含まれる。現在の辞書機能は「表記→読み」の置換しかできず、読みを空にすることも、特定のセグメントだけ音声生成の対象外にすることもできない。

加えて、仮に読みを空にできたとしても現状では破綻する。記号だけの行はそれ自体が1セグメントになるため、置換後のテキストが空文字のまま合成へ渡り、`TtsEditController.generateAllUngenerated` の `if (!success) break;` によって**そのセグメント以降の一括生成が丸ごと停止する**。読み上げなしを実現するには、空テキストの安全網が同時に必要になる。

## What Changes

- 辞書エントリの「読み」を空にできるようにする。辞書ダイアログに「読み上げしない」チェックボックスを設け、チェック時は読み欄を無効化して空文字（`reading = ''`）として保存する。既存の変換ロジックは空読みを削除として正しく扱えるため、変換アルゴリズム自体は変更しない。
- `tts_segments` に `skip` 列を追加し、セグメント単位の「音声生成不要」状態を永続化する（`tts_audio.db` を v3 → v4 へマイグレーション）。
- 読み上げ編集ダイアログの状態アイコンをクリックすると、そのセグメントのスキップ状態が切り替わる。
- スキップされたセグメントは、一括生成・単体生成・編集画面のプレビュー通し再生・閲覧画面のストリーミング再生・MP3エクスポートのすべてから除外される。
- **スキップしても既存の音声データは削除しない**。誤操作からの復帰を優先し、スキップ解除で即座に元へ戻せるようにする。この結果、「音声を持つかどうか」ではスキップを判定できないため、上記すべての経路に明示的なスキップ判定を入れる。
- 合成直前のテキストが空白のみ（`trim().isEmpty`）の場合、合成を呼ばずにそのセグメントを `skip = 1` として記録し、次へ進む。記録の契機は生成が実際にそのセグメントへ到達した時とし、編集ダイアログを開いただけではDBへ書き込まない。
- エピソードの完了判定を「全セグメントが音声を持つ」から「全セグメントが音声を持つか、スキップされている」へ改める。これを行わないと、スキップ行が1つでもあるエピソードは永久に `completed` にならず、ファイルブラウザの完了アイコンが付かない。

破壊的変更はない。`skip` 列は `DEFAULT 0` で追加されるため、既存DBの挙動は変わらない。

## Capabilities

### New Capabilities

なし。既存ケーパビリティの要件変更のみで構成される。

### Modified Capabilities

- `tts-dictionary`: 読みが空のエントリを許可する。追加時の「表記・読みの両方が必須」というバリデーション要件を変更し、空読みエントリの登録・表示・変換適用を規定する。
- `tts-audio-storage`: `tts_segments` に `skip` 列を追加。スキーマ定義、v3→v4 マイグレーション、`TtsAudioRepository` のスキップ更新メソッド、`TtsSegment` DTO のフィールド、および「生成済みセグメント数」の定義（スキップを充足として数える）を変更する。
- `tts-edit-screen`: 状態アイコンによるスキップ切替、スキップ行の表示と操作の無効化、一括生成・通し再生からの除外、リセット／全消去によるスキップ解除、完了判定の変更を規定する。
- `tts-streaming-pipeline`: 再生ループがスキップ済みセグメントを再生も生成もせず読み飛ばすこと、および合成直前のテキストが空白のみの場合に合成を行わずスキップとして記録することを規定する。
- `tts-audio-export`: MP3連結からスキップ済みセグメントの音声を除外することを規定する。

## Impact

**データベース**
- `tts_audio.db` を v3 → v4 へ。`tts_segments.skip INTEGER NOT NULL DEFAULT 0`。既存の `memo` 追加時と同じ手順を踏襲する。
- `tts_dictionary.db` は変更なし。`reading TEXT NOT NULL` は空文字を許容するため、マイグレーション不要。

**コード**
- `lib/features/tts/data/tts_dictionary_repository.dart` — `addEntry` / `updateEntry` の読み非空チェックを撤廃
- `lib/features/tts/presentation/tts_dictionary_dialog.dart` — チェックボックス、バリデーション、空読みの一覧表示
- `lib/features/tts/data/tts_audio_database.dart` — バージョンとマイグレーション
- `lib/features/tts/domain/tts_segment.dart` — `skip` フィールド
- `lib/features/tts/data/tts_audio_repository.dart` — `updateSegmentSkip`、`insertSegment` の `skip` 引数、`getGeneratedSegmentCount` の条件
- `lib/features/tts/data/tts_edit_segment.dart` — `skip` フィールドとマージ
- `lib/features/tts/data/tts_edit_controller.dart` — 生成対象の絞り込み、通し再生の除外、空テキストの安全網、完了判定、リセット時の解除
- `lib/features/tts/data/tts_streaming_controller.dart` — 再生ループのスキップ判定、空テキストの安全網、完了判定
- `lib/features/tts/presentation/tts_edit_segment_row.dart` — 状態アイコンのクリック切替、スキップ表示、ボタンの無効化
- `lib/features/tts/providers/tts_export_providers.dart` — 連結対象からスキップを除外
- `lib/l10n/app_ja.arb` / `app_en.arb` / `app_zh.arb` — 新規キー（3ロケール揃える）

**テスト**
- `test/features/tts/data/tts_audio_database_test.dart` の手書き `CREATE TABLE`（v1 / v2 / v3 の3箇所）は**旧バージョンの入力**であり、`skip` 列を追加してはならない。追加すると v3 → v4 の `ALTER TABLE` が重複列で失敗し、マイグレーションテストが実際の移行経路を検証しなくなる（`db-schema-test-fidelity` の要請）。v3→v4 の検証には、既存の v3 フィクスチャを入力とする新しいテストを追加する。

**既知の限界（変更しない）**
- スキップフラグは `segment_index` でマージされるため、原文が変更されると別の文へ付き替わる。これは既存のテキスト編集・メモと同一の性質であり、`text_hash` による既存の防御をそのまま適用する。
- 辞書は既存のDBレコードを持たないセグメントにのみ適用されるため、読みなしエントリを後から追加しても、生成済み・編集済みの行には遡って効かない。ユーザーはリセットが必要（既存の辞書と同じ挙動）。
