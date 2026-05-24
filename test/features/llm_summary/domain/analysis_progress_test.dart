import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/llm_summary/domain/analysis_progress.dart';

void main() {
  group('AnalysisExtractingFacts', () {
    test('holds the values passed to the constructor', () {
      const event = AnalysisExtractingFacts(round: 2, current: 3, total: 7);

      expect(event.round, 2);
      expect(event.current, 3);
      expect(event.total, 7);
    });

    test('two instances with the same payload are equal', () {
      const a = AnalysisExtractingFacts(round: 1, current: 1, total: 4);
      const b = AnalysisExtractingFacts(round: 1, current: 1, total: 4);

      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('instances with different payloads are not equal', () {
      const a = AnalysisExtractingFacts(round: 1, current: 1, total: 4);
      const b = AnalysisExtractingFacts(round: 1, current: 2, total: 4);

      expect(a, isNot(equals(b)));
    });
  });

  group('AnalysisGeneratingFinalSummary', () {
    test('two instances are equal (value semantics)', () {
      const a = AnalysisGeneratingFinalSummary();
      const b = AnalysisGeneratingFinalSummary();

      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('is a subtype of AnalysisProgress', () {
      const event = AnalysisGeneratingFinalSummary();

      expect(event, isA<AnalysisProgress>());
    });
  });

  group('AnalysisExtractingFacts', () {
    test('is a subtype of AnalysisProgress', () {
      const event = AnalysisExtractingFacts(round: 1, current: 1, total: 1);

      expect(event, isA<AnalysisProgress>());
    });
  });
}
