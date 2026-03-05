import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/tts/data/tts_language.dart';

void main() {
  group('TtsLanguage', () {
    test('contains exactly 10 languages', () {
      expect(TtsLanguage.values, hasLength(10));
    });

    test('each language has correct languageId', () {
      expect(TtsLanguage.en.languageId, 2050);
      expect(TtsLanguage.ru.languageId, 2069);
      expect(TtsLanguage.zh.languageId, 2055);
      expect(TtsLanguage.ja.languageId, 2058);
      expect(TtsLanguage.ko.languageId, 2064);
      expect(TtsLanguage.de.languageId, 2053);
      expect(TtsLanguage.fr.languageId, 2061);
      expect(TtsLanguage.es.languageId, 2054);
      expect(TtsLanguage.it.languageId, 2070);
      expect(TtsLanguage.pt.languageId, 2071);
    });

    test('each language has a displayName', () {
      expect(TtsLanguage.ja.displayName, '日本語');
      expect(TtsLanguage.en.displayName, 'English');
      expect(TtsLanguage.zh.displayName, '中文');
      expect(TtsLanguage.ko.displayName, '한국어');
      expect(TtsLanguage.de.displayName, 'Deutsch');
      expect(TtsLanguage.fr.displayName, 'Français');
      expect(TtsLanguage.es.displayName, 'Español');
      expect(TtsLanguage.it.displayName, 'Italiano');
      expect(TtsLanguage.pt.displayName, 'Português');
      expect(TtsLanguage.ru.displayName, 'Русский');
    });
  });
}
