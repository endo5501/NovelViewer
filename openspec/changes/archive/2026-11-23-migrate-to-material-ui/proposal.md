# Proposal

## Why

GitHub Actions のワークフロー（`test.yml` / `release.yml`）は Flutter を `channel: stable` で取得している。2026-11-23 にこの stable が 3.47.9 から 3.50.1 に上がり、Test ワークフローは3回続けて `flutter analyze` で失敗している。最後に成功した run 41273582833 は 3.47.9、失敗した run 45144080466 / 45147829627 / 45159645696 はいずれも 3.50.1。

3.50 では `package:flutter/material.dart` と、`flutter_localizations` の `GlobalMaterialLocalizations` / `GlobalCupertinoLocalizations` が非推奨になった。代わりに pub パッケージの `material_ui` / `cupertino_ui` を使う。このため info レベルの `deprecated_member_use` が196件出ており、`flutter analyze` は info も致命的として扱うので exit 1 になる。

ローカルの fvm `stable` は 3.47.5 のまま更新されていないため、ローカルでは再現しない。`release.yml` も analyze を実行するので、このままでは次のリリースタグでも失敗する。

CI はこれからも `channel: stable` のまま固定しない。新しい stable で出る非推奨や破壊的変更に早く気づくのが狙いである。今回の失敗は、その仕組みが狙いどおりに働いた結果である。

## What Changes

- Material の UI は `package:material_ui/material_ui.dart` から import する。`package:flutter/material.dart` の import は、`lib/` で56件、`test/` で138件の計194ファイルにあり、すべて置き換える
- `pubspec.yaml` の依存に `material_ui` を追加する（`environment.sdk` の下限は据え置く。design D3 を参照）
- ローカライズの delegate は `material_ui` / `cupertino_ui` が提供するものを使い、手書きのコードでは `flutter_localizations` の非推奨 delegate を使わない。gen-l10n の生成物は 3.50.1 でも旧 delegate を出力するので、analyze の対象から外す
- 最新の stable で `flutter analyze` を実行したとき、info を含めて0件で終わる状態にする
- CI の `channel: stable` は変えない（バージョンは固定しない）
- 開発環境は fvm `stable` を最新（3.50.1）に更新する。macOS / iOS の開発機でも同じ更新が必要

## Capabilities

### New Capabilities

（なし）

### Modified Capabilities

- `project-setup`：依存管理に `material_ui` を加える。Material UI の import 元を `material_ui` に限定する
- `i18n-infrastructure`：`pubspec.yaml` の i18n 依存と、`MaterialApp` に渡すローカライズ delegate の出所を、`material_ui` / `cupertino_ui` に変える
- `flutter-linter-config`：「info は許容する」という基準を改める。CI と同じ最新 stable で、`flutter analyze` を info も含めて0件で通す。analyze の対象から外してよいのは、生成されたローカライズファイルだけと定める

## Impact

- 依存：`material_ui` を追加する（`cupertino_ui` は推移的に入る）。開発環境と CI の Flutter は 3.50.1 以上になる
- コード
  - `lib/` と `test/` で material.dart を import している194ファイル（import 行の置き換え）
  - 非推奨にならない delegate リストを新しく定義し、`lib/app.dart` とテスト103ファイルの `AppLocalizations.localizationsDelegates` を、そのリストに置き換える
  - `analysis_options.yaml`：生成ファイル `lib/l10n/app_localizations*.dart` を analyze の対象から外す。gen-l10n のテンプレートは 3.50.1 でも旧 delegate を出力するため
- CI：ワークフローは変えない。この change が入れば `test.yml` が緑に戻り、`release.yml` の analyze も通るようになる
- リスク
  - material_ui のクラスは別ライブラリなので、旧 material の型と互換がない可能性がある。サードパーティのパッケージが旧 material の型（`ThemeData`、`ColorScheme` など）を API でやり取りしていると、型エラーになる
  - 3.50.1 ではまだテストを一度も流していない
  - macOS / iOS のビルドは Windows では確認できない
