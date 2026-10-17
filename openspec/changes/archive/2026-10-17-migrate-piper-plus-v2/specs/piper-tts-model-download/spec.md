# Spec Delta

## MODIFIED Requirements

### Requirement: Piper モデルは推論ランナーと互換な固定リビジョンから取得する
システムは Piper モデルファイル（`.onnx` / `.onnx.json`）を、同梱する piper-plus 推論ランナー（`third_party/piper-plus` サブモジュールの固定コミット）と**互換なモデルリビジョンに固定**して取得しなければならない（SHALL）。HuggingFace の `main` などの**可変参照からのライブ取得を行ってはならない**（MUST NOT）。モデル取得元の基底 URL は、互換性が確認された固定リビジョン（コミット SHA）を指し、その選定理由を near コメントで明示しなければならない（SHALL）。

ここでいう互換とは、ランナーがエラーなく合成できることに加え、ランナーの後処理（文末の EOS 区間の除去など）によって発話の末尾音節が欠落しないことを含む（SHALL）。

理由: モデル（実行時取得）と推論ランナー（git ピン留め）の参照方式が非対称だと、上流モデルの更新（例: 話者条件付けを `sid` から `speaker_embedding` + `speaker_embedding_mask` へ変更する 2026-05-03 のデコーダ刷新）により、ランナーが供給しない ONNX 入力を新モデルが要求し、合成が `Missing Input: speaker_embedding_mask` で失敗する。逆に、ランナーだけを更新した場合も壊れうる。piper-plus v1.12 以降のランナーは文末の EOS 区間を常に除去する（Issue #499）。最終母音の後半を EOS 区間で生成する旧モデル（2026-03-18 の eb9b882）では、これにより「そういった」が「そういっ」のように末尾音節が欠落する。

#### Scenario: 基底 URL は可変参照でなく固定リビジョンを指す
- **WHEN** Piper モデルのダウンロード元基底 URL を検査する
- **THEN** URL は `/resolve/main`（または他のブランチ名・可変タグ）ではなく、固定コミット SHA（`/resolve/<commit-sha>`）を含む

#### Scenario: 取得モデルが凍結ランナーと互換である
- **WHEN** ピン留めされたリビジョンから取得したモデルで Piper 合成を実行する
- **THEN** 合成はネイティブランナーのエラー（例: `Missing Input: speaker_embedding_mask`）なく完了し、音声が生成される

#### Scenario: 文末の音節が欠落しない
- **WHEN** ピン留めされたリビジョンのモデルで、末尾が母音で終わる文（例: 「彼はそういった」）を合成する
- **THEN** 最終音節（「た」）が欠けずに発音される

## ADDED Requirements

### Requirement: 旧リビジョンで取得済みのモデルは再取得対象になる
ピン留めリビジョンを更新したとき、旧リビジョン（例: `eb9b882e7ff738f1f590037d2a0fc7ccfd8a5d0a`）を記録した完了マーカーを持つ取得済みモデルは、未取得として扱われなければならない（SHALL）。これにより、ランナーと非互換になった旧モデルは、通常のダウンロード導線で新しいリビジョンに入れ替わる。

#### Scenario: 旧リビジョンのマーカーは不一致になる
- **WHEN** `models/piper/` に `.onnx` / `.onnx.json` と、内容が `eb9b882e7ff738f1f590037d2a0fc7ccfd8a5d0a` の完了マーカーがある状態で `areModelsDownloaded()` を呼ぶ
- **THEN** `false` が返る
