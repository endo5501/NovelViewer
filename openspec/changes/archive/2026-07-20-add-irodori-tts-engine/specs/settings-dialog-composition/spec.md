# settings-dialog-composition (delta)

## ADDED Requirements

### Requirement: Irodori 設定セクション
設定ダイアログの TTS 設定は `IrodoriSettingsSection` を独立した `ConsumerStatefulWidget` (ローカル可変状態が不要なら `ConsumerWidget`) として含まなければならない (SHALL)。シェル (`settings_dialog.dart`) は当該セクション固有のコントローラ・状態を保持してはならない (MUST NOT)。セクションは Irodori モデルダウンロード UI (進捗 / ダウンロード済み表示 / 再試行)、`speaker_guidance_scale` / `caption_guidance_scale` スライダー、`num_inference_steps` 入力を含まなければならない (SHALL)。すべてのユーザ可視ラベルは `AppLocalizations.of(context)!.<key>` で取得し、対応する ARB キーを `app_ja.arb` / `app_en.arb` / `app_zh.arb` のすべてに追加しなければならない (MUST)。

#### Scenario: セクションが独立ウィジェットとして存在
- **WHEN** Irodori エンジン選択中に設定ダイアログのウィジェットツリーを検査する
- **THEN** `IrodoriSettingsSection` がシェルのインラインビルドヘルパーではなく独立ウィジェットとして存在する

#### Scenario: パラメータスライダーの表示
- **WHEN** Irodori 設定セクションが表示される
- **THEN** speaker_guidance_scale / caption_guidance_scale スライダーと num_inference_steps 入力が表示され、変更が永続化される

#### Scenario: 3言語すべてに翻訳が存在
- **WHEN** `IrodoriSettingsSection` が使用する ARB キーを `app_ja.arb` / `app_en.arb` / `app_zh.arb` で検索する
- **THEN** いずれの ARB ファイルにも非空の翻訳が存在する
