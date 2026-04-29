## Why

`lib/features/settings/presentation/settings_dialog.dart` は 1,070 LOC の god file。`_SettingsDialogState` 1 クラスに 11 のインスタンス変数 (controllers / focus nodes / 一時状態) が混在し、13 の `build*` ヘルパが general / LLM / Ollama 取得 / Qwen3 / Piper / 音声参照 / drag-drop / rename / 録音 を 1 まとめにレンダリングしている。直近 6 ヶ月で 19 commits の高 churn 領域 — 触るたびにメンテナンスコストを払い続けている (F004)。

加えて、Piper セクションの 8 ヶ所の和文文字列 (`'TTSエンジン'`, `'モデル'`, `'モデルデータダウンロード'`, `'ダウンロード済み'`, `'再試行'`, `'速度 (lengthScale)'`, `'抑揚 (noiseScale)'`, `'ノイズ (noiseW)'`) が `AppLocalizations` を経由せずハードコードされており、既存の `i18n-infrastructure` spec の "no hardcoded Japanese in presentation files" 要件に違反している (F026)。

ユーザーは Sprint 4 を **1 PR で「テスト追加 → 解体 → l10n 修正」を 1 change に納める** 方針で承認済み。Sprint 5 (`text_viewer_panel` 解体) も同じパターンで進める前段検証としても価値がある。

## What Changes

### Phase A — 既存挙動の widget テスト追加 (リグレッションネット)

監査 F039 が指摘するとおり presentation 層の widget テストは薄い。1,070 LOC を分割する前に、各セクションの**現状の動作**を覆う widget テストを書き、解体後も green が維持されることを担保する。

- General タブ: 表示モード・テーマ・フォント関連のトグル/スライダー
- LLM プロバイダ設定: OpenAI 互換 (URL / API key / model)、Ollama (URL / モデル一覧 dropdown)
- TTS タブ Qwen3 セクション: model size、language、voice reference dropdown、ダウンロードステータス
- TTS タブ Piper セクション: model dropdown、3 sliders、ダウンロードステータス
- 音声ファイル管理: drag-drop、rename、refresh

このフェーズの TDD は変則的: テストは**現行コードに対して green**で書き、commit。後続 Phase の解体作業で red にならないことを継続的に確認する。

### Phase B — F026 Piper l10n コンプライアンス

8 つのハードコード和文を ARB に移管:
- `app_ja.arb` に 8 キー追加 (現状の和文を値として保持)
- `app_en.arb`、`app_zh.arb` に翻訳追加
- 実装側の文字列リテラルを `AppLocalizations.of(context)!.<key>` に置換

ARB キー命名規約: `settings*` プレフィックス (`settingsTtsEngine`, `settingsModel`, `settingsModelDownload`, `settingsDownloaded`, `settingsRetry`, `settingsLengthScale`, `settingsNoiseScale`, `settingsNoiseW`)。

### Phase C — セクション ConsumerStatefulWidget 抽出 (F004)

監査の推奨に従い、セクション単位で `ConsumerStatefulWidget` に分解:

- `lib/features/settings/presentation/sections/general_settings_section.dart`
- `lib/features/settings/presentation/sections/llm_settings_section.dart`
- `lib/features/settings/presentation/sections/qwen3_settings_section.dart`
- `lib/features/settings/presentation/sections/piper_settings_section.dart`
- `lib/features/settings/presentation/sections/voice_reference_section.dart`
- `lib/features/settings/presentation/sections/voice_recording_section.dart` (もし voice_reference と分離可能なら)

`settings_dialog.dart` は `TabBar` + `TabBarView` + 各セクション組み立てだけの 200 LOC 以下のシェルになる。各セクションはそのセクション専用の controller / focus node を**自分で**所有する (親への instance variable 流出を排除)。

### Phase D — Ollama モデル取得を Riverpod FutureProvider.family へ

監査推奨。現状はダイアログ state 内に fetch ロジックがあり、loading/error が ad-hoc な bool で扱われている。

- 新規 `ollamaModelListProvider` (`FutureProvider.family<List<String>, String>` キー = Ollama URL)
- `LlmSettingsSection` は `ref.watch(ollamaModelListProvider(currentUrl))` で `AsyncValue<List<String>>` を購読
- ローディング/エラーは `AsyncValue` の when パターンで分岐
- 既存の `OllamaClient.fetchModels` は内部実装として provider 内から呼ぶ

## Capabilities

### New Capabilities
- `settings-dialog-composition`: 設定ダイアログがセクション単位の `ConsumerStatefulWidget` で構成されることを契約として固定。将来「再び1つに戻す」commit を防ぐためのテスタブル契約

### Modified Capabilities
- `ollama-model-list`: Ollama モデル取得が `FutureProvider.family` を経由する形を要件として追記。loading/error 表示は `AsyncValue` のセマンティクスに揃える

## Impact

- **Code (additions)**:
  - `lib/features/settings/presentation/sections/general_settings_section.dart`
  - `lib/features/settings/presentation/sections/llm_settings_section.dart`
  - `lib/features/settings/presentation/sections/qwen3_settings_section.dart`
  - `lib/features/settings/presentation/sections/piper_settings_section.dart`
  - `lib/features/settings/presentation/sections/voice_reference_section.dart`
  - (任意) `lib/features/settings/presentation/sections/voice_recording_section.dart`
  - `lib/features/llm_summary/providers/ollama_model_list_provider.dart` (Phase D)
- **Code (modifications)**:
  - `lib/features/settings/presentation/settings_dialog.dart` — 1,070 LOC → 200 LOC 以下のシェル
  - `lib/l10n/app_ja.arb`, `app_en.arb`, `app_zh.arb` — 8 キー追加
- **Tests (additions)**:
  - `test/features/settings/presentation/settings_dialog_test.dart` (Phase A、シェルレベルの統合テスト)
  - `test/features/settings/presentation/sections/general_settings_section_test.dart`
  - `test/features/settings/presentation/sections/llm_settings_section_test.dart`
  - `test/features/settings/presentation/sections/qwen3_settings_section_test.dart`
  - `test/features/settings/presentation/sections/piper_settings_section_test.dart` (Piper のラベルが ARB 経由であることを assert)
  - `test/features/settings/presentation/sections/voice_reference_section_test.dart`
  - `test/features/llm_summary/providers/ollama_model_list_provider_test.dart`
- **Dependencies**: 追加なし
- **BREAKING (内部 API)**: なし。`SettingsDialog` の公開 API (build / コンストラクタ) は不変。内部実装のみ変更
- **UX**: 完全に不変。すべての入力値、保存挙動、ボタン動作、レイアウトは現状維持
- **Risk**: 11 インスタンス変数を section 間で正しく分配しないと、UI 状態の取り違え (タブ切り替えで controller が消える等) が起きる。Phase A の widget テストでこれを検出する
