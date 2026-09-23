## Context

動機と実測値は proposal.md の Why を参照。要件は `specs/` の2本を参照。

設計に効く制約:

- オンデバイスモデルの窓（約4,096トークン）は**プロンプトと応答で共有**される。応答予算を上げると、その分プロンプトに使える量が減る
- 字/トークンの実測: オンデバイス 1.37〜1.45（ja/en/zh いずれを要求しても日本語で回答）。Ollama は gemma4 1.46〜3.74、qwen3.5 1.44〜1.58、llama2 0.81〜0.84
- 現行の `FoundationModelsClient` は `onDeviceChunkSize = 3000`（文字）、`maxResponseTokens = 1000`（トークン）
- `OllamaClient` は `num_predict = 1024`。こちらは `llm-generation-efficiency` spec が定める既存要件
- 1回のオンデバイス生成に 8〜25秒かかる。呼び出し回数は体感時間に直結する

## Goals / Non-Goals

**Goals:**

- refinement の出力が応答予算に接近しない状態を、設計上の性質として作る
- `decodingFailure`（iPadOS）と沈黙の切り捨て（macOS）の両方を、同一の予防で消す
- 拒否が別型で飛ぶ回帰を直し、既存の非制約再試行を再び機能させる

**Non-Goals:**

- 切り捨ての**検出**。ユーザ判断により予防のみとする。フレームワークが終了理由を公開しているかは未調査であり、調査すること自体を本変更の範囲としない
- OpenAI互換クライアントの応答予算。このクライアントは応答上限を送っておらず、サーバ側の既定上限は未知のため、宣言は既定（文脈予算）のまま据え置く
- `fact_cache` のスキーマ・キー・`currentPromptVersion` の変更。Stage-1 の挙動は変えないため既存キャッシュは有効
- 最終要約プロンプトの変更

## Decisions

### D1: 応答予算は文字で宣言する（トークンではなく）

`LlmClient` が `maxResponseSize`（文字）を宣言する。`maxChunkSize` がすでに文字なので単位が揃い、チャンク分割器との比較に変換を挟まない。

トークンで宣言して利用側で換算する案も考えたが、換算比は言語依存であり、利用側（パイプライン）は表示言語を知っている一方で、クライアントはプロバイダのトークン化特性を知っている。**換算はクライアント側に置く**ことで、各クライアントが自分のプロバイダとモデルに合った比率を持てる。

切り捨て方向は必ず**切り下げ**。宣言値が実際に返せる量を上回ると、予防そのものが崩れる。

### D2: refinement のチャンクは応答予算で、Stage-1 のチャンクは文脈予算で切る

両者を同じ予算で切っていたことが欠陥の本体（proposal.md 参照）。

- Stage-1: 散文 → 箇条書き。実測の圧縮率が高く、出力は予算の 70/82% に収まっていた。文脈予算（3,000字）のまま
- refinement: 箇条書き → 箇条書き。圧縮率 0.42〜0.77。応答予算（オンデバイス 1,300字、Ollama 768字）を上限にする

Stage-1 も応答予算で切る案は、呼び出し回数が倍以上になり、最も遅いプロバイダで体感を悪化させる割に守るものがない。

### D3: 出力量の上限は「プロンプトで指示する」ことで担保する

実測で、統合プロンプトに「全体で400文字以内」と書くとモデルは 342〜464字 に収めた（5チャンク中4チャンクで成功、残り1チャンクは拒否＝別問題）。指示は効く。

上限値はプロンプト文にハードコードせず、**応答予算から導出**する。式は「応答予算 × 安全係数」で、係数は実測に基づき 0.3 程度を出発点とする（オンデバイスの応答予算 1,300字 × 0.3 ≒ 390字）。上限は**表示言語によらず同じ**にする。英語は1トークンあたりの字数が多いので上限を広げられる、という案は採らない。実測で、オンデバイスと qwen3.5 は英語・中国語の要求に日本語で答え、gemma4 も中国語の要求に日本語で答えた。英語用に広げた上限を日本語で埋められると、余裕が約3.4倍から約1.4倍まで縮む。クライアントの換算比は最も密な場合（日本語・llama2）に合わせてあるので、単一の字数上限でどの言語も安全に収まる。英語の読者には必要より短い上限になるが、これは最終要約の前の中間段である。

代替案として「モデルに構造化スキーマで項目数を制約する」ことも考えたが、現行のスキーマは単一文字列フィールドであり、配列スキーマへの変更は `_parseJsonResponse` の契約と `fact_cache` の内容形式に波及する。効果が実測で確認できている文字数指示を採る。

### D4: 再帰の出口は機械的に切り詰める

`afterLen >= beforeLen` の出口と深さ上限の出口は、どちらも「LLM に頼らず返す」経路なので、返す量も LLM に頼らず保証する。文脈予算を超えていれば**行単位で切り詰める**（`ContextChunker._withinLimit` と同じく改行を優先した切断）。

ここで LLM をもう一度呼ぶ案は、まさにその呼び出しが縮まなかったから到達している経路であり、堂々巡りになる。

### D5: エラー面は2つあり、両方を `switch` で写像する

SDK の定義を確認した結果（`MacOSX27.0.sdk` の `FoundationModels.swiftinterface`）、当初の想定は誤りだった。`LanguageModelError` は「拒否専用の別型」ではなく、**`LanguageModelSession.GenerationError` の後継**である。

```
GenerationError    : introduced 26.0, deprecated 27.0
LanguageModelError : available   27.0+   (enum, 9ケース)
  contextSizeExceeded / rateLimited / guardrailViolation / refusal /
  unsupportedCapability / unsupportedTranscriptContent /
  unsupportedGenerationGuide / unsupportedLanguageOrLocale / timeout
```

したがって影響は拒否に限らない。**macOS 27 では全てのエラーが新しい面から飛び、現行プラグインはその全てを `unknown` に落としている。** `unknown` は再試行対象なので、再試行しても無駄なもの（`contextSizeExceeded` など）まで再送している。

両方とも列挙型なので、**`switch` でケースごとに写像する**。文字列一致は不要になった。分類できないものは `unknown` のまま残す。

`LanguageModelError` は macOS/iOS 27.0 以降なので、プラグインの既存ガード（26.0）の内側に**入れ子の `if #available(iOS 27.0, macOS 27.0, *)`** を置く。26.0 のデプロイメントターゲットは変えない。

**置き換え先は1つの型ではない**（Codex レビューで判明、SDK の deprecation メッセージで確認）。旧9ケースのうち3つは `LanguageModelError` 以外へ移っている。

```
assetsUnavailable   --> SystemLanguageModel.Error.assetsUnavailable
decodingFailure     --> GeneratedContent.ParsingError
concurrentRequests  --> LanguageModelSession.Error.concurrentRequests
```

当初「新しい面には `decodingFailure` が無い＝切り捨てを表現できなくなったから macOS 27 では黙って成功する」と説明していたが、これは誤り。解析失敗は `GeneratedContent.ParsingError` として残っている。macOS 27 で上限到達の答えが JSON を閉じて成功扱いで返ってきた事実（実測）は変わらないが、その理由は説明できていない。したがって「iPadOS 27 に上げると症状が沈黙の欠落へ変わる」という予測も根拠を失った。いずれにせよ予防の設計は現れ方に依存しない。

4つの型すべてを読む。`LanguageModelSession.Error.transcriptMutationWhileResponding` はリクエストごとに新しいセッションを作るため起こりえず、対応する理由も無いので `unknown` とする。

### D6: 新しい3ケースの扱い

`timeout` / `unsupportedCapability` / `unsupportedTranscriptContent` に対応するワイヤコードが無い。`unsupportedGenerationGuide` はワイヤコード `unsupportedGuide` が既にプラグイン側にあるが、**Dart 側に写像が無く `unknown` に落ちている**（既存の穴）。

- `timeout` → 新しい理由を追加。再試行する（通る可能性がある）
- `unsupportedCapability` / `unsupportedTranscriptContent` / `unsupportedGenerationGuide` → **1つの理由にまとめる**。再試行しない

3つをまとめるのは、`rateLimited` と `concurrentRequests` を既に1つにまとめているのと同じ判断による。求めたものが違うだけで、**実行にとっても読者にとっても違いが無い**（どれも同一リクエストの再送では成功しない、どれも「このモデルが受け付けない形の要求」）。

## Risks / Trade-offs

- **統合プロンプトの文言が拒否を誘発する** → 実測で5チャンク中1チャンクが6/6拒否。現行プロンプトでは同じチャンクが6/6成功していたため、文言由来の可能性が高い。D5 を先に実装し、拒否が非制約再試行で救われる状態にしてから文言を確定する。文言確定前に**別の語でも拒否率を計測**する（tasks 参照）
- **安全係数 0.3 が保守的すぎて事実が落ちる** → 統合の目的は重複排除であり、元の事実は `fact_cache` に残る。係数は実測で調整可能な定数として持つ
- **Ollama の換算比が保守的** → モデルはユーザ選択でトークナイザが分からないため、実測最小の llama2（0.81）を下回る 0.75 で換算する。gemma4 などでは必要以上に refinement の呼び出しが増えるが、サーバモデルは速い。なお gemma4:e4b は統合段の入力で上限1024に達し JSON が途中で切れたことを実測しており、Ollama 側も同じ欠陥を持つ
- **iPadOS 26.6.2 で検証できない** → 本変更の予防は「応答が予算に接近しない」ことで成立し、超過時の現れ方に依存しない。したがって iPad で再現できなくても効く。ただし修正の**確認**は iPad 実機で行う必要がある

## Migration Plan

データ移行なし。`fact_cache` のキーもプロンプト版も変えないため、既存キャッシュはそのまま有効。

ロールバックは変更の revert のみ。保存済みの要約のうち、切り捨てられた事実から作られたものは残るが、再解析すれば上書きされる。

## Open Questions

- 安全係数の初期値 0.3 はオンデバイス・1語分の実測に基づく。係数は定数であり、後から実測で調整しても spec もタスク分解も変わらない
