## 1. ベースライン測定

- [x] 1.1 現行ggml v0.9.6でTTSエンジンをビルド（`scripts/build_tts_macos.sh`）
- [x] 1.2 ベースラインベンチマーク実行（`scripts/benchmark_tts.sh --model-dir <dir> --runs 5 --max-tokens 200 --output-dir benchmarks/baseline-v096`）
- [ ] 1.3 ベースライン結果をリポジトリにコミット

## 2. ggmlサブモジュール更新（qwen3-tts.cppリポジトリ側）

- [ ] 2.1 qwen3-tts.cppリポジトリでggmlサブモジュールをv0.9.11に更新（`git -C ggml fetch --tags && git -C ggml checkout v0.9.11`）
- [ ] 2.2 qwen3-tts.cppリポジトリでサブモジュール更新をコミット・プッシュ

## 3. ビルドと動作確認

- [ ] 3.1 ggml v0.9.11でTTSエンジンを再ビルド（`scripts/build_tts_macos.sh`）
- [ ] 3.2 CLIでの基本動作確認（音声合成が正常に完了すること）

## 4. パフォーマンス測定・比較

- [ ] 4.1 更新後ベンチマーク実行（`scripts/benchmark_tts.sh --model-dir <dir> --runs 5 --max-tokens 200 --output-dir benchmarks/upgraded-v0911`）
- [ ] 4.2 ベースラインとの比較結果を記録

## 5. NovelViewer統合

- [ ] 5.1 NovelViewerのqwen3-tts.cppサブモジュールポインタを更新
- [ ] 5.2 NovelViewerのTTSエンジンを再ビルド
- [ ] 5.3 `fvm flutter test` でFlutterテストを実行

## 6. 最終確認

- [ ] 6.1 simplifyスキルを使用してコードレビューを実施
- [ ] 6.2 codexスキルを使用して現在開発中のコードレビューを実施
- [ ] 6.3 `fvm flutter analyze`でリントを実行
- [ ] 6.4 `fvm flutter test`でテストを実行
