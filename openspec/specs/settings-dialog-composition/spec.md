## Purpose

Settings dialog composition rules: split the monolithic dialog into a thin shell hosting a TabBar and per-section ConsumerStatefulWidgets that own their own controllers/state. Cross-section communication goes through Riverpod providers, the shell stays ≤200 LOC, and Piper labels come from AppLocalizations.
## Requirements
### Requirement: Settings dialog is composed of section ConsumerStatefulWidgets
The settings dialog SHALL be implemented as a thin shell widget hosting `TabBar`/`TabBarView`, plus a set of dedicated section widgets — one per coherent settings group. The shell SHALL NOT directly own controllers, focus nodes, or transient state belonging to any section. Each section SHALL be a `ConsumerStatefulWidget` (or `ConsumerWidget` if no local mutable state is needed) that owns the controllers, focus nodes, and ephemeral UI state for that section's inputs.

#### Scenario: Sections are independent widgets
- **WHEN** the settings dialog widget tree is inspected
- **THEN** sections (`GeneralSettingsSection`, `LlmSettingsSection`, `Qwen3SettingsSection`, `PiperSettingsSection`, `VoiceReferenceSection`) are present as separate `ConsumerStatefulWidget` (or `ConsumerWidget`) instances rather than inline build helpers on the shell

#### Scenario: Shell does not own section state
- **WHEN** the shell `_SettingsDialogState` (or equivalent) is inspected
- **THEN** it does NOT declare `TextEditingController`, `FocusNode`, drag-drop hover flags, or fetch-generation counters belonging to any specific settings group; only the `TabController` is owned by the shell

#### Scenario: Section disposal releases its own resources
- **WHEN** a section widget is disposed (e.g., the parent dialog is closed)
- **THEN** the section's `dispose` releases its own controllers and focus nodes; the shell does not need to be aware of these resources

### Requirement: Cross-section state goes through Riverpod
State that more than one settings section needs to read or mutate (e.g., the active TTS engine type, the active LLM provider, theme, language) SHALL be accessed via Riverpod providers, not via instance variables on a shared parent. Sections SHALL NOT receive shared mutable state through constructor parameters or callbacks for the purpose of inter-section synchronization.

#### Scenario: Engine type is shared via provider
- **WHEN** the user changes the TTS engine in one section and another section needs to react (e.g., showing engine-specific subsection)
- **THEN** the change is observed via `ref.watch(ttsEngineTypeProvider)` rather than passed through callback or shared instance variable

#### Scenario: Theme and language changes propagate via provider
- **WHEN** the user changes theme or language
- **THEN** the change is persisted via the corresponding repository and observed by other sections via `ref.watch` of the relevant provider

### Requirement: Settings shell stays under 200 lines
The shell file (`settings_dialog.dart`) SHALL contain only: tab controller setup, tab labels, tab content composition, and the dialog's chrome (title, close button). The total line count of the shell file SHALL be ≤ 200 LOC after the refactor.

#### Scenario: Shell file size budget
- **WHEN** `lib/features/settings/presentation/settings_dialog.dart` is measured after the refactor
- **THEN** its line count is ≤ 200 lines (significantly down from the pre-refactor 1,070 LOC), and the file contains no engine-specific or LLM-specific build helpers

### Requirement: Piper section labels come from AppLocalizations
The Piper settings section SHALL render every user-visible label (`TTSエンジン`, `モデル`, `モデルデータダウンロード`, `ダウンロード済み`, `再試行`, `速度 (lengthScale)`, `抑揚 (noiseScale)`, `ノイズ (noiseW)`) via `AppLocalizations.of(context)!.<key>` rather than hardcoded Japanese literals. The corresponding ARB keys SHALL exist in `app_ja.arb`, `app_en.arb`, and `app_zh.arb`.

#### Scenario: Piper labels resolve via AppLocalizations
- **WHEN** the Piper section renders any of its labels
- **THEN** each label is the result of an `AppLocalizations.of(context)!.<key>` lookup; no hardcoded Japanese string literal appears in the section's source

#### Scenario: Labels available in all supported locales
- **WHEN** any of the eight Piper-section keys is fetched from `app_ja.arb`, `app_en.arb`, or `app_zh.arb`
- **THEN** a non-empty translation exists in each ARB file

#### Scenario: Locale switch updates labels
- **WHEN** the locale is changed at runtime (`localeProvider` updated to `en` or `zh`)
- **THEN** all eight Piper labels re-render in the new language without restart

### Requirement: 設定ダイアログにアプリ情報 / 更新セクションを追加
設定ダイアログは「アプリ情報 / 更新」セクション (`AboutAndUpdateSection`) をタブ一覧に含めなければならない（SHALL）。当該セクションは `ConsumerStatefulWidget` または `ConsumerWidget` として実装し、シェル (`settings_dialog.dart`) は当該セクション固有のコントローラ・状態を保持してはならない（MUST NOT）。

#### Scenario: AboutAndUpdateSection の存在
- **WHEN** 設定ダイアログを開く
- **THEN** タブ一覧に「アプリ情報 / 更新」（または対応するローカライズ済みラベル）が表示され、`AboutAndUpdateSection` ウィジェットがその TabView に配置されている

#### Scenario: シェルが状態を保持しない
- **WHEN** `lib/features/settings/presentation/settings_dialog.dart` の `_SettingsDialogState`（または相当）を確認する
- **THEN** 更新確認用のコントローラ・タイマー・進捗 state は当該シェルには定義されていない（すべて `AboutAndUpdateSection` 側に存在する）

### Requirement: AboutAndUpdateSection の表示項目
`AboutAndUpdateSection` は以下の情報・操作を含まなければならない（SHALL）。

- 現在のアプリバージョン（`PackageInfo.fromPlatform()` から取得）
- ビルド番号
- 配布形態の表示（「インストーラ版」または「ポータブル版 (ZIP)」、ローカライズ済み）
- 最終更新確認日時（未確認の場合は「未確認」）
- 「更新を確認」ボタン（手動チェック起動、押下中はインジケータ表示）
- 「自動チェック」ON/OFF スイッチ（デフォルト ON）

#### Scenario: バージョン情報の表示
- **WHEN** `AboutAndUpdateSection` がレンダリングされる
- **THEN** 現在バージョン・ビルド番号・配布形態が画面上で確認できる

#### Scenario: 「更新を確認」ボタンの動作
- **WHEN** ユーザが「更新を確認」ボタンを押す
- **THEN** 押下中はローディングインジケータが表示され、結果（「最新です」または「v* が利用可能」）が同セクション内に表示される

#### Scenario: 自動チェックスイッチの永続化
- **WHEN** ユーザが自動チェックスイッチを切り替える
- **THEN** `SharedPreferences` の `app_update.auto_check_enabled` キーが対応する値で更新される

### Requirement: AboutAndUpdateSection のラベル国際化
`AboutAndUpdateSection` 内のすべてのユーザ可視ラベルは `AppLocalizations.of(context)!.<key>` で取得しなければならない（MUST）。ハードコードされた日本語・英語リテラルを含んではならない（MUST NOT）。対応 ARB キーは `app_ja.arb`、`app_en.arb`、`app_zh.arb` のすべてに追加しなければならない（SHALL）。

#### Scenario: ラベルが AppLocalizations 経由で解決される
- **WHEN** `AboutAndUpdateSection` のソースを確認する
- **THEN** 「アプリ情報」「更新を確認」「自動チェック」「最終確認日時」「インストーラ版」「ポータブル版」等のラベルがすべて `AppLocalizations.of(context)!.<key>` で取得されている

#### Scenario: 3 言語すべてに翻訳が存在
- **WHEN** `AboutAndUpdateSection` が使用する ARB キーを `app_ja.arb`、`app_en.arb`、`app_zh.arb` で検索する
- **THEN** いずれの ARB ファイルにも非空の翻訳が存在する

