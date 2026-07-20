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

- [ ] 2.1 エンジン種別から取得状態を返すプロバイダのテストを書く (piper: 一致=ready / 旧形式マーカー=stale / 不一致=stale、qwen3・Irodori: 既存の判定に委譲)
- [ ] 2.2 テストが失敗することを確認し、テストのみをコミットする
- [ ] 2.3 プロバイダを実装する
- [ ] 2.4 読み上げ開始 (`tts_controls_bar.dart`) で検証し、stale なら合成を開始せずメッセージを表示する
- [ ] 2.5 編集画面の生成経路でも同様に検証する
- [ ] 2.6 l10n に文言を追加する (`app_ja.arb` / `app_en.arb` / `app_zh.arb`)
- [ ] 2.7 テストが通ることを確認する

## 3. 仕様との整合

- [ ] 3.1 デルタスペックの内容が実装と一致していることを確認する (`openspec validate`)
- [ ] 3.2 `openspec/specs/piper-tts-model-download/spec.md` の旧要件がアーカイブ時に置き換わることを確認する

## 4. 積み残しの判断

- [ ] 4.1 `TtsRefWavResolver.resolve()` の `resolver` を必須引数にするかを判断する (全呼び出し側の変更が必要。見送る場合は理由を design.md に追記)
- [ ] 4.2 qwen3 (`TtsModelDownloadService`) のマーカー方式を揃える別 change を起票するか判断する

## 5. 最終確認

- [ ] 5.1 code-reviewスキルを使用してコードレビューを実施
- [ ] 5.2 codexスキルを使用して現在開発中のコードレビューを実施
- [ ] 5.3 `fvm flutter analyze`でリントを実行
- [ ] 5.4 `fvm flutter test`でテストを実行
- [ ] 5.5 実機で確認する (編集画面でセグメント指定の参照音声を選んで単体生成が成功すること)
