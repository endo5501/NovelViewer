## 1. 依存追加と Inno Setup 側の追記

- [ ] 1.1 `pubspec.yaml` に `package_info_plus`、`url_launcher`、`pub_semver`、`win32_registry`、`crypto` (既存の可能性あり、要確認) を追加し、`fvm flutter pub get` を実行する
- [ ] 1.2 `installer/novel_viewer.iss` に `[Registry]` セクションを追加: `Root: HKCU; Subkey: "Software\NovelViewer"; ValueType: string; ValueName: "InstallType"; ValueData: "installer"; Flags: uninsdeletekey`
- [ ] 1.3 ローカルでインストーラを再ビルドし、`reg query HKCU\Software\NovelViewer /v InstallType` でキーが書き込まれること、アンインストール後に削除されることを確認する

## 2. 配布形態の検出

- [ ] 2.1 `lib/features/app_update/domain/distribution_type.dart` に `enum DistributionType { installer, portable }` を定義
- [ ] 2.2 `lib/features/app_update/data/registry_reader.dart` に `abstract class RegistryReader` と Windows 用実装 `Win32RegistryReader`（`win32_registry` 使用）、テスト用 `FakeRegistryReader` を実装
- [ ] 2.3 `lib/features/app_update/data/distribution_detector.dart` に `DistributionDetector.detect()` を実装。Windows 以外、レジストリキーなし、値不一致のいずれも `DistributionType.portable` を返す
- [ ] 2.4 `test/features/app_update/data/distribution_detector_test.dart` でレジストリ値あり/なし/非 Windows/エラー時の各ケースを検証

## 3. GitHub Releases API クライアント

- [ ] 3.1 `lib/features/app_update/domain/update_constants.dart` に `repoOwner = 'endo5501'`、`repoName = 'NovelViewer'`、`apiBaseUrl` 定数を定義
- [ ] 3.2 `lib/features/app_update/data/release_info.dart` にレスポンス DTO (`tagName`、`body`、`assets`) を定義し `fromJson` を実装
- [ ] 3.3 `lib/features/app_update/data/github_release_client.dart` に `Future<ReleaseInfo> fetchLatest()` を実装。`http.Client` を DI、10 秒タイムアウト、`User-Agent` ヘッダ設定
- [ ] 3.4 `test/features/app_update/data/github_release_client_test.dart` で `MockClient` を使い、正常レスポンス・404・タイムアウト・不正 JSON のシナリオをテスト

## 4. バージョン比較とアップデート判定

- [ ] 4.1 `lib/features/app_update/domain/version_comparator.dart` に `bool isNewer(String currentVersion, String tagName)` を実装。`pub_semver` の `Version.parse`、`v` 接頭辞除去、parse 失敗時 false 返却
- [ ] 4.2 `test/features/app_update/domain/version_comparator_test.dart` で正常比較・等しい・古い・parse 不能タグの各ケースをテスト

## 5. SharedPreferences 永続化レイヤ

- [ ] 5.1 `lib/features/app_update/data/update_preferences.dart` に `lastCheckAt`、`dismissedVersion`、`autoCheckEnabled` のゲッタ／セッタを実装
- [ ] 5.2 `test/features/app_update/data/update_preferences_test.dart` で値の保存・取得をユニットテスト

## 6. ダウンロード／検証／インストーラ起動

- [ ] 6.1 `lib/features/app_update/data/installer_downloader.dart` に `Future<String> download(ReleaseInfo info, void Function(double progress) onProgress)` を実装。`%TEMP%\novel_viewer_update\` に EXE と SHA256 を順に保存
- [ ] 6.2 `lib/features/app_update/data/installer_verifier.dart` に `Future<bool> verify(String exePath, String sha256Path)` を実装。`crypto.sha256` で計算しファイル内容と比較
- [ ] 6.3 `lib/features/app_update/data/process_starter.dart` に `abstract class ProcessStarter` と本番実装 `Win32ProcessStarter`、テスト用 `SpyProcessStarter` を実装。`Process.start(installerPath, ['/SILENT', '/SP-', '/UPDATELAUNCH'], mode: ProcessStartMode.detached)` を呼ぶ。`/UPDATELAUNCH` は windows-installer 側でサイレント完了後の自動起動オプトインに使用される
- [ ] 6.4 `lib/features/app_update/data/installer_updater.dart` に `Future<UpdateResult> apply(ReleaseInfo info)` を実装。DL → 検証 → 起動 → exit(0) の手順。失敗時はファイル削除＋エラー返却
- [ ] 6.5 ダウンロード / 検証 / 起動の各ステップをモックでユニットテスト

## 7. UpdateCheckService と Riverpod プロバイダ

- [ ] 7.1 `lib/features/app_update/providers/update_providers.dart` に `updatePreferencesProvider`、`distributionTypeProvider`、`releaseClientProvider`、`updateCheckServiceProvider`、`updateAvailableProvider` を定義
- [ ] 7.2 `lib/features/app_update/domain/update_check_service.dart` に `Future<UpdateStatus> check({bool manual = false})` を実装。`kDebugMode && !manual` でスキップ、レート制御、スヌーズ判定、結果を `updateAvailableProvider` 経由で公開
- [ ] 7.3 `lib/main.dart` で `runApp` 直後に `unawaited(container.read(updateCheckServiceProvider).check())` を発火

## 8. UI: AppBar バッジと更新ダイアログ

- [ ] 8.1 `lib/features/app_update/presentation/update_badge.dart` に AppBar 用バッジウィジェットを実装。`updateAvailableProvider` を watch
- [ ] 8.2 `lib/home_screen.dart`（または相当）に `UpdateBadge` を追加
- [ ] 8.3 `lib/features/app_update/presentation/update_dialog.dart` に更新ダイアログを実装。配布形態に応じてアクションボタン（インストーラ版: 「更新する」/「リリースページを開く」/「後で」、ZIP 版: 「リリースページを開く」/「後で」）を出し分け
- [ ] 8.4 ダウンロード中の進捗 UI（線形プログレスバー＋速度表示）を実装
- [ ] 8.5 失敗時のエラー表示（リトライ／リリースページを開くフォールバック）を実装

## 9. 設定ダイアログ: AboutAndUpdateSection

- [ ] 9.1 `lib/features/settings/presentation/sections/about_and_update_section.dart` を新規追加 (ConsumerStatefulWidget)
- [ ] 9.2 現在バージョン・ビルド番号・配布形態・最終確認日時の表示を実装
- [ ] 9.3 「更新を確認」ボタン（押下中インジケータ）と結果表示を実装
- [ ] 9.4 自動チェック ON/OFF スイッチを実装し `updatePreferencesProvider` 経由で永続化
- [ ] 9.5 `lib/features/settings/presentation/settings_dialog.dart` のタブ一覧に新セクションを追加
- [ ] 9.6 シェルの行数が 200 LOC 以内に収まっていることを確認

## 10. 国際化

- [ ] 10.1 `lib/l10n/app_ja.arb`、`app_en.arb`、`app_zh.arb` に新規キー（タブ名、バッジ tooltip、ダイアログタイトル、ボタンラベル、メッセージ等）を追加
- [ ] 10.2 セクション・ダイアログ内のすべての可視文字列を `AppLocalizations` 経由に置き換え
- [ ] 10.3 ja/en/zh の 3 言語切替で全文字列がローカライズされることを目視確認

## 11. ドキュメント

- [ ] 11.1 リリースノート文面ガイドライン（バージョンタグは `v1.2.3` 形式、`body` が更新ダイアログに表示されることを明記）を `README.md` または `CONTRIBUTING.md` に追加
- [ ] 11.2 v1.x.x（インストーラはあるが update-check 未搭載）から本 change のリリース v1.(x+1).x への手動アップグレード手順をユーザ向けに案内する文言をリリースノートに記載するメモを残す

## 12. エンドツーエンド検証

- [ ] 12.1 ローカルで偽の Release を返すモックサーバを用意するか、テスト用リポジトリで `v0.0.0-test*` を打って、AppBar バッジ表示まで動作することを確認
- [ ] 12.2 インストーラ版で実際に新バージョンを検知 → DL → 検証 → 起動 → 自動再起動 のフルフローを実機で 1 回検証する
- [ ] 12.3 ZIP 版で実行し、「リリースページを開く」フローのみが提示されることを実機で確認する
- [ ] 12.4 自動チェック OFF にした状態で起動して GitHub API が叩かれていないことを確認（Wireshark 等で確認、または logging 出力）
- [ ] 12.5 24 時間レート制御が動くことを `last_check_timestamp` を直接書き換えて確認
- [ ] 12.6 「後で」を押したバージョンが再通知されないこと、新バージョンで再通知されることを確認
- [ ] 12.7 SHA256 不一致時に正しく中断され、ファイルがクリーンアップされることを手動で `.sha256` ファイルを書き換えて確認

## 13. 最終確認

- [ ] 13.1 code-reviewスキルを使用してコードレビューを実施
- [ ] 13.2 codexスキルを使用して現在開発中のコードレビューを実施
- [ ] 13.3 `fvm flutter analyze` でリントを実行
- [ ] 13.4 `fvm flutter test` でテストを実行
