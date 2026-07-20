import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/tts/domain/tts_failure_message.dart';

void main() {
  group('formatTtsFailureMessage', () {
    test('appends the native cause to the localized headline', () {
      expect(
        formatTtsFailureMessage(
          '合成に失敗しました',
          'unsupported WAV encoding (need PCM16, PCM24, or float32)',
        ),
        '合成に失敗しました: unsupported WAV encoding '
        '(need PCM16, PCM24, or float32)',
      );
    });

    test('returns the headline alone when there is no cause', () {
      expect(formatTtsFailureMessage('Synthesis failed', null),
          'Synthesis failed');
    });

    test('treats a blank cause as no cause', () {
      expect(formatTtsFailureMessage('Synthesis failed', '   '),
          'Synthesis failed');
    });

    test('trims surrounding whitespace from the cause', () {
      expect(
        formatTtsFailureMessage('合成失败', '  could not open audio input  '),
        '合成失败: could not open audio input',
      );
    });
  });
}
