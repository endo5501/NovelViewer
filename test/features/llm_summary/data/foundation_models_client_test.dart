import 'package:flutter_test/flutter_test.dart';
import 'package:foundation_models_llm/foundation_models_llm.dart';
import 'package:novel_viewer/features/llm_summary/data/foundation_models_client.dart';
import 'package:novel_viewer/features/llm_summary/data/llm_response_schema.dart';
import 'package:novel_viewer/features/llm_summary/domain/llm_analysis_failure.dart';

/// Stands in for the plugin so the client is exercised without a native side.
class _FakePlugin implements FoundationModelsLlm {
  _FakePlugin({
    this.answer = '',
    this.failure,
    this.failWhenSchemaNamed = false,
    this.unconstrainedFailure,
  });

  final String answer;

  /// Mutable so a test can let a later request succeed where an earlier one
  /// was refused.
  OnDeviceGenerationException? failure;

  /// Fail only the calls that named a schema field.
  ///
  /// Mirrors what the model actually does: the same passage is refused for as
  /// long as generation is constrained, and answered once the constraint is
  /// gone.
  final bool failWhenSchemaNamed;

  /// Fail the call that named no schema field, with this instead.
  ///
  /// Lets a test give the retry a different fate from the attempt that
  /// provoked it.
  final OnDeviceGenerationException? unconstrainedFailure;

  final List<
    ({String prompt, String? field, int? maxTokens, OnDeviceSampling? sampling})
  >
  calls = [];
  OnDeviceModelAvailability availabilityAnswer =
      OnDeviceModelAvailability.available;

  @override
  Future<OnDeviceModelAvailability> availability() async => availabilityAnswer;

  @override
  Future<String> generate({
    required String prompt,
    String? schemaFieldName,
    int? maxResponseTokens,
    OnDeviceSampling? sampling,
  }) async {
    calls.add((
      prompt: prompt,
      field: schemaFieldName,
      maxTokens: maxResponseTokens,
      sampling: sampling,
    ));
    if (schemaFieldName == null && unconstrainedFailure != null) {
      throw unconstrainedFailure!;
    }
    if (failure != null && (!failWhenSchemaNamed || schemaFieldName != null)) {
      throw failure!;
    }
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

    test('leaves the response enough room to close what it started', () async {
      // A cap the answer runs into truncates the structured object, which
      // comes back as a response that will not parse. Measured on macOS: a
      // few hundred tokens was not enough for a chunk-sized extraction.
      expect(
        FoundationModelsClient.maxResponseTokens,
        greaterThanOrEqualTo(1000),
      );
    });

    test('keeps real margin under the measured context ceiling', () async {
      // Requests start failing between 5000 and 6000 characters of varied
      // Japanese prose. The chunk size stays well under that, because denser
      // text tokenizes worse than the sample did.
      expect(FoundationModelsClient.onDeviceChunkSize, lessThan(4000));
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
      'retries a refused schema-constrained request unconstrained',
      () async {
        const refusal = OnDeviceGenerationException(
          OnDeviceGenerationFailure.guardrailViolation,
        );
        final plugin = _FakePlugin(
          answer: '{"facts": "- one"}',
          failure: refusal,
          failWhenSchemaNamed: true,
        );

        final answer = await FoundationModelsClient(plugin: plugin).generate(
          '解析して',
          schema: const LlmResponseSchema.singleStringField('facts'),
        );

        expect(plugin.calls, hasLength(2));
        expect(plugin.calls.first.field, 'facts');
        expect(plugin.calls.last.field, isNull);
        expect(plugin.calls.last.prompt, '解析して');
        expect(answer, '{"facts": "- one"}');
      },
    );

    test('samples the unconstrained retry greedily', () async {
      // Without the schema the model repeats itself until the response cap
      // truncates the object, which reaches the caller as text that will not
      // parse. Measured on macOS: half the unconstrained answers were
      // unusable under the framework's default sampling, none under greedy.
      final plugin = _FakePlugin(
        answer: '{"facts": "- one"}',
        failure: const OnDeviceGenerationException(
          OnDeviceGenerationFailure.guardrailViolation,
        ),
        failWhenSchemaNamed: true,
      );

      await FoundationModelsClient(plugin: plugin).generate(
        'p',
        schema: const LlmResponseSchema.singleStringField('facts'),
      );

      expect(plugin.calls.first.sampling, isNull);
      expect(plugin.calls.last.sampling, OnDeviceSampling.greedy);
    });

    test(
      'retries when the model itself refused, not only the guardrails',
      () async {
        // The framework reports a guardrail block and the model declining as
        // separate cases, and this package reads both as the text having been
        // refused. Both qualify for the unconstrained retry: either way it is
        // the constrained path that was turned down, and the one request worth
        // making is the same prompt without it.
        //
        // The reason is built from the native code rather than named directly,
        // so this fails if that collapse is ever undone without the retry being
        // reconsidered.
        final plugin = _FakePlugin(
          answer: '{"facts": "- one"}',
          failure: OnDeviceGenerationException(
            OnDeviceGenerationFailure.fromWireCode('refusal'),
          ),
          failWhenSchemaNamed: true,
        );

        await FoundationModelsClient(plugin: plugin).generate(
          'p',
          schema: const LlmResponseSchema.singleStringField('facts'),
        );

        expect(plugin.calls, hasLength(2));
        expect(plugin.calls.last.field, isNull);
      },
    );

    test('reports what the retry failed with, not the refusal', () async {
      // The retry has its own fate. Reporting the refusal that provoked it
      // would send a reader after the text when the model was rate limited.
      final plugin = _FakePlugin(
        failure: const OnDeviceGenerationException(
          OnDeviceGenerationFailure.guardrailViolation,
        ),
        failWhenSchemaNamed: true,
        unconstrainedFailure: const OnDeviceGenerationException(
          OnDeviceGenerationFailure.rateLimited,
          detail: 'too many at once',
        ),
      );

      await expectLater(
        FoundationModelsClient(plugin: plugin).generate(
          'p',
          schema: const LlmResponseSchema.singleStringField('facts'),
        ),
        throwsA(
          isA<LlmOnDeviceGenerationFailure>()
              .having(
                (e) => e.cause,
                'cause',
                OnDeviceGenerationFailure.rateLimited,
              )
              .having((e) => e.detail, 'detail', 'too many at once'),
        ),
      );
      expect(plugin.calls, hasLength(2));
    });

    test('keeps the response cap on the retry', () async {
      // The retry runs against the same window as the attempt it replaces.
      final plugin = _FakePlugin(
        answer: '{"facts": "- one"}',
        failure: const OnDeviceGenerationException(
          OnDeviceGenerationFailure.guardrailViolation,
        ),
        failWhenSchemaNamed: true,
      );

      await FoundationModelsClient(plugin: plugin).generate(
        'p',
        schema: const LlmResponseSchema.singleStringField('facts'),
      );

      expect(
        plugin.calls.last.maxTokens,
        FoundationModelsClient.maxResponseTokens,
      );
    });

    test('a later request starts constrained again', () async {
      // The client holds no memory of having given up a schema, so one
      // refused prompt does not push the next one down the degraded path.
      final plugin = _FakePlugin(
        answer: '{"facts": "- one"}',
        failure: const OnDeviceGenerationException(
          OnDeviceGenerationFailure.guardrailViolation,
        ),
        failWhenSchemaNamed: true,
      );
      final client = FoundationModelsClient(plugin: plugin);

      await client.generate(
        'refused',
        schema: const LlmResponseSchema.singleStringField('facts'),
      );
      plugin.calls.clear();
      plugin.failure = null;
      await client.generate(
        '次の語',
        schema: const LlmResponseSchema.singleStringField('facts'),
      );

      expect(plugin.calls, hasLength(1));
      expect(plugin.calls.single.field, 'facts');
      expect(plugin.calls.single.sampling, isNull);
    });

    test('does not retry a refusal that named no schema', () async {
      // There is no constraint left to drop, so a second attempt would be the
      // identical request.
      final plugin = _FakePlugin(
        failure: const OnDeviceGenerationException(
          OnDeviceGenerationFailure.guardrailViolation,
        ),
      );

      await expectLater(
        FoundationModelsClient(plugin: plugin).generate('p'),
        throwsA(isA<LlmOnDeviceRefusedFailure>()),
      );
      expect(plugin.calls, hasLength(1));
    });

    test('reports the refusal when the retry is refused too', () async {
      final plugin = _FakePlugin(
        failure: const OnDeviceGenerationException(
          OnDeviceGenerationFailure.guardrailViolation,
        ),
      );

      await expectLater(
        FoundationModelsClient(plugin: plugin).generate(
          'p',
          schema: const LlmResponseSchema.singleStringField('facts'),
        ),
        throwsA(isA<LlmOnDeviceRefusedFailure>()),
      );
    });

    test('issues at most two requests for one prompt', () async {
      final plugin = _FakePlugin(
        failure: const OnDeviceGenerationException(
          OnDeviceGenerationFailure.guardrailViolation,
        ),
      );

      await expectLater(
        FoundationModelsClient(plugin: plugin).generate(
          'p',
          schema: const LlmResponseSchema.singleStringField('facts'),
        ),
        throwsA(isA<LlmOnDeviceRefusedFailure>()),
      );
      expect(plugin.calls, hasLength(2));
    });

    test('does not retry a failure that is not a refusal', () async {
      // Dropping the schema does not shorten the prompt, so a context
      // overflow overflows again.
      final plugin = _FakePlugin(
        failure: const OnDeviceGenerationException(
          OnDeviceGenerationFailure.contextWindowExceeded,
        ),
      );

      await expectLater(
        FoundationModelsClient(plugin: plugin).generate(
          'p',
          schema: const LlmResponseSchema.singleStringField('facts'),
        ),
        throwsA(isA<LlmOnDeviceGenerationFailure>()),
      );
      expect(plugin.calls, hasLength(1));
    });

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
        OnDeviceGenerationFailure.decodingFailure,
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
