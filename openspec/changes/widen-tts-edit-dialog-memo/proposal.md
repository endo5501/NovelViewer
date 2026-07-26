## Why

Irodori-TTS のキャプション指定機能により、読み上げ編集ダイアログのメモ欄には「落ち着いた女性の声で、ゆっくり悲しげに」といった自然文（最大20〜30文字程度）を入力するようになった。しかしメモ欄は `SizedBox(width: 100)` の固定幅かつ `maxLines` 未指定（1行固定）のままで、数文字入力しただけで全体が読めなくなり、キャプションの確認・編集が実用に耐えない。

ダイアログ自体も `width: 800` のベタ書き固定であるため、広い画面を使っていてもメモ欄には一切余裕が回らない。

## What Changes

- 読み上げ編集ダイアログの幅を固定値 800 から `min(1400, ウィンドウ幅 * 0.9 - 48)` の可変値に変更する。高さは 600 のまま据え置く
- メモ欄を `SizedBox(width: 100)` の固定幅から `Expanded(flex: 2)` に変更し、ダイアログ幅の拡大分がメモ欄にも配分されるようにする
- メモ欄を `maxLines: 2` とし、1行に収まらないキャプションが折り返して表示されるようにする（本文欄は既に `maxLines: null` で折り返す。この非対称を解消する）
- 本文 TextField の `flex` を 4 から 5 に変更し、本文優先の幅配分を明示する
- テスト可能性のため、private な `_TtsEditSegmentRow` を public な `TtsEditSegmentRow` として `lib/features/tts/presentation/tts_edit_segment_row.dart` に切り出す（挙動は変更しない機械的な移動）
- ダイアログ幅の算出を public な純粋関数として切り出す
- 読み上げ編集画面のウィジェットテスト／ユニットテストを新規に追加する（現在テストが存在しない）

破壊的変更はない。データモデル・永続化・音声合成の挙動には一切手を入れず、レイアウトと可視性のみの変更である。

## Capabilities

### New Capabilities

なし。

### Modified Capabilities

- `tts-edit-screen`: ダイアログのサイズ決定とセグメント行の幅配分・メモ欄の行数に関する要件を追加する。既存の「Segment row columns」「Segment memo field」要件が定めるカラム構成と永続化の挙動は変更しない

## Impact

- **コード**:
  - `lib/features/tts/presentation/tts_edit_dialog.dart`（`build` の `SizedBox` 制約、幅算出関数の追加、行ウィジェットの import 化）
  - `lib/features/tts/presentation/tts_edit_segment_row.dart`（新規。既存の `_TtsEditSegmentRow` を移動して public 化）
- **テスト**:
  - `test/features/tts/presentation/tts_edit_segment_row_test.dart`（新規。行のレイアウト検証）
  - `test/features/tts/presentation/tts_edit_dialog_test.dart`（新規。幅算出関数の検証）
- **影響しないもの**: `TtsEditController`、`TtsAudioRepository`、DB スキーマ、`TtsEngineConfig.captionFromMemo` によるキャプション連携、l10n 文字列
