## 1. 準備

- [x] 1.1 Sprint 0-3 のマージ状況を確認 (本 sprint 自体は前段成果に強い依存はない、独立に進められる)
- [x] 1.2 `lib/features/settings/presentation/sections/` ディレクトリ作成
- [x] 1.3 現行 `settings_dialog.dart` の `wc -l` 値を記録 (解体前 1,088 LOC)

## 2. Phase A — 既存挙動の widget テスト追加 (ベースライン)

- [x] 2.1 `test/features/settings/presentation/settings_dialog_test.dart` 新規作成 (既存ファイルへの追加 + `settings_dialog_phase_a_test.dart` を新規作成)
- [x] 2.2 「ダイアログを開くと "一般" / "読み上げ" の 2 タブが表示される」テスト (`settings_dialog_tabs_test.dart`)
- [x] 2.3 「一般タブで表示モード Switch が `displayModeProvider` に応じて表示される」テスト (`settings_dialog_tabs_test.dart` / `settings_dialog_test.dart`)
- [x] 2.4 「一般タブでテーマトグルが `themeModeProvider` に対応する」テスト (`settings_dialog_test.dart`)
- [x] 2.5 「LLM プロバイダ dropdown で OpenAI/Ollama/未設定 を切替できる」テスト (`llm_settings_test.dart`)
- [x] 2.6 「OpenAI 互換選択時に URL/API key/model TextField が表示される」テスト (`llm_settings_test.dart`)
- [x] 2.7 「Ollama 選択時にモデル dropdown が表示され、URL から取得を試みる」テスト (`llm_settings_test.dart`)
- [x] 2.8 「読み上げタブの engine SegmentedButton で Qwen3/Piper を切替」テスト (`settings_dialog_phase_a_test.dart`)
- [x] 2.9 「Qwen3 選択時に model size / language / voice reference UI が表示」テスト (`settings_dialog_tabs_test.dart` + `tts_model_download_ui_test.dart`)
- [x] 2.10 「Piper 選択時に model dropdown / 3 sliders / download status が表示」テスト (`settings_dialog_phase_a_test.dart`)
- [x] 2.11 「voice reference dropdown に refresh / rename / open-folder ボタンが表示」テスト (`voice_reference_selector_test.dart`)
- [x] 2.12 「drag-drop 領域が音声ファイルを受け入れる」テスト (`settings_dialog_phase_a_test.dart`)
- [x] 2.13 `fvm flutter test` で 2.x 全 green を確認 (現行実装に対するベースライン)
- [x] 2.14 ベースラインが固まった状態でコミット

## 3. Phase B — Piper UI の l10n 化 (F026)

- [x] 3.1 `lib/l10n/app_ja.arb` に 6 キー追加 + 既存 `settings_modelDataDownload` / `settings_retryButton` の再利用 (実 keys: `settings_ttsEngine`, `settings_modelLabel`, `settings_piperDownloaded`, `settings_piperLengthScale`, `settings_piperNoiseScale`, `settings_piperNoiseW`)
- [x] 3.2 `lib/l10n/app_en.arb` に英訳を追加
- [x] 3.3 `lib/l10n/app_zh.arb` に中文翻訳を追加
- [x] 3.4 `fvm flutter pub get` で `AppLocalizations` を再生成
- [x] 3.5 「`AppLocalizations` で 8 Piper ラベルが取得できる」テストを追加 (各 locale) — `settings_piper_l10n_test.dart`
- [x] 3.6 `settings_dialog.dart` の Piper セクションで 8 つの和文リテラルを `AppLocalizations.of(context)!.<key>` に置換
- [x] 3.7 Phase A テストの Piper 関連 finder を `find.text(AppLocalizations.of(...).<key>)` ベースに更新
- [x] 3.8 `fvm flutter test` で全 green、特に Piper 関連 widget テストが各 locale で通ることを確認

## 4. Phase C — GeneralSettingsSection 抽出

- [x] 4.1 既存ダイアログテスト群が "一般" タブの assertion をカバーしているため、独立したセクションテストファイルは新規作成せず再利用 (`settings_dialog_test.dart`, `settings_dialog_tabs_test.dart`)
- [x] 4.2 (skipped) — 既存テストが移植不要のため赤確認は不要
- [x] 4.3 `lib/features/settings/presentation/sections/general_settings_section.dart` を `ConsumerWidget` で実装
- [x] 4.4 `settings_dialog.dart` 内の "一般" タブ build を `GeneralSettingsSection()` + `LlmSettingsSection()` に置換
- [x] 4.5 全 settings テスト green

## 5. Phase C — LlmSettingsSection 抽出

- [x] 5.1 既存 `llm_settings_test.dart` が LLM 関連 assertion を網羅しているため再利用
- [x] 5.2 (skipped)
- [x] 5.3 `llm_settings_section.dart` を実装。`_baseUrlController` / `_apiKeyController` / `_modelController` / `_llmProvider` / `_selectedOllamaModel` を section local に移動
- [x] 5.4 Phase D の provider 化は行わず、現行の `_fetchOllamaModels` / `_ollamaModels*` ロジックをそのまま section に移動
- [x] 5.5 `settings_dialog.dart` から該当 build helper を削除
- [x] 5.6 全テスト green

## 6. Phase C — Qwen3SettingsSection 抽出

- [x] 6.1 既存 `settings_dialog_tabs_test.dart` / `tts_model_download_ui_test.dart` が Qwen3 関連 assertion を網羅
- [x] 6.2 (skipped)
- [x] 6.3 `qwen3_settings_section.dart` を実装 (language / model size / model download をサブウィジェットに分離)
- [x] 6.4 `settings_dialog.dart` 該当部を置換
- [x] 6.5 全テスト green

## 7. Phase C — PiperSettingsSection 抽出

- [x] 7.1 `settings_dialog_phase_a_test.dart` の Piper assertion (model dropdown / 3 sliders / download status / ARB キー経由ラベル) を再利用
- [x] 7.2 (skipped)
- [x] 7.3 `piper_settings_section.dart` を実装 (Phase B の `AppLocalizations` ラベルをそのまま使用)
- [x] 7.4 `settings_dialog.dart` 該当部を置換
- [x] 7.5 全テスト green
- [x] 7.6 `find.text('TTSエンジン')` 等の和文リテラル一致が `settings_dialog.dart` 含む presentation 層に残っていないことを `Grep` で確認

## 8. Phase C — VoiceReferenceSection 抽出

- [x] 8.1 既存 `voice_reference_selector_test.dart` が dropdown / refresh / rename / open-folder / drag-drop を網羅
- [x] 8.2 (skipped)
- [x] 8.3 `voice_reference_section.dart` を実装。`_voiceFiles` / `_isDragging` / `_RenameDialog` を section local に移動
- [x] 8.4 `settings_dialog.dart` 該当部を置換
- [x] 8.5 全テスト green (`navigateToTtsTab` のタイミング調整: section の `initState` が tab 切替後に走るため `pumpAndSettle` 後に追加で real-async 待機)

## 9. Phase C — VoiceRecordingSection 抽出 (可能なら)

- [x] 9.1 voice recording は `VoiceRecordingDialog` (既存ダイアログ) を呼び出すマイクボタンだけが voice reference に組み込まれており、独立したセクションを作る価値なし
- [x] 9.2 (skipped) — 独立しない判断
- [x] 9.3 voice reference section 内に保持

## 10. Phase C — シェル化と LOC 確認

- [x] 10.1 `settings_dialog.dart` を `TabController` / `TabBar` / `TabBarView` / 各 section 組み立て + close ボタンだけ持つシェルに整理 (`_GeneralTab`, `_TtsTab`, `_EngineSelector` のみ shell-private)
- [x] 10.2 旧 instance var を `_SettingsDialogState` から削除済み (TabController のみ保持)
- [x] 10.3 `wc -l lib/features/settings/presentation/settings_dialog.dart` で 160 LOC を確認 (≤ 200 達成)
- [x] 10.4 ダイアログ統合テストが green を維持

## 11. Phase D — ollamaModelListProvider 導入

- [x] 11.1 `test/features/llm_summary/providers/ollama_model_list_provider_test.dart` 作成
- [x] 11.2 「`ref.watch(ollamaModelListProvider(url))` が成功時にモデル一覧 `AsyncValue.data` を返す」テスト
- [x] 11.3 「fetch エラーが `AsyncValue.error` で返される」テスト
- [x] 11.4 「URL 変更で旧 family entry が autoDispose されること」テスト
- [x] 11.5 「`ref.invalidate` で再 fetch が走ること」テスト
- [x] 11.6 fail 確認 (実装前にコンパイルエラーで赤を確認)
- [x] 11.7 `lib/features/llm_summary/providers/ollama_model_list_provider.dart` を `FutureProvider.autoDispose.family<List<String>, String>` で実装
- [x] 11.8 セクション 11 テスト全 green

## 12. Phase D — LlmSettingsSection を provider 経由へ

- [x] 12.1 既存 `llm_settings_test.dart` の data/loading/error 観測テスト群を再利用 (provider 切替後もパス確認)
- [x] 12.2 (skipped — 既存テスト再利用)
- [x] 12.3 `LlmSettingsSection` の `_fetchOllamaModels` / `_ollamaModels` / `_ollamaModelsLoading` / `_ollamaModelsError` / `_fetchGeneration` を全削除
- [x] 12.4 `ref.watch(ollamaModelListProvider(currentBaseUrl))` で UI 構築 (error は `hasError` 経由で「reload 中も error を表示」を担保)
- [x] 12.5 refresh ボタンは `ref.invalidate(ollamaModelListProvider(currentBaseUrl))` を呼ぶ実装に
- [x] 12.6 全 settings + llm_summary テスト green、保存済みモデルが list に無いとき選択クリアも `ref.listen` 経由で動作

## 13. 統合動作確認

- [ ] 13.1 `fvm flutter run` でローカル起動、設定ダイアログを開く
- [ ] 13.2 一般タブ全項目の動作確認 (表示モード、テーマ、フォント等)
- [ ] 13.3 LLM 設定: OpenAI 設定 → 保存 → 再起動で復元、Ollama URL 入力で自動取得、refresh で再取得
- [ ] 13.4 TTS: Qwen3 / Piper 切替、各設定保存、再起動で復元
- [ ] 13.5 voice reference: 選択、refresh、rename、フォルダ open、drag-drop
- [ ] 13.6 ロケール切替で Piper ラベル 8 種が EN/ZH/JA で正しく表示
- [ ] 13.7 `settings_dialog.dart` の最終 LOC を記録 (≤ 200)
- [ ] 13.8 grep で `settings_dialog.dart` 内に和文リテラル `'TTSエンジン'` 等が残っていないことを確認

## 14. 最終確認

- [ ] 14.1 simplifyスキルを使用してコードレビューを実施
- [ ] 14.2 codexスキルを使用して現在開発中のコードレビューを実施
- [ ] 14.3 `fvm flutter analyze` でリントを実行
- [ ] 14.4 `fvm flutter test` でテストを実行
