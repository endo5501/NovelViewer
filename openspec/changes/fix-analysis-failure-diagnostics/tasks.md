## 1. 診断の model を実クライアントから取る

- [x] 1.1 オンデバイスプロバイダ選択時に、設定に別プロバイダのモデル名が残っていても `model` 診断がそれを含まないことを検証するテストを書き、失敗を確認する
- [x] 1.2 クライアントが作れずに失敗した場合、`model` 診断がクライアント不在を示し、モデル名を名乗らないことを検証するテストを書き、失敗を確認する
- [x] 1.3 `_diagnostics` が `LlmClient.modelId` を読むよう変更し、1.1 / 1.2 を通す。クライアント取得が例外を投げる場合も含めてフォールバックする（design.md D1）
- [x] 1.4 既存の `analysis_runner_test.dart` の診断関連テストが、新しい `model` の値で通ることを確認する

## 2. ビルド識別子

- [ ] 2.1 識別子が注入されていないビルドで、version ラベルが識別子不在を明示することを検証するテストを書き、失敗を確認する
- [ ] 2.2 識別子が注入されたビルドで、version ラベルがそれを含むことを検証するテストを書き、失敗を確認する
- [ ] 2.3 `appVersionLabelProvider` が `String.fromEnvironment` を読むよう変更し、2.1 / 2.2 を通す（design.md D2）
- [ ] 2.4 TTS の障害レポートも同じラベルを共有しているため、`tts_failure_report_test.dart` が通ることを確認する

## 3. ビルド経路への注入

- [ ] 3.1 `.github/workflows/release.yml` の `flutter build windows --release` に commit ハッシュの `--dart-define` を追加し、ワークフローが成功することを確認する
- [ ] 3.2 macOS / iOS 向けに識別子を注入するビルドスクリプトを用意し、生成物の version ラベルに識別子が入ることを実機または `flutter run` で確認する（design.md D3）
- [ ] 3.3 `.claude/CLAUDE.md` の開発コマンド一覧を、識別子を注入するビルド経路が正であるよう更新する

## 4. 確認

- [ ] 4.1 オンデバイスプロバイダで解析を失敗させ、障害ダイアログのコピーテキストが `provider: appleOnDevice` と整合する `model` を含み、`app version` が commit ハッシュを含むことを実機で確認する

## 5. 最終確認

- [ ] 5.1 code-reviewスキルを使用してコードレビューを実施
- [ ] 5.2 codexスキルを使用して現在開発中のコードレビューを実施
- [ ] 5.3 `fvm dart format .`でフォーマットを実行
- [ ] 5.4 `fvm flutter analyze`でリントを実行
- [ ] 5.5 `fvm flutter test`でテストを実行
