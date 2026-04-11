## Why

qwen3-tts.cppが依存するggmlサブモジュールが現在v0.9.6+42（2026-02-07時点のコミット `5cecdad6`）にピン留めされている。最新のv0.9.11（2026-04-02リリース）では、Metalバックエンドの大幅改善（Flash Attention拡張、並行性改善、mul_mv_ext拡張）、Vulkanバックエンドの安定性向上、CPUバックエンドの最適化が含まれており、TTSパイプラインのボトルネックであるSpeaker Encode（全体の63.8%）とVocoder Decode（27.1%）のパフォーマンス向上が期待できる。5バージョン分のギャップが開いており、セキュリティパッチ（RPC RCE修正）も含まれるため早期の更新が望ましい。

## What Changes

- qwen3-tts.cppリポジトリ内のggmlサブモジュールをv0.9.6+42からv0.9.11に更新
- ggmlの再ビルド（macOS: Metal、Windows: Vulkan）
- 更新前後のTTSベンチマークを実施しパフォーマンス変化を記録
- NovelViewerのqwen3-tts.cppサブモジュールポインタを更新

## Capabilities

### New Capabilities

（なし）

### Modified Capabilities

- `tts-native-engine`: ggmlバックエンドのバージョン更新（v0.9.6→v0.9.11）。Metal/Vulkan/CPU各バックエンドの内部最適化・バグ修正の恩恵を受ける。API互換性は調査済みで破壊的変更なし。

## Impact

- **C++ (ggml サブモジュール)**: サブモジュールポインタの更新のみ。qwen3-tts.cppのコード変更は不要（API完全互換を確認済み）
- **ビルドスクリプト**: `build_tts_windows.bat`, `build_tts_macos.sh` は変更不要（CMakeオプションに影響する変更なし）
- **CI**: `release.yml` のサブモジュール取得は `recursive` なので変更不要
- **依存**: qwen3-tts.cppサブモジュール内のggmlサブモジュール更新が必要（ネスト2階層）
- **パフォーマンス**: ベースライン測定と比較測定を実施し、改善/劣化を定量的に記録
