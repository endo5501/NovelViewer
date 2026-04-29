## 1. 準備

- [x] 1.1 Sprint 2 (`type-tts-dtos-and-cache-databases`) のマージ確認 (DTO/Resolver 前提)
- [x] 1.2 Sprint 0/1 のマージ確認 (Logger 前提)
- [x] 1.3 `lib/features/tts/domain/` 配下に新規 engine config の置き場所を確認、なければ作成

## 2. Phase A — TtsEngineConfig sealed (TDD)

- [x] 2.1 `test/features/tts/domain/tts_engine_config_test.dart` 作成
- [x] 2.2 「`Qwen3EngineConfig` 構築で全フィールドが期待値で保持される」テスト
- [x] 2.3 「`PiperEngineConfig` 構築で全フィールドが期待値で保持される」テスト
- [x] 2.4 「sealed switch で両サブクラスが要求される (compile time)」テスト (compile_time の確認はコメント + 静的解析)
- [x] 2.5 「`Qwen3EngineConfig` には Piper 専用フィールドが存在しない」テスト (型レベル)
- [x] 2.6 テストが fail することを確認 (赤)
- [x] 2.7 `lib/features/tts/domain/tts_engine_config.dart` を実装 (sealed + 2 サブクラス)
- [x] 2.8 セクション 2 のテストが pass することを確認 (緑)

## 3. Phase A — resolveFromRef / resolveFromReader (TDD)

- [x] 3.1 「Qwen3 type を渡すと Qwen3EngineConfig を返す (provider state を読む)」テスト
- [x] 3.2 「Piper type を渡すと PiperEngineConfig を返す」テスト
- [x] 3.3 「`resolveFromReader(read, type)` が同等動作」テスト
- [x] 3.4 「`ref.read` を使い `ref.watch` を使わない」を反映するテスト (ProviderContainer の rebuild トリガーをカウント)
- [x] 3.5 テストが fail することを確認
- [x] 3.6 `resolveFromReader` 実装、`resolveFromRef` は委譲
- [x] 3.7 セクション 3 のテストが pass

## 4. Phase A — call site の置換

- [x] 4.1 `text_viewer_panel.dart:131-163` を `TtsEngineConfig.resolveFromRef(ref, engineType)` 1 行に置換
- [x] 4.2 `tts_edit_dialog.dart:166-194` を同様に置換
- [x] 4.3 `tts_edit_dialog.dart:226-259` を同様に置換
- [x] 4.4 `fvm flutter analyze` で 3 箇所の if/else が消えたことを確認

## 5. Phase A — TtsStreamingController.start シグネチャ変更

- [x] 5.1 既存 `tts_streaming_controller_test.dart` の `start()` 呼び出しを `TtsEngineConfig` 引数版に書き換え (テストパス)
- [x] 5.2 「`start(config: PiperEngineConfig(...))` で PiperTtsEngine が読み込まれる」テスト
- [x] 5.3 「`start(config: Qwen3EngineConfig(...))` で TtsEngine (qwen3) が読み込まれる」テスト
- [x] 5.4 テストが fail することを確認
- [x] 5.5 `TtsStreamingController.start()` シグネチャを変更し、内部で `config` から isolate に渡すパラメータを抽出
- [x] 5.6 セクション 5 のテストが pass

## 6. Phase A — TtsEditController 合成 API シグネチャ変更

- [x] 6.1 既存 `tts_edit_controller_test.dart` の合成系メソッド呼び出しを `TtsEngineConfig` 引数版に書き換え
- [x] 6.2 テストが fail することを確認
- [x] 6.3 `TtsEditController` 合成系メソッドを `TtsEngineConfig` 引数受け取りに変更
- [x] 6.4 セクション 6 のテストが pass

## 7. Phase B — TtsSession (TDD)

- [x] 7.1 `test/features/tts/data/tts_session_test.dart` 作成
- [x] 7.2 「`ensureModelLoaded(config)` happy path で isolate に LoadModelMessage が送信される」テスト
- [x] 7.3 「同一 config で `ensureModelLoaded` を二度呼ぶと二回目は no-op」テスト
- [x] 7.4 「`synthesize(...)` happy path で結果 Future が解決する」テスト
- [x] 7.5 「`abort()` で in-flight synthesize completer がエラー解決し、isolate.abort が呼ばれる」テスト
- [x] 7.6 「`dispose()` で subscription/completer/isolate が片付く」テスト
- [x] 7.7 「dispose 後の `ensureModelLoaded` 呼び出しは StateError」テスト
- [x] 7.8 「abort 中の新規 ensureModelLoaded は abort 完了を待ってから続行」テスト
- [x] 7.9 テストが fail することを確認
- [x] 7.10 `lib/features/tts/data/tts_session.dart` を実装
- [x] 7.11 セクション 7 のテストが pass

## 8. Phase B — controller を TtsSession 経由に書き換え

- [x] 8.1 `TtsStreamingController` のコンストラクタに `TtsSession?` を受け入れ、未指定時は内部で生成
- [x] 8.2 既存の `_subscription` / `_modelLoaded` / `_activeSynthesisCompleter` を削除し、`_session` 経由に置換
- [x] 8.3 既存テストの fixture を `TtsSession` inject 形に書き換え (定型ヘルパを `test_utils/` に追加)
- [x] 8.4 `tts_streaming_controller_test.dart` がパスすることを確認
- [x] 8.5 同様に `TtsEditController` を書き換え、`tts_edit_controller_test.dart` パス確認

## 9. Phase C — SegmentPlayer (TDD)

- [x] 9.1 `test/features/tts/data/segment_player_test.dart` 作成
- [x] 9.2 「`playSegment(filePath, isLast: false)`: setFilePath が listen より先に呼ばれる」テスト (call order assert)
- [x] 9.3 「`play()` は unawaited、完了は playerStateStream 経由で通知される」テスト
- [x] 9.4 「intermediate 完了で `pause()` が呼ばれ、`stop()` は呼ばれない」テスト
- [x] 9.5 「`isLast: true` で 500ms drain 後に pause/dispose 順で進む」テスト
- [x] 9.6 「`bufferDrainDelay: Duration.zero` で intermediate も last も即時に進む」テスト
- [x] 9.7 「`stop()` 中に drain delay が pending なら skip」テスト
- [x] 9.8 「`play().catchError` が completer のエラーパスを解決する」テスト
- [x] 9.9 テストが fail することを確認
- [x] 9.10 `lib/features/tts/data/segment_player.dart` を実装。`SegmentPlayer.playSegment` の冒頭に WASAPI 関連コメント (4 ポイント) を集約
- [x] 9.11 セクション 9 のテストが pass

## 10. Phase C — TtsStreamingController を SegmentPlayer 経由に

- [x] 10.1 既存テスト `tts_streaming_controller_test.dart` の "all segments without audio cutoff" 系シナリオを `SegmentPlayer` 経由実装でも担保するように調整
- [x] 10.2 `tts_streaming_controller.dart:355-388` を `SegmentPlayer.playSegment` 利用に置換
- [x] 10.3 既存の WASAPI 関連コメントは削除し、`SegmentPlayer` のコメントが正典であることを明示
- [x] 10.4 テストが pass することを確認

## 11. Phase C — TtsStoredPlayerController を SegmentPlayer 経由に

- [x] 11.1 既存テスト `tts_stored_player_controller_test.dart` の `bufferDrainDelay: Duration.zero` 経路が `SegmentPlayer` を通る形でも動くようにテスト fixture を調整
- [x] 11.2 `tts_stored_player_controller.dart:60-121` を `SegmentPlayer` 利用に置換
- [x] 11.3 既存の `bufferDrainDelay` パラメータは保持し、`SegmentPlayer` への propagation で実現
- [x] 11.4 テスト pass

## 12. Phase C — TtsEditController.playSegment を SegmentPlayer 経由に

- [x] 12.1 既存テストで「pause not stop」が assert されているか確認、無ければ追加
- [x] 12.2 `tts_edit_controller.dart:381-411` を `SegmentPlayer` 利用に置換
- [x] 12.3 テスト pass

## 13. Phase D — TextSegmenter provider (F027)

- [x] 13.1 `test/features/tts/providers/text_segmenter_provider_test.dart` で「同一 ref で同じインスタンスが返る」テスト
- [x] 13.2 テストが fail することを確認
- [x] 13.3 `lib/features/tts/providers/text_segmenter_provider.dart` 実装 (`Provider<TextSegmenter>((ref) => const TextSegmenter())`)
- [x] 13.4 3 controller の `TextSegmenter()` 直接 instantiation を `ref.read(textSegmenterProvider)` に置換
- [x] 13.5 既存テスト群がパスすることを確認

## 14. Phase D — vacuum lifecycle (F021)

- [x] 14.1 `test/features/tts/providers/vacuum_lifecycle_provider_test.dart` 作成
- [x] 14.2 「`markDirty(folder)` でフォルダが pending list に追加される」テスト
- [x] 14.3 「`AppLifecycleState.detached` で pending list 全フォルダに `incremental_vacuum(0)` が呼ばれる」テスト
- [x] 14.4 「detached が来ない (resume 等) では vacuum しない」テスト
- [x] 14.5 「同一フォルダの `markDirty` 複数回で vacuum は 1 回」テスト
- [x] 14.6 テストが fail することを確認
- [x] 14.7 `lib/features/tts/providers/vacuum_lifecycle_provider.dart` 実装
- [x] 14.8 `TtsAudioRepository.deleteEpisode` から `_database.reclaimSpace()` 同期呼び出しを削除し、`markDirty` 呼び出しに置換
- [x] 14.9 `reclaimSpace()` は public API として残し、明示呼び出しテストを追加
- [x] 14.10 `main.dart` に `WidgetsBinding.instance.addObserver(vacuumLifecycle)` を追加
- [x] 14.11 既存 `tts_audio_repository_test.dart` の "Disk space reclaimed after episode deletion" シナリオを「`detached` で reclaim されることを assert」に書き換え

## 15. 統合確認

- [x] 15.1 `text_viewer_panel.dart`, `tts_edit_dialog.dart`, `tts_streaming_controller.dart`, `tts_edit_controller.dart`, `tts_stored_player_controller.dart` で WASAPI 関連の重複コメントが残っていないことを grep で確認 (SegmentPlayer doc が canonical、edit_controller は drain=zero 理由のみ)
- [x] 15.2 ローカル起動で:
  - [x] 15.2.1 Qwen3 で 1 エピソードのストリーミング再生が正常終了する (drain で末尾切れ無し)
  - [x] 15.2.2 Piper で同様
  - [x] 15.2.3 Edit dialog で 1 セグメント再生 → pause not stop の挙動確認
  - [x] 15.2.4 大きい (>50MB) `tts_audio.db` でエピソード削除後、即時には UI スパイク無し、アプリ終了で DB ファイルサイズが縮む

## 16. 最終確認

- [x] 16.1 simplifyスキルを使用してコードレビューを実施
- [x] 16.2 codexスキルを使用して現在開発中のコードレビューを実施
- [x] 16.3 `fvm flutter analyze` でリントを実行 (1 info: implementation_imports for ProviderListenable — documented)
- [x] 16.4 `fvm flutter test` でテストを実行 (1298 passed)
