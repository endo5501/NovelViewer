## ADDED Requirements

### Requirement: Piper モデルは推論ランナーと互換な固定リビジョンから取得する
システムは Piper モデルファイル（`.onnx` / `.onnx.json`）を、同梱する piper-plus 推論ランナー（`third_party/piper-plus` サブモジュールの固定コミット）と**互換なモデルリビジョンに固定**して取得しなければならない（SHALL）。HuggingFace の `main` などの**可変参照からのライブ取得を行ってはならない**（MUST NOT）。モデル取得元の基底 URL は、互換性が確認された固定リビジョン（コミット SHA）を指し、その選定理由を near コメントで明示しなければならない（SHALL）。

理由: モデル（実行時取得）と推論ランナー（git ピン留め）の参照方式が非対称だと、上流モデルの更新（例: 話者条件付けを `sid` から `speaker_embedding` + `speaker_embedding_mask` へ変更する 2026-05-03 のデコーダ刷新）により、ランナーが供給しない ONNX 入力を新モデルが要求し、合成が `Missing Input: speaker_embedding_mask` で失敗する。

#### Scenario: 基底 URL は可変参照でなく固定リビジョンを指す
- **WHEN** Piper モデルのダウンロード元基底 URL を検査する
- **THEN** URL は `/resolve/main`（または他のブランチ名・可変タグ）ではなく、固定コミット SHA（`/resolve/<commit-sha>`）を含む

#### Scenario: 取得モデルが凍結ランナーと互換である
- **WHEN** ピン留めされたリビジョンから取得したモデルで Piper 合成を実行する
- **THEN** 合成はネイティブランナーのエラー（例: `Missing Input: speaker_embedding_mask`）なく完了し、音声が生成される

### Requirement: 旧モデル取得済みユーザの再取得は手動で行う
モデルの基底リビジョンを変更した場合、既にモデルを取得済みのユーザのディスク上には旧（非互換の可能性がある）モデルファイルが残り、`areModelsDownloaded()` がマーカーとファイルの存在により取得済みと判定するため、システムは自動的な再取得を行わない（SHALL NOT, 現行方針）。互換モデルへ入れ替えるには、ユーザが `models/piper/` 内のモデルファイル（`*.onnx` / `*.onnx.json` / `.piper_models_complete` マーカー）を手動削除してから再ダウンロードする必要がある。`open_jtalk_dic/` の削除は不要とする。

#### Scenario: 旧モデルが残っていると自動再取得されない
- **WHEN** 基底リビジョンを変更したが、ユーザのディスクに旧モデルファイルと完了マーカーが残っている
- **THEN** `areModelsDownloaded()` は取得済み（true）と判定し、新リビジョンのモデルは自動取得されない

#### Scenario: 手動削除後に互換モデルが取得される
- **WHEN** ユーザが `models/piper/` のモデルファイルと完了マーカーを削除し、再ダウンロードを実行する
- **THEN** ピン留めされたリビジョンの互換モデルが取得され、`open_jtalk_dic/` は既存のまま再利用される
