## 1. 参照音声パスの解決 (TDD)

- [x] 1.1 `TtsEditController.generateSegment` に対する失敗するテストを書く
  - セグメントに `Anna.mp3` を指定した単体生成で、エンジンへ渡る参照音声パスが `voices/` 配下の絶対パスであること
  - 同一セグメントについて単体生成と一括生成で同じパスが渡ること
  - 「なし」(空文字) はグローバル設定へフォールバックせず参照音声なしになること
  - 「設定値」(null) はグローバル設定の解決済みパスになること
- [x] 1.2 テストが失敗することを確認し、テストのみをコミットする (`No named parameter with the name 'resolveRefWavPath'` / `2dba6a9`)
- [x] 1.3 `generateSegment` に `resolveRefWavPath` オプション引数を追加し、`TtsRefWavResolver.resolve` へ渡す
- [x] 1.4 `tts_edit_dialog.dart` の呼び出しで `voiceService?.resolveVoiceFilePath` を渡す
- [x] 1.5 同ファイルの Qwen3 限定の `copyWithRefWavPath` 暫定処理と、未使用になった `_resolveRefWavPath` ヘルパを削除する (`TtsEngineConfig.copyWithRefWavPath` 自体は本番の呼び出し元が無くなった。撤去可否は 4.1 と併せて判断する)
- [x] 1.6 テストが通ることを確認する (62件 pass)

## 2. モデル取得状態の検証 (TDD)

- [x] 2.1 エンジン種別から取得状態を返すプロバイダのテストを書く (piper: 一致=ready / 旧形式マーカー=stale / 不一致=stale、qwen3・Irodori: 既存の判定に委譲)
- [x] 2.2 テストが失敗することを確認し、テストのみをコミットする (`ttsModelReadinessProvider` 未定義)
- [x] 2.3 プロバイダを実装する (`lib/features/tts/providers/tts_model_readiness_provider.dart`)
- [x] 2.4 読み上げ開始 (`tts_controls_bar.dart`) で検証し、stale なら合成を開始せずメッセージを表示する
- [x] 2.5 編集画面の生成経路でも同様に検証する (単体生成・一括生成の両方)
- [x] 2.6 l10n に文言を追加する (`app_ja.arb` / `app_en.arb` / `app_zh.arb`)
- [x] 2.7 テストが通ることを確認する (readiness 6件 + 全体 2430件 pass)

## 3. 仕様との整合

- [x] 3.1 デルタスペックの内容が実装と一致していることを確認する (`openspec validate` 通過)
- [x] 3.2 `openspec/specs/piper-tts-model-download/spec.md` の旧要件がアーカイブ時に置き換わることを確認する

## 4. 積み残しの判断

- [x] 4.1 `TtsRefWavResolver.resolve()` の `resolver` を**必須（nullable）**にした。本番の呼び出し3箇所は既に渡していたため lib 側の変更は不要で、`resolver: null` を明示するテスト4箇所のみ更新。あわせて呼び出し元が無くなった `Qwen3EngineConfig.copyWithRefWavPath` / `IrodoriEngineConfig.copyWithRefWavPath` とそのテストを削除（docコメントが「編集ダイアログが使う」と実態と異なる説明のまま残るため）
- [x] 4.2 qwen3 (`TtsModelDownloadService`) のマーカー方式は**別 change として起票する**判断とした。自前ホストの `resolve/main` から取得しており再アップロード時に同じ潜在問題を抱えるが、Irodori のサイズマニフェスト方式と揃えるか revision 方式にするかの設計判断を伴うため、本 change には含めない

## 5. 最終確認

レビューで判明した設計変更: 検証は UI ではなく **`TtsStreamingController` のモデルロード地点**で行う
(`TtsStartOutcome.modelNotReady` を追加)。再生専用の経路はモデルを必要としないため、
ボタンでの事前ブロックは生成済み音声の再生を壊していた。readiness 自体も各ダウンロード
Notifier の `…Completed` 状態へ委譲し、完了判定の二重実装を解消した。

- [x] 5.1 code-reviewスキルを使用してコードレビューを実施 (reuse/簡素化/altitude。**altitude で退行を検出**: ガードを再生ボタンに置いたため、生成済み音声の再生までブロックしていた。モデルロード地点へ移動して修正)
- [x] 5.2 codexスキルを使用して現在開発中のコードレビューを実施 (readiness がキャッシュされ、DL完了後も未取得のままになる指摘 → ダウンロード状態への依存を追加)
- [x] 5.3 `fvm flutter analyze`でリントを実行 (No issues found)
- [x] 5.4 `fvm flutter test`でテストを実行 (2432件 pass)
- [x] 5.5 実機で確認する: (1) 編集画面でセグメント指定の参照音声による単体生成が成功、(2) 本文の読み上げが従来どおり動作、(3) 生成済みエピソードの再生が動作 (readiness ガードの退行修正の確認) — いずれも問題なし
