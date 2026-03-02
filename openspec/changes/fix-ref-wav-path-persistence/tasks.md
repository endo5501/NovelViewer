## 1. テスト作成

- [ ] 1.1 `generateSegment()` が新規セグメント挿入時に `segment.refWavPath`（メタデータ値）をDBに保存することを検証するテストを作成
- [ ] 1.2 テストを実行し、現在の実装でテストが失敗することを確認

## 2. 実装

- [ ] 2.1 `TtsEditController.generateSegment()` の `insertSegment()` 呼び出しで `refWavPath: refWavPath` を `refWavPath: segment.refWavPath` に変更
- [ ] 2.2 テストを実行し、すべてのテストがパスすることを確認

## 3. 最終確認

- [ ] 3.1 simplifyスキルを使用してコードレビューを実施
- [ ] 3.2 codexスキルを使用して現在開発中のコードレビューを実施
- [ ] 3.3 `fvm flutter analyze`でリントを実行
- [ ] 3.4 `fvm flutter test`でテストを実行
