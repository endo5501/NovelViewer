import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/shared/utils/cancellation_token.dart';

void main() {
  group('CancellationToken', () {
    test('starts uncancelled and throwIfCancelled does not throw', () {
      final token = CancellationToken();
      expect(token.isCancelled, isFalse);
      expect(token.throwIfCancelled, returnsNormally);
    });

    test('cancel() flips isCancelled and throwIfCancelled throws', () {
      final token = CancellationToken();
      token.cancel();
      expect(token.isCancelled, isTrue);
      expect(token.throwIfCancelled, throwsA(isA<CancelledException>()));
    });

    test('cancel() is idempotent', () {
      final token = CancellationToken();
      token.cancel();
      token.cancel();
      expect(token.isCancelled, isTrue);
    });

    test('onCancel callback runs when cancelled', () {
      final token = CancellationToken();
      var called = 0;
      token.onCancel(() => called++);
      token.cancel();
      expect(called, 1);
    });

    test('onCancel callback runs immediately if already cancelled', () {
      final token = CancellationToken();
      token.cancel();
      var called = 0;
      token.onCancel(() => called++);
      expect(called, 1);
    });
  });
}
