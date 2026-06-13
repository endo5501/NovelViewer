## 1. テスト（TDD: 先に失敗するテストを書く）

- [x] 1.1 `test/features/tts/` 配下に、`PiperModelDownloadService` の基底 URL が可変参照（`/resolve/main` 等のブランチ名）でなく固定リビジョン（`/resolve/<commit-sha>`）を指すことを検証する回帰テストを追加する
- [x] 1.2 テストを実行し、現状（または素の `main` 状態）で失敗することを確認してからコミットする

## 2. 実装（テストをパスさせる）

- [x] 2.1 `lib/features/tts/data/piper_model_download_service.dart` の `_baseUrl` を `resolve/main` から互換リビジョン `resolve/eb9b882`（2026-03-18, 5/3 デコーダ刷新 `e22f5fe` の直前）へピン留めし、選定理由を near コメントで明記する（※作業ツリーに 1 行変更済み・本タスクで確定）
- [x] 2.2 1.1 のテストがパスすることを確認する

## 3. 実機確認（spike の再現性確認）

- [x] 3.1 旧モデルを手動削除（`models/piper/*.onnx` / `*.onnx.json` / `.piper_models_complete`）し、ピン留め版を再ダウンロード→Piper で合成→再生が成功し、ログに `Missing Input: speaker_embedding_mask` が出ないことを確認する
- [x] 3.2 既存ユーザ向けの再取得手順（手動削除）をリリースノート/README 等に周知する

## 4. 最終確認

- [x] 4.1 code-review スキルを使用してコードレビューを実施
- [x] 4.2 codex スキルを使用して現在開発中のコードレビューを実施
- [x] 4.3 `fvm flutter analyze` でリントを実行
- [x] 4.4 `fvm flutter test` でテストを実行
