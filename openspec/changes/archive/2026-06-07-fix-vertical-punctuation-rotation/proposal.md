## Why

縦書き表示において、ダブルクオート（`"` `"` `"` `＂`）、シングルクオート/アポストロフィ（`'` `'` `'` `＇`）、バッククォート（`` ` `` `｀`）が回転されず、セルの右上に小さく浮いた不自然な見た目になっている（`tmp/ダブルクオーテーション.png`）。これらの文字にはUnicodeの縦書き用字形（presentation form）が存在しないため、現行の「文字置換」方式では対応できない。

また、コロン・セミコロン（`:` `：` `;` `；`）は既に `verticalCharMap` で縦書き用字形（`︓` `︔`、U+FE13/FE14）へ置換しているにもかかわらず、このフォントが当該CJK互換形を回転グリフとして描画できず、点が縦に並んだまま回転して見えない（`tmp/コロン.png`）。

縦書き用字形への置換（`〝〟` 案を含む）はフォント依存で破綻するため、字形を物理的に90°回転させる方式へ統一する。

## What Changes

- 縦書きレンダリングに「物理回転」方式を新規導入する。対象文字を `RotatedBox(quarterTurns: 1)`（時計回り90°）で回転させ、文字自体は置換しない。
- 回転対象文字: ダブルクオート（`"` `＂` `"` `"`）、シングルクオート/アポストロフィ（`'` `＇` `'` `'`）、バッククォート（`` ` `` `｀`）、コロン（`:` `：`）、セミコロン（`;` `；`）。
- コロン・セミコロンを `verticalCharMap` の置換対象から除外し、回転対象集合へ移管する。これにより既存の「コロン/セミコロンを縦書き字形に置換」する挙動を**回転に置き換える**。
- ハイブリッド（一部を `〝〟` 置換）は採用しない（`tmp/ダブルクオート置換テスト.png` で同様に不自然と確認済み）。

## Capabilities

### New Capabilities
<!-- なし（既存capabilityの要件変更のみ） -->

### Modified Capabilities
- `vertical-text-display`: 「Vertical character mapping」要件配下の `Colons and semicolons are mapped to vertical form` シナリオを、置換から物理回転へ変更。加えて「クオート類・コロン類は90°回転で描画する」新シナリオと、回転方式そのものを規定する新シナリオを追加する。

## Impact

- 影響コード:
  - `lib/features/text_viewer/data/vertical_char_map.dart`: コロン・セミコロンの置換エントリ削除、回転対象集合の追加。
  - `lib/features/text_viewer/presentation/vertical_text_page.dart`: `_buildCharWidget` に回転分岐を追加。
  - `lib/features/text_viewer/presentation/vertical_ruby_text_widget.dart`: ルビ経路での約物の扱いを必要に応じて整合（スコープは design で確定）。
- 依存・API変更なし。設定項目の追加なし。
- 表示のみの変更で、保存データ・テキストオフセット（検索/TTSハイライト）には影響しない（文字を置換しないため文字数・オフセットが不変）。
