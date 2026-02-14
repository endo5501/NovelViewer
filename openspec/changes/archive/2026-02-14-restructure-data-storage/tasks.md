## 1. バンドルID・アプリ識別子の一括変更

- [x] 1.1 `macos/Runner/Configs/AppInfo.xcconfig` の `PRODUCT_BUNDLE_IDENTIFIER` と `PRODUCT_COPYRIGHT` を `com.endo5501` に変更
- [x] 1.2 `macos/Runner.xcodeproj/project.pbxproj` 内の全 `PRODUCT_BUNDLE_IDENTIFIER` を `com.endo5501.novelViewer` に変更（RunnerTests含む）
- [x] 1.3 `ios/Runner.xcodeproj/project.pbxproj` 内の全 `PRODUCT_BUNDLE_IDENTIFIER` を `com.endo5501.novelViewer` に変更（RunnerTests含む）
- [x] 1.4 `android/app/build.gradle.kts` の `namespace` と `applicationId` を `com.endo5501.novel_viewer` に変更
- [x] 1.5 `android/app/src/main/kotlin/` のパッケージディレクトリを `com/example/` から `com/endo5501/` にリネームし、`MainActivity.kt` の `package` 宣言を更新
- [x] 1.6 `linux/CMakeLists.txt` の `APPLICATION_ID` を `com.endo5501.novel_viewer` に変更
- [x] 1.7 `windows/runner/Runner.rc` の `CompanyName` と `LegalCopyright` を `com.endo5501` に変更
- [x] 1.8 バンドルID変更後にmacOSビルドが通ることを確認

## 2. 依存パッケージ追加

- [x] 2.1 `pubspec.yaml` に `sqflite_common_ffi` と `sqflite` パッケージを追加
- [x] 2.2 `fvm flutter pub get` で依存関係を解決

## 3. NovelSiteインターフェース拡張

- [x] 3.1 `NovelSite` 抽象クラスに `String get siteType` プロパティを追加
- [x] 3.2 `NovelSite` 抽象クラスに `String extractNovelId(Uri url)` メソッドを追加
- [x] 3.3 `NarouSite` に `siteType` (`narou`) と `extractNovelId` (ncodeを抽出) を実装
- [x] 3.4 `KakuyomuSite` に `siteType` (`kakuyomu`) と `extractNovelId` (work IDを抽出) を実装
- [x] 3.5 各サイトの `extractNovelId` のユニットテストを作成・実行

## 4. メタデータDBモジュール作成

- [x] 4.1 `lib/features/novel_metadata_db/domain/novel_metadata.dart` に `NovelMetadata` モデルクラスを作成
- [x] 4.2 `lib/features/novel_metadata_db/data/novel_database.dart` にDB初期化・テーブル作成ロジックを実装
- [x] 4.3 `lib/features/novel_metadata_db/data/novel_repository.dart` にCRUD操作（insert/upsert, findAll, findByFolderName, findBySiteAndNovelId）を実装
- [x] 4.4 `lib/features/novel_metadata_db/providers/novel_metadata_providers.dart` にRiverpodプロバイダーを作成
- [x] 4.5 `NovelRepository` のユニットテストを作成・実行（挿入、更新、検索）

## 5. ダウンロードサービス変更

- [x] 5.1 `DownloadService` のフォルダ作成ロジックを変更し、タイトル名の代わりに `{site_type}_{novel_id}` フォルダを作成するようにする
- [x] 5.2 ダウンロード完了時に `NovelRepository` を呼び出してメタデータをDBに登録する処理を追加
- [x] 5.3 再ダウンロード時に既存レコードを更新（upsert）するロジックを実装
- [x] 5.4 ダウンロードサービスのテストを更新・実行

## 6. ファイルブラウザ変更

- [x] 6.1 `DirectoryEntry` モデルに表示名フィールド（`displayName`）を追加
- [x] 6.2 ライブラリルートでサブディレクトリを取得する際に、DBからメタデータを引いてタイトルを表示名に設定するロジックを実装
- [x] 6.3 DB未登録フォルダはフォルダ名をそのまま表示名として使用
- [x] 6.4 `FileBrowserPanel` のUI表示を `displayName` を使うように更新
- [x] 6.5 ファイルブラウザのテストを更新・実行

## 7. アプリ初期化フロー変更

- [x] 7.1 `main.dart` にSQLiteデータベースの初期化処理を追加
- [x] 7.2 DBインスタンスをRiverpodプロバイダー経由でアプリ全体に供給

## 8. 旧バンドルIDデータのマイグレーション

- [x] 8.1 アプリ起動時に旧パス（`com.example.novelViewer`）にデータが存在するかチェックする処理を実装
- [x] 8.2 旧パスにデータが存在する場合、新パスへコピーする処理を実装
- [x] 8.3 コピー失敗時のエラーハンドリングを実装

## 9. 最終確認

- [x] 9.1 code-simplifierエージェントを使用してコードをよりシンプルにできないか確認
- [x] 9.2 codexスキルを使用して現在開発中のコードレビューを実施
- [x] 9.3 `fvm flutter analyze`でリントを実行
- [x] 9.4 `fvm flutter test`でテストを実行
