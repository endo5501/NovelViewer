## Context

現在のNovelViewerは、ダウンロードした小説をタイトル名のフォルダで管理している。小説のタイトルは作者によって頻繁に変更されるため、フォルダ名と実際のタイトルが乖離する問題がある。また、`NovelIndex` や `Episode` のデータモデルにはサイト固有のID（なろうのncode、カクヨムのwork ID）が保持されておらず、URLの正規化時に一度だけ抽出されるのみで再利用されていない。

macOSのバンドルIDも `com.example.novelViewer` のままであり、データ保存パスに `com.example` が含まれてしまっている。

## Goals / Non-Goals

**Goals:**
- 小説の保存フォルダをサイト固有IDベースに変更し、タイトル変更の影響を受けない安定した構造にする
- SQLiteデータベースでメタデータを管理し、IDとタイトルを紐付ける
- macOSバンドルIDを適切な値に変更する
- 既存データとの共存を実現する

**Non-Goals:**
- 既存のタイトル名フォルダの自動マイグレーション（IDが不明なため自動変換は困難）
- 小説の更新チェック機能
- クラウド同期やバックアップ機能
- ORMやコード生成ツール（drift等）の導入

## Decisions

### 1. SQLiteパッケージの選択: `sqflite_common_ffi`

**選択**: `sqflite_common_ffi` を使用

**理由**: `sqflite` はモバイル向けだが、`sqflite_common_ffi` はFFI経由でmacOSデスクトップをネイティブサポートする。`drift` のようなORM/コード生成ツールは、テーブルが1つ程度の小規模なスキーマには過剰。

**代替案**:
- `drift`: 型安全なクエリとコード生成が可能だが、ビルドランナーの設定が必要で複雑さが増す
- `sqlite3` (dart:ffi直接): 低レベルすぎてボイラープレートが多い

### 2. フォルダ命名規則: `{site_type}_{novel_id}`

**選択**: サイト種別とIDを組み合わせた形式

**例**:
- なろう: `narou_n1234ab`
- カクヨム: `kakuyomu_16816452220917939820`

**理由**: サイト種別のプレフィックスにより、異なるサイト間でのID衝突を防ぐ。フォルダ名を見ただけで出典が判別できる。

**代替案**:
- IDのみ: サイト間でのID衝突リスクがある
- UUID生成: 元のサイトとの紐付けが不明瞭になる

### 3. データベーススキーマ

```sql
CREATE TABLE novels (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  site_type TEXT NOT NULL,          -- 'narou' | 'kakuyomu'
  novel_id TEXT NOT NULL,           -- サイト固有ID (ncode, work id)
  title TEXT NOT NULL,              -- 小説タイトル
  url TEXT NOT NULL,                -- 元URL
  folder_name TEXT NOT NULL UNIQUE, -- IDベースのフォルダ名
  episode_count INTEGER NOT NULL DEFAULT 0,
  downloaded_at TEXT NOT NULL,      -- ISO8601
  updated_at TEXT                   -- ISO8601
);

CREATE UNIQUE INDEX idx_novels_site_novel ON novels(site_type, novel_id);
```

**理由**: 最小限のスキーマで必要な情報を管理。`folder_name` にUNIQUE制約を設けてフォルダの一意性を保証。`site_type` + `novel_id` の複合ユニーク制約で同一小説の重複登録を防止。

### 4. NovelSiteインターフェースへのID抽出メソッド追加

**選択**: `NovelSite` 抽象クラスに `extractNovelId(Uri url)` メソッドを追加

```dart
abstract class NovelSite {
  bool canHandle(Uri url);
  String get siteType;                    // 追加: 'narou' | 'kakuyomu'
  String extractNovelId(Uri url);         // 追加: URL→ID抽出
  Future<NovelIndex> parseIndex(...);
  Future<String> parseEpisode(...);
}
```

**理由**: 既存の `normalizeUrl()` 内に同様のロジックがあるため、それを再利用・分離する形で実装できる。`siteType` ゲッターにより、サイト種別をDB保存時に取得可能。

### 5. 既存データとの共存戦略

**選択**: レガシーフォルダとの共存方式

**方針**:
- 既存のタイトル名フォルダはそのまま残す
- ファイルブラウザは、DBに登録された小説をタイトル付きで一覧表示する
- DBに未登録のフォルダ（レガシー）はフォルダ名をそのまま表示する
- 同じ小説を再ダウンロードすると、新しいIDベースフォルダに保存され、DBに登録される
- レガシーフォルダの手動削除はユーザーに委ねる

**理由**: 既存フォルダからサイト固有IDを逆引きする手段がないため、自動マイグレーションは現実的でない。共存方式であればデータロスのリスクがなく、段階的に新方式へ移行できる。

### 6. ファイルブラウザの表示方式変更

**選択**: ライブラリルートではDB + ファイルシステムのハイブリッド表示

**フロー**:
1. ライブラリルート表示時:
   - DBから登録済み小説一覧を取得（タイトルで表示）
   - ファイルシステムからサブディレクトリ一覧を取得
   - DB未登録のフォルダはフォルダ名で表示（レガシー扱い）
2. 小説フォルダ内: 従来通りファイルシステムを直接スキャン

### 7. データベースサービスの配置

**選択**: `lib/features/novel_metadata_db/` に新規featureとして配置

```
lib/features/novel_metadata_db/
├── data/
│   ├── novel_database.dart          -- DB初期化・マイグレーション
│   └── novel_repository.dart        -- CRUD操作
├── domain/
│   └── novel_metadata.dart          -- メタデータモデル
└── providers/
    └── novel_metadata_providers.dart -- Riverpodプロバイダー
```

**理由**: 既存のfeatureベースのディレクトリ構造に合わせる。DBロジックを独立したfeatureとすることで、`text_download` と `file_browser` の両方から参照可能。

### 8. バンドルID変更

**選択**: `com.example.novelViewer` → `com.endo5501.novelViewer`

**影響**: macOSではバンドルIDが変わるとサンドボックスの保存先パスが変わるため、既存のデータパスからはアクセスできなくなる。

**対策**: アプリ初回起動時に旧パス (`com.example.novelViewer`) のデータが存在する場合、新パスへコピーする処理を入れる。

## Risks / Trade-offs

**[リスク] バンドルID変更によるデータパス変更** → 初回起動時のデータコピー処理で対応。コピー失敗時はユーザーに手動コピーを案内するダイアログを表示する。

**[リスク] SQLite依存の追加によるアプリサイズ増加** → `sqflite_common_ffi` はネイティブSQLiteライブラリを同梱するため、数MB程度の増加が見込まれる。メタデータ管理の安定性向上とのトレードオフとして許容する。

**[リスク] レガシーフォルダの永続的な残存** → ユーザーが手動で削除するか、同じ小説を再ダウンロードするまでレガシーフォルダが残る。UIでレガシーフォルダであることを示す表示は行わず、シンプルに共存させる。

**[トレードオフ] 自動マイグレーションの不採用** → 既存データの安全性を優先。ユーザーの操作なしにデータを移動するリスクを避ける。
