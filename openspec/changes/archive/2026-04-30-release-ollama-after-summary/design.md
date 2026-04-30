## Context

NovelViewer の LLM 要約機能は、ユーザが選択した単語に対して `[解析開始]` ボタンを押すたびに `LlmSummaryNotifier.analyze()` → `LlmSummaryService.generateSummary()` → `LlmSummaryPipeline.generate()` の経路で実行される。`LlmSummaryPipeline` は同一の `LlmClient` インスタンスに対して `generate()` を複数回（再帰的 fact 抽出 + 最終要約）連続的に呼び出す。

Ollama の API は、最後の生成リクエストから既定で 5 分間モデルを GPU メモリにロードしたまま保持する（`keep_alive` 既定値）。本アプリのように単発・短時間で集中して使う場面では、生成が終わった直後から最大 5 分間 GPU を占有し続けることになり、ユーザの他作業を圧迫する。

`LlmClient` 抽象は現在 `Future<String> generate(String prompt)` のみを定義する単純なインターフェースであり、`OllamaClient` と `OpenAiCompatibleClient` の 2 実装がある。

## Goals / Non-Goals

**Goals:**
- 1 回の `analyze()`（= 1 つの再利用ウィンドウ）が完了した直後に、Ollama の GPU メモリを明示的に解放する。
- 複数回の `generate()` 呼び出しが含まれる 1 回の解析処理の途中ではモデルを保持し続ける（再ロードコストを避ける）。
- 解放処理がうまくいかなくてもユーザの動作・UI に影響を与えない。
- OpenAI 互換クライアントの挙動は変更しない。

**Non-Goals:**
- LLM プロバイダ間でリソース管理戦略を統一すること（Ollama 固有の挙動として扱う）。
- 設定 UI からこの挙動を ON/OFF 可能にすること。
- 並列解析（spoiler/non-spoiler 同時実行）に対する精緻な制御（reference counting 等）。最悪 1 回の再ロードを許容する。
- アプリ終了時のフックや、長時間アイドル時のフォアグラウンド外イベント検知。Ollama 既定の 5 分タイムアウトをフォールバックとする。

## Decisions

### Decision 1: `LlmClient` インターフェースに既定 no-op の `releaseResources()` を追加する

```dart
abstract class LlmClient {
  Future<String> generate(String prompt);
  Future<void> releaseResources() async {} // default no-op
}
```

`OllamaClient` のみがオーバーライドして実装し、`OpenAiCompatibleClient` は既定の no-op をそのまま使う。

**代替案と却下理由:**
- `if (client is OllamaClient) client.unload()` の型分岐: サービス層に Ollama 知識が漏れる。インターフェースに置けば全プロバイダが同じ「契約」を持てる。
- 別 mixin / capability 抽象化: 1 メソッド・1 実装プロバイダのために抽象を増やすのは過剰。
- `LlmClient` interface 階層を分けて `Disposable` を導入: Dart の抽象クラスで default no-op を提供するほうが低コスト。

### Decision 2: 解放呼び出しは `LlmSummaryService.generateSummary()` の `try / finally` の `finally` 節で行う

```dart
try {
  return await pipeline.generate(...);
} finally {
  try {
    await llmClient.releaseResources();
  } catch (_) {
    // 握りつぶす
  }
}
```

**理由:**
- サービス層が「1 単位の作業（= 1 解析）」の境界として最も自然。
- パイプライン内部に置くと再帰呼び出しのたびに発火する恐れがある。
- ノーティファイア層に置くとサービスをバイパスする他経路が将来できたときに漏れる。

**代替案と却下理由:**
- `LlmSummaryNotifier.analyze()` の finally: ノーティファイアは UI に近い責務であり、リソース管理を持たせるのは責務の混在。
- Riverpod の `ref.onDispose` で解放: クライアントの寿命と解析の寿命が一致しないため、必要なタイミングで発火しない場合がある。

### Decision 3: Ollama アンロード API は `POST /api/generate` に `{ "model": "<model>", "keep_alive": 0, "stream": false }` を `prompt` 省略で送る

Ollama は `prompt` を省略しても `keep_alive` 指定があればロード状態だけを変更するリクエストとして処理する。生成は行われずレスポンスは即座に返る。ただし `/api/generate` の既定は `stream=true` であり、レスポンスが NDJSON ストリームで返ると `jsonDecode(response.body)` が `FormatException` を投げ、サービス層で握りつぶされて解放がサイレントに壊れる恐れがある。これを防ぐため明示的に `"stream": false` を指定し、必ず単一の JSON オブジェクトとして返るよう保証する。

**代替案と却下理由:**
- `generate()` の本リクエストに `keep_alive: 0` を相乗りさせる: パイプライン内のどの呼び出しが「最後」かを呼び出し側で判定する必要があり、責務の越境が大きい。
- `keep_alive: "30s"` 程度に短縮するだけ: 30 秒間の GPU 占有が残り、また「即解放」の意図が API レイヤから読めない。
- 別途 `/api/show` や `/api/ps` による状態確認を併用: 不要に複雑。失敗時は既定タイムアウト（5 分）が結局フォールバックとして効く。

### Decision 4: `await` で同期的に解放を待つ

解放完了を待ってから `analyze()` が戻る。スピナーが解放往復分（数十 ms 〜 100 ms 程度）長く回るが、戻った瞬間に GPU 解放が確定するため、直後に他作業（他のモデルでの生成、ゲーム等の GPU 使用）に切り替えられる。

**代替案と却下理由:**
- Fire-and-forget: スピナーは短く済むが、戻った直後の操作と race する可能性。本機能は連発しない前提なので「確実性」を優先する。

### Decision 5: 解放例外はサービス層内側で握りつぶす

`releaseResources()` のネットワーク例外・サーバ例外はユーザに見せず、ログ出力もせず（最小限の実装に留める）、握りつぶす。最悪のケースでも Ollama 既定の 5 分タイムアウトが効くので、ユーザ影響はない。

**代替案と却下理由:**
- WARNING ログを出す: 観測の価値はあるが、本機能は付帯的な解放処理なので、冗長なログを増やすコストの方が高いと判断。必要なら将来追加する。
- ユーザに通知: 要約結果は正しく取得できているのに「解放に失敗しました」と表示するのは混乱を生むだけ。

## Risks / Trade-offs

- **[並列実行で 1 回の再ロードが発生し得る]** → spoiler 用と non-spoiler 用の `analyze()` がほぼ同時に走った場合、先に終わった側の `releaseResources()` で一度アンロードされ、後発の次の `generate()` で Ollama が再ロードする。再ロードは数百 ms 〜 数秒。本機能は連発しない前提のため許容する（reference counting は導入しない）。
- **[解放呼び出しが失敗した場合の保証なし]** → ネットワーク断やサーバ側エラーで解放できなかった場合、Ollama 側の既定 5 分タイムアウトに任せる。明示解放の「速さ」は失われるが、ユーザ可視の障害にはならない。
- **[インターフェース拡張の他実装影響]** → 既定 no-op を提供するため、既存の `OpenAiCompatibleClient` および将来の他実装は明示対応しなくてよい。テストダブル（モッククライアント）が抽象クラスを継承していれば自動で no-op が継承される。

## Migration Plan

互換性破壊なし。段階的デプロイ不要。全ユーザに同時に有効化される。ロールバックは単純に該当変更のリバートで完了する（解放を呼ばなくなれば従来挙動に戻る）。

## Open Questions

なし。
