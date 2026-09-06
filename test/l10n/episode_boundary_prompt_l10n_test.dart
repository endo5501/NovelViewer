import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';
import 'package:novel_viewer/l10n/app_localizations_en.dart';
import 'package:novel_viewer/l10n/app_localizations_ja.dart';
import 'package:novel_viewer/l10n/app_localizations_zh.dart';

/// The boundary hint is shown by both the vertical and the horizontal viewer,
/// and will later be reached by touch as well, so the strings must exist in
/// every locale and must not name an input device ("press", "按").
void main() {
  final locales = <String, AppLocalizations>{
    'ja': AppLocalizationsJa(),
    'en': AppLocalizationsEn(),
    'zh': AppLocalizationsZh(),
  };

  locales.forEach((tag, l10n) {
    group(tag, () {
      test('the next-episode hint embeds the file name', () {
        expect(l10n.episodeBoundary_nextPrompt('003.txt'), contains('003.txt'));
      });

      test('the previous-episode hint embeds the file name', () {
        expect(l10n.episodeBoundary_prevPrompt('001.txt'), contains('001.txt'));
      });

      test('neither hint names an input device', () {
        for (final text in [
          l10n.episodeBoundary_nextPrompt('003.txt'),
          l10n.episodeBoundary_prevPrompt('001.txt'),
        ]) {
          expect(text.toLowerCase(), isNot(contains('press')));
          expect(text, isNot(contains('按')));
        }
      });
    });
  });
}
