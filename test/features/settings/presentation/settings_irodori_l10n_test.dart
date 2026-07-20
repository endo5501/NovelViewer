import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';

/// Verifies that the Irodori-section labels resolve to non-empty strings
/// for every supported locale (settings-dialog-composition delta,
/// "3言語すべてに翻訳が存在" scenario).
void main() {
  Future<AppLocalizations> loadFor(Locale locale) async {
    return AppLocalizations.delegate.load(locale);
  }

  for (final locale in const [Locale('ja'), Locale('en'), Locale('zh')]) {
    group(
        'Irodori labels resolve via AppLocalizations [${locale.languageCode}]',
        () {
      late AppLocalizations l10n;

      setUp(() async {
        l10n = await loadFor(locale);
      });

      test('settings_irodoriDownloaded is non-empty', () {
        expect(l10n.settings_irodoriDownloaded, isNotEmpty);
      });
      test('settings_irodoriSpeakerGuidanceScale is non-empty', () {
        expect(l10n.settings_irodoriSpeakerGuidanceScale, isNotEmpty);
      });
      test('settings_irodoriCaptionGuidanceScale is non-empty', () {
        expect(l10n.settings_irodoriCaptionGuidanceScale, isNotEmpty);
      });
      test('settings_irodoriNumInferenceSteps is non-empty', () {
        expect(l10n.settings_irodoriNumInferenceSteps, isNotEmpty);
      });
    });
  }
}
