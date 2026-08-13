## 1. 失敗するテストの作成（TDD: Red）

- [x] 1.1 `test/features/text_viewer/ruby_text_parser_test.dart` に、空親文字ルビ `<ruby><rb></rb><rp>(</rp><rt>戦術的優位性</rt><rp>)</rp></ruby>` をパースすると `base == ""` / `rubyText == "戦術的優位性"` の `RubyTextSegment` が得られることを確認するテストを追加する（現状の挙動の固定。ここは通るはず）
- [x] 1.2 同ファイルに、空親文字ルビを含むテキストのプレーンテキスト抽出結果が親文字ぶん 0 文字であること（例: `何の<ruby>...</ruby>もなかった` → `何のもなかった`）を確認するテストを追加する
- [x] 1.3 `test/features/text_viewer/data/column_splitter_test.dart` に、空 base の `RubyTextSegment` を含むセグメント列を `flattenSegments` に渡しても例外が発生しないテストを追加する
- [x] 1.4 同ファイルに、空 base ルビエントリの `charCount` が 0、`firstChar` / `lastChar` が空文字列であることを確認するテストを追加する
- [x] 1.5 同ファイルに、`charsPerColumn` ぶんの平文＋空 base ルビ 1 個の行が、空 base ルビが存在しない場合と同じ列構造に分割されることを確認するテストを追加する（列の文字数を消費しない）
- [x] 1.6 同ファイルに、空 base ルビが列境界に来るケース（列が満杯の直後に空 base ルビが来る／空 base ルビの直後に行頭禁則文字が来る）で、追い出しが誘発されず無限ループにもならないことを確認するテストを追加する
- [x] 1.7 `fvm flutter test` を実行し、1.3〜1.6 が `StateError: Bad state: No element` で失敗することを確認する（Red の確認: `column_splitter.dart:16 new FlatCharEntry.ruby` ← `column_splitter.dart:37 flattenSegments`）
- [x] 1.8 テストのみをコミットする（プロジェクトの TDD ルール: テストが正しいことを確認した段階でコミット）

## 2. 実装（TDD: Green）

- [x] 2.1 `lib/features/text_viewer/data/column_splitter.dart` の `FlatCharEntry.ruby` を、空の親文字に対して `firstChar` / `lastChar` を空文字列、`charCount` を 0 とするようガードする
- [x] 2.2 `FlatCharEntry.ruby` の変更意図（空親文字ルビはサイト由来の正当な入力であること、プレーンテキスト座標系を動かさないこと）をコメントとして残す
- [x] 2.3 `fvm flutter test` を実行し、1.3〜1.6 を含む全テストが通ることを確認する（対象2ファイル 55件パス）
- [x] 2.4 禁則処理・ページネーション関連の既存テストに回帰がないことを確認する（`test/features/text_viewer` 486件パス）

## 3. 縦書き描画の確認

- [x] 3.1 `test/features/text_viewer/presentation/vertical_ruby_text_widget_test.dart` に、空 base のルビを `VerticalRubyTextWidget` に渡してもエラーにならず、ルビ文字が描画されることを確認するテストを追加する（このウィジェット自体は修正前から空 base 耐性があったため、修正の有無に関わらず通る。回帰ガードとして残す）
- [x] 3.2 空 base ルビを含むセグメント列を縦書きビューアに与えたとき、`ErrorWidget` にフォールバックせずページ内容が描画されることを確認するウィジェットテストを追加する（修正を一時退避して 2 件とも `StateError` で失敗することを確認済み）

## 4. 実データによる手動検証

- [ ] 4.1 `fvm flutter build windows` でビルドし、`hameln_419738/07_07.txt` を縦書きで開いて本文が表示されることを確認する
- [ ] 4.2 同様に `hameln_419738/09_09.txt`（空 base ルビ 4 件）を縦書きで開いて本文が表示されることを確認する
- [ ] 4.3 同じ 2 ファイルを横書きで開き、修正前と表示が変わっていないことを確認する
- [ ] 4.4 空 base ルビを含むページで TTS 再生を行い、ハイライト位置がずれていないことを確認する

## 5. 最終確認

- [ ] 5.1 code-reviewスキルを使用してコードレビューを実施
- [ ] 5.2 codexスキルを使用して現在開発中のコードレビューを実施
- [x] 5.3 `fvm flutter analyze`でリントを実行（No issues found）
- [x] 5.4 `fvm flutter test`でテストを実行（2823件パス / 1件 skip）
