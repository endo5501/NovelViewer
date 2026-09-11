import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';
import 'package:novel_viewer/l10n/app_localizations_en.dart';
import 'package:novel_viewer/l10n/app_localizations_ja.dart';
import 'package:novel_viewer/l10n/app_localizations_zh.dart';

/// A download request shared from outside the app can be turned down, and the
/// reason has to be readable in every locale: the reader is looking at a
/// modal dialog they cannot see past, with no other place for the app to say
/// what happened to the URL they just sent.
void main() {
  final locales = <String, AppLocalizations>{
    'ja': AppLocalizationsJa(),
    'en': AppLocalizationsEn(),
    'zh': AppLocalizationsZh(),
  };

  locales.forEach((tag, l10n) {
    group(tag, () {
      test('the ignored-request notice is translated', () {
        expect(l10n.download_incomingRequestIgnored, isNotEmpty);
      });
    });
  });
}
