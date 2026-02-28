## ADDED Requirements

### Requirement: Theme-aware search highlight colors
検索ハイライトの背景色とテキスト色は、現在のテーマモード（ライト/ダーク）に応じて切り替えなければならない（SHALL）。ライトモードでは黄色背景を使用し、ダークモードでは暗めのアンバー背景と黒テキストを使用して視認性を確保する。この配色は縦書きプレーンテキスト、縦書きルビテキスト、横書きテキストの3つの表示モードすべてに統一的に適用されなければならない（SHALL）。

#### Scenario: Light mode search highlight
- **WHEN** ライトモードでテキスト内を検索し、マッチする文字列が存在する
- **THEN** マッチ箇所は黄色（`Colors.yellow`）背景でハイライトされ、テキスト色は変更されない

#### Scenario: Dark mode search highlight
- **WHEN** ダークモードでテキスト内を検索し、マッチする文字列が存在する
- **THEN** マッチ箇所は暗めのアンバー（`Colors.amber.shade700`）背景でハイライトされ、テキスト色は黒に設定される

#### Scenario: Vertical plain text highlight in dark mode
- **WHEN** ダークモードで縦書きプレーンテキスト表示中に検索ハイライトが適用される
- **THEN** ハイライト色はダークモード用の配色（アンバー背景・黒テキスト）で表示される

#### Scenario: Vertical ruby text highlight in dark mode
- **WHEN** ダークモードで縦書きルビテキスト表示中に検索ハイライトが適用される
- **THEN** ハイライト色はダークモード用の配色（アンバー背景・黒テキスト）で表示される

#### Scenario: Horizontal text highlight in dark mode
- **WHEN** ダークモードで横書きテキスト表示中に検索ハイライトが適用される
- **THEN** ハイライト色はダークモード用の配色（アンバー背景・黒テキスト）で表示される
