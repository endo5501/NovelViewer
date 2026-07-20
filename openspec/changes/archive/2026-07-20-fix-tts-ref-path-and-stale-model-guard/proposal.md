## Why

読み上げ編集画面でセグメントごとに参照音声を選ぶと、**デフォルト（設定値）以外を選んだ瞬間に音声生成が必ず失敗する**。ファイル名 (`Anna.mp3`) が絶対パスに解決されないままエンジンへ渡るためで、実機のログに `could not open audio input: Anna.mp3` / `PathNotFoundException: '月ノ美兎3.wav'` として記録されている。既存仕様 (`tts-edit-screen`) は「合成には解決済みのフルパスを使う」と定めており、実装が仕様に反している状態。

あわせて、piper の古いモデル残置問題の後始末が残っている。マーカーをピン留めリビジョンに束縛する修正 (commit `d475878`) は入ったが、(1) `piper-tts-model-download` の仕様は「再取得は手動で行う」のままで実装と食い違い、(2) 再生経路は `areModelsDownloaded()` を参照しないため、設定画面を開かずに再生を始めたユーザは今も古いモデルで `Missing Input: speaker_embedding_mask` に当たりうる。

## What Changes

- `TtsEditController.generateSegment` に参照音声パスの解決関数を渡せるようにし、一括生成 (`generateAllSegments`) と同じ経路に揃える。単体生成でもセグメント指定の参照音声が絶対パスへ解決される
- 上記により不要になる編集ダイアログ側の Qwen3 限定の暫定処理 (`copyWithRefWavPath`) を整理する
- TTS 生成の開始時点でモデルの取得状態を確認し、**古い/不完全なモデルのまま合成を始めない**ようにする。ユーザには再ダウンロードが必要である旨を提示する
- `piper-tts-model-download` の仕様を実装に合わせて更新する（マーカーはリビジョンを記録し、不一致なら未取得として扱う＝自動的に再取得導線に乗る）

非対象 (スコープ外):

- `TtsModelDownloadService` (qwen3) の完了マーカーも同じくタイムスタンプのみで、自前ホストの `resolve/main` から取得しているため再アップロード時に同じ潜在問題を抱える。ただし現時点で実害は観測されておらず、Irodori が採用している固定サイズマニフェスト方式と揃えるかどうかの判断を含むため、本 change では扱わない
- 参照音声の許可拡張子が Dart 側とネイティブ側で二重定義されている構造の解消

## Capabilities

### New Capabilities

なし

### Modified Capabilities

- `tts-edit-screen`: 単体生成でもセグメント指定の参照音声を解決済みフルパスで合成しなければならないことを、シナリオとして明示する
- `piper-tts-model-download`: 「旧モデルの再取得は手動」という要件を、「完了マーカーは取得元リビジョンを記録し、不一致は未取得として扱う」へ置き換える。さらに合成開始時に取得状態を検証する要件を追加する

## Impact

- `lib/features/tts/data/tts_edit_controller.dart` — `generateSegment` のシグネチャ変更（オプション引数追加）
- `lib/features/tts/presentation/tts_edit_dialog.dart` — 呼び出し側の更新と暫定処理の整理
- TTS 生成の開始経路 — `lib/features/text_viewer/presentation/widgets/tts_controls_bar.dart` および編集ダイアログ。モデル未取得時のメッセージ表示のため l10n (`app_ja.arb` / `app_en.arb` / `app_zh.arb`) の追加が必要
- `openspec/specs/piper-tts-model-download/spec.md` — 実装との齟齬の解消
- ネイティブ側の変更なし。audio.cpp / piper-plus サブモジュールは触らない
