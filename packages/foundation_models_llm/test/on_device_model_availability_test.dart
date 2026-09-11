import 'package:flutter_test/flutter_test.dart';
import 'package:foundation_models_llm/foundation_models_llm.dart';

void main() {
  group('OnDeviceModelAvailability', () {
    test('available is the only value that reports itself available', () {
      expect(OnDeviceModelAvailability.available.isAvailable, isTrue);
      for (final other in OnDeviceModelAvailability.values.where(
        (v) => v != OnDeviceModelAvailability.available,
      )) {
        expect(other.isAvailable, isFalse, reason: '$other');
      }
    });

    test('reads each name the native side can report', () {
      expect(
        OnDeviceModelAvailability.fromWireName('available'),
        OnDeviceModelAvailability.available,
      );
      expect(
        OnDeviceModelAvailability.fromWireName('deviceNotEligible'),
        OnDeviceModelAvailability.deviceNotEligible,
      );
      expect(
        OnDeviceModelAvailability.fromWireName('intelligenceNotEnabled'),
        OnDeviceModelAvailability.intelligenceNotEnabled,
      );
      expect(
        OnDeviceModelAvailability.fromWireName('modelNotReady'),
        OnDeviceModelAvailability.modelNotReady,
      );
      expect(
        OnDeviceModelAvailability.fromWireName('unsupportedPlatform'),
        OnDeviceModelAvailability.unsupportedPlatform,
      );
    });

    test('keeps the three reasons distinct from one another', () {
      const reasons = {
        OnDeviceModelAvailability.deviceNotEligible,
        OnDeviceModelAvailability.intelligenceNotEnabled,
        OnDeviceModelAvailability.modelNotReady,
      };
      expect(reasons.length, 3);
    });

    test('reads a name it does not know as unknown', () {
      expect(
        OnDeviceModelAvailability.fromWireName('somethingNewInAFutureOs'),
        OnDeviceModelAvailability.unknown,
      );
    });

    test('reads a missing name as unknown', () {
      expect(
        OnDeviceModelAvailability.fromWireName(null),
        OnDeviceModelAvailability.unknown,
      );
    });
  });
}
