## Why

解析済みの語句に引かれた傍線は、要約が読めるという合図として読者に見えている。しかし指で触れても何も起きない。ポップアップを開く経路が、横書きは `TextSpan` の `onEnter`/`onExit`、縦書きは `MouseRegion.onHover` と、どちらもホバー専用だからである。iPad にはホバーがないため、解析はできるのに結果が読めない状態になっている。実機でもその通りであることが確認されている。

閉じる経路も同じ理由で塞がっている。いま唯一の退出は `MouseRegion` の離脱であり、指には離脱がない。開ける道を足すだけでは、開いたまま外せないポップアップができてしまう。

## What Changes

- **縦書きビューアで、マーク上の指のタップが要約ポップアップを開く。** 既存の `_onTapUp` に分岐を足す。優先順位は「選択範囲の内側 → コンテキストメニュー、マークの上 → 要約ポップアップ、それ以外 → 選択クリア」とする。前後の二つは既存の意味であり、変わらない。
- **横書きビューアで、マーク上の指のタップが要約ポップアップを開く。** `SelectableText` が指のタップに対して報告する折りたたみ選択 (`SelectionChangedCause.tap`) からタップ位置を受け取り、既存の `plainTextOffsetFromDisplayOffset` で平文オフセットへ変換してマークを引く。タップ座標からの独自のレイアウト計算は行わない。
- **ポップアップの下に画面全体の透過リスナーを敷き、ポップアップの外で起きたタッチのポインタダウンでポップアップを閉じる。** 素通しなので下の操作は妨げない。マウスのイベントは無視するため、デスクトップの挙動は変わらない。
- **横書きでもスクロールでポップアップを閉じる。** 縦書きにはすでにある `onHoverHideRequest` 相当の経路を、横書きのスクロール通知にも繋ぐ。
- **横書きのポップアップ配置にも、画面内へ収める処理を通す。** 現在の横書きのアンカーはポインタの右下にずらすだけで、めくり返しも切り詰めも行わない。iPad の縦持ちでは画面右寄りのマークをタップするとポップアップが画面外へ出る。縦書き用にすでに実装されているめくり返しとクランプを横書きにも適用する。配置の基本方針 (ポインタの右下) は変えない。
- 長押しは両モードとも現状維持とする。横書きの長押しは Flutter の `SelectableText` が語選択と解析メニューに使っており、空きがない。縦書きの長押しは、パン認識器をアリーナから追い出して選択ドラッグを壊すため、意図的に避けた判断が `touch-context-menu-trigger` に記録されている。

破壊的変更はない。マウスで開く経路、ホバーの猶予時間、ポップアップの中身と操作は一切変わらない。

## Capabilities

### New Capabilities

なし。

### Modified Capabilities

- `llm-summary-hover-popup`: ポップアップの起動がホバー専用でなくなる。マーク上のタッチのタップという第二の起動経路と、それに対応する閉じ方 (外側のタッチ、スクロール) を要件として加える。横書きの配置要件に、画面内へ収める規定を加える。再解析ドロップダウンの要件に書かれた「トラックパッドが繋がっていればホバーが届くので到達できる」という記述は、到達手段が増えたため書き換える。
- `touch-context-menu-trigger`: 縦書きビューアのタップに関する要件を変更する。現在は「選択範囲の外側のタップは選択をクリアする」と定めているが、そこにマークの上という中間の場合が入る。優先順位を明示し、コンテキストメニューが最優先であること、マークにも選択にも当たらないタップが従来どおり選択をクリアすることを規定する。

## Impact

**コード**

- `lib/features/text_viewer/presentation/vertical_text_page.dart` — `_onTapUp` にマーク判定の分岐を足す。`_hitTest` と `_markedRanges` は既存のものを使う。
- `lib/features/text_viewer/presentation/vertical_text_viewer.dart` — マークのタップをページから上位へ運ぶコールバックを通す。
- `lib/features/text_viewer/presentation/widgets/text_content_renderer.dart` — 横書きの `onSelectionChanged` からマークを引く経路、スクロールでの非表示、縦書きからのタップ通知の受け口。
- `lib/features/text_viewer/presentation/ruby_text_builder.dart` — 横書きのマーク情報を、`TextSpan` の中だけでなく呼び出し側からも引けるようにする。
- `lib/features/llm_summary/presentation/hover_popup_host.dart` — ポップアップの下に敷く透過リスナーのオーバーレイ。
- `lib/features/llm_summary/presentation/hover_popup_anchor.dart` — 横書きのめくり返しとクランプ。
- `lib/features/llm_summary/providers/hover_popup_provider.dart` — タッチで開いた場合の状態遷移 (ホバーの猶予時間を経由しない経路)。

**依存・プラットフォーム**

新規の依存はない。プラットフォーム判定も増やさない。分岐はすべて `kNoSecondaryButtonPointerKinds` によるポインタ種別で行い、`Platform.isIOS` は参照しない。タッチスクリーン付きのデスクトップも同じ経路で到達できる。

**テスト**

`test/features/llm_summary/presentation/` のポップアップ関連テスト群と、`test/features/text_viewer/presentation/` のビューア側テスト群が主な対象。既存のホバー経路のテストは変更しない。
