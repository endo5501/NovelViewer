## Context

NovelViewerは約115個の日本語UI文字列が12個のプレゼンテーション層ファイルにハードコードされている。現在i18nインフラは未導入。設定はSharedPreferencesとRiverpodで管理されている。MaterialAppは`lib/app.dart`の`NovelViewerApp`で定義されている。

## Goals / Non-Goals

**Goals:**
- Flutter公式i18n機構を使い、日本語(ja)・英語(en)・簡体字中国語(zh)の3言語をサポート
- 設定画面から言語切り替え可能にし、選択を永続化
- 型安全なローカライズ文字列アクセス（コード生成）

**Non-Goals:**
- RTL言語のサポート
- 翻訳管理ツール(Crowdinなど)との連携
- TTS言語設定との連動（独立のまま）
- 日付・数値のローカライズフォーマット（現時点では不要）

## Decisions

### 1. Flutter公式 `flutter_localizations` + `intl` を採用

**選択**: Flutter公式のi18n機構（`gen_l10n`によるコード生成）
**代替案**: `easy_localization` パッケージ
**理由**: 型安全、Flutter teamによる長期メンテナンス、ICU MessageFormat対応。115個程度の文字列であればコード生成のセットアップコストは許容範囲。

### 2. ARBファイルの配置とテンプレート言語

**選択**: `lib/l10n/` に配置、`app_ja.arb` をテンプレート（ソース）ファイルとする
**理由**: 日本語がデフォルト言語であり、すべてのキーが日本語から定義される。`template-arb-file: app_ja.arb` を `l10n.yaml` で指定。

### 3. ARBキーの命名規則

**選択**: `featureName_contextDescription` 形式（例: `settings_title`, `download_dialogTitle`, `fileBrowser_noFiles`）
**理由**: feature別にプレフィックスを付けることで、115個のキーが一覧で見やすくなる。

### 4. 言語設定の管理

**選択**: 既存の `SettingsRepository` + `SharedPreferences` に `locale` キーを追加。Riverpodの `localeProvider` でリアクティブに管理。
**理由**: 既存パターンとの一貫性。`MaterialApp` の `locale` プロパティにバインドすることで即時反映。

### 5. 言語選択UIの配置

**選択**: 設定ダイアログの一般タブ最上部にDropdownとして配置。言語名はその言語自身で表示（日本語 / English / 中文）。
**理由**: 最も目立つ位置に配置し、誤設定時でも言語名から元に戻せるようにする。

### 6. デフォルト言語のフォールバック

**選択**: 未設定時は常に日本語(ja)。OSロケールは参照しない。
**理由**: アプリの主要ターゲットが日本語Web小説の読者であり、OSロケール依存は想定外の言語で起動するリスクがある。

### 7. プレースホルダ付き文字列の扱い

**選択**: ICU MessageFormatのplaceholder構文を使用（例: `{name}を削除しますか？`）
**理由**: `gen_l10n`が自動的に型安全な引数付きメソッドを生成してくれる。

## Risks / Trade-offs

- **翻訳品質**: LLMによる初期翻訳は完璧ではない可能性がある → 英語・中国語ネイティブによるレビューを後日実施
- **文字列抽出漏れ**: data層やエラーメッセージにもハードコード文字列がある可能性 → プレゼンテーション層を優先し、data層は後続の変更で対応
- **テストへの影響**: 文字列を直接比較しているテストがある場合、ロケール依存になる → テスト時はデフォルトロケール(ja)を固定
- **ビルドプロセスの変更**: `flutter gen-l10n`の実行が必要 → `generate: true` により `flutter run/build` 時に自動実行される
