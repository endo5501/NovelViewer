## Purpose

macOS の `Runner.app/Contents/Frameworks/` へのネイティブ共有ライブラリ (dylib) の同梱とコード署名を規定する。同梱対象は `macos/Frameworks/` ディレクトリのグロブによって決定され、当該ディレクトリが唯一の source of truth となる。ライブラリ名の静的な列挙、依存解析によるフェーズのスキップ、未ビルド dylib によるビルド破損を排除することを目的とする。

## Requirements

### Requirement: macos/Frameworks を同梱リストの唯一の source of truth とする

`macos/Runner.xcodeproj` の `Embed Native Libraries` ビルドフェーズは、同梱対象の dylib を `macos/Frameworks/` ディレクトリのグロブ (`"${SRCROOT}"/Frameworks/*.dylib`) によって決定しなければならない (MUST)。ライブラリ名を列挙した静的なリストをビルドフェーズ内に保持してはならない (MUST NOT)。

これは、従来 `inputPaths` / `outputPaths` / `shellScript` の3ヶ所で同じ名前を重複管理しており、記載漏れが無言で別々の破損 (実行時ロード失敗、フェーズの up-to-date 誤判定、古いコピーの残存) を引き起こしていたためである。

#### Scenario: 新規 dylib の追加時に編集箇所が1ヶ所で済む

- **WHEN** `macos/Frameworks/` に新しい `.dylib` を配置して macOS ビルドを実行する
- **THEN** `project.pbxproj` を編集することなく、当該 dylib が `Runner.app/Contents/Frameworks/` へコピー・署名される

#### Scenario: ビルドフェーズに静的なライブラリ名リストが存在しない

- **WHEN** `Embed Native Libraries` ビルドフェーズの定義を確認する
- **THEN** `inputPaths` と `outputPaths` がいずれも空であり、`shellScript` 内に個別のライブラリ名が現れない

### Requirement: 依存解析を無効化してフェーズのスキップを防ぐ

`Embed Native Libraries` ビルドフェーズは `alwaysOutOfDate = 1` を設定し、Xcode の依存解析によるスキップ対象から除外しなければならない (MUST)。`inputFileListPaths` / `outputFileListPaths` による静的な依存宣言を用いてはならない (MUST NOT)。

グロブで決まる集合を静的リストで宣言し直すと、両者の乖離という同じドリフト問題が再発するためである。

#### Scenario: 出力先を削除しても次のビルドで復元される

- **WHEN** `Runner.app/Contents/Frameworks/` 配下の dylib を削除し、ソースを変更せずに再ビルドする
- **THEN** `Embed Native Libraries` フェーズが実行され、削除された dylib が再度コピー・署名される

### Requirement: 同梱時にコード署名する

`Embed Native Libraries` ビルドフェーズは、コピーした各 dylib に対して `EXPANDED_CODE_SIGN_IDENTITY` を用いた `codesign --force` を実行しなければならない (MUST)。

#### Scenario: 同梱済み dylib が署名されている

- **WHEN** `fvm flutter build macos` の完了後に `codesign --verify --deep --strict` を `Runner.app` に対して実行する
- **THEN** 検証がエラーなく完了する

### Requirement: dylib が1件も存在しなくてもビルドが壊れない

`Embed Native Libraries` ビルドフェーズは、`macos/Frameworks/` に `.dylib` が1件も存在しない場合でも非ゼロ終了してはならない (MUST NOT)。`shellPath` が `/bin/sh` であり `nullglob` が利用できないため、グロブ不一致時にパターン文字列がそのままループへ渡される。ループ内で対象がファイルであることを確認し、そうでなければスキップしなければならない (MUST)。

#### Scenario: Frameworks ディレクトリが空の場合

- **WHEN** `macos/Frameworks/` に `.dylib` が1件も存在しない状態で macOS ビルドを実行する
- **THEN** `Embed Native Libraries` フェーズはコピーを行わずに正常終了し、ビルド自体が失敗しない

#### Scenario: 一部の dylib が未ビルドの場合

- **WHEN** 一部の dylib のみが `macos/Frameworks/` に存在する状態で macOS ビルドを実行する
- **THEN** 存在するものだけが同梱され、ビルドは成功する

### Requirement: 同梱される dylib 集合が期待どおりである

全ネイティブライブラリをビルド済みの状態で macOS ビルドを実行したとき、`Runner.app/Contents/Frameworks/` には `libqwen3_tts_ffi.dylib` / `liblame_enc_ffi.dylib` / `libpiper_tts_ffi.dylib` / `libonnxruntime.dylib` / `libaudiocpp_ffi.dylib` の5件が同梱されなければならない (MUST)。これ以外の `.dylib` を同梱してはならない (MUST NOT)。

#### Scenario: 同梱集合の確認

- **WHEN** 全ネイティブライブラリをビルドした状態で `fvm flutter build macos` を実行し、`Runner.app/Contents/Frameworks/*.dylib` を列挙する
- **THEN** 上記5件と一致し、バージョン付きの `libonnxruntime.*.dylib` などの余分なファイルが含まれない

### Requirement: pbxproj の編集後にパース可能性を検証する

`macos/Runner.xcodeproj/project.pbxproj` を手編集した場合、`xcodebuild -list -project macos/Runner.xcodeproj` が成功することを確認しなければならない (MUST)。

#### Scenario: 編集後の検証

- **WHEN** `project.pbxproj` を編集した後に `xcodebuild -list -project macos/Runner.xcodeproj` を実行する
- **THEN** パースエラーを出さずにターゲット一覧が出力される
