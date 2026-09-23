## Why

オンデバイス解析の統合（refinement）段階で、応答トークン上限が答えを途中で打ち切っている。フレームワークは打ち切った文字列を正しい JSON として閉じて返すため、パイプラインからは完全な答えと区別がつかず、事実が黙って失われる。

実測（macOS 27.0 / 実データ 54ファイル 11,393字）:

- refinement の出力は上限に張り付き **1,455〜1,493字 = 予算の約100%**。生成物は単語の途中で切れているが JSON は閉じている
- 上限を 200/350/500/700 と下げると出力も 285/514/753/1,056字 と追随し、**一度も失敗しない**（3/3 成功 × 5水準）
- この小説では本番設定の refinement 呼び出しがほぼ毎回切り捨てられており、保存済みの要約は欠落した事実から作られている

同じ超過が OS 版によって別の現れ方をする。iPadOS 26.6.2 では `decodingFailure` として送出され解析全体が死ぬ（報告されたエラー）。macOS 27.0 では黙って切り捨てられる。iPad 実機から回収したデータでは入力がむしろ少なく（7,092字・refinement 3回）、それでも落ちている。入力量やモデルの饒舌さでは説明できず、版差による現れ方の違いである。

原因は、**出力量を決める予算と、入力量を決める予算が結び付いていないこと**にある。`llm-summary-pipeline` の現行要件は「同じ予算が Stage-1 のチャンク分割と再帰集約の両方を統べる」と定めているが、その予算はプロンプト窓の大きさであって応答の大きさではない。Stage-1 は散文を箇条書きに圧縮するので出力が予算に収まる（実測 max 1,018/1,187字 = 切断点の70/82%）。refinement は箇条書きを入力に取るため圧縮率が下がり（実測 0.42〜0.77）、出力が予算を超える。

## What Changes

- `LlmClient` が **応答予算**（1回の生成が最後まで返せる文字数）を、既存の `maxChunkSize` と並ぶ性質として宣言する
- refinement 専用のプロンプトを新設する。統合・重複排除を指示し、**出力量の上限を応答予算から導出**して明示する。Stage-1 の抽出プロンプトの使い回しをやめる
- 再帰集約が参照する予算を、プロンプト窓からこの応答予算に切り替える。**BREAKING**: `llm-summary-pipeline` の「同じ予算が両ステージを統べる」要件を改める
- 再帰の2つの出口（縮まなかったとき／深さ上限）が、いずれも次段のプロンプトに収まる大きさを返すことを要件化する
- オンデバイスプロバイダが、フレームワークの**新旧両方のエラー面**を認識する。`LanguageModelSession.GenerationError` は 27.0 で非推奨となり、後継は `LanguageModelError` を中心に `SystemLanguageModel.Error` / `GeneratedContent.ParsingError` / `LanguageModelSession.Error` の4つの型に分かれている。現行プラグインは旧面しか捕捉しないため、macOS 27 では**拒否に限らず全てのエラー**が「分類不能」に落ち、再試行しても無駄なものまで再送されている。既存要件「モデルの拒否も refusal として数える」が破れているのはその一部
- 新しいエラー面が持つ `timeout` と未対応要求の各ケースに理由を与え、再試行可否を定める
- 切り捨ての**検出は行わない**。正しい答えが予算に接近しない設計（予防）で根本原因を除く

実測による裏付け: 統合プロンプト案の出力は現行の約1/3（窓サイズのチャンクで 342〜464字）、所要時間は 24〜25秒から 8〜10秒へ短縮。応答予算（オンデバイス 1300字）で分割した新設計では、実コードで生成した23チャンク×3回の出力が最大 801字 = 予算の62% に収まり、切り捨ては0件。11,393字はラウンド2で約11回、ラウンド3で数回の生成を経て窓内に収まる。

## Capabilities

### New Capabilities

なし。

### Modified Capabilities

- `llm-summary-pipeline`: 再帰集約を統べる予算をプロンプト窓から応答予算へ変更する。refinement 専用プロンプトの構築要件を追加する。再帰の2つの出口が返す大きさを要件化する。`LlmClient` が応答予算を宣言することを要件化する
- `apple-on-device-llm`: 応答予算が答えの形を決めてはならないことを要件化する。フレームワークの新旧どちらのエラー型から報告されても同じ原因を名指しできるよう、失敗報告の要件と拒否要件を改める。新しいケースの再試行可否を定める

## Impact

- `lib/features/llm_summary/data/llm_client.dart`: 応答予算の宣言を追加
- `lib/features/llm_summary/data/llm_prompt_builder.dart`: refinement 専用プロンプトを追加
- `lib/features/llm_summary/data/llm_summary_pipeline.dart`: `_extractFactsRecursive` が新プロンプトと応答予算を使う
- `lib/features/llm_summary/data/foundation_models_client.dart`: 応答予算の宣言
- `packages/foundation_models_llm/darwin/.../GenerationFailureWireCode.swift`（新設）: エラー型からワイヤコードへの写像をプラグインから切り出し、新旧の型をすべて読む。既存ガードの内側に 27.0 の可用性チェックを入れ子にする。`FoundationModelsLlmPlugin.swift` はこれを呼ぶだけにする
- `packages/foundation_models_llm/lib/src/on_device_generation_failure.dart`: `timeout` と未対応要求の理由を追加
- `packages/foundation_models_llm/darwin/wire_code_tests/`（新設）: 写像ファイルをシンボリックリンクで取り込む独立 SPM パッケージ。プラグイン本体は FlutterFramework に依存し Flutter ビルドの外で走らないため、写像だけをここで `swift test` する。プラグインの `Package.swift` は変更しない
- `lib/features/llm_summary/data/ollama_client.dart`: 既存の `num_predict: 1024` を応答予算として宣言。ローカル Ollama の実測で、`gemma4:e4b` が統合段の入力で上限1024トークンに達し JSON が途中で切れたことを確認しており、同じ欠陥を持つ
- `fact_cache` のスキーマ・キー・プロンプト版は変更しない。Stage-1 の出力は変わらないため既存キャッシュは有効なまま
