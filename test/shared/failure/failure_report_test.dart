import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/shared/failure/failure_report.dart';

void main() {
  group('FailureReport', () {
    test('preserves the order diagnostics were inserted in', () {
      const report = FailureReport(
        headline: 'failed',
        diagnostics: {
          'time': '2026-09-12T10:23:45.123Z',
          'app version': '1.8.2+41',
          'provider': 'ollama',
          'model': 'qwen3:8b',
        },
      );

      expect(report.diagnostics.keys, [
        'time',
        'app version',
        'provider',
        'model',
      ]);
    });

    test('accepts a report carrying neither a cause nor a stack trace', () {
      const report = FailureReport(
        headline: 'failed',
        diagnostics: {'time': '2026-09-12T10:23:45.123Z'},
      );

      expect(report.cause, isNull);
      expect(report.stackTrace, isNull);
    });
  });

  group('renderFailureReport', () {
    test('renders diagnostics, then the cause, then the stack trace', () {
      final report = FailureReport(
        headline: 'failed',
        cause: 'LlmAnalysisPartialFailure: 3 file(s) failed extraction',
        stackTrace: StackTrace.fromString('#0      first\n#1      second'),
        diagnostics: const {
          'time': '2026-09-12T10:23:45.123Z',
          'app version': '1.8.2+41',
          'provider': 'ollama',
          'model': 'qwen3:8b',
          'word': 'アリス',
          'scope': 'upToAll',
          'file': '040_chapter.txt',
        },
      );

      expect(renderFailureReport(report), '''
time: 2026-09-12T10:23:45.123Z
app version: 1.8.2+41
provider: ollama
model: qwen3:8b
word: アリス
scope: upToAll
file: 040_chapter.txt

LlmAnalysisPartialFailure: 3 file(s) failed extraction

#0      first
#1      second''');
    });

    test('omits the cause and stack-trace sections when absent', () {
      const report = FailureReport(
        headline: 'failed',
        diagnostics: {'time': '2026-09-12T10:23:45.123Z', 'engine': 'piper'},
      );

      expect(renderFailureReport(report), '''
time: 2026-09-12T10:23:45.123Z
engine: piper''');
    });

    test('drops diagnostics whose value is null or empty', () {
      const report = FailureReport(
        headline: 'failed',
        diagnostics: {
          'time': '2026-09-12T10:23:45.123Z',
          'file': '',
          'word': null,
          'provider': 'appleOnDevice',
        },
      );

      final text = renderFailureReport(report);

      expect(text, isNot(contains('file:')));
      expect(text, isNot(contains('word:')));
      expect(text, '''
time: 2026-09-12T10:23:45.123Z
provider: appleOnDevice''');
    });

    test('redacts the endpoint out of the cause', () {
      const report = FailureReport(
        headline: 'failed',
        cause:
            'ClientException: Connection refused, '
            'uri=http://192.168.1.20:11434/api/generate',
        diagnostics: {'provider': 'ollama'},
      );

      final text = renderFailureReport(report);

      expect(text, isNot(contains('192.168.1.20')));
      expect(text, contains('<endpoint>'));
    });

    test('redacts absolute paths out of the stack trace', () {
      final report = FailureReport(
        headline: 'failed',
        stackTrace: StackTrace.fromString(
          '#0      main (file:///Users/someone/app/lib/main.dart:12:3)',
        ),
        diagnostics: const {'provider': 'ollama'},
      );

      expect(renderFailureReport(report), isNot(contains('/Users/someone')));
    });

    test('does not wrap the output in a code fence', () {
      final report = FailureReport(
        headline: 'failed',
        cause: 'boom',
        stackTrace: StackTrace.fromString('#0      first'),
        diagnostics: const {'time': '2026-09-12T10:23:45.123Z'},
      );

      expect(renderFailureReport(report), isNot(contains('```')));
    });
  });
}
