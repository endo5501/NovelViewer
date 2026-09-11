import 'package:flutter_test/flutter_test.dart';
import 'package:foundation_models_llm/foundation_models_llm.dart';
import 'package:novel_viewer/features/llm_summary/data/foundation_models_client.dart';
import 'package:novel_viewer/features/llm_summary/data/llm_response_schema.dart';
import 'package:novel_viewer/features/llm_summary/domain/llm_analysis_failure.dart';

/// Stands in for the plugin so the client is exercised without a native side.
class _FakePlugin implements FoundationModelsLlm {
  _FakePlugin({this.answer = '', this.failure});

  final String answer;
  final OnDeviceGenerationException? failure;

  final List<({String prompt, String? field, int? maxTokens})> calls = [];
  OnDeviceModelAvailability availabilityAnswer =
      OnDeviceModelAvailability.available;

  @override
  Future<OnDeviceModelAvailability> availability() async => availabilityAnswer;

  @override
  Future<String> generate({
    required String prompt,
    String? schemaFieldName,
    int? maxResponseTokens,
  }) async {
    calls.add((
      prompt: prompt,
      field: schemaFieldName,
      maxTokens: maxResponseTokens,
    ));
    if (failure != null) throw failure!;
    return answer;
  }
}

void main() {
  group('FoundationModelsClient', () {
    test('passes the prompt through untouched', () async {
      final plugin = _FakePlugin(answer: '{"facts": "- one"}');

      await FoundationModelsClient(plugin: plugin).generate('解析して');

      expect(plugin.calls.single.prompt, '解析して');
    });

    test('names the schema field the caller asked for', () async {
      final plugin = _FakePlugin(answer: '{"facts": "- one"}');

      await FoundationModelsClient(plugin: plugin).generate(
        'p',
        schema: const LlmResponseSchema.singleStringField('facts'),
      );

      expect(plugin.calls.single.field, 'facts');
    });

    test('names no field when the caller supplied no schema', () async {
      final plugin = _FakePlugin(answer: 'free text');

      await FoundationModelsClient(plugin: plugin).generate('p');

      expect(plugin.calls.single.field, isNull);
    });

    test('bounds the response so the prompt has a predictable share', () async {
      final plugin = _FakePlugin(answer: 'x');

      await FoundationModelsClient(plugin: plugin).generate('p');

      expect(plugin.calls.single.maxTokens, isNotNull);
      expect(plugin.calls.single.maxTokens, greaterThan(0));
    });

    test('returns the generated text unchanged', () async {
      final plugin = _FakePlugin(answer: '{"facts": "- アリスは騎士"}');

      expect(
        await FoundationModelsClient(plugin: plugin).generate('p'),
        '{"facts": "- アリスは騎士"}',
      );
    });

    test(
      'declares a context budget smaller than a server client would',
      () async {
        expect(
          FoundationModelsClient(plugin: _FakePlugin()).maxChunkSize,
          lessThan(4000),
        );
      },
    );

    test(
      'reports a guardrail refusal as a refusal, not as unreachable',
      () async {
        final plugin = _FakePlugin(
          failure: const OnDeviceGenerationException(
            OnDeviceGenerationFailure.guardrailViolation,
          ),
        );

        await expectLater(
          FoundationModelsClient(plugin: plugin).generate('p'),
          throwsA(isA<LlmOnDeviceRefusedFailure>()),
        );
      },
    );

    test('reports the model being out of reach as its own failure', () async {
      final plugin = _FakePlugin(
        failure: const OnDeviceGenerationException(
          OnDeviceGenerationFailure.modelUnavailable,
        ),
      );

      await expectLater(
        FoundationModelsClient(plugin: plugin).generate('p'),
        throwsA(isA<LlmOnDeviceUnavailableFailure>()),
      );
    });

    test('carries every other cause through as a named failure', () async {
      for (final cause in [
        OnDeviceGenerationFailure.contextWindowExceeded,
        OnDeviceGenerationFailure.rateLimited,
        OnDeviceGenerationFailure.unsupportedLanguage,
        OnDeviceGenerationFailure.assetsUnavailable,
        OnDeviceGenerationFailure.unknown,
      ]) {
        final plugin = _FakePlugin(failure: OnDeviceGenerationException(cause));

        await expectLater(
          FoundationModelsClient(plugin: plugin).generate('p'),
          throwsA(
            isA<LlmOnDeviceGenerationFailure>().having(
              (e) => e.cause,
              'cause',
              cause,
            ),
          ),
          reason: '$cause',
        );
      }
    });

    test(
      'releasing resources completes and leaves the client usable',
      () async {
        final plugin = _FakePlugin(answer: 'x');
        final client = FoundationModelsClient(plugin: plugin);

        await expectLater(client.releaseResources(), completes);
        await expectLater(client.generate('p'), completes);
      },
    );
  });
}
