## Context

2つの不具合はどちらも「同じ処理の2つの経路のうち片方だけが正しい」形をしている。

```
参照音声パスの解決
  一括生成  generateAllSegments  → TtsRefWavResolver.resolve(..., resolver: resolveRefWavPath)  ✓
  単体生成  generateSegment      → TtsRefWavResolver.resolve(...)  ← resolver 未指定 ✗

モデル取得状態の検査
  設定画面   areModelsDownloaded() を参照 → 「未DL」と表示され再取得できる  ✓
  再生/生成  config.modelDir.isEmpty しか見ない → 古いモデルをロードして合成時に失敗 ✗
```

`TtsRefWavResolver.resolve()` は resolver が無いと `storedPath` をそのまま返す仕様のため、セグメントに保存されたファイル名 (`Anna.mp3`) がそのままネイティブ層へ渡る。編集ダイアログには Qwen3 のときだけ `copyWithRefWavPath(_resolveRefWavPath(...))` する処理があるが、その後 controller 側が `storedPath` から再解決して上書きするため無効化されている。

モデル検査側は、直前の change で完了マーカーをピン留めリビジョンに束縛したことで「設定画面には未取得と出る」状態までは到達したが、再生経路がその判定を参照しない。

## Goals / Non-Goals

**Goals:**

- 単体生成でもセグメント指定の参照音声が使えるようにする (エンジン非依存)
- 参照音声の解決経路を1つに揃え、「片方だけ正しい」構造を解消する
- 非互換モデルのまま合成が始まらないようにし、失敗ではなく再取得の案内で終わらせる
- 実装と `piper-tts-model-download` 仕様の齟齬を解消する

**Non-Goals:**

- `TtsModelDownloadService` (qwen3) のマーカー方式変更
- 参照音声の許可拡張子が Dart 側とネイティブ側で二重定義されている構造の解消
- モデルの自動再ダウンロード (下記 D2 参照)

## Decisions

### D1: 解決関数は `generateSegment` の引数として渡し、一括生成と対称にする

`generateAllSegments` は既に `resolveRefWavPath` を受け取っている。`generateSegment` にも同じオプション引数を追加し、呼び出し側 (編集ダイアログ) が `voiceService?.resolveVoiceFilePath` を渡す。ダイアログ側の Qwen3 限定の暫定処理は、controller 側で正しく解決されるようになるため削除する。

代替案: controller が `VoiceReferenceService` を直接持つ → data 層が UI 層のプロバイダ解決に依存し、既存の設計 (解決関数を注入する形) と不揃いになる。棄却。

代替案: `TtsRefWavResolver.resolve()` の `resolver` を必須引数にして、渡し忘れをコンパイルエラーにする → より強い再発防止になるが、`tts_streaming_controller` を含む全呼び出し側の変更が必要。**タスクの最後に検討事項として残す**（テストが揃った後なら安全に踏み込める）。

### D2: 検証に失敗しても自動ダウンロードはしない

piper で約40MB、qwen3/Irodori では数GBを再取得することになるため、再生ボタンを押しただけで大容量通信が始まるのは避ける。合成をブロックし、「モデルの再ダウンロードが必要です（設定画面から実行してください）」を提示するに留める。ユーザ判断で設定画面から再取得する既存導線に接続する。

### D3: 検証はエンジン共通の入口に置き、各ダウンロード Notifier の状態へ委譲する

3つのダウンロードサービス (`piper` / `tts`(qwen3) / `irodori`) は `areModelsDownloaded` のシグネチャが揃っていない (`(dir, modelName)` / `(dir, size)` / `(dir)`)。合成開始点でエンジンごとに分岐を書くと、エンジン追加のたびに検証漏れが起きるため、エンジン種別から取得状態を返す単一のプロバイダを設ける。

**当初はこのプロバイダ内で3つの述語を呼び分ける実装にしたが、レビューで各ダウンロード Notifier が既に同じ判定を行っていることが判明したため、`…Completed` 状態への委譲に改めた** (`piper_model_download_providers.dart:54`, `tts_model_download_providers.dart:68`, `irodori_model_download_providers.dart:63`)。これにより完了判定の二重実装、ディレクトリ/サイズ/モデル名の再配線、ファイルシステム述語を呼ぶためだけの http client 注入がすべて不要になり、ダウンロード完了時の再評価も状態遷移として自然に得られる。

なお本 change で実際に「不一致」を返しうるのは piper のみ (qwen3/Irodori はリビジョン束縛をしていない)。それでも共通の入口を作るのは、qwen3 を後から同じ方式にしたときに検証側を変更せずに済ませるため。

### D3-a: 検証はボタンではなくモデルロード地点で行う (実装中に修正)

当初は読み上げ開始ボタンと編集画面の生成ボタンで事前にブロックした。しかし読み上げ開始は**再生と生成の共通入口**であり、`TtsStreamingController._startPlayback` は音声を持つセグメントを DB から再生してモデルをロードしない。入口でのブロックは、生成済み音声の再生まで巻き添えで止めていた (レビューで検出)。

`TtsStreamingController.start` が `modelsReady` を前提条件として受け取り、**合成が必要になった時点**で `TtsStartOutcome.modelNotReady` を返す形に変更した。UI はその結果をメッセージに写像するだけになり、`start()` の将来の呼び出し側が検証を迂回することもできない。編集画面の生成は必ずモデルを必要とするため、ダイアログ側のガードのままとする。

### D4: TDD の順序

先に失敗するテストを書く。単体生成の不具合は `TtsEditController` のテストで再現でき (解決関数を渡したときに合成へ渡るパスを検証)、モデル検証はプロバイダ単体のテストで確認する。UI のメッセージ表示は既存の l10n テストのパターンに合わせる。

## Risks / Trade-offs

- **検証の入口を増やすことで、正常なユーザの合成開始が遅くなる** → 判定はマーカー1ファイルの読み取り (100バイト未満) とファイル存在確認のみ。合成本体の数百ms〜数秒に対して無視できる
- **piper 以外は常に「取得済み」を返すため、検証が形骸化して見える** → D3 のとおり将来のための入口であることをコメントで明示する。形骸化を避けるため、qwen3 のマーカー方式変更は別 change として起票する
- **`resolver` を必須引数にする案を見送ると、同じ渡し忘れが再発しうる** → 最終的に `TtsRefWavResolver.resolve` と両コントローラの引数をすべて必須 (nullable) にした。null を渡すのは「保存値が既に絶対パス」という明示的な意思表示であり、忘れることはできない
- **メッセージが設定画面への導線を持たない** → 文言で場所を案内するに留める。ボタン化は本 change のスコープ外

## Migration Plan

1. 参照音声パスの解決を修正 (テスト → 実装)
2. モデル取得状態の検証を追加 (テスト → 実装 → l10n)
3. `piper-tts-model-download` 仕様の更新はアーカイブ時に同期される
4. ロールバックは通常のコミット単位で可能。ネイティブ層・サブモジュールには触れない

## Open Questions

- ~~`TtsRefWavResolver.resolve()` の `resolver` 必須化~~ → 本 change で実施 (上記 Risks 参照)
- qwen3 のマーカーをリビジョン/サイズマニフェスト方式に揃えるかどうか → **別 change として起票する**判断 (タスク 4.2)
- 編集画面のガードには自動テストが無く、実機確認のみで担保している。ダイアログの widget テストが1本も無いため、本 change では追加しなかった
