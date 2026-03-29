## 1. CLI Vulkanビルド対応

- [ ] 1.1 `third_party/qwen3-tts.cpp/CMakeLists.txt` の `qwen3-tts-cli` ターゲットにWindows Vulkanリンク設定を追加
- [ ] 1.2 CLIをビルドし、Vulkanバックエンドでの動作を確認

## 2. ベンチマークスクリプト作成

- [ ] 2.1 `scripts/benchmark_tts.sh` を作成（CLI呼び出し、タイミングパース、JSON出力、Windows/macOS両対応）
- [ ] 2.2 ベンチマークスクリプトの動作確認（実際にCLIを実行してJSON結果を取得）

## 3. 最終確認

- [ ] 3.1 simplifyスキルを使用してコードレビューを実施
- [ ] 3.2 codexスキルを使用して現在開発中のコードレビューを実施
- [ ] 3.3 `fvm flutter analyze`でリントを実行
- [ ] 3.4 `fvm flutter test`でテストを実行
