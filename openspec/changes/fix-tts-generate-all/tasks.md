## 1. TtsEditController の cancel() 改修

- [ ] 1.1 cancel() の Isolate dispose テストを作成: cancel() 呼び出し時に TtsIsolate.dispose() が呼ばれることを検証するテストを追加
- [ ] 1.2 cancel() 後の再生成テストを作成: cancel() 後に generateSegment() を呼び出すと新しい Isolate で正常に生成できることを検証するテストを追加
- [ ] 1.3 `_ttsIsolate` を非 final に変更し、cancel() メソッドを改修: Isolate dispose → 新インスタンス作成 → `_modelLoaded = false` → `_subscription?.cancel()` のロジックを実装
- [ ] 1.4 テストが通ることを確認

## 2. _synthesize() の即座キャンセル対応

- [ ] 2.1 _synthesize() 中の cancel テストを作成: _synthesize() の await 中に cancel() を呼ぶと即座に null が返ることを検証するテストを追加
- [ ] 2.2 `_activeSynthesisCompleter` フィールドを追加し、_synthesize() を改修: Completer をフィールドに保持し、cancel() 時に completeError で即座に await を解除。_synthesize() 内で try-catch してキャンセル時は null を返す
- [ ] 2.3 テストが通ることを確認

## 3. generateAllUngenerated の onSegmentStart コールバック追加

- [ ] 3.1 onSegmentStart コールバックのテストを作成: generateAllUngenerated() が各セグメント生成開始前に onSegmentStart を正しいインデックスで呼び出すことを検証
- [ ] 3.2 generateAllUngenerated() に `onSegmentStart` パラメータを追加し、ループ内の generateSegment() 呼び出し前に `onSegmentStart?.call(segmentIndex)` を実行
- [ ] 3.3 テストが通ることを確認

## 4. UI の変更（ツールバーと生成中表示）

- [ ] 4.1 `_buildToolbar()` を改修: isGenerating 時の `Spacer` + `CircularProgressIndicator`（16×16）を削除し、「全生成」ボタンの位置に「中断」ボタンを表示する切り替えロジックに変更
- [ ] 4.2 `_generateAll()` を改修: `controller.generateAllUngenerated()` の呼び出しに `onSegmentStart` コールバックを追加し、`ttsEditGeneratingIndexProvider` にセグメントインデックスを設定
- [ ] 4.3 中断ボタンのハンドラを改修: `_controller?.cancel()` 呼び出し後に `ttsEditSegmentsProvider` を更新して、中断時点のセグメント状態を正しく反映

## 5. 最終確認

- [ ] 5.1 code-simplifierエージェントを使用してコードをよりシンプルにできないか確認
- [ ] 5.2 codexスキルを使用して現在開発中のコードレビューを実施
- [ ] 5.3 `fvm flutter analyze`でリントを実行
- [ ] 5.4 `fvm flutter test`でテストを実行
