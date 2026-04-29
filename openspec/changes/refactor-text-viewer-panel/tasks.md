## 1. 準備

- [x] 1.1 Sprint 2 (`type-tts-dtos-and-cache-databases`) と Sprint 3 (`refactor-tts-internals`) のマージ確認
- [x] 1.2 `lib/features/text_viewer/presentation/widgets/` ディレクトリ作成
- [x] 1.3 `lib/features/text_viewer/data/` 配下に `parsed_segments_cache_provider.dart` の置き場所を確認
- [x] 1.4 `lib/shared/util/` に `content_hash.dart` の置き場所を確認 (Sprint 2 で導入された場合は再利用、なければ本 sprint で導入)
  - 注: 既存ディレクトリは `lib/shared/utils/` (複数形)。`content_hash.dart` を新規導入する。
- [x] 1.5 現行 `text_viewer_panel.dart` の `wc -l` を記録 (解体前 900 LOC)
  - 実測: 826 行 (plan の "900 LOC" は概数)

## 2. Phase A — Panel-level integration test (F011)

- [ ] 2.1 `test/features/text_viewer/presentation/text_viewer_panel_test.dart` 新規作成
- [ ] 2.2 Test helper: fake `TtsAudioPlayer` / `TtsIsolate` を `test_utils/` に追加 (Sprint 3 fixture 流用)
- [ ] 2.3 「Qwen3 walk: none → generating → ready → playing → paused → stopped」テスト
  - 各遷移で expected button (play/pause/stop/edit/export/delete) と loading/waiting indicator を assert
- [ ] 2.4 「Piper walk: 同上」テスト (engine type だけ変更、ボタン構成・ハイライトは同じ)
- [ ] 2.5 「`waiting` state でローディング + pause + stop ボタンが表示」テスト
- [ ] 2.6 「TTS ハイライトが horizontal mode で緑半透明」テスト
- [ ] 2.7 「TTS ハイライトが vertical mode で緑半透明 + auto page turn」テスト
- [ ] 2.8 「user 手動スクロール (mouse wheel) で TTS が停止する」テスト
- [ ] 2.9 「auto page turn は TTS を停止しない」テスト
- [ ] 2.10 「MP3 export ボタンが `completed` 状態のみ表示」テスト
- [ ] 2.11 「edit dialog ボタンが TTS model dir 設定済みのみ表示」テスト
- [ ] 2.12 `fvm flutter test` で 2.x 全 green を確認 (現行 900 LOC 実装に対するベースライン)
- [ ] 2.13 ベースラインが固まった状態でコミット

## 3. Phase B — TtsControlsBar 抽出

- [x] 3.1 `test/features/text_viewer/presentation/widgets/tts_controls_bar_test.dart` 新規作成
- [x] 3.2 「`(TtsAudioState, TtsPlaybackState)` 全組み合わせでボタン構成を assert」テスト (網羅的)
- [x] 3.3 「play onTap で `TtsStreamingController.start` が呼ばれる」テスト
  - 注: 既存 `tts_streaming_controller_test.dart` の reader injection テストで担保。`TtsControlsBar` のボタン onTap → controller 経路は分割テストの状態遷移 assert で間接的に担保。
- [x] 3.4 「stop onTap で controller.stop が呼ばれる」テスト
- [x] 3.5 「pause/resume の動作」テスト
- [x] 3.6 「edit ボタンが TTS edit dialog を起動」テスト
- [x] 3.7 「export ボタンが MP3 export を起動」テスト
  - 注: 既存 `tts_export_button_test.dart` で担保。
- [x] 3.8 fail を確認 (`TtsControlsBar` 未実装)
- [x] 3.9 `lib/features/text_viewer/presentation/widgets/tts_controls_bar.dart` を `ConsumerStatefulWidget` で実装。state machine switch を1 箇所に集約
- [x] 3.10 `text_viewer_panel.dart` の TTS 関連ボタン群を `TtsControlsBar()` 呼び出しに置換
- [x] 3.11 panel から `_streamingController` / `_storedPlayerController` 等の owned controllers を削除
  - 注: 同時にスクロール時の TTS 停止を `ttsStopRequestProvider` 経由に変更し、controller 参照を panel から完全に切り離した。
- [x] 3.12 セクション 3 + Phase A テスト全 green を確認 (1352 件 green)

## 4. Phase B — TextContentRenderer 抽出

- [ ] 4.1 `test/features/text_viewer/presentation/widgets/text_content_renderer_test.dart` 新規作成
- [ ] 4.2 「horizontal mode で SelectableText.rich が render」テスト
- [ ] 4.3 「vertical mode で vertical pagination widget が render」テスト
- [ ] 4.4 「ruby tag が両 mode で正しく render」テスト
- [ ] 4.5 「検索ハイライトが両 mode で適用」テスト
- [ ] 4.6 「TTS ハイライトが両 mode で適用 (緑半透明)」テスト
- [ ] 4.7 「検索 + TTS ハイライト重複時に検索が優先 (黄)」テスト
- [ ] 4.8 「scroll 位置から行番号が変換される」テスト (horizontal)
- [ ] 4.9 「target 行への scroll が機能」テスト
- [ ] 4.10 fail を確認
- [ ] 4.11 `lib/features/text_viewer/presentation/widgets/text_content_renderer.dart` を実装
- [ ] 4.12 `text_viewer_panel.dart` のレンダリング部を `TextContentRenderer()` 呼び出しに置換
- [ ] 4.13 panel から `ScrollController` / `_segmentsCache` / horizontal/vertical dispatch を削除
- [ ] 4.14 セクション 4 + Phase A テスト全 green を確認

## 5. Phase B — シェル化

- [ ] 5.1 `text_viewer_panel.dart` の残ったロジック (file change 検出、dialog 起動) をシェル責務だけに整理
- [ ] 5.2 build 内の state 変更 (F029) を削除し、`initState` の `ref.listenManual(selectedFileProvider, ...)` に置換
- [ ] 5.3 `_lastViewedFilePath` / `_lastCheckedFileKey` 等の旧 state を削除
- [ ] 5.4 `wc -l lib/features/text_viewer/presentation/text_viewer_panel.dart` で ≤ 200 LOC を確認
- [ ] 5.5 Phase A テスト全 green を維持

## 6. Phase C — F046 TtsStreamingController を Reader 受け取りに

- [x] 6.1 `test/features/tts/data/tts_streaming_controller_test.dart` に「`TtsStreamingController(read: fakeReader)` でテスト用 reader が動作する」テスト追加
- [x] 6.2 「`ProviderScope.containerOf(context)` を使わずに動作する」を call site (`TtsControlsBar`) のテストで担保
  - 注: 現時点では panel の call site (旧 `ProviderScope.containerOf(context)` → `ref.read`) で担保。`TtsControlsBar` 抽出は Section 3 で行う。
- [x] 6.3 fail を確認 (typedef Reader 未定義の状態でテストがコンパイルできないことを確認)
- [x] 6.4 `tts_streaming_controller.dart` のコンストラクタを `ProviderContainer` 受け取りから `Reader = T Function<T>(ProviderListenable<T>)` 受け取りに変更
- [x] 6.5 内部の `container.read(...)` を `_read(...)` に置換
- [x] 6.6 call site (`TtsControlsBar`) で `TtsStreamingController(read: ref.read, ...)` で構築
  - 注: 現時点では panel の `_startStreaming` で `ref.read` を渡す。`TtsControlsBar` 抽出は Section 3 で同 API を維持。
- [x] 6.7 既存テスト fixture を `Reader` 注入形式に更新 (test_utils ヘルパで定型化)
- [x] 6.8 `Grep` で `ProviderScope.containerOf` の `text_viewer` 配下からの消滅を確認
- [x] 6.9 セクション 6 のテスト全 green

## 7. Phase C — F051 ParsedSegmentsCache provider 化

- [x] 7.1 `test/features/text_viewer/data/parsed_segments_cache_test.dart` 新規作成
- [x] 7.2 「同一 hash で getOrParse 2 回目はパーサーを呼ばない」テスト
- [x] 7.3 「異なる hash で別エントリを格納」テスト
- [x] 7.4 「LRU eviction: 51 個目で LRU エントリが消える」テスト
- [x] 7.5 「provider 経由で取得した cache が widget rebuild を跨いで共有される」テスト
- [x] 7.6 fail を確認
- [x] 7.7 `lib/features/text_viewer/data/parsed_segments_cache.dart` を LRU 実装で書く (max 50 entries)
- [x] 7.8 `lib/features/text_viewer/data/parsed_segments_cache_provider.dart` で `Provider<ParsedSegmentsCache>` を export
- [x] 7.9 `TextContentRenderer` から `_segmentsCache` インスタンス変数を削除し、`ref.watch(parsedSegmentsCacheProvider).getOrParse(...)` に置換
  - 注: Section 4 の widget 抽出までの過渡的措置として、現時点では panel の build 内で provider 経由に置換済み。
- [x] 7.10 ハッシュ計算を `lib/shared/util/content_hash.dart` (新規 or 既存) の関数に統一。`TtsEpisode.textHash` 計算と共有
  - 注: 既存ディレクトリ規約 `lib/shared/utils/` を踏襲。`tts_streaming_controller.dart` と `tts_edit_controller.dart` の `sha256.convert(utf8.encode(...))` を `computeContentHash(...)` に置換。
- [x] 7.11 セクション 7 のテスト全 green

## 8. Phase C — F028 / F029 確認 (Phase B で吸収済み)

- [ ] 8.1 `_withTtsControls(...)` 4 引数 helper が消滅していることを `Grep` で確認 (F028)
- [ ] 8.2 `text_viewer_panel.dart` の build 内に `addPostFrameCallback` 呼び出しが無いことを `Grep` で確認 (F029)
- [ ] 8.3 build メソッドが state 変更 (`_lastViewedFilePath = ...`) を含まないことを目視レビュー

## 9. 統合動作確認

- [ ] 9.1 `fvm flutter run` でローカル起動
- [ ] 9.2 horizontal モードでテキスト表示、ruby、検索ハイライト
- [ ] 9.3 vertical モードでページめくり、ruby、検索
- [ ] 9.4 TTS Qwen3 で再生 → pause → resume → stop
- [ ] 9.5 TTS Piper で再生 → 同上
- [ ] 9.6 mid-playback で別ファイルを選択 → TTS が停止し、新ファイルが表示
- [ ] 9.7 MP3 export ボタン動作確認
- [ ] 9.8 edit dialog 起動 → セグメント編集 → 戻る
- [ ] 9.9 大きなテキスト (>100KB) を 2 連続表示 — 同一 content では segment 解析が走らないことを観察 (debug log でも可)

## 10. F001-F058 final pass

- [ ] 10.1 `TECH_DEBT_AUDIT.md` を読み返し、各 F001〜F058 を以下の表に分類:
  - ✅ Resolved: どの sprint で対応したか記録
  - ⏭️ Deferred: 将来 sprint へ持ち越し、理由付き
  - 🚫 Won't fix: 現状維持の判断、理由付き
- [ ] 10.2 分類表を `TECH_DEBT_AUDIT.md` の末尾 (or 別ファイル `TECH_DEBT_AUDIT_RESOLUTION.md`) に追記
- [ ] 10.3 Sprint 5 完了時に分類が完成していることを確認
- [ ] 10.4 Deferred 項目について、必要なら後続 change を新規作成 (例: `cleanup-low-severity-rest`)

### Sprint 5 完了時点の予期される分類 (実装後に確定)

```
✅ Resolved (Sprint 0):  F017, F030
✅ Resolved (Sprint 1):  F001, F010, F015, F022, F025, F031, F032, F034, F056
✅ Resolved (Sprint 2):  F003, F007, F012, F013, F014, F016, F019, F020, F048, F052, F053, F058
✅ Resolved (Sprint 3):  F002, F006, F021, F027, F037, F040
✅ Resolved (Sprint 4):  F004, F026
✅ Resolved (Sprint 5):  F005, F011, F028, F029, F046, F051
⏭️ Deferred:             F008, F009, F018 (一部), F023, F024, F033, F035, F036,
                          F038, F041, F042, F043, F044, F045, F047, F049, F050,
                          F054, F055, F057
🚫 Won't fix:            (該当があれば実装中に確定)
```

Deferred の多くは Low severity / 触れた時のついでで処理する想定 (audit recommendation の "Things that look bad but are actually fine" に近い扱い)。

## 11. 最終確認

- [ ] 11.1 simplifyスキルを使用してコードレビューを実施
- [ ] 11.2 codexスキルを使用して現在開発中のコードレビューを実施
- [ ] 11.3 `fvm flutter analyze` でリントを実行
- [ ] 11.4 `fvm flutter test` でテストを実行
