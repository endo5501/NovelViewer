import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/shared/platform/platform_capabilities.dart';

void main() {
  group('PlatformCapabilities.forPlatform', () {
    test('a desktop platform supports every optional feature', () {
      const capabilities = PlatformCapabilities.forPlatform(isIOS: false);

      expect(capabilities.textToSpeech, isTrue);
      expect(capabilities.appUpdate, isTrue);
      expect(capabilities.llmSummary, isTrue);
    });

    test('iOS supports none of the optional features', () {
      const capabilities = PlatformCapabilities.forPlatform(isIOS: true);

      expect(capabilities.textToSpeech, isFalse);
      expect(capabilities.appUpdate, isFalse);
      expect(capabilities.llmSummary, isFalse);
    });

    test('is evaluated from the flag alone, not from the host platform', () {
      // The test process runs on a desktop platform; passing isIOS: true still
      // yields the iOS capability set, which is what makes the model testable.
      const asIOS = PlatformCapabilities.forPlatform(isIOS: true);
      const asDesktop = PlatformCapabilities.forPlatform(isIOS: false);

      expect(asIOS.textToSpeech, isNot(asDesktop.textToSpeech));
    });
  });

  test('capabilities can be constructed feature by feature', () {
    const capabilities = PlatformCapabilities(
      textToSpeech: true,
      appUpdate: false,
      llmSummary: true,
    );

    expect(capabilities.textToSpeech, isTrue);
    expect(capabilities.appUpdate, isFalse);
    expect(capabilities.llmSummary, isTrue);
  });
}
