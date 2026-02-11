## Context

現在のプロジェクトは `flutter_lints: ^6.0.0` を dev_dependencies に含み、`analysis_options.yaml` で `package:flutter_lints/flutter.yaml` を include している。しかし `linter: rules:` セクションが空であり、flutter_lints が提供するデフォルトルールセット以上のカスタムルールが有効化されていない。

現時点で `fvm flutter analyze` を実行すると2件の warning が検出される：
- `unused_import`（file_browser_panel.dart）
- `unused_field`（kakuyomu_site.dart）

Flutter/Dart のリンティングエコシステムでは、`flutter_lints` が公式推奨パッケージであり、利用可能なルールの約46%をカバーしている。より厳格な `very_good_analysis`（約86%カバー）というサードパーティ選択肢も存在する。

## Goals / Non-Goals

**Goals:**
- 標準的なリントルールを `analysis_options.yaml` に設定し、コード品質チェックを強化する
- 既存コードのリント違反をできる限り修正する
- `fvm flutter analyze` でゼロ warning を目指す
- 開発者がリンターを日常的に実行できる手順を整備する

**Non-Goals:**
- CI/CD パイプラインへのリンター統合（将来の対応）
- `very_good_analysis` 等の厳格なサードパーティルールセットの導入
- pre-commit hook の設定
- IDE固有のリンター設定（VS Code, IntelliJ等）

## Decisions

### 1. リントパッケージ: `flutter_lints` を継続利用する

**選択**: `flutter_lints: ^6.0.0` をそのまま使用する

**理由**:
- 公式推奨パッケージであり、Flutter SDK のアップデートに追従する
- 既にプロジェクトに導入済みで追加の依存変更が不要
- 「標準的なルール」という要件に最も合致する

**検討した代替案**:
- `very_good_analysis`: 約86%のルールをカバーするが、既存コードへの影響が大きすぎる。「標準的」という要件から外れる
- `lints`（Dart公式）: Flutter固有のルールが含まれないため不十分

### 2. 追加で有効化するリントルール

**選択**: flutter_lints のデフォルトに加え、広く推奨される追加ルールを段階的に有効化する

追加するルール（一般的に推奨されるもの）:
- `prefer_const_constructors`: const コンストラクタの使用を促進（パフォーマンス改善）
- `prefer_const_declarations`: const 宣言の使用を促進
- `prefer_final_locals`: ローカル変数の final 化を促進（不変性）
- `avoid_print`: print 文の検出（デバッグコードの残留防止）
- `prefer_single_quotes`: 文字列の引用符を統一
- `sort_child_properties_last`: Widget の child プロパティを最後に配置
- `use_build_context_synchronously`: async ギャップ後の BuildContext 使用を検出

**理由**: これらは Flutter コミュニティで広く採用されている追加ルールであり、既存コードへの影響が限定的かつ修正が機械的に行えるものを選定した

### 3. 既存違反への対応方針

**選択**: 追加ルール適用後に検出される違反をすべて修正する。修正が難しい・影響が大きい場合のみ個別にルールを無効化（`// ignore`）する

**理由**: リンター導入の目的がコード品質の向上であるため、既存違反を放置して警告を無視する文化を作りたくない

### 4. `analysis_options.yaml` の除外設定

**選択**: 既存の `memo/**` と `openspec/**` の除外は維持する。生成コード（`.g.dart`, `.freezed.dart` 等）がある場合は追加で除外する

**理由**: ドキュメントやspecファイルに対してDart解析を実行する意味がない。生成コードは手動修正の対象外

## Risks / Trade-offs

- **[既存コードへの広範な修正]** → 追加ルールにより多数のファイルに修正が入る可能性がある。ただし `prefer_const_constructors` 等の修正は機械的であり、ロジックへの影響はない
- **[開発体験への影響]** → 新ルールにより開発中の warning が増える可能性がある。ただし標準的なルールに限定しているため、負担は最小限
- **[パッケージバージョンの陳腐化]** → `flutter_lints: ^6.0.0` が最新かどうか確認し、必要に応じてアップデートする
