## MODIFIED Requirements

### Requirement: 既定のキー割り当て

システムはカスタマイズ可能な各アクションに既定のキー割り当てを提供しなければならない（SHALL）。修飾子はプラットフォームに応じて、Apple プラットフォーム（macOS および iOS）では Meta（⌘）、それ以外（Windows・Linux）では Control を使用しなければならない（SHALL）。判定には `defaultTargetPlatform` を用い、`dart:io` の `Platform` を読んではならない（MUST NOT）。カスタマイズ可能アクションの既定値は次のとおりとする: `search`=Ctrl/Cmd+F、`bookmark`=Ctrl/Cmd+B、`ttsToggle`=Ctrl/Cmd+T、`switchPane`=Tab。ページ送りの物理キーは向きごとに固定とする（カスタマイズ対象外）: 縦書き=`←`(next)/`→`(prev)、横書き=`↓`(next)/`↑`(prev)。

#### Scenario: macOSでの修飾子既定
- **WHEN** macOS上で既定のキー割り当てが生成される
- **THEN** `search` の既定は Cmd+F（Meta修飾子）となる

#### Scenario: iPadでの修飾子既定
- **WHEN** iOS上で既定のキー割り当てが生成される
- **THEN** `search` の既定は Cmd+F（Meta修飾子）となり、外付けキーボードを接続した iPad で macOS と同じ操作が通る

#### Scenario: Windowsでの修飾子既定
- **WHEN** Windows上で既定のキー割り当てが生成される
- **THEN** `search` の既定は Ctrl+F（Control修飾子）となる

#### Scenario: TTSトグルの既定キー
- **WHEN** 既定のキー割り当てが生成される
- **THEN** `ttsToggle` には Ctrl+T（Apple プラットフォームでは Cmd+T）が割り当てられる
