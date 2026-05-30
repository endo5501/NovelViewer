## ADDED Requirements

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
