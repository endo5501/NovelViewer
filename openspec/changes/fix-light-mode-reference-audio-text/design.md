## Context

TTS編集画面の`_SegmentRow`ウィジェット内のリファレンス音声ドロップダウン（`DropdownButtonFormField`）で、`style: const TextStyle(fontSize: 12)`を指定している。この`style`プロパティは選択済みアイテムの表示スタイルを制御するが、色が未指定のため、ライトモード時にテキストが白色で描画され読めない状態になっている。

該当箇所: `lib/features/tts/presentation/tts_edit_dialog.dart` 564行目

## Goals / Non-Goals

**Goals:**
- ライトモード・ダークモードの両方でリファレンス音声ドロップダウンのテキストが適切に読める色で表示される

**Non-Goals:**
- 他のドロップダウンやウィジェットのテーマ対応の網羅的な見直し
- DropdownMenuItemの個別スタイル変更（メニュー展開時の表示はテーマのデフォルトで正常動作する）

## Decisions

### `style`プロパティの色指定を削除する

`DropdownButtonFormField`の`style`プロパティから`const TextStyle(fontSize: 12)`を指定すると、Flutter Material 3ではデフォルトのテキスト色が適切に継承されないケースがある。

**選択肢:**

1. **`style`プロパティを削除し、`DropdownMenuItem`側のTextStyleのみで制御する** ← 採用
   - `DropdownButtonFormField`の`style`を削除すれば、テーマのデフォルト色が自動適用される
   - `DropdownMenuItem`のchildの`Text`ウィジェットで`fontSize: 12`を既に指定しているため、メニュー展開時・選択時ともにフォントサイズは保たれる

2. `Theme.of(context).colorScheme.onSurface`を明示的に指定する
   - `const`が使えなくなるが、動作は確実
   - ただしテーマの変更に対して脆弱（Surface以外の背景に配置された場合）

3. `Theme.of(context).textTheme.bodyMedium`をマージする
   - テーマ準拠だが冗長

アプローチ1が最もシンプルで、Flutterのテーマシステムに自然に委ねる方法。

## Risks / Trade-offs

- **[フォントサイズの変化]** → `DropdownButtonFormField.style`を削除するとデフォルトのフォントサイズが適用されるが、`DropdownMenuItem`の`Text`で`fontSize: 12`を個別指定しているため、実際の表示サイズは変わらない
