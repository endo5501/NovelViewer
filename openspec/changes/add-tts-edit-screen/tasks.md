## 1. DBスキーマ変更とマイグレーション

- [x] 1.1 `TtsAudioDatabase`のマイグレーション（version 2 → 3）のテストを作成: `tts_segments`テーブル再作成（`audio_data`/`sample_count`をnullable化、`memo`カラム追加）、既存データの保持を検証
- [x] 1.2 `TtsAudioDatabase._onUpgrade`にversion 3マイグレーションを実装: テーブル再作成方式（新テーブル作成→データコピー→旧テーブル削除→リネーム→インデックス再作成）
- [x] 1.3 `TtsAudioDatabase._onCreate`のスキーマを更新: `audio_data BLOB`（nullable）、`sample_count INTEGER`（nullable）、`memo TEXT`（nullable）

## 2. リポジトリCRUD拡張

- [x] 2.1 `TtsAudioRepository`の新規メソッドのテストを作成: `updateSegmentText`, `updateSegmentAudio`, `updateSegmentRefWavPath`, `updateSegmentMemo`, `deleteSegment`, `getGeneratedSegmentCount`
- [x] 2.2 `TtsAudioRepository`に新規メソッドを実装
- [x] 2.3 既存の`insertSegment`メソッドを`audio_data`/`sample_count`がnullableな引数を受け付けるように修正（テスト更新含む）

## 3. TtsEditSegmentモデル

- [x] 3.1 `TtsEditSegment`データクラスを作成: `segmentIndex`, `originalText`, `text`, `textOffset`, `textLength`, `hasAudio`, `refWavPath`, `memo`, `dbRecordExists`フィールドを持つ
- [x] 3.2 セグメントマージロジックのテストを作成: TextSegmenter出力とDB既存レコードをsegment_indexで照合し`List<TtsEditSegment>`を生成するロジック
- [x] 3.3 セグメントマージロジックを実装

## 4. TtsEditController

- [x] 4.1 `TtsEditController`の単一セグメント生成（`generateSegment`）のテストを作成
- [x] 4.2 `TtsEditController`の一括生成（`generateAllUngenerated`）のテストを作成
- [x] 4.3 `TtsEditController`のプレビュー再生（`playSegment`, `playAll`）のテストを作成
- [x] 4.4 `TtsEditController`のリセット（`resetSegment`, `resetAll`）のテストを作成
- [x] 4.5 `TtsEditController`を実装: TtsIsolateのライフサイクル管理（初回生成時ロード、ダイアログ閉鎖時破棄）、単一セグメント生成、一括生成、プレビュー再生、リセット

## 5. 編集画面プロバイダー

- [x] 5.1 編集画面用Riverpodプロバイダーを設計・実装: セグメントリスト状態、生成中状態、再生中状態の管理
- [x] 5.2 テキスト編集時のDB書き込みとaudio_data削除のテストを作成
- [x] 5.3 テキスト編集時のDB書き込みロジックを実装: 編集確定時にレコードなければINSERT、あればUPDATE、既存audio_data削除

## 6. 編集画面ダイアログUI

- [ ] 6.1 `TtsEditDialog`ウィジェットを作成: ダイアログ外枠、タイトル、上部ツールバー（全再生/全生成/全消去ボタン）
- [ ] 6.2 `TtsEditSegmentRow`ウィジェットを作成: 状態アイコン、テキストフィールド、リファレンス音声ドロップダウン、メモフィールド、再生/再生成/リセットボタン
- [ ] 6.3 リファレンス音声セレクターを実装: 「設定値」「なし」+voicesフォルダ内ファイル一覧、ファイル不在時の「無し」表示
- [ ] 6.4 ダイアログ閉鎖時のクリーンアップ実装: TtsIsolateの破棄

## 7. TTSコントロールへの導線追加

- [ ] 7.1 `TextViewerPanel`のTTSコントロール部分に編集ボタンを追加するテストを作成
- [ ] 7.2 `TextViewerPanel._buildTtsControls`に編集ボタンを追加: TTSモデル設定済み＋エピソード選択中の場合のみ表示、クリックで`TtsEditDialog`を開く

## 8. TtsStreamingController変更（オンデマンド生成対応）

- [ ] 8.1 混在生成状態（一部生成済み・一部未生成）での再生のテストを作成
- [ ] 8.2 オンデマンド生成（未生成セグメント到達時にDB上のtextで生成→再生）のテストを作成
- [ ] 8.3 セグメント単位のref_wav_pathを使用した生成のテストを作成
- [ ] 8.4 `TtsStreamingController`を修正: 再生ループでセグメントごとにaudio_dataの有無を確認し、未生成の場合はオンデマンドで生成してから再生する

## 9. 最終確認

- [ ] 9.1 code-simplifierエージェントを使用してコードをよりシンプルにできないか確認
- [ ] 9.2 codexスキルを使用して現在開発中のコードレビューを実施
- [ ] 9.3 `fvm flutter analyze`でリントを実行
- [ ] 9.4 `fvm flutter test`でテストを実行
