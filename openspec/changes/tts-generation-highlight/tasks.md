## 1. TtsGenerationController に onSegmentStart コールバック追加

- [ ] 1.1 `TtsGenerationController` に `void Function(int textOffset, int textLength)? onSegmentStart` コールバックプロパティを追加
- [ ] 1.2 生成ループ内で、各セグメントの合成開始前に `onSegmentStart?.call(segment.offset, segment.length)` を呼び出す
- [ ] 1.3 `onSegmentStart` コールバックのテストを作成（合成前に呼ばれること、正しい offset/length が渡されることを検証）

## 2. TextViewerPanel でハイライト連動

- [ ] 2.1 `_startGeneration()` 内で `controller.onSegmentStart` に `ttsHighlightRangeProvider` を更新するコールバックを設定
- [ ] 2.2 `_startGeneration()` の生成完了後に `ttsHighlightRangeProvider.set(null)` でハイライトをクリア
- [ ] 2.3 `_cancelGeneration()` 内に `ttsHighlightRangeProvider.set(null)` を追加

## 3. 最終確認

- [ ] 3.1 code-simplifierエージェントを使用してコードをよりシンプルにできないか確認
- [ ] 3.2 codexスキルを使用して現在開発中のコードレビューを実施
- [ ] 3.3 `fvm flutter analyze`でリントを実行
- [ ] 3.4 `fvm flutter test`でテストを実行
