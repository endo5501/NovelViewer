import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/shared/failure/sensitive_redaction.dart';

void main() {
  group('redactSensitive', () {
    test('replaces a whole URL, host and port included', () {
      expect(
        redactSensitive(
          'ClientException: Connection refused, '
          'uri=http://192.168.1.20:11434/api/generate',
        ),
        'ClientException: Connection refused, uri=<endpoint>',
      );
    });

    test('removes credentials carried in a URL', () {
      final text = redactSensitive(
        'failed to reach https://user:secret@example.com/v1/chat',
      );

      expect(text, isNot(contains('user')));
      expect(text, isNot(contains('secret')));
      expect(text, isNot(contains('example.com')));
    });

    test('keeps only the file name of a POSIX path', () {
      expect(
        redactSensitive(
          'could not open audio input: /Users/someone/voices/sample.wav',
        ),
        'could not open audio input: <path>/sample.wav',
      );
    });

    test('keeps only the file name of a Windows path', () {
      expect(
        redactSensitive(r'could not open C:\Users\someone\voices\sample.wav'),
        r'could not open <path>\sample.wav',
      );
    });

    test('redacts a file URI in a stack frame', () {
      final text = redactSensitive(
        '#0      main (file:///Users/someone/app/lib/main.dart:12:3)',
      );

      expect(text, isNot(contains('/Users/someone')));
      expect(text, contains('#0'));
    });

    test('redacts every occurrence, not just the first', () {
      final text = redactSensitive(
        'tried http://a.example/x then http://b.example/y',
      );

      expect(text, 'tried <endpoint> then <endpoint>');
    });

    test('leaves ordinary text untouched', () {
      const text =
          'unsupported WAV encoding (need PCM16, PCM24, or float32) 2/3';

      expect(redactSensitive(text), text);
    });

    test('leaves a bare file name untouched', () {
      expect(
        redactSensitive('could not read 040_chapter.txt'),
        'could not read 040_chapter.txt',
      );
    });
  });
}
