## Why

障害レポートの2つの診断項目が、受け取った側を誤った方向へ導く。実際に調査で両方踏んだ。

**1. `model` が実際に答えたモデルを指していない。** 報告された値は設定に残っている値であり、その解析を実行したクライアントとは無関係でありうる。

```
provider: appleOnDevice
model: gemma4:e4b        <-- Ollama を使っていた頃の設定値が残っていただけ
```

オンデバイスプロバイダはモデル名を設定から取らないため、`model` は必ず無関係な値になる。受け取った側は「gemma4 の問題か」と読むが、実際に動いていたのは Apple のオンデバイスモデルである。

**2. `app version` がビルドを特定できない。** `pubspec.yaml` の version は次のリリースまで据え置かれるため、タグ間の全ビルドが同じ文字列を報告する。

```
v1.8.4 タグ     : 1.8.4+19
その5時間後のコミット : 1.8.4+19   <-- Info.plist に iOS のファイル共有キーを追加したコミット
v2.0.0 タグ     : 2.0.0+20
```

実際にこれが原因で、iPad に入っているビルドがそのコミットの前か後かを判定できなかった。`1.8.4+19` は v1.8.4 から v2.0.0 までの全ビルドを指しうる。

どちらも障害レポートの目的そのもの（受け取った側が原因に辿り着けること）を損なっている。

## What Changes

- 解析失敗の診断が報告する `model` を、設定値ではなく**その解析に使われたクライアントが名乗るモデル識別子**に変更する。オンデバイスなら on-device のモデルを指す
- `app version` の診断を、リリース間のビルドどうしを区別できる識別子へ拡張する。ビルド時に識別子が与えられなかった場合は、与えられていないことが分かる形で報告する
- 障害レポートの他の診断項目（`time` / `provider` / `word` / `covered up to` / `file`）と、エンドポイントを出さない方針は変更しない

## Capabilities

### New Capabilities

なし。

### Modified Capabilities

- `llm-summary-context-menu-trigger`: 解析失敗の診断が報告する `model` を、設定上のモデル名から、実行に使われたクライアントのモデル識別子へ変更する
- `failure-detail-dialog`: 診断に載せる application version が、リリース間のビルドを区別できることを要件化する

## Impact

- `lib/features/llm_summary/presentation/analysis_runner.dart`: `_diagnostics` が `config.model` ではなくクライアントのモデル識別子を読む
- `lib/features/app_update/providers/update_providers.dart`: `appVersionLabelProvider` がビルド識別子を含める
- `lib/features/tts/presentation/tts_failure_report.dart`: 同じ version ラベルを共有するため、TTS の障害レポートも同様に改善される。TTS の `model`（モデルディレクトリ名）は別物であり変更しない
- ビルド経路（`scripts/` のビルドスクリプトとリリースワークフロー）が識別子を注入する
- 保存データへの影響なし。診断は通知とダイアログにのみ現れる
