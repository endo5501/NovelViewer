## Why

境界での話送り（本文の末尾／先頭からさらにページを進める操作で次話・前話へ移る挙動）が、縦書きモードと横書きモードで別々に実装され、**異なる仕様になっている**。

- 縦書き（`vertical-text-display`）: 1 回目でヒントを表示し、2 回目の同方向入力で確定する **2 段階確認**
- 横書き（`text-viewer`）: **1 回の入力で即座に遷移**し、暴発をクールダウン（一定時間の入力無視）で抑えている

横書き側のクールダウンは「1 回で遷移すると事故る」ことへの対症療法であり、実装コメントも複数話を一気に飛ばす暴走の防止だと明言している。縦書きで既に成立している 2 段階確認のほうが素直な解であり、モード間で挙動が割れている理由もない。

加えて、iPad 対応で横書きモードにタッチ入力（境界でのオーバースクロール）を足す計画がある。入力ソースを増やす前に、境界確認のロジックを両モードで共有できる形に整理しておく必要がある。

## What Changes

- 2 段階確認の状態機械を、縦書き／横書きの両ビューアから共有できる独立したユニットとして切り出す（タイムアウト・確定クールダウン・遷移時クリアを内包し、`fake_async` でテスト可能な純粋ロジック）
- 縦書きビューアを共有ユニットに載せ替える。**観測される挙動は変わらない**
- **BREAKING**: 横書きモードの境界ナビゲーションを 2 段階確認に変更する。本文末尾で下カーソルキー／下方向ホイールを 1 回操作しても次話へ遷移せず、ヒント表示を挟んで 2 回目の同方向操作で確定する（前話方向も対称）
- **BREAKING**: 横書きモードの「境界ナビゲーション暴発防止クールダウン」要件を削除する。2 段階確認が同じ目的を満たすため不要になる
- 横書きモードにヒント表示領域を新設する。縦書きのページ番号領域と同じ位置（本文下部中央）に、プロンプト中のみ薄いバナーとして表示する
- ヒント文言の l10n キーをモード中立な名前へ改名する（現行 `verticalText_nextEpisodePrompt` / `verticalText_prevEpisodePrompt` は縦書き専用を示唆するため）。ja / en / zh の 3 ロケールが対象

### 含まないもの

- 横書きモードのタッチ入力（境界でのオーバースクロール検出）。本変更で共有ユニットに入力ソースを 1 つ足せる形にしておき、実際の接続は iPad 対応の後続変更で行う
- 縦書きモードの挙動変更

## Capabilities

### New Capabilities
- `episode-boundary-prompt`: 境界での話送りに対する 2 段階確認の共通規則。ヒント表示状態の遷移、タイムアウト、確定クールダウン、隣接ファイルが無い場合の no-op、遷移時のクリアを定義する。縦書き・横書きの両ビューアと、将来のタッチ入力がこの capability を共有する

### Modified Capabilities
- `text-viewer`: 「横書きモードの境界エピソードナビゲーション」を 1 段階即遷移から 2 段階確認へ変更。「横書きモードの境界ナビゲーション暴発防止クールダウン」要件を削除。ヒント表示領域の要件を追加

## Impact

**コード**

- `lib/features/text_viewer/presentation/vertical_text_viewer.dart` — 私有の 2 段階確認状態（`_pendingNextFilePrompt` / `_pendingPrevFilePrompt` / `_promptTimeoutTimer` / `_confirmCooldownTimer`）を共有ユニットへ移譲
- `lib/features/text_viewer/presentation/widgets/text_content_renderer.dart` — `_navigateEpisodeAtEdge` の 1 段階遷移と `_edgeNavCooldownTimer` を共有ユニットに置換、ヒントバナーを追加
- 共有ユニットの新規追加（配置先は design.md で決定）
- `lib/l10n/app_ja.arb` / `app_en.arb` / `app_zh.arb` — ヒント文言キーの改名

**テスト**

- `test/features/text_viewer/presentation/horizontal_edge_episode_nav_test.dart`（375 行）— 1 段階遷移前提のケースを 2 段階へ書き換え。`runaway cooldown` グループは削除し、2 段階確認のケースに置き換える
- `test/features/text_viewer/presentation/vertical_text_viewer_episode_nav_test.dart` / `vertical_text_viewer_swipe_test.dart` / `vertical_text_viewer_wheel_test.dart` — 挙動不変のため回帰確認として維持
- 共有ユニットのユニットテストを新規追加（`fake_async` 使用）

**依存関係**

- 新規パッケージなし。`fake_async` は既に dev_dependencies にある

**ユーザーへの影響**

- 横書きモードで読んでいるユーザーは、境界での話送りに操作が 1 回増える。リリースノートに記載する
