# Spec Delta

## ADDED Requirements

### Requirement: 設定ダイアログに同期セクションを追加
同期が使えるビルドでは、設定ダイアログは同期のセクションをタブ一覧に含めなければならない（SHALL）。同期が使えないビルドでは、そのタブを含めてはならない（SHALL NOT）。当該セクションは `ConsumerStatefulWidget` または `ConsumerWidget` として実装し、シェル（`settings_dialog.dart`）は当該セクション固有の状態（ログインの進行状況、同期の実行状態など）を保持してはならない（MUST NOT）。表示項目は `progress-sync-account` に従う。

#### Scenario: 同期が使えるビルド
- **WHEN** 同期が使える状態で設定ダイアログを開く
- **THEN** タブ一覧に「同期」（または対応するローカライズ済みラベル）が表示され、同期のセクションがその TabView に配置されている

#### Scenario: 同期が使えないビルド
- **WHEN** 同期が使えない状態で設定ダイアログを開く
- **THEN** タブ一覧に「同期」は表示されない

#### Scenario: シェルが状態を保持しない
- **WHEN** `lib/features/settings/presentation/settings_dialog.dart` を確認する
- **THEN** 同期のログインや実行状態に関する state は当該シェルに定義されていない
