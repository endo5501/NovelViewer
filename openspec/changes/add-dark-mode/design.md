## Context

NovelViewerは現在、`app.dart`の`MaterialApp`でライトテーマのみをハードコードしている（`ColorScheme.fromSeed(seedColor: Colors.blueGrey)` + `useMaterial3: true`）。設定の永続化には`SharedPreferences`を使用し、Riverpodプロバイダ経由で各UIに反映するパターンが確立されている。

## Goals / Non-Goals

**Goals:**
- ユーザーが設定画面からダークモードをON/OFFできるようにする
- テーマ設定をSharedPreferencesに永続化し、アプリ再起動時に復元する
- Flutter標準の`ThemeMode`を活用してライト/ダークテーマを切り替える

**Non-Goals:**
- システムテーマ（OS設定）への自動追従（将来的に追加可能だが、今回はマニュアル切り替えのみ）
- カスタムカラーテーマの作成機能
- テキストビューア内の独自配色（Material Themeの自動適用に委ねる）

## Decisions

### 1. ThemeMode列挙型の使用

FlutterのMaterialAppが提供する`themeMode`パラメータと`ThemeMode`列挙型を使用する。

- **選択肢A**: `ThemeMode.light` / `ThemeMode.dark` の2値切り替え → **採用**
- **選択肢B**: `ThemeMode.system` を含む3値切り替え → 不採用（Non-Goalsでシステム追従を除外）

**理由**: 要件がシンプルなON/OFFトグルであり、2値で十分。将来的にシステム追従を追加する場合も`ThemeMode`列挙型をそのまま拡張できる。

### 2. 設定の永続化方式

既存の`SettingsRepository`に`getThemeMode()`/`setThemeMode()`メソッドを追加する。

**理由**: フォントサイズ、表示モード等と同じパターンに統一。SharedPreferencesに文字列としてenum名を保存する既存の慣習に従う。

### 3. テーマの反映方式

`app.dart`の`NovelViewerApp`を`ConsumerWidget`に変更し、Riverpodプロバイダ経由で`themeMode`を取得する。

- **選択肢A**: `ConsumerWidget`に変更 → **採用**
- **選択肢B**: `ValueNotifier`やStreamで伝搬 → 不採用

**理由**: アプリ全体で既にRiverpodを使用しており、他の設定（フォント等）と同じパターンで統一できる。

### 4. ダークテーマの定義

`ThemeData`の`ColorScheme.fromSeed`に`brightness: Brightness.dark`を指定してダークテーマを自動生成する。

**理由**: Material 3の`fromSeed`はライト/ダーク両方のカラースキームを同じseed colorから自動生成でき、一貫性のあるデザインが得られる。カスタム配色は不要。

### 5. UI配置

設定ダイアログ内で、既存の「縦書き表示」トグルの直下にダークモードトグルを追加する。`SwitchListTile`を使用する。

**理由**: 表示に関する設定として縦書きトグルと同じグループに配置するのが自然。既存UIパターンとの一貫性。

## Risks / Trade-offs

- **[テキストビューアの視認性]** → ダークテーマ適用時にテキストビューア（特に縦書き表示のカスタムレンダリング）の色が適切か確認が必要。Material Themeの色がカスタムウィジェットに自動適用されない場合は個別対応する。
- **[デフォルト値]** → デフォルトはライトモード（`ThemeMode.light`）。既存ユーザーへの影響なし。
