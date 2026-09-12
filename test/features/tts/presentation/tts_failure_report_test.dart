import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/tts/data/tts_engine_type.dart';
import 'package:novel_viewer/features/tts/presentation/tts_failure_report.dart';
import 'package:novel_viewer/shared/failure/failure_report.dart';

void main() {
  FailureReport build({
    String headline = '音声の生成に失敗しました',
    String? reason = 'unsupported WAV encoding',
    TtsEngineType engine = TtsEngineType.piper,
    String modelDir = '/Users/someone/Library/tts/ja_JP-test-medium.onnx',
    String appVersion = '1.8.2+41',
    String? fileName = '040_chapter.txt',
    int? segmentIndex,
  }) {
    return buildTtsFailureReport(
      headline: headline,
      reason: reason,
      engine: engine,
      modelDir: modelDir,
      appVersion: appVersion,
      fileName: fileName,
      segmentIndex: segmentIndex,
    );
  }

  group('buildTtsFailureReport', () {
    test('keeps the headline localized and the engine reason raw', () {
      final report = build();

      expect(report.headline, '音声の生成に失敗しました');
      expect(report.cause, 'unsupported WAV encoding');
    });

    test('carries no cause when the engine gave no reason', () {
      expect(build(reason: null).cause, isNull);
    });

    test('names the run: time, version, engine, model and file', () {
      final text = renderFailureReport(build());

      expect(text, contains('time: '));
      expect(text, contains('app version: 1.8.2+41'));
      expect(text, contains('engine: piper'));
      expect(text, contains('model: ja_JP-test-medium.onnx'));
      expect(text, contains('file: 040_chapter.txt'));
    });

    test('reduces the model to its name, not its path', () {
      final text = renderFailureReport(build());

      expect(text, isNot(contains('/Users/someone')));
    });

    test('records the segment index only when a segment failed', () {
      expect(
        renderFailureReport(build(segmentIndex: 7)),
        contains('segment: 7'),
      );
      expect(renderFailureReport(build()), isNot(contains('segment:')));
    });

    test('never carries a stack trace', () {
      // Synthesis failures arrive as an outcome, not a throw, so there is no
      // catch site to capture one.
      expect(build(segmentIndex: 7).stackTrace, isNull);
      expect(renderFailureReport(build()), isNot(contains('#0')));
    });
  });
}
