## Why

オンデバイス解析の統合（refinement）段階で、応答トークン上限が答えを途中で打ち切っている。フレームワークは打ち切った文字列を正しい JSON として閉じて返すため、パイプラインからは完全な答えと区別がつかず、事実が黙って失われる。

実測（macOS 27.0 / 実データ 54ファイル 11,393字）:

- refinement の出力は上限に張り付き **1,455〜1,493字 = 予算の約100%**。生成物は単語の途中で切れているが JSON は閉じている
- 上限を 200/350/500/700 と下げると出力も 285/514/753/1,056字 と追随し、**一度も失敗しない**（3/3 成功 × 5水準）
- この小説では本番設定の refinement 呼び出しがほぼ毎回切り捨てられており、保存済みの要約は欠落した事実から作られている

同じ超過が OS 版によって別の現れ方をする。iPadOS 26.6.2 では `decodingFailure` として送出され解析全体が死ぬ（報告されたエラー）。macOS 27.0 では黙って切り捨てられる。iPad 実機から回収したデータでは入力がむしろ少なく（7,092字・refinement 3回）、それでも落ちている。入力量やモデルの饒舌さでは説明できず、版差による現れ方の違いである。

原因は、**出力量を決める予算と、入力量を決める予算が結び付いていないこと**にある。`llm-summary-pipeline` の現行要件は「同じ予算が Stage-1 のチャンク分割と再帰集約の両方を統べる」と定めているが、その予算はプロンプト窓の大きさであって応答の大きさではない。Stage-1 は散文を箇条書きに圧縮するので出力が予算に収まる（実測 max 1,018/1,187字 = 切断点の70/82%）。refinement は箇条書きを入力に取るため圧縮率が下がり（実測 0.42〜0.77）、出力が予算を超える。

## What Changes

- `LlmClient` が **応答予算**（1回の生成が返しうるトークン数）を、既存の `maxChunkSize` と並ぶ性質として宣言する
- refinement 専用のプロンプトを新設する。統合・重複排除を指示し、**出力量の上限を応答予算から導出**して明示する。Stage-1 の抽出プロンプトの使い回しをやめる
- 再帰集約が参照する予算を、プロンプト窓からこの応答予算に切り替える。**BREAKING**: `llm-summary-pipeline` の「同じ予算が両ステージを統べる」要件を改める
- 再帰の2つの出口（縮まなかったとき／深さ上限）が、いずれも次段のプロンプトに収まる大きさを返すことを要件化する
- オンデバイスプロバイダが、`GenerationError` の外側で報告される拒否も拒否として扱う。既存要件「モデルの拒否も refusal として数える」が macOS 27.0 で破れている回帰の修正
- 切り捨ての**検出は行わない**。正しい答えが予算に接近しない設計（予防）で根本原因を除く

実測による裏付け: 統合プロンプト案の出力は **342〜464字 = 予算の約30%**、現行の約1/3。所要時間も 24〜25秒から 8〜10秒へ短縮し、11,393字が 5×約400字 = 2,000字となり再帰1ラウンドで収束する。

## Capabilities

### New Capabilities

なし。

### Modified Capabilities

- `llm-summary-pipeline`: 再帰集約を統べる予算をプロンプト窓から応答予算へ変更する。refinement 専用プロンプトの構築要件を追加する。再帰の2つの出口が返す大きさを要件化する。`LlmClient` が応答予算を宣言することを要件化する
- `apple-on-device-llm`: 応答予算が答えの形を決めてはならないことを要件化する。`GenerationError` 以外の型で報告される拒否も拒否として扱うよう、既存の拒否要件を改める

## Impact

- `lib/features/llm_summary/data/llm_client.dart`: 応答予算の宣言を追加
- `lib/features/llm_summary/data/llm_prompt_builder.dart`: refinement 専用プロンプトを追加
- `lib/features/llm_summary/data/llm_summary_pipeline.dart`: `_extractFactsRecursive` が新プロンプトと応答予算を使う
- `lib/features/llm_summary/data/foundation_models_client.dart`: 応答予算の宣言
- `packages/foundation_models_llm/darwin/.../FoundationModelsLlmPlugin.swift`: `LanguageModelError` を拒否として写像
- `lib/features/llm_summary/data/ollama_client.dart`: 既存の `num_predict: 1024` を応答予算として宣言。サーバ側も同じクラスの超過を起こしうるが**未計測**であり、本変更は予算の宣言と refinement の上限適用にとどめる
- `fact_cache` のスキーマ・キー・プロンプト版は変更しない。Stage-1 の出力は変わらないため既存キャッシュは有効なまま
