## Context

現在のアプリアイコンはFlutterのデフォルトアイコンが使われている。macOSでは `Assets.xcassets/AppIcon.appiconset/` に7サイズのPNG、Windowsでは `windows/runner/resources/app_icon.ico` がある。カスタムアイコン画像（1024x1024px）は `assets/app_icon.png` に配置済み。

## Goals / Non-Goals

**Goals:**
- `flutter_launcher_icons` を使って元画像から各プラットフォーム向けアイコンを自動生成
- macOS / Windows 両方のアイコンを差し替え

**Non-Goals:**
- アイコンデザイン自体の作成（既に完了）
- Linux / iOS / Android 向けアイコン対応

## Decisions

### flutter_launcher_icons パッケージの採用

**選択**: `flutter_launcher_icons` を使用して各サイズを自動生成
**理由**: 手動で各サイズにリサイズして配置するよりも再現性が高く、将来のアイコン変更も元画像の差し替えだけで済む
**代替案**: 手動リサイズ — シンプルだが、サイズごとの管理が煩雑で人的ミスが起きやすい

### 元画像の配置場所

**選択**: `assets/app_icon.png`
**理由**: Flutter プロジェクトの慣習に従い、アセットは `assets/` ディレクトリに配置する

## Risks / Trade-offs

- `flutter_launcher_icons` が macOS / Windows の特定バージョンで正しく動作しない可能性 → 生成後に実際のアイコンを目視確認する
- 16px など極小サイズでアイコンのディテールが潰れる可能性 → 生成後に各サイズを確認し、必要なら小サイズ用の簡略化画像を別途用意
