## 1. ヘルパー関数の修正

- [ ] 1.1 `navigateToTtsTab` 内で `_loadVoiceFiles` の非同期完了を確実に待機するよう `runAsync` + `pumpAndSettle` を調整
- [ ] 1.2 Voice Reference Selectorにアクセスする前に `ensureVisible` でスクロールするヘルパー関数を追加

## 2. Voice reference selector グループのテスト修正

- [ ] 2.1 `lists audio files from voices directory` — ensureVisible + 非同期待機を追加
- [ ] 2.2 `refresh button rescans voices directory` — ensureVisible + 非同期待機を追加
- [ ] 2.3 `selecting a file persists the file name` — ensureVisible + 非同期待機を追加

## 3. Rename dialog グループのテスト修正

- [ ] 3.1 `openRenameDialog` ヘルパーに ensureVisible を追加
- [ ] 3.2 `rename dialog shows current file name without extension` — 修正確認
- [ ] 3.3 `rename dialog cancel does not rename file` — 修正確認
- [ ] 3.4 `rename dialog confirms and renames file` — 修正確認
- [ ] 3.5 `rename dialog disables confirm when name already exists` — 修正確認
- [ ] 3.6 `rename dialog disables confirm when name is empty` — 修正確認

## 4. 最終確認

- [ ] 4.1 simplifyスキルを使用してコードレビューを実施
- [ ] 4.2 codexスキルを使用して現在開発中のコードレビューを実施
- [ ] 4.3 `fvm flutter analyze`でリントを実行
- [ ] 4.4 `fvm flutter test`でテストを実行
