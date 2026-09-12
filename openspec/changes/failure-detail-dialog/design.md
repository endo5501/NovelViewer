## Context

現状、失敗の通知は2つの独立した経路に分かれている。

```
LLM解析の失敗                          TTS合成の失敗
  analysis_runner.dart                   tts_controls_bar.dart
  catch (e)                              tts_edit_dialog.dart
    │ st を捨てている                       │
    ▼                                      ▼
  SnackBar(l10n.llmAnalysis_failed(      showTtsFailureSnackBar(
    e.toString()))                         headline, reason)
  duration: 既定の約4秒                    duration: 8秒
```

どちらも1行のテキストで、読み切る前に消える。LLM側は `e.toString()` をそのまま埋めるため、画面に `LlmAnalysisPartialFailure: 3 file(s) failed extraction: ...` のようにクラス名が漏れる。

原因を追うにはログファイルを読むしかないが、そのログは `app_logger.dart` の `getApplicationSupportDirectory()` 配下に置かれる。iOSではこれが `Library/Application Support` にあたり、`Info.plist` の `UIFileSharingEnabled` が公開する `Documents` の外側にある。ファイルアプリからも Finder 共有からも到達できない。

一方、既存の下地は2つある。`tts_failure_snackbar.dart` は失敗表示を1箇所に集約する先例で、`llm_summary_history_panel.dart` にはクリップボードへコピーして確認スナックバーを出す流れがある。`packageInfoProvider` は起動時に解決済みで同期的に読める。

## Goals / Non-Goals

**Goals:**

- 失敗の内容を、ユーザーが閉じるまで画面に留める
- 原因の全文とスタックトレースを、落ち着いて読める形で表示する
- 診断情報を1回の操作で丸ごとコピーでき、そのまま不具合報告に貼れる
- LLM解析とTTS合成が同じ型・同じ表示経路を通り、後から他の失敗も乗せられる

**Non-Goals:**

- 見逃した失敗へ後から再到達する手段（直近エラーの保持、設定画面からの閲覧）
- ログファイルの配置変更、アプリ内ログビューア、共有シートによる送信
- 成功時スナックバーの挙動変更。従来どおり自動で消える
- エラー文言そのものの書き直し。見出しの改善は別の変更で扱う

## Decisions

### 1. 共通の型 `FailureReport` を置く

```
FailureReport
  headline    : String              ローカライズ済みの短い見出し
  cause       : String?             生の原因文字列（例外や native の理由）
  stackTrace  : StackTrace?         あれば。TTS側は持たない
  diagnostics : Map<String, String> 順序を保った診断項目
```

`diagnostics` は `Map<String, String>` とする。Dart のマップリテラルは挿入順を保持するため、順序つきの組を別に定義する必要がない。

キーは英語固定とする。読むのは開発者であり、翻訳しても報告を受け取る側の役に立たない。3言語ぶんの arb を増やさずに済む利点もある。ダイアログの見出し、`[詳細]`、`[閉じる]`、`[コピー]` のみローカライズする。

*代替案*: TTSとLLMでそれぞれ専用の型を持つ。却下。表示側が型ごとに分岐することになり、共通化の意味が失われる。

### 2. スナックバーは `showCloseIcon` と単一アクションで構成する

Flutter の `SnackBar` は `action` を1つしか持てない。`[詳細]` と `[閉じる]` を2つのアクションとして並べることはできない。

したがって `action` に `[詳細]` を割り当て、閉じる手段には `showCloseIcon: true` を使う。表示時間は `Duration(days: 365)` とし、実質的に手動で閉じるまで残す。

```
┌──────────────────────────────────────────────┐
│ 解析に失敗しました: ...        [詳細]     ✕   │
└──────────────────────────────────────────────┘
```

失敗が連続すると `ScaffoldMessenger` のキューに積み上がり、閉じるたびに古い失敗が現れる。これを避けるため、失敗スナックバーを出す前に `removeCurrentSnackBar()` で現在のものを取り除く。

*代替案*: `SnackBar` をやめて常に `AlertDialog` を出す。却下。成功と失敗で通知の形が大きく変わり、軽微な失敗でも操作を止めることになる。

### 3. ダイアログは `NavigatorState` 経由で開く

`SnackBarAction.onPressed` は `BuildContext` を受け取らない。クロージャが捕まえた `context` は、スナックバーが残っている間に元のウィジェットが破棄されると無効になる。

そのため、スナックバー表示時に `Navigator.of(context, rootNavigator: true)` を解決して `NavigatorState` を保持し、`onPressed` では `navigator.mounted` を確認したうえで `showDialog(context: navigator.context, ...)` を呼ぶ。root navigator は画面の入れ替えでは失われないため、捕まえた `BuildContext` より寿命が長い。

このアプリには `navigatorKey` が存在しないので、グローバルキーを新設する案は取らない。

### 4. 診断情報の内容

| キー | 値 | 出所 |
|---|---|---|
| `time` | 発生時刻（ISO 8601） | 生成時の `DateTime.now()` |
| `app version` | バージョン + ビルド番号 | `packageInfoProvider`（同期で読める） |
| `provider` | `ollama` / `openai` / `appleOnDevice` | `LlmConfig.provider` |
| `model` | モデル名 | `LlmConfig.model` / TTSエンジンのモデル |
| `word` | 解析対象の語句 | LLM解析のみ |
| `scope` | `upToCurrent` / `upToAll` | LLM解析のみ |
| `file` | 対象ファイル名 | 両方 |
| `engine` | TTSエンジン種別 | TTSのみ |

エンドポイントURLは含めない。Ollama および OpenAI 互換の `baseUrl` は設定値がそのまま入り、宅内のプライベートIPを含みうる。プロバイダ種別とモデル名が残るため、どの構成で起きたかは追える。

APIキーは `LlmConfig` に存在せずセキュアストレージ側にあるため、診断情報に混入する経路がない。

`app version` は呼び出し側が `FailureReport` に詰める必須の値とする。表示側で `Ref` を要求すると、ヘルパーが Riverpod に依存して純粋なウィジェットテストが書きにくくなる。

### 5. コピー文字列の書式

診断項目を1行ずつ並べ、空行を挟んで原因の全文、さらに空行を挟んでスタックトレースを置くプレーンテキストとする。

```
time: 2026-09-12T10:23:45.123Z
app version: 1.8.2+41
provider: ollama
model: qwen3:8b
word: アリス
scope: upToAll
file: 040_chapter.txt

LlmAnalysisPartialFailure: 3 file(s) failed extraction: ClientException: ...

#0      ...
#1      ...
```

値が `null` または空の項目は行ごと落とす。TTS側ではスタックトレースの節が丸ごと存在しない。

コードフェンスでは囲まない。貼り先が GitHub Issue とは限らず、囲みが不要な場面のほうが多い。

### 6. 既存ヘルパーの吸収

`showTtsFailureSnackBar` は新しい共通ヘルパーへ置き換える。`formatTtsFailureMessage` の「見出し + 原因」の連結規則は、スナックバー本文を組み立てる処理として共通ヘルパー側に残す。

`tts_failure_snackbar_test.dart` は共通ヘルパーのテストへ移し、連結規則に関する既存の振る舞いを保つ。

### 7. LLM側の `catch (e, st)` 化

`analysis_runner.dart` の `catch (e)` はスタックトレースを捨てている。`catch (e, st)` に変える。既存の型別メッセージ分岐（`LlmAnalysisPartialFailure` / `LlmAnalysisNoFactsFailure` / その他）は見出しの決定にそのまま使い、`cause` には `e.toString()` を入れる。

## Risks / Trade-offs

**閉じない通知が操作の邪魔になる** → 画面下部を占有し続ける。`showCloseIcon` で1タップで閉じられ、新しい失敗が出るときは古いものを取り除くことで、積み上がりを防ぐ。

**スタックトレースが長く、コピー量が大きくなる** → 数KB規模になりうるが、クリップボードとしては許容範囲。切り詰めると肝心の発生箇所を落とす危険があるため、全文を入れる。

**`navigator.context` を使ったダイアログ表示はテストしにくい** → `NavigatorState` を保持する形なので、ウィジェットテストでは `MaterialApp` 配下でスナックバーを出し、`[詳細]` をタップしてダイアログの出現を確認できる。グローバルキーを使う案より検証が素直になる。

**診断項目のキーが英語のままユーザーの目に触れる** → 日本語UIの中に `provider: ollama` のような行が並ぶ。報告の貼り付けを主目的とする画面であり、意味が取れない読み手が操作を誤る余地はないと判断する。

**TTS側に診断情報がほとんど無い** → `engine` と `model` と `file` 程度しか埋まらず、詳細ダイアログの価値がLLMほど高くない。それでも表示経路を共通化する利点のほうが大きく、後からTTS側の項目を足せる形にしておく。
