## Context

per-folder DB（`episode_cache.db` / `tts_audio.db` / `tts_dictionary.db`）のハンドルは Riverpod の `Provider.family`（`ttsAudioDatabaseProvider` ほか）が保持し、`ref.onDispose` でフォルダ切替・無効化時に `close()` する。フォルダの移動/リネーム/削除の前にこのハンドルを閉じ切らないと、Windows では SQLite ファイルが排他ロックされたまま `Directory.rename`/`delete` が失敗する。

現状（`commit 81ca506` 時点）の整合性は機能ごとにバラバラ：

```
                        close を await?   キー正規化?
削除 (novel_delete_providers)   ✅ await        ✅ folderDbKey
移動 (file_browser_panel:422)   ❌ invalidateのみ  ❌ 生パス(TTS)
リネーム (:505)                 ❌ invalidateのみ  ❌ 生パス(TTS)
空フォルダ削除 (:476)            ❌ invalidateのみ  ❌ 生パス(TTS)
フォルダ切替 (file_browser_providers:35) ❌ invalidateのみ ❌ 生パス(TTS)
```

`_releaseFolderHandles`（file_browser_panel.dart:445-451）は3フロー共用だが、中身は fire-and-forget の `ref.invalidate` のみ。`onDispose` の `close()` は await されず、直後の `await service.moveDirectory(...)` とレースする（F108）。

`folderDbKey`（= `p.normalize`）は `episode_cache` には適用されているが、TTS 系 family は生パスをキーにしている（F126）。`episode-cache` spec には既に「normalized folder path key」要件があり、TTS 系をこれに揃える。

F131: ハンドル解放順序を固定するテストは削除フロー（`novel_delete_order_test.dart`）にしかなく、move/rename は無防備。

## Goals / Non-Goals

**Goals:**
- 移動 / リネーム / 空フォルダ削除の3フローで、ファイル操作の前に3つの per-folder DB ハンドルを `await close()` し、その後 `invalidate` する（F108）。
- 削除フローと3フローが**同一の共有ヘルパー**で close→invalidate を振り付ける（重複ロジックの一本化）。
- per-folder DB ハンドルの参照・無効化を、開く側・解放する側の**全箇所で `folderDbKey` 正規化キー**に統一する（F126）。`tts-audio-storage` / `tts-dictionary` spec に episode-cache と同形の要件を追加。
- move / rename のハンドル解放順序を固定するテストを追加（F131）。

**Non-Goals:**
- DB ラッパー自体に open/close のインターロックを設ける根本対応（F124）。本変更は「UI/provider 層が正しい順序で振り付ける」ことに留め、ハンドルレジストリ化（F125）は別 change とする。
- `episode_cache` の利用箇所の挙動変更（既に正規化済み・spec 済み）。共有ヘルパー経由に揃える以上の変更はしない。
- `Provider.family` を完全にキー正規化して「呼び出し側の規律」を機構的にゼロにする accessor 層の導入（後述の判断参照）。

## Decisions

### D1. close→invalidate を共有ヘルパーに一本化する（F108）

`Ref` と `WidgetRef` は共通の基底型を持たないが、どちらも `T read<T>(ProviderListenable<T>)` と `void invalidate(ProviderOrFamily)` を提供する。これをジェネリックなテアオフとして受ける自由関数を新設する：

```dart
// lib/shared/database/folder_db_handles.dart（新規）
Future<void> releaseFolderDbHandles(
  String folderPath, {
  required T Function<T>(ProviderListenable<T>) read,
  required void Function(ProviderOrFamily) invalidate,
}) async {
  final key = folderDbKey(folderPath);
  // close を await してから invalidate（onDispose の close は待たれないため）。
  await read(episodeCacheDatabaseProvider(key)).close();
  await read(ttsAudioDatabaseProvider(key)).close();
  await read(ttsDictionaryDatabaseProvider(key)).close();
  invalidate(episodeCacheDatabaseProvider(key));
  invalidate(ttsAudioDatabaseProvider(key));
  invalidate(ttsDictionaryDatabaseProvider(key));
}
```

- 呼び出し側: `await releaseFolderDbHandles(dir.path, read: ref.read, invalidate: ref.invalidate)`。
- `file_browser_panel` の move/rename/空削除の3フローは、ファイル操作の `await` の**前**にこのヘルパーを `await` する。
- `novel_delete_providers` の既存インラインクロージャもこのヘルパー呼び出しへ置換（重複解消）。

**代替案**: DB インスタンスを読んでから渡す `closeFolderDbHandles(episodeCache, ttsAudio, ttsDict)` 案も検討したが、invalidate 側の重複が残り、キー導出が呼び出し側に散る。テアオフ案は close 順序・キー導出・invalidate を1関数に閉じ込められるため採用。

### D2. F126 は「開く側・解放する側の全箇所で正規化キー」に統一する（in-body 正規化は採らない）

`Provider.family` は引数文字列でキャッシュを引くため、**provider 本体の中で `folderDbKey` を適用してもキーは生パスのまま**で、別綴りのパスは別ハンドルとして開かれてしまう（解放系が届かない＝バグが残る）。したがって TECH_DEBT_AUDIT の「provider 本体で適用」の文字どおりの実装は family のキー重複を解消できない。

代わりに `episode_cache` が既に採る方式＝**全利用箇所が `folderDbKey(path)` を渡す**に TTS 系を揃える。対象（生パスを渡している箇所）：
- `tts_audio_state_provider.dart:47`（`ref.watch`）
- `file_browser_providers.dart:35-36, 87`（切替時 invalidate / watch）
- `tts_edit_dialog.dart:67,73`、`tts_controls_bar.dart:117,123,225`、`text_content_renderer.dart:381`、`vacuum_lifecycle_provider.dart:82`（`ref.read`）
- `file_browser_panel.dart:446-447` の旧 `_releaseFolderHandles`（D1 のヘルパーへ吸収され消滅）

**代替案（accessor 層で規律を機構的にゼロ化）**: 生 family を private 化し `ttsAudioDatabase(ref, path)` 等の正規化アクセサ経由のみに限定すれば呼び出し側の規律は不要になる。しかし `ref.watch` する反応的消費者（2箇所）が関数アクセサと相性が悪く、`episode_cache` 側も巻き込む大きめの改修になる。本 change は episode_cache と同じ「正規化キー＋spec/テストで規律を担保」モデルでパリティを取るに留め、accessor 化は将来改善（F124/F125 と併せて）とする。

### D3. F131 は削除フローの order-test を move/rename へ移植する

`novel_delete_order_test.dart` は「ファイル削除より前に全ハンドルの close が完了している」ことを、close 呼び出しとファイル操作の順序を記録する fake で検証している。同パターンを move/rename 用に移植し、共有ヘルパー D1 が「close（await 完了）→ ファイル操作」の順を保証することを固定する。空フォルダ削除も同テストに含める。

## Risks / Trade-offs

- **[テアオフのジェネリック関数引数が Dart で受かるか]** → `Ref.read`/`WidgetRef.read` はともに `T read<T>(ProviderListenable<T>)`、`invalidate` は任意引数 `asReload` を持つが `void Function(ProviderOrFamily)` へ代入可能。最初に小さなコンパイル確認を行い、不可なら D1 代替案（DB インスタンス受け取り＋invalidate は呼び出し側）へフォールバック。
- **[F126 の open 側正規化漏れが1つでも残ると解放系が届かない]** → 全 TTS 利用箇所を網羅的に置換し、`tts-audio-storage`/`tts-dictionary` spec へ「normalized key」要件を追加、正規化テスト（episode-cache の同名テストが手本）で別綴り→同一ハンドルを固定する。
- **[根本原因 F124（open/close インターロック欠如）は未解決のまま]** → 本 change は振り付けの正しさに限定。新たな per-folder DB 消費者が将来増えると同型バグが再発し得る点を design に明記し、F124/F125 を後続 change として残す。
- **[reactive watch 経由のハンドルは invalidate で再 open され得る]** → 既存の削除フローと同じ挙動。ファイル操作はヘルパー await 完了後に走るため、再 open はファイル操作後（=ロック解除後）。順序テスト（D3）で担保。
