import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundation_models_llm/foundation_models_llm.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const channel = MethodChannel(FoundationModelsLlm.channelName);

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

  group('generation over the method channel', () {
    test('sends the prompt and the field the caller named', () async {
      final calls = stub('{"facts": "- one"}');

      await MethodChannelFoundationModelsLlm().generate(
        prompt: 'tell me about アリス',
        schemaFieldName: 'facts',
        maxResponseTokens: 700,
      );

      expect(calls.single.method, 'generate');
      final args = calls.single.arguments as Map;
      expect(args['prompt'], 'tell me about アリス');
      expect(args['schemaFieldName'], 'facts');
      expect(args['maxResponseTokens'], 700);
    });

    test('names a different field for a different stage', () async {
      final calls = stub('{"summary": "..."}');

      await MethodChannelFoundationModelsLlm().generate(
        prompt: 'summarise',
        schemaFieldName: 'summary',
      );

      expect((calls.single.arguments as Map)['schemaFieldName'], 'summary');
    });

    test('sends no field name when the caller asked for no schema', () async {
      final calls = stub('free text');

      final answer = await MethodChannelFoundationModelsLlm().generate(
        prompt: 'anything',
      );

      expect((calls.single.arguments as Map)['schemaFieldName'], isNull);
      expect(answer, 'free text');
    });

    test('returns what the native side generated, unchanged', () async {
      stub('{"facts": "- アリスは騎士である"}');

      expect(
        await MethodChannelFoundationModelsLlm().generate(
          prompt: 'p',
          schemaFieldName: 'facts',
        ),
        '{"facts": "- アリスは騎士である"}',
      );
    });
  });

  group('generation failures', () {
    Future<OnDeviceGenerationFailure> reasonFor(Object thrown) async {
      stub(thrown);
      try {
        await MethodChannelFoundationModelsLlm().generate(prompt: 'p');
        fail('expected a failure');
      } on OnDeviceGenerationException catch (e) {
        return e.reason;
      }
    }

    test('names a guardrail refusal as its own reason', () async {
      expect(
        await reasonFor(PlatformException(code: 'guardrailViolation')),
        OnDeviceGenerationFailure.guardrailViolation,
      );
    });

    test('names a context overflow as its own reason', () async {
      expect(
        await reasonFor(PlatformException(code: 'exceededContextWindowSize')),
        OnDeviceGenerationFailure.contextWindowExceeded,
      );
    });

    test('names rate limiting as its own reason', () async {
      expect(
        await reasonFor(PlatformException(code: 'rateLimited')),
        OnDeviceGenerationFailure.rateLimited,
      );
    });

    test('names an unsupported language as its own reason', () async {
      expect(
        await reasonFor(PlatformException(code: 'unsupportedLanguageOrLocale')),
        OnDeviceGenerationFailure.unsupportedLanguage,
      );
    });

    test('names missing assets as its own reason', () async {
      expect(
        await reasonFor(PlatformException(code: 'assetsUnavailable')),
        OnDeviceGenerationFailure.assetsUnavailable,
      );
    });

    test(
      'keeps a refusal distinct from a failure to reach the model',
      () async {
        final refusal = await reasonFor(
          PlatformException(code: 'guardrailViolation'),
        );
        final unreachable = await reasonFor(
          PlatformException(code: 'modelUnavailable'),
        );

        expect(refusal, isNot(unreachable));
        expect(unreachable, OnDeviceGenerationFailure.modelUnavailable);
      },
    );

    test('reads the model refusing as a refusal too', () async {
      // The framework reports a guardrail block and the model's own refusal
      // as different cases. They mean the same thing to a reader: the text
      // was refused.
      expect(
        await reasonFor(PlatformException(code: 'refusal')),
        OnDeviceGenerationFailure.guardrailViolation,
      );
    });

    test('names a response that would not parse as its own reason', () async {
      // Seen in practice when the response cap cuts a structured answer off
      // mid-object. Reading it as "unknown" would hide a cause that has a
      // clear remedy.
      expect(
        await reasonFor(PlatformException(code: 'decodingFailure')),
        OnDeviceGenerationFailure.decodingFailure,
      );
    });

    test('reads a concurrent-request rejection as transient', () async {
      // It passes on its own, like rate limiting, and reading it as unknown
      // would make a momentary clash look like a permanent fault.
      expect(
        await reasonFor(PlatformException(code: 'concurrentRequests')),
        OnDeviceGenerationFailure.rateLimited,
      );
    });

    test('names an error code it does not know as unknown', () async {
      expect(
        await reasonFor(PlatformException(code: 'somethingNewInAFutureOs')),
        OnDeviceGenerationFailure.unknown,
      );
    });

    test(
      'names an unregistered plugin as the model being unavailable',
      () async {
        expect(
          await reasonFor(MissingPluginException()),
          OnDeviceGenerationFailure.modelUnavailable,
        );
      },
    );

    test('carries the native message so a log can say what happened', () async {
      stub(
        PlatformException(code: 'guardrailViolation', message: 'refused here'),
      );

      expect(
        () => MethodChannelFoundationModelsLlm().generate(prompt: 'p'),
        throwsA(
          isA<OnDeviceGenerationException>().having(
            (e) => e.toString(),
            'toString',
            contains('refused here'),
          ),
        ),
      );
    });

    test(
      'treats a missing answer as a failure rather than empty text',
      () async {
        stub(null);

        expect(
          () => MethodChannelFoundationModelsLlm().generate(prompt: 'p'),
          throwsA(isA<OnDeviceGenerationException>()),
        );
      },
    );
  });
}
