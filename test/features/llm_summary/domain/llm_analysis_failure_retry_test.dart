import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/llm_summary/domain/llm_analysis_failure.dart';

/// Whether an identical second attempt is worth making is decided per cause.
/// The pipeline spends a full on-device generation on every retry it makes,
/// so a cause that cannot answer differently must not claim one.
void main() {
  bool retries(OnDeviceGenerationFailure cause) =>
      LlmOnDeviceGenerationFailure(cause).isWorthRetrying;

  group('isWorthRetrying', () {
    test('a timed-out request is retried', () {
      // Nothing about the request decided the timeout, so the same request
      // can finish on a second attempt.
      expect(retries(OnDeviceGenerationFailure.timeout), isTrue);
    });

    test('an unsupported request is not retried', () {
      // The model does not accept the shape of this request, and sending it
      // again unchanged asks for the same thing.
      expect(retries(OnDeviceGenerationFailure.unsupportedRequest), isFalse);
    });

    test('the existing classification is unchanged', () {
      expect(retries(OnDeviceGenerationFailure.rateLimited), isTrue);
      expect(retries(OnDeviceGenerationFailure.decodingFailure), isTrue);
      expect(retries(OnDeviceGenerationFailure.unknown), isTrue);

      expect(retries(OnDeviceGenerationFailure.guardrailViolation), isFalse);
      expect(retries(OnDeviceGenerationFailure.contextWindowExceeded), isFalse);
      expect(retries(OnDeviceGenerationFailure.unsupportedLanguage), isFalse);
      expect(retries(OnDeviceGenerationFailure.assetsUnavailable), isFalse);
      expect(retries(OnDeviceGenerationFailure.modelUnavailable), isFalse);
    });

    test('every cause is classified', () {
      // The classification is a switch over the enum. A cause added later
      // must be given an answer rather than falling through to a default.
      for (final cause in OnDeviceGenerationFailure.values) {
        expect(
          () => retries(cause),
          returnsNormally,
          reason: '${cause.name} has no retry classification',
        );
      }
    });
  });
}
