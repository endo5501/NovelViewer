## 1. Repository層: insertSegment に memo パラメータ追加

- [ ] 1.1 `TtsAudioRepository.insertSegment` に `String? memo` パラメータを追加し、DB insert に `'memo': memo` を含める
- [ ] 1.2 insertSegment の memo パラメータに関するユニットテストを追加（memo あり・なし）

## 2. TtsEditController: セグメント再生成で memo を instruct として使用

- [ ] 2.1 `TtsEditController._synthesize` に `String? instruct` パラメータを追加し、`_ttsIsolate.synthesize` に渡す
- [ ] 2.2 `TtsEditController.generateSegment` に `String? instruct` パラメータを追加し、`segment.memo ?? instruct` を `_synthesize` に渡す
- [ ] 2.3 `TtsEditController.generateAllSegments` で各セグメントの `memo ?? globalInstruct` を `_synthesize` に渡す
- [ ] 2.4 TtsEditController の再生成テストを追加（memo あり→memo 使用、memo なし→globalInstruct 使用、両方なし→instruct なし）

## 3. TtsStreamingController: オンデマンド生成で memo を instruct として使用

- [ ] 3.1 `_startPlayback` 内のオンデマンド生成箇所で `dbRow?['memo']` を読み取り、`dbMemo ?? instruct` を `_synthesize` に渡す
- [ ] 3.2 オンデマンド生成で新規セグメント挿入時に、使用した instruct を memo として `insertSegment` に渡す
- [ ] 3.3 TtsStreamingController のテストを追加（memo ありセグメント→memo 使用、memo なしセグメント→globalInstruct 使用）

## 4. TtsGenerationController: バッチ生成で instruct を memo として保存

- [ ] 4.1 `_synthesizeSegment` 後の `insertSegment` 呼び出しに、使用した `instruct` を `memo` パラメータとして渡す
- [ ] 4.2 TtsGenerationController のテストを追加（instruct あり→memo に保存、instruct なし→memo=NULL）

## 5. 呼び出し側の接続

- [ ] 5.1 `TtsEditDialog` から `generateSegment` / `generateAllSegments` 呼び出し時にグローバル instruct を渡す
- [ ] 5.2 既存の呼び出し箇所で新しいパラメータが正しく渡されていることを確認

## 6. 最終確認

- [ ] 6.1 simplifyスキルを使用してコードレビューを実施
- [ ] 6.2 codexスキルを使用して現在開発中のコードレビューを実施
- [ ] 6.3 `fvm flutter analyze`でリントを実行
- [ ] 6.4 `fvm flutter test`でテストを実行
