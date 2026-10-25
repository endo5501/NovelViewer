// On-device check of how the Apple model answers a final-summary prompt that
// runs away on iPhone 16 (iOS 27.0.1): under its schema the model writes the
// summary, closes it with 」} where the string's own quotation mark belonged,
// and keeps writing inside the still-open string until the response cap. The
// framework then closes the object, so the answer parses. The same prompt
// does not run away on macOS 27.0.1 or iPadOS 26.6.2, so only a device
// carrying the iPhone's model shows it. See openspec change
// on-device-retry-runaway; the runs so far are in its measurements/.
//
// Each case goes through the package's method channel, as the app does, and
// is measured separately: the constrained request, the unconstrained request
// under greedy and under the default sampling, and what the client the app
// uses finally returns. A constrained answer counts as having run away when
// its field passes the client's response budget or contains a closing brace
// (design D2). Nothing here is judged against a threshold; the output is the
// record.
//
// Run with flutter drive. Needs Apple Intelligence enabled on the device. On a
// device every run ends with the app uninstalled and its data gone (see
// test_driver/), so back the reader's data up first (docs/ios.md):
//   device (needs profile mode, see test_driver/):
//     fvm flutter drive --profile --driver=test_driver/integration_test.dart \
//       --target=integration_test/on_device_llm_runaway_test.dart \
//       -d <device UDID>
//   macOS:
//     fvm flutter drive --driver=test_driver/integration_test.dart \
//       --target=integration_test/on_device_llm_runaway_test.dart -d macos
//
// Result: build/integration_response_data.json on the host, and printed line
// by line to the device log.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:foundation_models_llm/foundation_models_llm.dart';
import 'package:integration_test/integration_test.dart';
import 'package:novel_viewer/features/llm_summary/data/foundation_models_client.dart';
import 'package:novel_viewer/features/llm_summary/data/llm_prompt_builder.dart';
import 'package:novel_viewer/features/llm_summary/data/llm_summary_pipeline.dart';

const _word = '記憶人';

/// The facts the iPhone's run extracted, as it showed them.
const _facts = '''
-  〈記憶人〉とは別種名のひとつである。
-  〈記憶人〉は〈記憶人シィー〉という別種名を持つ。
-  〈記憶人〉は生まれがロンドンである。
-  〈記憶人〉は人口が少ない。
-  〈記憶人〉は非生殖性の別種である。''';

/// How many times the constrained request is made. On iPhone 16 (iOS 27.0.1)
/// it ran away on four to five attempts out of five; on macOS 27.0.1 it was
/// refused on about four out of five.
const _constrainedRuns = 5;

/// Characters of each answer's head and tail kept in the report. Enough to
/// see how it ended without the report growing with the response cap.
const _kept = 200;

/// The field value's length past which an answer counts as having run away:
/// the response budget the client declares (design D2).
final _budget = FoundationModelsClient(
  plugin: MethodChannelFoundationModelsLlm(),
).maxResponseSize;

/// The value of [fieldName] in a constrained answer, or null when the answer
/// does not decode to an object carrying it as a string.
String? _fieldValue(String answer, String fieldName) {
  try {
    final decoded = jsonDecode(answer);
    if (decoded is Map && decoded[fieldName] is String) {
      return decoded[fieldName] as String;
    }
  } on FormatException {
    return null;
  }
  return null;
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'on-device model answers the final-summary prompt',
    (tester) async {
      final plugin = MethodChannelFoundationModelsLlm();
      final availability = await plugin.availability();
      expect(
        availability,
        OnDeviceModelAvailability.available,
        reason: 'the on-device model is not available: $availability',
      );

      final prompt = LlmPromptBuilder.buildFinalSummaryPrompt(
        word: _word,
        facts: _facts,
      );
      final fieldName = LlmSummaryPipeline.summarySchema.fieldName;
      final cases = <Map<String, Object?>>[];

      void report() {
        binding.reportData = {
          'on_device_llm_runaway': {
            'operatingSystemVersion': Platform.operatingSystemVersion,
            'cases': cases,
          },
        };
      }

      Future<void> measure(String label, Future<String> Function() run) async {
        final watch = Stopwatch()..start();
        Map<String, Object?> outcome;
        try {
          final text = await run();
          final value = _fieldValue(text, fieldName);
          outcome = {
            'outcome': 'text',
            'length': text.length,
            if (value != null)
              'ranAway': value.length > _budget || value.contains('}'),
            'head': text.length <= _kept ? text : text.substring(0, _kept),
            if (text.length > _kept)
              'tail': text.substring(text.length - _kept),
          };
        } on OnDeviceGenerationException catch (e) {
          outcome = {'outcome': 'failure', 'cause': e.reason.name};
        } on Exception catch (e) {
          outcome = {'outcome': 'failure', 'cause': '$e'};
        }
        watch.stop();
        cases.add({
          'label': label,
          'elapsedMs': watch.elapsedMilliseconds,
          ...outcome,
        });
        report();
      }

      for (var i = 1; i <= _constrainedRuns; i++) {
        await measure(
          'constrained#$i',
          () => plugin.generate(
            prompt: prompt,
            schemaFieldName: fieldName,
            maxResponseTokens: FoundationModelsClient.maxResponseTokens,
          ),
        );
      }
      await measure(
        'unconstrained_greedy',
        () => plugin.generate(
          prompt: prompt,
          maxResponseTokens: FoundationModelsClient.maxResponseTokens,
          sampling: OnDeviceSampling.greedy,
        ),
      );
      await measure(
        'unconstrained_default_sampling',
        () => plugin.generate(
          prompt: prompt,
          maxResponseTokens: FoundationModelsClient.maxResponseTokens,
        ),
      );
      await measure(
        'client',
        () => FoundationModelsClient(
          plugin: plugin,
        ).generate(prompt, schema: LlmSummaryPipeline.summarySchema),
      );

      // Line by line: the device log truncates long lines.
      // ignore: avoid_print
      print('=== on-device LLM runaway ===');
      for (final c in cases) {
        // ignore: avoid_print
        print(jsonEncode(c));
      }
    },
    skip: !(Platform.isIOS || Platform.isMacOS),
    timeout: Timeout.none,
  );
}
