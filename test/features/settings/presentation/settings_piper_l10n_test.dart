import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';

/// Verifies that the 8 Piper-section labels resolve to non-empty strings
/// for every supported locale (Phase B, F026).
void main() {
  Future<AppLocalizations> loadFor(Locale locale) async {
    return AppLocalizations.delegate.load(locale);
  }

  for (final locale in const [Locale('ja'), Locale('en'), Locale('zh')]) {
    group('Piper labels resolve via AppLocalizations [${locale.languageCode}]',
        () {
      late AppLocalizations l10n;

      setUp(() async {
        l10n = await loadFor(locale);
      });

      test('settings_ttsEngine is non-empty', () {
        expect(l10n.settings_ttsEngine, isNotEmpty);
      });
      test('settings_modelLabel is non-empty', () {
        expect(l10n.settings_modelLabel, isNotEmpty);
      });
      test('settings_modelDataDownload is non-empty', () {
        expect(l10n.settings_modelDataDownload, isNotEmpty);
      });
      test('settings_piperDownloaded is non-empty', () {
        expect(l10n.settings_piperDownloaded, isNotEmpty);
      });
      test('settings_retryButton is non-empty', () {
        expect(l10n.settings_retryButton, isNotEmpty);
      });
      test('settings_piperLengthScale is non-empty', () {
        expect(l10n.settings_piperLengthScale, isNotEmpty);
      });
      test('settings_piperNoiseScale is non-empty', () {
        expect(l10n.settings_piperNoiseScale, isNotEmpty);
      });
      test('settings_piperNoiseW is non-empty', () {
        expect(l10n.settings_piperNoiseW, isNotEmpty);
      });
    });
  }

  test('settings_ttsEngine is localized per language', () async {
    final ja = await loadFor(const Locale('ja'));
    final en = await loadFor(const Locale('en'));
    final zh = await loadFor(const Locale('zh'));
    expect(ja.settings_ttsEngine, 'TTSエンジン');
    expect(en.settings_ttsEngine, 'TTS Engine');
    expect(zh.settings_ttsEngine, 'TTS 引擎');
  });
}
