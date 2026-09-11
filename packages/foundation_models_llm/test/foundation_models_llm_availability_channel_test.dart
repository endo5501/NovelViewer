import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundation_models_llm/foundation_models_llm.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const channel = MethodChannel(FoundationModelsLlm.channelName);

  /// Answers `availability` with [answer], or throws it when it is an
  /// exception, and records the invocations for the caller to assert on.
  List<MethodCall> stub(Object? answer) {
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (answer is Exception) throw answer;
      return answer;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    return calls;
  }

  group('availability over the method channel', () {
    test('asks the native side and reads its answer', () async {
      final calls = stub('available');

      final result = await MethodChannelFoundationModelsLlm().availability();

      expect(result, OnDeviceModelAvailability.available);
      expect(calls.single.method, 'availability');
    });

    test('carries each reason through unchanged', () async {
      for (final reason in [
        OnDeviceModelAvailability.deviceNotEligible,
        OnDeviceModelAvailability.intelligenceNotEnabled,
        OnDeviceModelAvailability.modelNotReady,
      ]) {
        stub(reason.name);
        expect(await MethodChannelFoundationModelsLlm().availability(), reason);
      }
    });

    test('reads an answer it does not recognise as unknown', () async {
      stub('somethingNewInAFutureOs');

      expect(
        await MethodChannelFoundationModelsLlm().availability(),
        OnDeviceModelAvailability.unknown,
      );
    });

    test('reads no answer at all as unknown', () async {
      stub(null);

      expect(
        await MethodChannelFoundationModelsLlm().availability(),
        OnDeviceModelAvailability.unknown,
      );
    });

    test('reads an answer of the wrong type as unknown', () async {
      stub(42);

      expect(
        await MethodChannelFoundationModelsLlm().availability(),
        OnDeviceModelAvailability.unknown,
      );
    });

    test('reads a platform error as unknown rather than throwing', () async {
      stub(PlatformException(code: 'boom'));

      expect(
        await MethodChannelFoundationModelsLlm().availability(),
        OnDeviceModelAvailability.unknown,
      );
    });

    test('reads an unregistered plugin as an unsupported platform', () async {
      // No mock handler at all: the channel has no implementation, which is
      // what a build without the native side looks like.
      expect(
        await MethodChannelFoundationModelsLlm().availability(),
        OnDeviceModelAvailability.unsupportedPlatform,
      );
    });
  });
}
