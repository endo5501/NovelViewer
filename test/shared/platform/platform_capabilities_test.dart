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

    test('iOS supports LLM summary but neither speech nor self-update', () {
      const capabilities = PlatformCapabilities.forPlatform(isIOS: true);

      expect(capabilities.llmSummary, isTrue);
      expect(capabilities.textToSpeech, isFalse);
      expect(capabilities.appUpdate, isFalse);
    });

    test('LLM summary does not depend on the platform flag', () {
      // The work is done by a server the reader runs themselves, reached over
      // plain HTTP through a client that opens its own sockets. Nothing in
      // that path differs by platform, so the flag must not reach this
      // feature: deriving it from a shared `!isIOS` would tie it to the two
      // features that do differ.
      const asIOS = PlatformCapabilities.forPlatform(isIOS: true);
      const asDesktop = PlatformCapabilities.forPlatform(isIOS: false);

      expect(asIOS.llmSummary, isTrue);
      expect(asDesktop.llmSummary, isTrue);
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
