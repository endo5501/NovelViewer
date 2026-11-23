# Design

## Context

- 背景と動機は proposal.md の Why を参照
- CI（`test.yml` / `release.yml`）は `subosito/flutter-action@v2` を `channel: stable` で使っている。ローカルの `.fvmrc` も `{"flutter": "stable"}` なので、どちらも「その時点の stable」で動く。ただしローカルは fvm のキャッシュを明示的に更新しない限り古いままになり、現在は 3.47.5
- 3.50.1 で analyze を実行すると196件の issue が出る。いずれも `deprecated_member_use` で、内訳は次の2種類
  - `package:flutter/material.dart` の import が194件（lib 56件 / test 138件）
  - `lib/l10n/app_localizations.dart:91-92` の `GlobalMaterialLocalizations.delegate` / `GlobalCupertinoLocalizations.delegate` が2件
- `lib/l10n/app_localizations.dart` は `flutter gen-l10n` の生成物である（`pubspec.yaml` の `generate: true`、`l10n.yaml`）。手で編集しても再生成で上書きされる。3.50.1 のテンプレートも旧 delegate を出力する（D2）
- `AppLocalizations.localizationsDelegates` は `lib/app.dart` と、`test/` 配下の103ファイルで使われている
- `package:flutter/cupertino.dart` を直接 import している箇所はない。`packages/foundation_models_llm` には Dart の material import がない
- material_ui 1.11.1 と cupertino_ui 1.1.7 は、どちらも `sdk: ^3.13.0` と `flutter: >=3.47.0` を要求する

## Goals / Non-Goals

**Goals:**
- 3.50.1（現在の最新 stable）で `flutter analyze` を0件にし、`flutter test` を全件成功させる
- 移行は機械的にできる部分を最大にし、ロジックは変えない

**Non-Goals:**
- Flutter のバージョンを固定すること。ユーザーの決定により、CI は stable のまま追随する
- material_ui への移行を機に、UI やテーマを変えること
- 3.50 のほかの新機能を取り入れること

## Decisions

### D1. import は `dart fix --code=migrate_design_widgets` で一括移行する
公式の自動修正を使う。194ファイルを sed で置き換える方法と比べ、依存の追加や、`Icons` などがどちらのライブラリに属するかの解決も、公式の判断に任せられる。修正のあと、import 順を整えるために `dart fix --apply` をもう1回実行し、続けて `dart format lib test` を実行する。
- 代替案：sed で一括置換する。`cupertino_ui` 側にあるシンボルを取りこぼすおそれがあるので、fix が対応しきれなかった残りにだけ使う
- 生成ファイル `lib/l10n/app_localizations*.dart` は、dart fix の対象から外す（D2 で analyze の対象からも外すうえ、再生成で戻るため）

### D2. ローカライズ delegate は非生成ファイルで組み立て、生成ファイルは analyze の対象から外す
gen-l10n のテンプレートは、3.50.1 タグでも master でも、`package:flutter_localizations` を import して `GlobalMaterialLocalizations.delegate` / `GlobalCupertinoLocalizations.delegate` を出力する（`packages/flutter_tools/lib/src/localizations/gen_l10n_templates.dart` の 91-92 行で確認）。CI のログでも、`lib/l10n/app_localizations.dart:91:9` / `:92:9` が指摘されている。つまり再生成しても解決しない。

さらに、material_ui のウィジェットが引くのは material_ui 側の `MaterialLocalizations` 型である。旧 delegate が提供するのは別の型なので、`AppLocalizations.localizationsDelegates` を使い続けると、実行時にローカライズが見つからなくなるおそれがある。

そこで、次のようにする。
1. 非生成のファイル（例：`lib/l10n/app_localization_delegates.dart`）に、`AppLocalizations.delegate` と material_ui の `GlobalMaterialLocalizations.delegates` を合わせたリストを定義する（後者は Cupertino と Widgets も含む）
2. `lib/app.dart` と、テスト103ファイルで `AppLocalizations.localizationsDelegates` を参照している箇所を、このリストに置き換える（機械的な置換）
3. 生成ファイル `lib/l10n/app_localizations*.dart` だけを、`analysis_options.yaml` の `analyzer: exclude` に加える。生成物を lint の対象から外すのは一般的なやり方である。手書きのコードは除外しない

- 代替案1：生成ファイルを手で直す。再生成で戻ってしまうので採らない
- 代替案2：`// ignore_for_file` を生成ファイルに入れる。これも再生成で消えるので採らない
- フレームワークがテンプレートを material_ui に対応させたら、exclude を外し、生成リストを使う形に戻せる（Open Questions を参照）

### D3. `pubspec.yaml`
- `material_ui` を `dependencies` に加える
- `cupertino_ui` は material_ui 経由で入る。ただし dart fix の結果、手書きコードが `package:cupertino_ui/...` を直接 import した場合は、`depend_on_referenced_packages` が fatal info として扱われるので、直接の依存に加える。実際に import したのは回帰テスト（`test/l10n/framework_localizations_test.dart`）だけだったので、`dev_dependencies` に加えた
- `environment.sdk` の下限は `^3.10.8` のまま据え置く。実装の途中で `^3.13.0` に上げたところ、言語バージョンも上がり、移行と無関係な `prefer_initializing_formals` の info が63件出て、format でも131ファイルが書き換わった。pub が見るのは「実行している SDK が material_ui の要求（3.13 以上）を満たすか」だけで、プロジェクトの下限は関係しない。下限を上げるのは別の change で扱う
- `flutter_localizations` は残す。生成ファイルがこれを import しており、material_ui も依存しているため

### D4. 型の不一致への対応
material_ui のクラスは旧 material とは別の型である可能性がある。analyze で型エラーが出たら、次の順に対応する。
1. 該当するサードパーティのパッケージを更新する
2. それでも解決しなければ、`MaterialApp.builder` に `MaterialUiCompatibilityBridge` を入れて解決するかを試す
3. 解決しなければ、作業を止めてユーザーに相談する

### D5. CI は変えない
`channel: stable` を維持する（spec：flutter-linter-config）。この change の目的は、最新の stable で緑に戻すことにある。

## Risks / Trade-offs

- 3.50.1 で、フレームワーク側の挙動が変わってテストが落ちる
  → analyze が通ったら、すぐに全テストを流す。落ちたテストは1件ずつ原因を調べる。テストの期待値を安易に書き換えない
- サードパーティのパッケージとの型の不一致
  → D4 の手順で対応する
- macOS / iOS の開発機が 3.47 のままだと、material_ui は動く（>=3.47.0）が、analyze の結果が CI と食い違う
  → 完了報告で、各開発機に `fvm flutter upgrade` を実行するよう案内する
- CI が stable に追随する以上、同じ種類の失敗はこれからも起きる
  → これは意図した挙動である（早期検知）。この change の作業手順が、次に起きたときの手本になる

## Migration Plan

1. ローカルの fvm stable を 3.50.1 に更新し、196件が再現することを確かめる（Red）
2. D1 → D3 → D2 → D4 の順に実施し、analyze を0件にする
3. 全テストを成功させ（Green）、アプリを起動して確かめる
4. ブランチで PR を作り、CI の Test が緑になることを確かめてからマージする

ロールバックするときは、この change のコミットを revert する。ただし CI は stable のままなので、revert すると analyze の失敗も元に戻る。

## Open Questions

- gen-l10n のテンプレートが material_ui / cupertino_ui に対応するのはいつか（flutter/flutter #192954 周辺）。対応したら、D2 の exclude と独自の delegate リストをやめ、生成リストに戻す。これは別の change で扱えばよく、この change の作業内容は変わらない
