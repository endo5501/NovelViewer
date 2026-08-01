## Why

読み上げ編集ダイアログの再生手段は現在2つしかない。

- **[全再生]** — 常にセグメント0から末尾まで通しで鳴らす
- **行の [▶]** — そのセグメント1つだけを鳴らす

通し確認には前者、単体確認には後者で足りるが、**「一部を修正して、その前後のつながりを確かめる」という編集作業で最も頻度の高い確認ができない**。セグメント120を直したとき、[全再生]では頭から119個を聴き流すことになり、[▶]では前後との接続が分からない。結果として、修正のたびに確認が省略されるか、[全再生]を押して手で止める運用になる。

原因は、ダイアログが「いま作業している位置」という状態を一切持っていないことにある。`ttsEditPlaybackIndexProvider`（再生中のみ非 null）はあるが、これは再生中の一時的な表示用であり、再生の開始位置を決める役割は持っていない。

## What Changes

任意位置からの再生ボタンを追加するのではなく、**「再生ヘッド」という単一の状態を導入し、既存の [全再生] をその上に再定義する**。

- `ttsEditCursorIndexProvider : int`（初期値 0）を追加する。これが再生ヘッドであり、次に再生を開始する位置を指す
- `ttsEditPlaybackIndexProvider : int?` を廃止し、「再生中かどうか」だけを持つ `ttsEditPlayingProvider : bool` に置き換える。位置の情報は再生ヘッドへ一本化する
- 再生ヘッドは次の3つの契機で移動する
  - ユーザーがセグメント行のどこかをクリックしたとき（再生中を除く）
  - 再生が次のセグメントへ進んだとき
  - 再生が末尾まで到達したとき（0 に戻る）
- ツールバーの **[全再生] を [再生] に改める**。再生ヘッドの位置から末尾まで再生する。ヘッドが 0 にあるときの挙動は従来の全再生と完全に一致するため、機能は失われない
- 再生ヘッドのある行に背景色を付け、位置が常に見えるようにする
- 再生ヘッドが画面外にあるとき、その行が見えるところまでリストを自動スクロールする
- `TtsEditController.playAll` に `startIndex` を追加し、末尾到達で `true` / 中断で `false` を返すようにする
- ウィジェットテストを可能にするため、リスト部分を `TtsEditSegmentList` として切り出す

未生成セグメントを読み飛ばす既存の規則、[停止] による打ち切り、行の [▶] による単体再生は変更しない。DB・音声合成・永続化には一切触れない。

## Capabilities

### New Capabilities

なし。

### Modified Capabilities

- `tts-edit-screen`: 「Play all segments」要件を再生ヘッドからの再生へ置き換え、ヘッドの移動規則・強調表示・自動スクロールの要件を追加する。「Segment preview playback」要件に、行の [▶] がヘッドを移動させる旨を追記する

## Impact

- **コード**:
  - `lib/features/tts/providers/tts_edit_providers.dart`（`ttsEditPlaybackIndexProvider` を `ttsEditCursorIndexProvider` + `ttsEditPlayingProvider` へ置換）
  - `lib/features/tts/data/tts_edit_controller.dart`（`playAll` の `startIndex` と戻り値）
  - `lib/features/tts/presentation/tts_edit_segment_row.dart`（ポインタ検知と強調表示）
  - `lib/features/tts/presentation/tts_edit_segment_list.dart`（新規。ヘッド所有と自動スクロール）
  - `lib/features/tts/presentation/tts_edit_dialog.dart`（配線とツールバー）
  - `lib/l10n/app_ja.arb` / `app_en.arb` / `app_zh.arb`（`ttsEdit_playAllButton` → `ttsEdit_playButton`）
- **テスト**:
  - `test/features/tts/data/tts_edit_controller_test.dart`（`startIndex` と戻り値）
  - `test/features/tts/presentation/tts_edit_segment_row_test.dart`（ポインタ検知と強調表示）
  - `test/features/tts/presentation/tts_edit_segment_list_test.dart`（新規。ヘッド移動の抑止と自動スクロール）
- **影響しないもの**: `TtsAudioRepository`、DBスキーマ、`SegmentPlayer`、`TtsSession`、音声合成の全経路、ビューア側の読み上げ（`TtsStreamingController`）
