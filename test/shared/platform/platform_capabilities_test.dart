import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/shared/platform/platform_capabilities.dart';

void main() {
  group('PlatformCapabilities.forPlatform', () {
    test('a desktop platform supports every optional feature', () {
      const capabilities = PlatformCapabilities.forPlatform(
        isIOS: false,
        isMacOS: false,
      );

      expect(capabilities.textToSpeech, isTrue);
      expect(capabilities.appUpdate, isTrue);
      expect(capabilities.llmSummary, isTrue);
    });

    test('iOS supports LLM summary but neither speech nor self-update', () {
      const capabilities = PlatformCapabilities.forPlatform(
        isIOS: true,
        isMacOS: false,
      );

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
      const asIOS = PlatformCapabilities.forPlatform(
        isIOS: true,
        isMacOS: false,
      );
      const asDesktop = PlatformCapabilities.forPlatform(
        isIOS: false,
        isMacOS: false,
      );

      expect(asIOS.llmSummary, isTrue);
      expect(asDesktop.llmSummary, isTrue);
    });

    test('the on-device LLM is supported on Apple platforms only', () {
      const asIOS = PlatformCapabilities.forPlatform(
        isIOS: true,
        isMacOS: false,
      );
      const asMacOS = PlatformCapabilities.forPlatform(
        isIOS: false,
        isMacOS: true,
      );

      expect(asIOS.onDeviceLlm, isTrue);
      expect(asMacOS.onDeviceLlm, isTrue);
    });

    test('the on-device LLM is unsupported off Apple platforms', () {
      const elsewhere = PlatformCapabilities.forPlatform(
        isIOS: false,
        isMacOS: false,
      );

      expect(elsewhere.onDeviceLlm, isFalse);
    });

    test('naming the on-device LLM does not move the other features', () {
      // macOS is a desktop platform and keeps every answer it had before this
      // feature existed; only the new one distinguishes it from Windows.
      const asMacOS = PlatformCapabilities.forPlatform(
        isIOS: false,
        isMacOS: true,
      );
      const asWindows = PlatformCapabilities.forPlatform(
        isIOS: false,
        isMacOS: false,
      );

      expect(asMacOS.textToSpeech, asWindows.textToSpeech);
      expect(asMacOS.appUpdate, asWindows.appUpdate);
      expect(asMacOS.llmSummary, asWindows.llmSummary);
      expect(asMacOS.onDeviceLlm, isNot(asWindows.onDeviceLlm));
    });

    test('is evaluated from the flag alone, not from the host platform', () {
      // The test process runs on a desktop platform; passing isIOS: true still
      // yields the iOS capability set, which is what makes the model testable.
      const asIOS = PlatformCapabilities.forPlatform(
        isIOS: true,
        isMacOS: false,
      );
      const asDesktop = PlatformCapabilities.forPlatform(
        isIOS: false,
        isMacOS: false,
      );

      expect(asIOS.textToSpeech, isNot(asDesktop.textToSpeech));
    });
  });

  test('capabilities can be constructed feature by feature', () {
    const capabilities = PlatformCapabilities(
      textToSpeech: true,
      appUpdate: false,
      llmSummary: true,
      onDeviceLlm: false,
    );

    expect(capabilities.textToSpeech, isTrue);
    expect(capabilities.appUpdate, isFalse);
    expect(capabilities.llmSummary, isTrue);
  });
}
