## Context

NovelViewer の Piper TTS は 2 つの成果物が連携して動作する:

1. **推論ランナー**（ネイティブ）: `third_party/piper-plus` サブモジュールを `scripts/build_piper_*` でビルドした `piper_tts_ffi.dll`。サブモジュールは commit `123efd6`（2026-03-23, branch `feat/support_cpp_library`）で**git ピン留め**されている。ONNX への入力は `input / input_lengths / scales / [sid] / [lid] / [prosody_features]` のみ（`src/cpp/piper.cpp` の `synthesize`）。
2. **モデル**（実行時取得）: `PiperModelDownloadService` が `https://huggingface.co/ayousanz/piper-plus-tsukuyomi-chan/resolve/main/...` から `tsukuyomi-chan-6lang-fp16.onnx` と `config.json` を**バージョン無固定でライブ取得**。

この 2 つは「git ピン留め（凍結）」と「`main` からのライブ取得（追従）」という**非対称な参照方式**になっており、上流モデルが更新されると静かに不整合になる。実際 HF 履歴の `e22f5fe`（2026-05-03, MB-iSTFT-VITS2 デコーダ刷新）で話者条件付けが `sid` から `speaker_embedding` + `speaker_embedding_mask` に変わり、凍結ランナーが供給しない入力を新モデルが要求するようになった。症状はロード成功・合成失敗（`Missing Input: speaker_embedding_mask`）。リリースビルドのログ（`%APPDATA%/com.endo5501/novel_viewer/logs/app.log`）に F112 由来の native エラー文字列として現れる。

## Goals / Non-Goals

**Goals:**
- Piper の合成を復旧させる（凍結ランナーと同一世代のモデルを取得する）。
- 「モデルは推論ランナーと互換な固定リビジョンから取得する」という非対称参照の解消を spec で恒久化し、再発（上流更新のたびに壊れる）を防ぐ。
- 変更は最小（基底 URL のリビジョンピン留め 1 箇所）に留め、TDD で回帰テストを残す。

**Non-Goals:**
- piper-plus サブモジュール自体のアップグレード（Option B）。新モデル世代に追従するならランナー側 C++ が `speaker_embedding_mask` を供給する版に更新＋DLL 再ビルドが必要だが、本変更の範囲外。
- onnxruntime（現在 1.14.1）の更新。
- 既存ダウンロード済みユーザの**強制再取得の自動化**（モデルのハッシュ/リビジョン検証による入れ替え）。利用者限定の現状では手動削除で足りる。
- qwen3 側の DLL 同梱問題（これはデバッグ環境特有で別件）。

## Decisions

### 決定 1: Option A（モデルをランナー互換リビジョンに固定）を採用する
`_baseUrl` の `resolve/main` を `resolve/eb9b882`（2026-03-18, 破壊的変更 `e22f5fe` の直前）に変更する。

- **根拠**: HF 履歴上、ランナーをピン留めした 2026-03-23 と同世代の最後のモデル状態が `eb9b882`。ファイル名（`tsukuyomi-chan-6lang-fp16.onnx`）も現行と同一のため、`modelName` 解決ロジックを触らず**基底 URL の 1 箇所**だけで完結する。spike で実機検証済み（ピン留め＋旧モデル削除＋再 DL → 合成成功、`speaker_embedding_mask` エラー消滅をログで確認）。
- **代替案 (Option B: ランナーを更新)**: 最新モデルを使えるが、`feat/support_cpp_library` 系に `speaker_embedding_mask` 対応 C-API が揃っているかの上流調査、サブモジュール更新、DLL 再ビルド、場合により onnxruntime 更新まで波及し、コスト・リスクが大きい。復旧の即時性と最小差分を優先して却下（将来の選択肢としては残す）。

### 決定 2: リビジョンは短縮 SHA をコメント付きで直書きする
`resolve/eb9b882` を定数に直書きし、「なぜこのリビジョンか（5/3 デコーダ刷新の直前・ランナー世代と一致）」を near コメントで残す。

- **根拠**: ピン留めの意図が次の更新者に伝わらないと、安易に `main` へ戻されて再発する。コメントが load-bearing。

### 決定 3: 再取得は当面手動とし、spec に制約として明記する
`areModelsDownloaded()` はマーカー＋ファイル存在で `true` を返すため、URL 変更だけでは既存ユーザのディスク上の旧モデルは入れ替わらない。強制再取得は実装せず、「旧モデル取得済みユーザは `models/piper/` のモデルファイルを手動削除して再 DL する」ことを許容事項として spec に書く。

- **根拠**: 現状ユーザは限定的。自動入れ替え（ハッシュ/リビジョン検証）は設計・テストコストに見合わない。将来必要になれば別 change で対応。

## Risks / Trade-offs

- **[旧モデルが残り続ける]** → 既存ユーザは手動削除が必要。spec とリリースノート/READMEで周知。影響は限定的（ユーザ数が少ない）。
- **[モデルが古い世代に固定される]** → 5/3 以降のモデル改善（新デコーダ等）は享受できない。これは Option B を将来選ぶことで解消可能。トレードオフとして受容。
- **[`eb9b882` が将来 HF 側で消える可能性]** → コミットSHA固定は通常永続だが、上流が force-push 等で履歴を改変すると 404 になりうる。発生時はダウンロード失敗→error 状態で可視化される（既存の状態機械）。必要なら本リポジトリ側でモデルをミラーする選択肢を将来検討。
- **[テストの粒度]** → ネットワークや実モデルに依存しない単体テストとして、「`_baseUrl` が `/resolve/main` 等の可変参照でなく固定リビジョンを指す」ことを検証する（実 DL は CI で回さない）。

## Migration Plan

1. `_baseUrl` をピン留めに変更（コメント付き）。
2. 回帰テスト追加（基底 URL が固定リビジョンであること）。
3. `fvm flutter analyze` / `fvm flutter test` 通過を確認。
4. 既存ユーザ向けに「`models/piper/` のモデルファイルを削除して再 DL」する手順を周知（リリースノート/README）。
5. ロールバック: 変更は定数 1 行＋テストのみ。元の `resolve/main` に戻せば即時 revert 可能。

## Open Questions

- 将来 Option B（ランナー更新で最新モデル追従）に倒すかは別途判断。倒す場合、本 change のピン留めは「ランナーと整合する新リビジョン」へ更新する形で引き継ぐ。
