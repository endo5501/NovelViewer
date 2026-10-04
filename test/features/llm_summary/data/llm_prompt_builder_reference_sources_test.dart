import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/llm_summary/data/llm_prompt_builder.dart';

void main() {
  group('refinement prompt', () {
    test('is unchanged when source labels need no preserving', () {
      final defaulted = LlmPromptBuilder.buildFactRefinementPrompt(
        word: 'アリス',
        facts: '- f',
        maxResponseSize: 1000,
      );
      final explicit = LlmPromptBuilder.buildFactRefinementPrompt(
        word: 'アリス',
        facts: '- f',
        maxResponseSize: 1000,
        preserveSourceLabels: false,
      );
      expect(explicit, defaulted);
      expect(defaulted, isNot(contains('より:')));
    });

    test('asks to keep source labels and not to mix sources', () {
      final prompt = LlmPromptBuilder.buildFactRefinementPrompt(
        word: 'アリス',
        facts: '『第1部』より:\n- f',
        maxResponseSize: 1000,
        preserveSourceLabels: true,
      );
      expect(prompt, contains('出典ラベル'));
      expect(prompt, contains('『作品名』より:'));
      expect(prompt, contains('異なる出典'));
    });
  });

  group('final summary prompt', () {
    test('is unchanged when no reference sources are present', () {
      final defaulted = LlmPromptBuilder.buildFinalSummaryPrompt(
        word: 'アリス',
        facts: '- f',
      );
      final explicit = LlmPromptBuilder.buildFinalSummaryPrompt(
        word: 'アリス',
        facts: '- f',
        hasReferenceSources: false,
      );
      expect(explicit, defaulted);
      expect(defaulted, isNot(contains('本作')));
    });

    test('says unlabeled facts are this work and this work wins', () {
      final prompt = LlmPromptBuilder.buildFinalSummaryPrompt(
        word: 'アリス',
        facts: '『第1部』より:\n- f',
        hasReferenceSources: true,
      );
      expect(prompt, contains('ラベルの無い事実は本作'));
      expect(prompt, contains('本作の事実を優先'));
      expect(prompt, contains('混同しない'));
    });
  });
}
